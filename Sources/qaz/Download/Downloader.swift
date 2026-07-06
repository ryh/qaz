import Foundation

actor Downloader {
    private var receivedBytes: Int64 = 0
    private var totalBytes: Int64 = 0
    private var progressHandler: (@Sendable (Progress) -> Void)?

    struct Progress: Sendable {
        let received: Int64
        let total: Int64
        let percentage: Double
    }

    func download(url: String, fileName: String? = nil, to directory: String, quiet: Bool, verbose: Bool, progressHandler: @escaping @Sendable (Progress) -> Void) async throws -> String {
        guard let downloadURL = URL(string: url) else {
            throw URLError(.badURL)
        }

        let name = fileName ?? downloadURL.lastPathComponent
        let fileURL = URL(fileURLWithPath: directory).appendingPathComponent(name)
        self.progressHandler = progressHandler
        self.receivedBytes = 0
        self.totalBytes = 0

        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let delegate = DownloadDelegate(fileURL: fileURL) { [weak self] received, total in
            guard let self else { return }
            Task { @Sendable [weak self] in
                await self?.handleProgress(totalBytesWritten: received, totalBytesExpectedToWrite: total)
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let request = URLRequest(url: downloadURL)

        return try await withCheckedThrowingContinuation { continuation in
            delegate.setContinuation(continuation)
            session.downloadTask(with: request).resume()
        }
    }

    private func handleProgress(totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        receivedBytes = totalBytesWritten
        totalBytes = totalBytesExpectedToWrite

        let progress: Progress
        if totalBytes > 0 {
            progress = Progress(
                received: receivedBytes,
                total: totalBytes,
                percentage: Double(receivedBytes) / Double(totalBytes) * 100
            )
        } else {
            progress = Progress(
                received: receivedBytes,
                total: -1,
                percentage: 0
            )
        }
        progressHandler?(progress)
    }
}

final private class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let fileURL: URL
    nonisolated(unsafe) private var continuation: CheckedContinuation<String, Error>?
    private let progressCallback: @Sendable (Int64, Int64) -> Void

    init(fileURL: URL, progressCallback: @escaping @Sendable (Int64, Int64) -> Void) {
        self.fileURL = fileURL
        self.progressCallback = progressCallback
    }

    func setContinuation(_ c: CheckedContinuation<String, Error>) {
        self.continuation = c
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: fileURL.path) {
                try fm.removeItem(at: fileURL)
            }
            try fm.moveItem(at: location, to: fileURL)
            continuation?.resume(returning: fileURL.path)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progressCallback(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
