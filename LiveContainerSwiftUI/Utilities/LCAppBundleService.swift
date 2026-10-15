import Foundation
import UniformTypeIdentifiers

struct LCContainerManifestInfo: Codable, Hashable {
    var folderName: String
    var name: String
    var isDefault: Bool
    var isShared: Bool
    var isolateAppGroup: Bool
    var spoofIdentifierForVendor: Bool
    var spoofedIdentifier: String?
    var keychainGroupId: Int?

    init(
        folderName: String,
        name: String,
        isDefault: Bool = false,
        isShared: Bool = false,
        isolateAppGroup: Bool = false,
        spoofIdentifierForVendor: Bool = false,
        spoofedIdentifier: String? = nil,
        keychainGroupId: Int? = nil
    ) {
        self.folderName = folderName
        self.name = name
        self.isDefault = isDefault
        self.isShared = isShared
        self.isolateAppGroup = isolateAppGroup
        self.spoofIdentifierForVendor = spoofIdentifierForVendor
        self.spoofedIdentifier = spoofedIdentifier
        self.keychainGroupId = keychainGroupId
    }
}

struct LCBundleAppSettings: Codable {
    var isJITNeeded: Bool
    var classicMode: Bool
    var isLocked: Bool
    var isHidden: Bool
    var spoofSDKVersion: Bool
    var doSymlinkInbox: Bool
    var doUseLCBundleId: Bool
    var fixFilePickerNew: Bool
    var fixLocalNotification: Bool
    var hideLiveContainer: Bool
    var dontInjectTweakLoader: Bool
    var dontLoadTweakLoader: Bool
    var dontSign: Bool
    var orientationLock: Int
    var selectedLanguage: String?
    var selected32BitEmulator: String?
    var remark: String?
    var multitaskSpecified: Int
    var jitLaunchScriptJs: String?

    init(
        isJITNeeded: Bool = false,
        classicMode: Bool = false,
        isLocked: Bool = false,
        isHidden: Bool = false,
        spoofSDKVersion: Bool = true,
        doSymlinkInbox: Bool = false,
        doUseLCBundleId: Bool = false,
        fixFilePickerNew: Bool = false,
        fixLocalNotification: Bool = false,
        hideLiveContainer: Bool = false,
        dontInjectTweakLoader: Bool = false,
        dontLoadTweakLoader: Bool = false,
        dontSign: Bool = false,
        orientationLock: Int = 0,
        selectedLanguage: String? = nil,
        selected32BitEmulator: String? = nil,
        remark: String? = nil,
        multitaskSpecified: Int = 0,
        jitLaunchScriptJs: String? = nil
    ) {
        self.isJITNeeded = isJITNeeded
        self.classicMode = classicMode
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.spoofSDKVersion = spoofSDKVersion
        self.doSymlinkInbox = doSymlinkInbox
        self.doUseLCBundleId = doUseLCBundleId
        self.fixFilePickerNew = fixFilePickerNew
        self.fixLocalNotification = fixLocalNotification
        self.hideLiveContainer = hideLiveContainer
        self.dontInjectTweakLoader = dontInjectTweakLoader
        self.dontLoadTweakLoader = dontLoadTweakLoader
        self.dontSign = dontSign
        self.orientationLock = orientationLock
        self.selectedLanguage = selectedLanguage
        self.selected32BitEmulator = selected32BitEmulator
        self.remark = remark
        self.multitaskSpecified = multitaskSpecified
        self.jitLaunchScriptJs = jitLaunchScriptJs
    }
}

struct LCAppBundleManifest: Codable {
    var formatVersion: Int
    var bundleIdentifier: String
    var version: String
    var displayName: String
    var createdAt: Date?
    var liveContainerVersion: String?
    var hasAppBundle: Bool
    var appRelativePath: String?
    var defaultDataUUID: String?
    var containers: [LCContainerManifestInfo]
    var tweakFolder: String?
    var appSettings: LCBundleAppSettings?

    init(
        formatVersion: Int = 1,
        bundleIdentifier: String,
        version: String,
        displayName: String,
        createdAt: Date? = Date(),
        liveContainerVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        hasAppBundle: Bool = true,
        appRelativePath: String? = nil,
        defaultDataUUID: String? = nil,
        containers: [LCContainerManifestInfo] = [],
        tweakFolder: String? = nil,
        appSettings: LCBundleAppSettings? = nil
    ) {
        self.formatVersion = formatVersion
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.displayName = displayName
        self.createdAt = createdAt
        self.liveContainerVersion = liveContainerVersion
        self.hasAppBundle = hasAppBundle
        self.appRelativePath = appRelativePath
        self.defaultDataUUID = defaultDataUUID
        self.containers = containers
        self.tweakFolder = tweakFolder
        self.appSettings = appSettings
    }
}

struct LCBundleExportOptions {
    var includeAppBundle: Bool
    var includeData: Bool
    var selectedContainers: [LCContainer]
    var includeTweaks: Bool

    init(
        includeAppBundle: Bool = true,
        includeData: Bool = true,
        selectedContainers: [LCContainer] = [],
        includeTweaks: Bool = true
    ) {
        self.includeAppBundle = includeAppBundle
        self.includeData = includeData
        self.selectedContainers = selectedContainers
        self.includeTweaks = includeTweaks
    }
}

enum LCAppBundleError: LocalizedError {
    case noContentsSelected
    case sourceAppNotFound
    case compressionFailed
    case decompressionFailed
    case invalidManifest
    case appNotFoundInBundle
    case appNotInstalledForDataOnly(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noContentsSelected:
            return "lc.bundle.selectAtLeastOne".loc
        case .sourceAppNotFound:
            return "lc.appList.bundleNotFondError".loc
        case .compressionFailed:
            return "Failed to compress application bundle."
        case .decompressionFailed:
            return "Failed to decompress application bundle."
        case .invalidManifest:
            return "lc.bundle.invalidBundleError".loc
        case .appNotFoundInBundle:
            return "lc.appList.bundleNotFondError".loc
        case .appNotInstalledForDataOnly(let bundleId):
            return "lc.bundle.appNotInstalledError %@".localizeWithFormat(bundleId)
        case .cancelled:
            return "Operation cancelled."
        }
    }
}

final class LCAppBundleService {

    static func exportBundle(
        app: LCAppModel,
        options: LCBundleExportOptions,
        progress: Progress
    ) async throws -> URL {
        guard options.includeAppBundle || options.includeData else {
            throw LCAppBundleError.noContentsSelected
        }

        let fm = FileManager.default
        let exportTempDir = fm.temporaryDirectory.appendingPathComponent("LCExport_\(UUID().uuidString)", isDirectory: true)
        let stagingDir = exportTempDir.appendingPathComponent("staging", isDirectory: true)
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let appInfo = app.appInfo
        var exportedContainers: [LCContainerManifestInfo] = []

        // 1. Copy App Bundle
        var appRelativePath: String? = nil
        if options.includeAppBundle {
            guard let bundlePath = appInfo.bundlePath(), fm.fileExists(atPath: bundlePath) else {
                try? fm.removeItem(at: exportTempDir)
                throw LCAppBundleError.sourceAppNotFound
            }
            let payloadDir = stagingDir.appendingPathComponent("Payload", isDirectory: true)
            try fm.createDirectory(at: payloadDir, withIntermediateDirectories: true)

            let appDirName = URL(fileURLWithPath: bundlePath).lastPathComponent
            let destAppURL = payloadDir.appendingPathComponent(appDirName, isDirectory: true)
            try fm.copyItem(at: URL(fileURLWithPath: bundlePath), to: destAppURL)
            appRelativePath = appDirName
        }

        // 2. Copy Container Data
        if options.includeData {
            let containersToExport = options.selectedContainers.isEmpty ? app.uiContainers : options.selectedContainers
            if !containersToExport.isEmpty {
                let dataAppDir = stagingDir.appendingPathComponent("Data/Application", isDirectory: true)
                try fm.createDirectory(at: dataAppDir, withIntermediateDirectories: true)

                for container in containersToExport {
                    let containerURL = container.containerURL
                    if fm.fileExists(atPath: containerURL.path) {
                        let destURL = dataAppDir.appendingPathComponent(container.folderName, isDirectory: true)
                        try fm.copyItem(at: containerURL, to: destURL)

                        let isDefault = (container.folderName == app.uiDefaultDataFolder)
                        let containerManifest = LCContainerManifestInfo(
                            folderName: container.folderName,
                            name: container.name,
                            isDefault: isDefault,
                            isShared: container.isShared,
                            isolateAppGroup: container.isolateAppGroup,
                            spoofIdentifierForVendor: container.spoofIdentifierForVendor,
                            spoofedIdentifier: container.spoofedIdentifier,
                            keychainGroupId: container.keychainGroupId
                        )
                        exportedContainers.append(containerManifest)
                    }
                }
            }
        }

        // 3. Copy Tweaks
        var exportedTweakFolder: String? = nil
        if options.includeTweaks, let tweakFolder = app.uiTweakFolder, !tweakFolder.isEmpty {
            let tweakBase = app.uiIsShared ? LCPath.lcGroupTweakPath : LCPath.tweakPath
            let tweakURL = tweakBase.appendingPathComponent(tweakFolder)
            if fm.fileExists(atPath: tweakURL.path) {
                let tweaksDir = stagingDir.appendingPathComponent("Tweaks", isDirectory: true)
                try fm.createDirectory(at: tweaksDir, withIntermediateDirectories: true)
                let destTweakURL = tweaksDir.appendingPathComponent(tweakFolder, isDirectory: true)
                try fm.copyItem(at: tweakURL, to: destTweakURL)
                exportedTweakFolder = tweakFolder
            }
        }

        // 4. Create Settings Object
        let settings = LCBundleAppSettings(
            isJITNeeded: app.uiIsJITNeeded,
            classicMode: app.uiClassicMode,
            isLocked: app.uiIsLocked,
            isHidden: app.uiIsHidden,
            spoofSDKVersion: app.uiSpoofSDKVersion,
            doSymlinkInbox: app.uiDoSymlinkInbox,
            doUseLCBundleId: app.uiUseLCBundleId,
            fixFilePickerNew: app.uiFixFilePickerNew,
            fixLocalNotification: app.uiFixLocalNotification,
            hideLiveContainer: app.uiHideLiveContainer,
            dontInjectTweakLoader: app.uiDontInjectTweakLoader,
            dontLoadTweakLoader: app.uiDontLoadTweakLoader,
            dontSign: app.uiDontSign,
            orientationLock: app.uiOrientationLock.rawValue,
            selectedLanguage: app.uiSelectedLanguage,
            selected32BitEmulator: app.uiSelected32BitEmulator,
            remark: app.uiRemark,
            multitaskSpecified: app.uiIsMultitaskModeSpecificed.rawValue,
            jitLaunchScriptJs: app.jitLaunchScriptJs
        )

        // 5. Write manifest.json
        let manifest = LCAppBundleManifest(
            formatVersion: 1,
            bundleIdentifier: app.bundleIdentifier,
            version: app.version,
            displayName: app.displayName,
            createdAt: Date(),
            hasAppBundle: options.includeAppBundle,
            appRelativePath: appRelativePath,
            defaultDataUUID: app.uiDefaultDataFolder,
            containers: exportedContainers,
            tweakFolder: exportedTweakFolder,
            appSettings: settings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        let manifestURL = stagingDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestURL, options: .atomic)

        // 6. Compress to .lcbundle
        let rawDisplayName = app.displayName.replacingOccurrences(of: "/", with: "_").sanitizeNonACSII()
        let safeDisplayName = rawDisplayName.isEmpty ? "App" : rawDisplayName
        let bundleFileName = "\(safeDisplayName)_\(app.version).lcbundle"
        let outputZipURL = exportTempDir.appendingPathComponent(bundleFileName)

        let compressRes = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let code = compress_directory(stagingDir.path, outputZipURL.path, progress)
                continuation.resume(returning: code)
            }
        }

        try? fm.removeItem(at: stagingDir)

        guard compressRes == 0, fm.fileExists(atPath: outputZipURL.path) else {
            try? fm.removeItem(at: exportTempDir)
            throw LCAppBundleError.compressionFailed
        }

        return outputZipURL
    }

    static func readManifest(from bundleExtractURL: URL) -> LCAppBundleManifest? {
        let fm = FileManager.default
        let jsonURL = bundleExtractURL.appendingPathComponent("manifest.json")
        if fm.fileExists(atPath: jsonURL.path), let data = try? Data(contentsOf: jsonURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let manifest = try? decoder.decode(LCAppBundleManifest.self, from: data) {
                return manifest
            }
        }

        let plistURL = bundleExtractURL.appendingPathComponent("manifest.plist")
        if fm.fileExists(atPath: plistURL.path), let data = try? Data(contentsOf: plistURL) {
            let decoder = PropertyListDecoder()
            if let manifest = try? decoder.decode(LCAppBundleManifest.self, from: data) {
                return manifest
            }
        }

        return nil
    }

    static func findAppBundle(in bundleExtractURL: URL) async throws -> URL? {
        let fm = FileManager.default
        let payloadDir = bundleExtractURL.appendingPathComponent("Payload")

        // 1. Direct check in Payload/*.app
        if fm.fileExists(atPath: payloadDir.path),
           let contents = try? fm.contentsOfDirectory(atPath: payloadDir.path) {
            for item in contents {
                if item.hasSuffix(".app") {
                    return payloadDir.appendingPathComponent(item)
                }
            }
        }

        // 2. Check for an embedded .ipa in root or Payload/
        var ipaURL: URL? = nil
        if let rootContents = try? fm.contentsOfDirectory(atPath: bundleExtractURL.path) {
            for item in rootContents {
                if item.lowercased().hasSuffix(".ipa") || item.lowercased().hasSuffix(".tipa") {
                    ipaURL = bundleExtractURL.appendingPathComponent(item)
                    break
                }
            }
        }

        if ipaURL == nil, fm.fileExists(atPath: payloadDir.path),
           let payloadContents = try? fm.contentsOfDirectory(atPath: payloadDir.path) {
            for item in payloadContents {
                if item.lowercased().hasSuffix(".ipa") || item.lowercased().hasSuffix(".tipa") {
                    ipaURL = payloadDir.appendingPathComponent(item)
                    break
                }
            }
        }

        if let ipaURL {
            let dummyProgress = Progress.discreteProgress(totalUnitCount: 100)
            let ipaExtractRes = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let code = extract(ipaURL.path, bundleExtractURL.path, dummyProgress)
                    continuation.resume(returning: code)
                }
            }
            if ipaExtractRes == 0, fm.fileExists(atPath: payloadDir.path),
               let contents = try? fm.contentsOfDirectory(atPath: payloadDir.path) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        return payloadDir.appendingPathComponent(item)
                    }
                }
            }
        }

        // 3. Check directly in extracted root
        if let rootContents = try? fm.contentsOfDirectory(atPath: bundleExtractURL.path) {
            for item in rootContents {
                if item.hasSuffix(".app") {
                    return bundleExtractURL.appendingPathComponent(item)
                }
            }
        }

        return nil
    }

    static func restoreContainers(
        from bundleExtractURL: URL,
        manifest: LCAppBundleManifest?,
        bundleId: String,
        isShared: Bool
    ) throws -> (containers: [LCContainer], defaultUUID: String?) {
        let fm = FileManager.default
        let possibleDataDirs = [
            bundleExtractURL.appendingPathComponent("Data/Application"),
            bundleExtractURL.appendingPathComponent("Data"),
            bundleExtractURL.appendingPathComponent("Documents")
        ]

        var dataAppDir: URL? = nil
        for dir in possibleDataDirs {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                let contents = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
                if !contents.isEmpty {
                    dataAppDir = dir
                    break
                }
            }
        }

        guard let dataAppDir else {
            return ([], nil)
        }

        let containerFolders = (try? fm.contentsOfDirectory(atPath: dataAppDir.path)) ?? []
        let targetBasePath = isShared ? LCPath.lcGroupDataPath : LCPath.dataPath
        try fm.createDirectory(at: targetBasePath, withIntermediateDirectories: true)

        var restoredContainers: [LCContainer] = []
        let manifestContainersByFolder = Dictionary(
            (manifest?.containers ?? []).map { ($0.folderName, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for folder in containerFolders {
            let srcContainerURL = dataAppDir.appendingPathComponent(folder)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: srcContainerURL.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            let destContainerURL = targetBasePath.appendingPathComponent(folder)
            if fm.fileExists(atPath: destContainerURL.path) {
                try? fm.removeItem(at: destContainerURL)
            }
            try fm.moveItem(at: srcContainerURL, to: destContainerURL)

            let info = manifestContainersByFolder[folder]
            let containerName = info?.name ?? (folder.isEmpty ? "Default" : folder)
            let isolateAppGroup = info?.isolateAppGroup ?? false
            let spoofVendor = info?.spoofIdentifierForVendor ?? false
            let spoofedVendor = info?.spoofedIdentifier
            let keychainGroupId = info?.keychainGroupId ?? 0

            let container = LCContainer(
                folderName: folder,
                name: containerName,
                isShared: isShared,
                isolateAppGroup: isolateAppGroup,
                spoofIdentifierForVendor: spoofVendor
            )
            if let spoofedVendor {
                container.spoofedIdentifier = spoofedVendor
            }
            container.makeLCContainerInfoPlist(appIdentifier: bundleId, keychainGroupId: keychainGroupId)
            restoredContainers.append(container)
        }

        return (restoredContainers, manifest?.defaultDataUUID)
    }

    static func restoreTweaks(
        from bundleExtractURL: URL,
        manifest: LCAppBundleManifest?,
        isShared: Bool
    ) throws -> String? {
        let fm = FileManager.default
        let tweaksDir = bundleExtractURL.appendingPathComponent("Tweaks")
        guard fm.fileExists(atPath: tweaksDir.path) else {
            return nil
        }

        let tweakFolders = (try? fm.contentsOfDirectory(atPath: tweaksDir.path)) ?? []
        guard let tweakFolder = tweakFolders.first else {
            return nil
        }

        let srcTweakURL = tweaksDir.appendingPathComponent(tweakFolder)
        let targetBase = isShared ? LCPath.lcGroupTweakPath : LCPath.tweakPath
        try fm.createDirectory(at: targetBase, withIntermediateDirectories: true)

        let destTweakURL = targetBase.appendingPathComponent(tweakFolder)
        if fm.fileExists(atPath: destTweakURL.path) {
            try? fm.removeItem(at: destTweakURL)
        }
        try fm.moveItem(at: srcTweakURL, to: destTweakURL)
        return tweakFolder
    }

    static func applySettings(
        from settings: LCBundleAppSettings,
        to appInfo: LCAppInfo
    ) {
        appInfo.autoSaveDisabled = true
        appInfo.isJITNeeded = settings.isJITNeeded
        appInfo.classicMode = settings.classicMode
        appInfo.isLocked = settings.isLocked
        appInfo.isHidden = settings.isHidden
        appInfo.spoofSDKVersion = settings.spoofSDKVersion
        appInfo.doSymlinkInbox = settings.doSymlinkInbox
        appInfo.doUseLCBundleId = settings.doUseLCBundleId
        appInfo.fixFilePickerNew = settings.fixFilePickerNew
        appInfo.fixLocalNotification = settings.fixLocalNotification
        appInfo.hideLiveContainer = settings.hideLiveContainer
        appInfo.dontInjectTweakLoader = settings.dontInjectTweakLoader
        appInfo.dontLoadTweakLoader = settings.dontLoadTweakLoader
        appInfo.dontSign = settings.dontSign
        appInfo.orientationLock = LCOrientationLock(rawValue: settings.orientationLock) ?? .Disabled
        if let lang = settings.selectedLanguage, !lang.isEmpty {
            appInfo.selectedLanguage = lang
        }
        if let emu = settings.selected32BitEmulator, !emu.isEmpty {
            appInfo.selected32BitEmulator = emu
        }
        if let remark = settings.remark {
            appInfo.remark = remark
        }
        appInfo.multitaskSpecified = MultitaskSpecified(rawValue: settings.multitaskSpecified) ?? .default
        if let script = settings.jitLaunchScriptJs, !script.isEmpty {
            appInfo.jitLaunchScriptJs = script
        }
        appInfo.autoSaveDisabled = false
    }
}
