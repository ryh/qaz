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
        if lower.contains("freebsd") || lower.contains("openbsd") || lower.contains("netbsd") {
            return "BSD"
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
        if lower.contains("armv6") || lower.contains("armv7") || lower.contains("armhf") {
            return "arm"
        }
        if lower.contains("32-bit") || lower.contains("i386") || lower.contains("i686") {
            return "x86"
        }
        return ""
    }

    var isRecommended: Bool {
        guard size >= 100_000 else {
            return false
        }

        let platform = platformHint
        let arch = architectureHint

        guard !platform.isEmpty || !arch.isEmpty else {
            return false
        }

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
        let sizeStr = formatter.string(fromByteCount: Int64(size))
        if size == 0 && id < 0 {
            return "\(sizeStr) (size unavailable for source archives)"
        }
        return sizeStr
    }
}
