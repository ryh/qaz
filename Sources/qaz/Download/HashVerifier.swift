import Foundation
import CryptoKit

enum HashError: Error, LocalizedError {
    case noDigest
    case mismatch(expected: String, actual: String)
    case fileError(Error)

    var errorDescription: String? {
        switch self {
        case .noDigest:
            return "No digest available for verification"
        case .mismatch(let expected, let actual):
            return """
            Hash verification FAILED!
            Expected: \(expected)
            Actual:   \(actual)
            The downloaded file may be corrupted or tampered with.
            """
        case .fileError(let err):
            return "Failed to read file: \(err.localizedDescription)"
        }
    }
}

enum HashVerifier {
    static func verify(filePath: String, expectedDigest: String?) async throws {
        guard let digestStr = expectedDigest else {
            throw HashError.noDigest
        }

        let expectedHash = parseDigest(digestStr)

        let computedHash = try computeSHA256(filePath: filePath)

        guard computedHash == expectedHash else {
            let fileManager = FileManager.default
            try? fileManager.removeItem(atPath: filePath)
            throw HashError.mismatch(expected: expectedHash, actual: computedHash)
        }
    }

    private static func parseDigest(_ digest: String) -> String {
        if digest.hasPrefix("sha256:") {
            return String(digest.dropFirst(7))
        }
        return digest
    }

    private static func computeSHA256(filePath: String) throws -> String {
        let fileURL = URL(fileURLWithPath: filePath)

        guard let inputStream = InputStream(url: fileURL) else {
            throw HashError.fileError(NSError(domain: "HashVerifier", code: 1))
        }

        inputStream.open()
        defer { inputStream.close() }

        var hasher = SHA256()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                throw HashError.fileError(NSError(domain: "HashVerifier", code: 2))
            }
            if bytesRead == 0 { break }
            let data = Data(bytes: buffer, count: bytesRead)
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
