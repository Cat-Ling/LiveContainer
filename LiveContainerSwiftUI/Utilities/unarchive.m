#import "unarchive.h"

#include "archive.h"
#include "archive_entry.h"
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>

static int
copy_data(struct archive *ar, struct archive *aw, NSProgress *progress)
{
  int r;
  const void *buff;
  size_t size;
  la_int64_t offset;

  for (;;) {
    r = archive_read_data_block(ar, &buff, &size, &offset);
    if (r == ARCHIVE_EOF)
      return (ARCHIVE_OK);
    if (r < ARCHIVE_OK)
      return (r);
    r = archive_write_data_block(aw, buff, size, offset);
    if (r < ARCHIVE_OK) {
      fprintf(stderr, "%s\n", archive_error_string(aw));
      return (r);
    }
    progress.completedUnitCount += size;
  }
}

int extract(NSString* fileToExtract, NSString* extractionPath, NSProgress* progress)
{
    struct archive *a;
    struct archive *ext;
    struct archive_entry *entry;
    int flags;
    int r;

    /* Select which attributes we want to restore. */
    flags = ARCHIVE_EXTRACT_TIME;
    flags |= ARCHIVE_EXTRACT_PERM;
    flags |= ARCHIVE_EXTRACT_ACL;
    flags |= ARCHIVE_EXTRACT_FFLAGS;

    // Calculate decompressed size
    a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    if ((r = archive_read_open_filename(a, fileToExtract.fileSystemRepresentation, 10240))) {
        archive_read_free(a);
        return 1;
    }
    while ((r = archive_read_next_header(a, &entry)) != ARCHIVE_EOF) {
        if (r < ARCHIVE_OK)
            fprintf(stderr, "%s\n", archive_error_string(a));
        if (r < ARCHIVE_WARN) {
            archive_read_close(a);
            archive_read_free(a);
            return 1;
        }
        progress.totalUnitCount += archive_entry_size(entry);
    }
    archive_read_close(a);
    archive_read_free(a);

    // Re-open the archive and extract
    a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    if ((r = archive_read_open_filename(a, fileToExtract.fileSystemRepresentation, 10240))) {
        archive_read_free(a);
        return 1;
    }
    ext = archive_write_disk_new();
    archive_write_disk_set_options(ext, flags);
    archive_write_disk_set_standard_lookup(ext);

    while ((r = archive_read_next_header(a, &entry)) != ARCHIVE_EOF) {
        if (r == ARCHIVE_EOF)
            break;
        if (r < ARCHIVE_OK)
            fprintf(stderr, "%s\n", archive_error_string(a));
        if (r < ARCHIVE_WARN)
            break;
        
        NSString* currentFile = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
        NSString* fullOutputPath = [extractionPath stringByAppendingPathComponent:currentFile];
        //printf("extracting %@ to %@\n", currentFile, fullOutputPath);
        archive_entry_set_pathname(entry, fullOutputPath.fileSystemRepresentation);
        
        r = archive_write_header(ext, entry);
        if (r < ARCHIVE_OK)
            fprintf(stderr, "%s\n", archive_error_string(ext));
        else if (archive_entry_size(entry) > 0) {
            r = copy_data(a, ext, progress);
            if (r < ARCHIVE_OK)
                fprintf(stderr, "%s\n", archive_error_string(ext));
            if (r < ARCHIVE_WARN)
                break;
        }
        r = archive_write_finish_entry(ext);
        if (r < ARCHIVE_OK)
            fprintf(stderr, "%s\n", archive_error_string(ext));
        if (r < ARCHIVE_WARN)
            break;
    }
    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);
    
    return 0;
}

int compress_directory(NSString* sourceDirectory, NSString* outputZipPath, NSProgress* progress)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:sourceDirectory isDirectory:&isDir] || !isDir) {
        return 1;
    }

    NSDirectoryEnumerator *sizeEnum = [fm enumeratorAtPath:sourceDirectory];
    int64_t totalBytes = 0;
    for (NSString *subpath in sizeEnum) {
        if (progress && progress.isCancelled) {
            return 1;
        }
        NSString *fullPath = [sourceDirectory stringByAppendingPathComponent:subpath];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        if ([attrs[NSFileType] isEqualToString:NSFileTypeRegular]) {
            totalBytes += [attrs[NSFileSize] longLongValue];
        }
    }
    if (progress) {
        progress.totalUnitCount = totalBytes > 0 ? totalBytes : 1;
        progress.completedUnitCount = 0;
    }

    struct archive *a = archive_write_new();
    if (!a) {
        return 1;
    }
    archive_write_set_format_zip(a);
    archive_write_zip_set_compression_deflate(a);

    int r = archive_write_open_filename(a, outputZipPath.fileSystemRepresentation);
    if (r != ARCHIVE_OK) {
        fprintf(stderr, "%s\n", archive_error_string(a));
        archive_write_free(a);
        return 1;
    }

    NSDirectoryEnumerator *fileEnum = [fm enumeratorAtPath:sourceDirectory];
    for (NSString *subpath in fileEnum) {
        if (progress && progress.isCancelled) {
            archive_write_close(a);
            archive_write_free(a);
            [fm removeItemAtPath:outputZipPath error:nil];
            return 1;
        }

        NSString *fullPath = [sourceDirectory stringByAppendingPathComponent:subpath];
        struct stat st;
        if (lstat(fullPath.fileSystemRepresentation, &st) != 0) {
            continue;
        }

        struct archive_entry *entry = archive_entry_new();
        if (!entry) {
            continue;
        }

        NSString *entryPath = subpath;
        if (S_ISDIR(st.st_mode) && ![entryPath hasSuffix:@"/"]) {
            entryPath = [entryPath stringByAppendingString:@"/"];
        }

        archive_entry_set_pathname(entry, entryPath.UTF8String);
        archive_entry_copy_stat(entry, &st);

        if (S_ISLNK(st.st_mode)) {
            char target[PATH_MAX];
            ssize_t len = readlink(fullPath.fileSystemRepresentation, target, sizeof(target) - 1);
            if (len != -1) {
                target[len] = '\0';
                archive_entry_set_symlink(entry, target);
            }
        }

        r = archive_write_header(a, entry);
        if (r < ARCHIVE_OK) {
            fprintf(stderr, "%s\n", archive_error_string(a));
        }

        if (S_ISREG(st.st_mode) && st.st_size > 0) {
            FILE *f = fopen(fullPath.fileSystemRepresentation, "rb");
            if (f) {
                char buffer[32768];
                size_t bytesRead;
                while ((bytesRead = fread(buffer, 1, sizeof(buffer), f)) > 0) {
                    if (progress && progress.isCancelled) {
                        break;
                    }
                    archive_write_data(a, buffer, bytesRead);
                    if (progress) {
                        progress.completedUnitCount += bytesRead;
                    }
                }
                fclose(f);
            }
        }

        archive_write_finish_entry(a);
        archive_entry_free(entry);
    }

    archive_write_close(a);
    archive_write_free(a);
    return 0;
}
