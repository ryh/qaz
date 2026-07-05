import Foundation

struct Asset: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let browserDownloadURL: String
    let digest: String?
    let size: Int
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case id, name, size
        case browserDownloadURL = "browser_download_url"
        case digest
        case contentType = "content_type"
    }

    var platformHint: String {
        let lower = name.lowercased()
        if lower.contains("darwin") || lower.contains("macos") || lower.contains("osx") {
            return "macOS"
        }
        if lower.hasSuffix(".dmg") || lower.hasSuffix(".app.zip") {
            return "macOS"
        }
        if lower.contains("linux") || lower.contains("ubuntu") || lower.contains("debian") {
            return "Linux"
        }
        if lower.hasSuffix(".deb") || lower.hasSuffix(".rpm") || lower.hasSuffix(".pkg.tar.zst") {
            return "Linux"
        }
        if lower.contains("win") || lower.contains("windows") {
            return "Windows"
        }
        return ""
    }

    var architectureHint: String {
        let lower = name.lowercased()
        if lower.contains("arm64") || lower.contains("aarch64") {
            return "arm64"
        }
        if lower.contains("x86_64") || lower.contains("amd64") || lower.contains("x64") {
            return "x86_64"
        }
        return ""
    }

    var isRecommended: Bool {
        let platform = platformHint
        let arch = architectureHint

        #if os(macOS)
        guard platform == "macOS" || platform.isEmpty else {
            return false
        }
        #elseif os(Linux)
        guard platform == "Linux" || platform.isEmpty else {
            return false
        }
        #endif

        #if arch(arm64)
        return arch == "arm64" || arch.isEmpty
        #elseif arch(x86_64)
        return arch == "x86_64" || arch.isEmpty
        #else
        return true
        #endif
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
