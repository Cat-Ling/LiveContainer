#import <Foundation/Foundation.h>

extern int extract(NSString* fileToExtract, NSString* extractionPath, NSProgress* progress);
extern int compress_directory(NSString* sourceDirectory, NSString* outputZipPath, NSProgress* progress);
