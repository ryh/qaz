import Foundation

actor Downloader: NSObject, URLSessionDownloadDelegate {
    private var receivedBytes: Int64 = 0
    private var totalBytes: Int64 = 0
    private var progressHandler: (@Sendable (Progress) -> Void)?
    private var fileURL: URL?
    private var continuation: CheckedContinuation<String, Error>?

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
        self.fileURL = URL(fileURLWithPath: directory).appendingPathComponent(name)
        self.progressHandler = progressHandler
        self.receivedBytes = 0
        self.totalBytes = 0

        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let request = URLRequest(url: downloadURL)

        return try await withCheckedThrowingContinuation { continuation in
            Task { @Sendable [weak self] in
                await self?.setContinuation(continuation)
            }
            session.downloadTask(with: request).resume()
        }
    }

    private func setContinuation(_ c: CheckedContinuation<String, Error>) {
        self.continuation = c
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @Sendable in
            await self.handleDownloadComplete(location: location)
        }
    }

    private func handleDownloadComplete(location: URL) {
        guard let fileURL = fileURL else {
            continuation?.resume(throwing: URLError(.badURL))
            continuation = nil
            return
        }

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

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @Sendable in
            await self.handleProgress(totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
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

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @Sendable in
                await self.handleError(error)
            }
        }
    }

    private func handleError(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
