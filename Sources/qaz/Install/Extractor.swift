import Foundation

enum ExtractError: Error, LocalizedError {
    case unsupportedFormat(String)
    case extractionFailed(String)
    case noAppFound

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported archive format: \(ext)"
        case .extractionFailed(let msg):
            return "Extraction failed: \(msg)"
        case .noAppFound:
            return "No .app bundle found in archive"
        }
    }
}

enum Extractor {
    static func extract(archivePath: String, verbose: Bool) throws -> String {
        let fileManager = FileManager.default
        let archiveURL = URL(fileURLWithPath: archivePath)
        let ext = archiveURL.pathExtension.lowercased()
        let fileName = archiveURL.lastPathComponent.lowercased()

        if ext == "dmg" || ext == "pkg" || ext == "deb" || ext == "rpm" {
            return archivePath
        }

        let extractDir = archiveURL.deletingLastPathComponent().appendingPathComponent("extracted_\(archiveURL.deletingPathExtension().lastPathComponent)")
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

        if fileName.hasSuffix(".tar.gz") || fileName.hasSuffix(".tgz") {
            try extractTarGz(archivePath: archivePath, to: extractDir.path, verbose: verbose)
        } else if fileName.hasSuffix(".tar.xz") {
            try extractTarXz(archivePath: archivePath, to: extractDir.path, verbose: verbose)
        } else if fileName.hasSuffix(".tar.bz2") {
            try extractTarBz2(archivePath: archivePath, to: extractDir.path, verbose: verbose)
        } else if ext == "zip" {
            try extractZip(archivePath: archivePath, to: extractDir.path, verbose: verbose)
        } else {
            throw ExtractError.unsupportedFormat(ext)
        }

        return findMainContent(in: extractDir.path, verbose: verbose) ?? extractDir.path
    }

    private static func extractTarGz(archivePath: String, to destination: String, verbose: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", archivePath, "-C", destination]
        process.standardOutput = verbose ? FileHandle.standardOutput : nil
        process.standardError = verbose ? FileHandle.standardError : nil
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExtractError.extractionFailed("tar exited with status \(process.terminationStatus)")
        }
    }

    private static func extractTarXz(archivePath: String, to destination: String, verbose: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xJf", archivePath, "-C", destination]
        process.standardOutput = verbose ? FileHandle.standardOutput : nil
        process.standardError = verbose ? FileHandle.standardError : nil
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExtractError.extractionFailed("tar exited with status \(process.terminationStatus)")
        }
    }

    private static func extractTarBz2(archivePath: String, to destination: String, verbose: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xjf", archivePath, "-C", destination]
        process.standardOutput = verbose ? FileHandle.standardOutput : nil
        process.standardError = verbose ? FileHandle.standardError : nil
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExtractError.extractionFailed("tar exited with status \(process.terminationStatus)")
        }
    }

    private static func extractZip(archivePath: String, to destination: String, verbose: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", archivePath, "-d", destination]
        process.standardOutput = verbose ? FileHandle.standardOutput : nil
        process.standardError = verbose ? FileHandle.standardError : nil
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExtractError.extractionFailed("unzip exited with status \(process.terminationStatus)")
        }
    }

    private static func mountDMG(dmgPath: String, verbose: Bool) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgPath, "-nobrowse", "-quiet"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExtractError.extractionFailed("hdiutil attach failed")
        }

        let mountPoint = try findDMGMountPoint(dmgPath: dmgPath)
        return mountPoint
    }

    private static func findDMGMountPoint(dmgPath: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["info", "-plist"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let images = plist?["images"] as? [[String: Any]] ?? []

        for image in images {
            if let systemEntities = image["system-entity"] as? [[String: Any]] {
                for entity in systemEntities {
                    if let mountPoint = entity["mount-point"] as? String {
                        if mountPoint.contains(dmgPath.replacingOccurrences(of: ".dmg", with: "")) {
                            return mountPoint
                        }
                    }
                }
            }
        }

        let fileManager = FileManager.default
        let volumes = try? fileManager.contentsOfDirectory(atPath: "/Volumes")
        if let lastVolume = volumes?.last {
            return "/Volumes/\(lastVolume)"
        }

        throw ExtractError.extractionFailed("Could not find DMG mount point")
    }

    static func unmountDMG(mountPoint: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-quiet"]
        try? process.run()
        process.waitUntilExit()
    }

    private static func findMainContent(in directory: String, verbose: Bool) -> String? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        for item in contents {
            if item.hasSuffix(".app") {
                return (directory as NSString).appendingPathComponent(item)
            }
        }

        let executables = contents.filter { item in
            let path = (directory as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: path, isDirectory: &isDir)
            return !isDir.boolValue && isExecutable(path: path)
        }

        if executables.count == 1 {
            return (directory as NSString).appendingPathComponent(executables[0])
        }

        if contents.count == 1 {
            let singleItem = (directory as NSString).appendingPathComponent(contents[0])
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: singleItem, isDirectory: &isDir), isDir.boolValue {
                return singleItem
            }
        }

        return nil
    }

    private static func isExecutable(path: String) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return false }
        return fileManager.isExecutableFile(atPath: path)
    }
}
