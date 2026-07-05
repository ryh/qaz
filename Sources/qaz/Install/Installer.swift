import Foundation

enum InstallError: Error, LocalizedError {
    case permissionDenied(String)
    case installationFailed(String)
    case notSupported(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return "Permission denied: \(path). Try with sudo."
        case .installationFailed(let msg):
            return "Installation failed: \(msg)"
        case .notSupported(let msg):
            return "Not supported: \(msg)"
        }
    }
}

enum Installer {
    static func install(from sourcePath: String, verbose: Bool) throws {
        #if os(macOS)
        try installDarwin(from: sourcePath, verbose: verbose)
        #elseif os(Linux)
        try installLinux(from: sourcePath, verbose: verbose)
        #else
        throw InstallError.notSupported("Installation not supported on this platform")
        #endif
    }

    #if os(macOS)
    private static func installDarwin(from sourcePath: String, verbose: Bool) throws {
        let fileManager = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let sourceName = sourceURL.lastPathComponent

        if sourceName.hasSuffix(".dmg") {
            let mountPoint = try mountDMG(dmgPath: sourcePath, verbose: verbose)
            if verbose {
                print(Color.cyan("Mounted at: ") + mountPoint)
            }
            defer {
                unmountDMG(mountPoint: mountPoint)
            }
            try installFromDMG(mountPoint: mountPoint, verbose: verbose)
            return
        }

        if sourceName.hasSuffix(".app") || isAppBundle(path: sourcePath) {
            let appsDir = NSString(string: "~/Applications").expandingTildeInPath
            try fileManager.createDirectory(atPath: appsDir, withIntermediateDirectories: true)
            let dest = (appsDir as NSString).appendingPathComponent(sourceName)
            if fileManager.fileExists(atPath: dest) {
                try fileManager.removeItem(atPath: dest)
            }
            try fileManager.copyItem(atPath: sourcePath, toPath: dest)
            if verbose {
                print(Color.green("Installed to ") + dest)
            }
            return
        }

        if isDirectory(path: sourcePath) {
            let contents = try fileManager.contentsOfDirectory(atPath: sourcePath)

            for item in contents {
                let itemPath = (sourcePath as NSString).appendingPathComponent(item)
                if isAppBundle(path: itemPath) {
                    try installDarwin(from: itemPath, verbose: verbose)
                    return
                }
            }

            let executables = contents.filter { item in
                let itemPath = (sourcePath as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: itemPath, isDirectory: &isDir)
                return isExecutable(path: itemPath) && !isDir.boolValue
            }

            if executables.count == 1 {
                let execPath = (sourcePath as NSString).appendingPathComponent(executables[0])
                try installDarwin(from: execPath, verbose: verbose)
                return
            }

            if !executables.isEmpty {
                let binDir = NSString(string: "~/.local/bin").expandingTildeInPath
                try fileManager.createDirectory(atPath: binDir, withIntermediateDirectories: true)
                for exec in executables {
                    let execPath = (sourcePath as NSString).appendingPathComponent(exec)
                    let dest = (binDir as NSString).appendingPathComponent(exec)
                    if fileManager.fileExists(atPath: dest) {
                        try fileManager.removeItem(atPath: dest)
                    }
                    try fileManager.copyItem(atPath: execPath, toPath: dest)
                    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
                    if verbose {
                        print(Color.green("Installed ") + exec + " to " + dest)
                    }
                }
                return
            }

            let binDir = NSString(string: "~/.local/bin").expandingTildeInPath
            try fileManager.createDirectory(atPath: binDir, withIntermediateDirectories: true)
            let dest = (binDir as NSString).appendingPathComponent(sourceName)
            if fileManager.fileExists(atPath: dest) {
                try fileManager.removeItem(atPath: dest)
            }
            try fileManager.copyItem(atPath: sourcePath, toPath: dest)
            if verbose {
                print(Color.green("Installed to ") + dest)
            }
            return
        }

        let binDir = NSString(string: "~/.local/bin").expandingTildeInPath
        try fileManager.createDirectory(atPath: binDir, withIntermediateDirectories: true)
        let dest = (binDir as NSString).appendingPathComponent(sourceName)
        if fileManager.fileExists(atPath: dest) {
            try fileManager.removeItem(atPath: dest)
        }
        try fileManager.copyItem(atPath: sourcePath, toPath: dest)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
        if verbose {
            print(Color.green("Installed to ") + dest)
        }
    }

    private static func installFromDMG(mountPoint: String, verbose: Bool) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: mountPoint)
        for item in contents {
            if item.hasSuffix(".app") {
                let appPath = (mountPoint as NSString).appendingPathComponent(item)
                try installDarwin(from: appPath, verbose: verbose)
                return
            }
        }
        let executables = contents.filter { item in
            let itemPath = (mountPoint as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: itemPath, isDirectory: &isDir)
            return isExecutable(path: itemPath) && !isDir.boolValue
        }
        if executables.count == 1 {
            let execPath = (mountPoint as NSString).appendingPathComponent(executables[0])
            try installDarwin(from: execPath, verbose: verbose)
            return
        }
    }

    private static func mountDMG(dmgPath: String, verbose: Bool) throws -> String {
        if let existingMount = findExistingDMGMount(dmgPath: dmgPath) {
            if verbose {
                print(Color.yellow("DMG already mounted at ") + existingMount)
            }
            return existingMount
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgPath, "-nobrowse", "-quiet"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw InstallError.installationFailed("hdiutil attach failed")
        }
        return try findDMGMountPoint(dmgPath: dmgPath)
    }

    private static func findExistingDMGMount(dmgPath: String) -> String? {
        let fileManager = FileManager.default
        let dmgFileName = URL(fileURLWithPath: dmgPath).deletingPathExtension().lastPathComponent
        guard let volumes = try? fileManager.contentsOfDirectory(atPath: "/Volumes") else {
            return nil
        }
        for volume in volumes {
            if volume == dmgFileName || volume.hasPrefix(dmgFileName) || dmgFileName.hasPrefix(volume) {
                let mountPath = "/Volumes/\(volume)"
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: mountPath, isDirectory: &isDir), isDir.boolValue {
                    return mountPath
                }
            }
        }
        return nil
    }

    private static func findDMGMountPoint(dmgPath: String) throws -> String {
        let fileManager = FileManager.default
        let dmgFileName = URL(fileURLWithPath: dmgPath).deletingPathExtension().lastPathComponent

        guard let volumes = try? fileManager.contentsOfDirectory(atPath: "/Volumes") else {
            throw InstallError.installationFailed("Could not list /Volumes")
        }

        for volume in volumes {
            if volume == dmgFileName || volume.hasPrefix(dmgFileName) || dmgFileName.hasPrefix(volume) {
                let mountPath = "/Volumes/\(volume)"
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: mountPath, isDirectory: &isDir), isDir.boolValue {
                    return mountPath
                }
            }
        }

        throw InstallError.installationFailed("Could not find DMG mount point")
    }

    static func unmountDMG(mountPoint: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-quiet"]
        try? process.run()
        process.waitUntilExit()
    }
    #endif

    #if os(Linux)
    private static func installLinux(from sourcePath: String, verbose: Bool) throws {
        let fileManager = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let sourceName = sourceURL.lastPathComponent

        if isExecutable(path: sourcePath) || !isDirectory(path: sourcePath) {
            let binDir = NSString(string: "~/.local/bin").expandingTildeInPath
            try fileManager.createDirectory(atPath: binDir, withIntermediateDirectories: true)
            let dest = (binDir as NSString).appendingPathComponent(sourceName)
            if fileManager.fileExists(atPath: dest) {
                try fileManager.removeItem(atPath: dest)
            }
            try fileManager.copyItem(atPath: sourcePath, toPath: dest)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
            if verbose {
                print(Color.green("Installed to ") + dest)
            }
            return
        }

        if isDirectory(path: sourcePath) {
            let binDir = NSString(string: "~/.local/bin").expandingTildeInPath
            try fileManager.createDirectory(atPath: binDir, withIntermediateDirectories: true)
            let dest = (binDir as NSString).appendingPathComponent(sourceName)
            if fileManager.fileExists(atPath: dest) {
                try fileManager.removeItem(atPath: dest)
            }
            try fileManager.copyItem(atPath: sourcePath, toPath: dest)
            if verbose {
                print(Color.green("Installed to ") + dest)
            }
            return
        }
    }
    #endif

    private static func isAppBundle(path: String) -> Bool {
        let fileManager = FileManager.default
        guard path.hasSuffix(".app") else { return false }
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        let contents = (path as NSString).appendingPathComponent("Contents")
        return fileManager.fileExists(atPath: contents)
    }

    private static func isExecutable(path: String) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return false }
        return fileManager.isExecutableFile(atPath: path)
    }

    private static func isDirectory(path: String) -> Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
