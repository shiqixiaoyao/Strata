//
//  LCUtilsExtensions.swift
//  LiveContainer
//
//  Created by s s on 2026/3/20.
//

import LocalAuthentication

// MARK: - 固定 key 的本地化查表

/// 用写死的 key 查 Localizable 表。
///
/// 带插值的字面量交给编译器抽取时，键名（%lld / %@ / %1$@ …）由它自己决定，跨 Xcode 版本还可能变化；
/// 这里把 key 固定下来，中文译文由 `Resources/Strata2-zh-Hans.xcstrings-fragment.json` 在构建前合并进 catalog。
/// `fallback` 是英文兜底文案，当 catalog 里没有该 key 时直接显示英文，避免把裸 key 暴露到界面上。
func LCStr(_ key: String, _ fallback: String) -> String {
    let value = key.loc
    return value == key ? fallback : value
}

/// 带格式参数的版本，`key` 对应的译文需包含相同数量的格式符（如 `%lld`、`%@`、`%1$@`）。
func LCStr(_ key: String, _ fallback: String, _ args: CVarArg...) -> String {
    String(format: LCStr(key, fallback), arguments: args)
}

extension LCUtils {
    public static let appGroupUserDefault = UserDefaults.init(suiteName: LCSharedUtils.appGroupID()) ?? UserDefaults.standard
    
    public static func signTweaks(tweakFolderUrl: URL, force : Bool = false, progressHandler : ((Progress) -> Void)? = nil) async throws {
        guard LCSharedUtils.certificatePassword() != nil else {
            return
        }
        let fm = FileManager.default
        // a disabled folder is renamed to .disabled; skip it, it gets signed again once re-enabled
        if !fm.fileExists(atPath: tweakFolderUrl.path) {
            let disabledUrl = tweakFolderUrl.deletingLastPathComponent().appendingPathComponent(tweakFolderUrl.lastPathComponent + ".disabled")
            if fm.fileExists(atPath: disabledUrl.path) {
                return
            }
        }
        var isFolder :ObjCBool = false
        if(fm.fileExists(atPath: tweakFolderUrl.path, isDirectory: &isFolder) && !isFolder.boolValue) {
            return
        }
        
        // check if re-sign is needed
        // if signature is invalid, we need to re-sign. dylib and framework's main binary are supported
        let fileURLs = try fm.contentsOfDirectory(at: tweakFolderUrl, includingPropertiesForKeys: nil)

        var filesToSign: [URL] = []
        
        for fileURL in fileURLs {
            var fileURL = fileURL
            let attributes = try fm.attributesOfItem(atPath: fileURL.path)
            let fileType = attributes[.type] as? FileAttributeType
            if(fileType != FileAttributeType.typeDirectory && fileType != FileAttributeType.typeRegular) {
                continue
            }
            let name = fileURL.lastPathComponent
            let baseName = name.hasSuffix(".disabled") ? String(name.dropLast(".disabled".count)) : name
            if(fileType == FileAttributeType.typeDirectory) {
                if(!baseName.hasSuffix(".framework")) {
                    continue
                }
                guard let frameworkBundle = Bundle(url: fileURL), let executableURL = frameworkBundle.executableURL else {
                    continue
                }
                fileURL = executableURL
            } else if (fileType == FileAttributeType.typeRegular && !baseName.hasSuffix(".dylib")) {
                continue
            }

            if !force, checkCodeSignature((fileURL.path as NSString).utf8String) {
                continue;
            }
            
            filesToSign.append(fileURL)
        }
        
        if filesToSign.isEmpty {
            return
        }
        
        for fileURL in filesToSign {
            LCPatchAppBundleFixupARM64eSlice(fileURL)
        }
        
        try await withUnsafeThrowingContinuation({ c in
            let progress = signFilesWithZSign(with: filesToSign) { success, error in
                if(success) {
                    c.resume()
                    return
                }
                
                guard let error else {
                    c.resume()
                    return
                }
                c.resume(throwing: error)
            }
            if let progress {
                progressHandler?(progress)
            }
        })
    }
        
    private static func authenticateUser(completion: @escaping (Bool, Error?) -> Void) {
        // Create a context for authentication
        let context = LAContext()
        var error: NSError?

        // Check if the device supports biometric authentication
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            // Determine the reason for the authentication request
            let reason = "lc.utils.requireAuthentication".loc

            // Evaluate the authentication policy
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evaluationError in
                DispatchQueue.main.async {
                    if success {
                        // Authentication successful
                        completion(true, nil)
                    } else {
                        if let evaluationError = evaluationError as? LAError, evaluationError.code == LAError.userCancel || evaluationError.code == LAError.appCancel {
                            completion(false, nil)
                        } else {
                            // Authentication failed
                            completion(false, evaluationError)
                        }

                    }
                }
            }
        } else {
            // Biometric authentication is not available
            DispatchQueue.main.async {
                if let evaluationError = error as? LAError, evaluationError.code == LAError.passcodeNotSet {
                    // No passcode set, we also define this as successful Authentication
                    completion(true, nil)
                } else {
                    completion(false, error)
                }

            }
        }
    }
    
    public static func authenticateUser() async throws -> Bool {
        if DataManager.shared.model.isHiddenAppUnlocked {
            return true
        }
        
        var success = false
        var error : Error? = nil
        await withUnsafeContinuation { c in
            LCUtils.authenticateUser { success1, error1 in
                success = success1
                error = error1
                c.resume()
            }
        }
        if let error = error {
            throw error
        }
        if !success {
            return false
        }
        DispatchQueue.main.async {
            DataManager.shared.model.isHiddenAppUnlocked = true
        }
        return true
    }
    
    public static func getStoreName() -> String {
        switch LCUtils.store() {
        case .AltStore:
            return "AltStore"
        case .SideStore:
            return "SideStore"
        case .ADP:
            return "ADP"
        default:
            return "Unknown Store".loc
        }
    }
    
    public static func removeAppKeychain(dataUUID label: String) {
        [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity].forEach {
          let status = SecItemDelete([
            kSecClass as String: $0,
            "alis": label,
          ] as CFDictionary)
          if status != errSecSuccess && status != errSecItemNotFound {
              //Error while removing class $0
              NSLog("[LC] Failed to find keychain items: \(status)")
          }
        }
    }
    
    public static func forEachInstalledLC(isFree: Bool, block: (String, inout Bool) -> Void) {
        for scheme in LCSharedUtils.lcUrlSchemes() {
            if scheme == UserDefaults.lcAppUrlScheme() {
                continue
            }
            
            // Check if the app is installed
            guard let url = URL(string: "\(scheme)://"),
                  UIApplication.shared.canOpenURL(url) else {
                continue
            }
            
            // Check shared utility logic
            if isFree && LCSharedUtils.isLCScheme(inUse: scheme) {
                continue
            }
            
            var shouldBreak = false
            block(scheme, &shouldBreak)
            
            if shouldBreak {
                break
            }
        }
    }
    
    public static func askForJIT(withScript script: String? = nil, appName: String? = nil, classicMode: UInt = 0, onServerMessage: ((String) -> Void)? = nil) async -> Bool {
        // if LiveContainer is installed by TrollStore
        let tsPath = "\(Bundle.main.bundlePath)/../_TrollStore"
        if (access((tsPath as NSString).utf8String, 0) == 0) {
            LCSharedUtils.launchToGuestApp(withClassicMode: classicMode)
            return true
        }
        
        guard let groupUserDefaults = UserDefaults(suiteName: LCSharedUtils.appGroupID()),
              let jitEnabler = JITEnablerType(rawValue: groupUserDefaults.integer(forKey: "LCJITEnablerType")) else {
            return false
        }
        
        if jitEnabler == .BuiltIn {
            onServerMessage?(LCStr("strata.jit.builtInRequiresLiveProcess", "Built-in JIT must launch into a LiveProcess guest. Return to the library and retry Launch with JIT."))
            return false
        }
        if(jitEnabler == .SideJITServer){
            guard
                  let sideJITServerAddress = groupUserDefaults.string(forKey: "LCSideJITServerAddress"),
                  let deviceUDID = groupUserDefaults.string(forKey: "LCDeviceUDID"),
                  !sideJITServerAddress.isEmpty && !deviceUDID.isEmpty else {
                return false
            }
            
            onServerMessage?(LCStr("strata.jit.vpnHint", "Please make sure the VPN is connected if the server is not in your local network."))
            
            do {
                let launchJITUrlStr = "\(sideJITServerAddress)/\(deviceUDID)/\(Bundle.main.bundleIdentifier ?? "")"
                guard let launchJITUrl = URL(string: launchJITUrlStr) else { return false }
                let session = URLSession.shared
                
                onServerMessage?(LCStr("strata.jit.contactSideJIT", "Contacting SideJITServer at %@...", sideJITServerAddress))
                let request = URLRequest(url: launchJITUrl)
                let (data, _) = try await session.data(for: request)
                onServerMessage?(String(decoding: data, as: UTF8.self))
                
            } catch {
                onServerMessage?(LCStr("strata.jit.contactSideJITFailed", "Failed to contact SideJITServer: %@", String(describing: error)))
            }
            
            return false
        } else if (jitEnabler == .JITStreamerEBLegacy) {
            var JITStresmerEBAddress = groupUserDefaults.string(forKey: "LCSideJITServerAddress") ?? ""
            if JITStresmerEBAddress.isEmpty {
                JITStresmerEBAddress = "http://[fd00::]:9172"
            }
            
            onServerMessage?(LCStr("strata.jit.vpnHint", "Please make sure the VPN is connected if the server is not in your local network."))
            
            do {
                
                onServerMessage?(LCStr("strata.jit.contactEB", "Contacting JitStreamer-EB server at %@...", JITStresmerEBAddress))
                
                let session = URLSession.shared
                let decoder = JSONDecoder()
                
                let mountStatusUrlStr = "\(JITStresmerEBAddress)/mount"
                guard let mountStatusUrl = URL(string: mountStatusUrlStr) else { return false }
                let mountRequest = URLRequest(url: mountStatusUrl)
                
                // check mount status
                onServerMessage?(LCStr("strata.jit.checkingMount", "Checking mount status..."))
                let (mountData, _) = try await session.data(for: mountRequest)
                let mountResponseObj = try decoder.decode(JITStreamerEBMountResponse.self, from: mountData)
                guard mountResponseObj.ok else {
                    onServerMessage?(mountResponseObj.error ?? LCStr("strata.jit.mountUnknownError", "Mounting failed with unknown error."))
                    return false
                }
                if mountResponseObj.mounting {
                    onServerMessage?(LCStr("strata.jit.mountingDdi", "Your device is currently mounting the developer disk image. Leave your device on and connected. Once this finishes, you can run JitStreamer again."))
                    onServerMessage?(LCStr("strata.jit.checkMountStatus", "Check %@/mount_status for mounting status.", JITStresmerEBAddress))
                    if let mountStatusUrl = URL(string: "\(JITStresmerEBAddress)/mount_status") {
                        await UIApplication.shared.open(mountStatusUrl)
                    }
                    return false
                }
                
                // open safari to use /launch_app api
                if let mountStatusUrl = URL(string: "\(JITStresmerEBAddress)/launch_app/\(Bundle.main.bundleIdentifier!)") {
                    onServerMessage?(LCStr("strata.jit.continueInBrowser", "JIT acquisition will continue in the default browser."))
                    await UIApplication.shared.open(mountStatusUrl)
                }
                return false
                
                
            } catch {
                onServerMessage?(LCStr("strata.jit.contactEBFailed", "Failed to contact JitStreamer-EB server: %@", String(describing: error)))
            }
        } else if jitEnabler == .StosDebug || jitEnabler == .StosDebugLC {
            guard let appName else { onServerMessage?(LCStr("strata.jit.noAppName", "Unable to get App Name, Please try again.")); return false }
            var launchURLStr = "stosdebug://enableJIT?bundleId=\(Bundle.main.bundleIdentifier!)&appName=\(appName)"
            
            if let script = script, !script.isEmpty {
                launchURLStr += "&script=\(script)"
            }
            
            if jitEnabler == .StosDebugLC {
                let encodedStr = Data(launchURLStr.utf8).base64EncodedString()


                var appToLaunch: LCAppModel? = nil
                // find an app that can respond to stikjit://
                appLoop:
                for app in DataManager.shared.model.apps {
                    if let schemes = app.appInfo.urlSchemes() {
                        for scheme in schemes {
                            if let scheme = scheme as? String, scheme == "stosdebug" {
                                appToLaunch = app
                                break appLoop
                            }
                        }
                    }
                }
                guard let appToLaunch else {
                    onServerMessage?(LCStr("strata.jit.stosDebugMissing", "StosDebug is not installed in LiveContainer."))
                    return false
                }
                
                if !appToLaunch.uiIsShared {
                    onServerMessage?(LCStr("strata.jit.stosDebugNotShared", "StosDebug is installed in LiveContainer, but is not a shared app. Convert it to a shared app to continue."))
                    return false
                }
                // check if stosdebug is already running
                var freeScheme = LCSharedUtils.getContainerUsingLCScheme(withFolderName: appToLaunch.uiDefaultDataFolder)
                
                if(freeScheme == nil) {
                    // if not, try to find a free lc
                    forEachInstalledLC(isFree: true) { scheme, shouldBreak in
                        freeScheme = scheme
                        shouldBreak = true
                    }
                }
                guard let freeScheme else {
                    onServerMessage?(LCStr("strata.jit.noFreeContainer", "No free LiveContainer is available. Please either: \n(1)close one, \n(2)install a new one, \n(3)choose another method to enable JIT."))
                    return false
                }
                
                let launchURL = URL(string: "\(freeScheme)://open-url?url=\(encodedStr)")!
                LCUtils.appGroupUserDefault.set(freeScheme, forKey: "LCLaunchExtensionScheme")
                LCUtils.appGroupUserDefault.set(appToLaunch.appInfo.relativeBundlePath, forKey: "LCLaunchExtensionBundleID")
                LCUtils.appGroupUserDefault.set(Date.now, forKey: "LCLaunchExtensionLaunchDate")
                onServerMessage?(LCStr("strata.jit.continueInAnotherLC", "JIT acquisition will continue in another LiveContainer."))
                
                await UIApplication.shared.open(launchURL)
            } else {
                onServerMessage?(LCStr("strata.jit.continueInStosDebug", "JIT acquisition will continue in StosDebug."))
                
                await UIApplication.shared.open(URL(string: launchURLStr)!)
            }
            
        } else if jitEnabler == .StikJIT || jitEnabler == .StikJITLC {
            var launchURLStr = "stikjit://enable-jit?bundle-id=\(Bundle.main.bundleIdentifier!)"

            if let script = script, !script.isEmpty {
                launchURLStr += "&script-data=\(script)"
            }
            let launchURL : URL
            if jitEnabler == .StikJITLC {
                let encodedStr = Data(launchURLStr.utf8).base64EncodedString()


                var appToLaunch: LCAppModel? = nil
                // find an app that can respond to stikjit://
                appLoop:
                for app in DataManager.shared.model.apps {
                    if let schemes = app.appInfo.urlSchemes() {
                        for scheme in schemes {
                            if let scheme = scheme as? String, scheme == "stikjit" {
                                appToLaunch = app
                                break appLoop
                            }
                        }
                    }
                }
                guard let appToLaunch else {
                    onServerMessage?(LCStr("strata.jit.stikDebugMissing", "StikDebug is not installed in LiveContainer."))
                    return false
                }
                
                if !appToLaunch.uiIsShared {
                    onServerMessage?(LCStr("strata.jit.stikDebugNotShared", "StikDebug is installed in LiveContainer, but is not a shared app. Convert it to a shared app to continue."))
                    return false
                }
                // check if stikdebug is already running
                var freeScheme = LCSharedUtils.getContainerUsingLCScheme(withFolderName: appToLaunch.uiDefaultDataFolder)
                
                if(freeScheme == nil) {
                    // if not, try to find a free lc
                    forEachInstalledLC(isFree: true) { scheme, shouldBreak in
                        freeScheme = scheme
                        shouldBreak = true
                    }
                }
                guard let freeScheme else {
                    onServerMessage?(LCStr("strata.jit.noFreeContainer", "No free LiveContainer is available. Please either: \n(1)close one, \n(2)install a new one, \n(3)choose another method to enable JIT."))
                    return false
                }
                
                launchURL = URL(string: "\(freeScheme)://open-url?url=\(encodedStr)")!
                LCUtils.appGroupUserDefault.set(freeScheme, forKey: "LCLaunchExtensionScheme")
                LCUtils.appGroupUserDefault.set(appToLaunch.appInfo.relativeBundlePath, forKey: "LCLaunchExtensionBundleID")
                LCUtils.appGroupUserDefault.set(Date.now, forKey: "LCLaunchExtensionLaunchDate")
                onServerMessage?(LCStr("strata.jit.continueInAnotherLC", "JIT acquisition will continue in another LiveContainer."))
                
            } else {
                launchURL = URL(string: launchURLStr)!
                onServerMessage?(LCStr("strata.jit.continueInStikDebug", "JIT acquisition will continue in StikDebug."))
            }
            await UIApplication.shared.open(launchURL)
        } else if jitEnabler == .SideStore {
            onServerMessage?(LCStr("strata.jit.continueInSideStore", "JIT acquisition will continue in SideStore."))
            let launchURL = URL(string: "sidestore://enable-jit?bundle-id=\(Bundle.main.bundleIdentifier!)")!
            await UIApplication.shared.open(launchURL)
        }
        return false
    }

    static func moveFilesAtomicallyAfterPreflight(_ moves: [(URL, URL)]) throws {
        let fileManager = FileManager.default

        var seenSources = Set<URL>()
        var seenDestinations = Set<URL>()

        let normalizedMoves = moves.map { source, destination in
            (
                source.standardizedFileURL,
                destination.standardizedFileURL
            )
        }

        // MARK: - Preflight

        for (source, destination) in normalizedMoves {
            guard !source.path.isEmpty else {
                throw BatchMoveError.emptySource(source)
            }

            guard source != destination else {
                throw BatchMoveError.sourceEqualsDestination(source)
            }

            guard seenSources.insert(source).inserted else {
                throw BatchMoveError.duplicateSource(source)
            }
            
            guard fileManager.isWritableFile(atPath: source.deletingLastPathComponent().path) else {
                throw BatchMoveError.sourceParentIsNotWritable(source.deletingLastPathComponent())
            }

            guard seenDestinations.insert(destination).inserted else {
                throw BatchMoveError.duplicateDestination(destination)
            }

            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
                throw BatchMoveError.sourceDoesNotExist(source)
            }

            do {
                _ = try source.checkResourceIsReachable()
            } catch {
                throw BatchMoveError.sourceIsNotReachable(source, underlying: error)
            }

            guard !fileManager.fileExists(atPath: destination.path) else {
                throw BatchMoveError.destinationAlreadyExists(destination)
            }

            let parent = destination.deletingLastPathComponent()

            var parentIsDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory) else {
                throw BatchMoveError.destinationParentDoesNotExist(parent)
            }

            guard parentIsDirectory.boolValue else {
                throw BatchMoveError.destinationParentIsNotDirectory(parent)
            }

            guard fileManager.isWritableFile(atPath: parent.path) else {
                throw BatchMoveError.destinationParentIsNotWritable(parent)
            }

            if isDirectory.boolValue {
                let sourcePath = source.path.hasSuffix("/") ? source.path : source.path + "/"
                let destinationPath = destination.path.hasSuffix("/") ? destination.path : destination.path + "/"

                if destinationPath.hasPrefix(sourcePath) {
                    throw BatchMoveError.moveWouldPlaceDirectoryInsideItself(
                        source: source,
                        destination: destination
                    )
                }
            }
        }

        // MARK: - Execute only after all preflight checks pass

        for (source, destination) in normalizedMoves {
            do {
                try fileManager.moveItem(at: source, to: destination)
            } catch {
                throw BatchMoveError.moveFailed(
                    source: source,
                    destination: destination,
                    underlying: error
                )
            }
        }
    }
    
    static func openSideStore(delegate: LCAppModelDelegate? = nil, urlStr: String? = nil) {
        let sideStoreApp = LCAppModel(appInfo: BuiltInSideStoreAppInfo.shared, delegate: delegate)
        
        Task {
            try await sideStoreApp.runApp(bundleIdOverride: "builtinSideStore", urlStr: urlStr)
        }
    }
}
