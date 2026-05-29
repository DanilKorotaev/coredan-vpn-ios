import Foundation

final class FileLogger: Logger, @unchecked Sendable {
    static let shared = FileLogger(fileProvider: .shared)

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private let fileProvider: LogFilesProvider
    private let lock = NSLock()
    private var cachedWriter: FileBatchWriter?
    private var cachedWriterURL: URL?

    private init(fileProvider: LogFilesProvider) {
        self.fileProvider = fileProvider
    }

    func log(_ message: Any?, level: LogLevel, buildLevel: LogBuildLevel) {
        guard let message, let writer = writer() else { return }
        let dateText = Self.formatter.string(from: Date())
        let logMessage = "\(dateText): \(prepare(message))\n"
        writer.write(logMessage)
    }

    func tag(_ tag: LoggerTag) -> Logger { self }

    /// Re-create writer when session file path changes (e.g. after toggling file logging).
    func resetWriter() {
        lock.lock()
        cachedWriter?.close()
        cachedWriter = nil
        cachedWriterURL = nil
        lock.unlock()
    }

    private func writer() -> FileBatchWriter? {
        guard let url = fileProvider.currentSessionLogFilePath else { return nil }
        lock.lock()
        defer { lock.unlock() }
        if cachedWriterURL != url {
            cachedWriter?.close()
            cachedWriter = FileBatchWriter(url: url, batchCapacity: 1)
            cachedWriterURL = url
        }
        return cachedWriter
    }

    private func prepare(_ message: Any) -> String {
        if let error = message as? Error {
            return prepareError(error)
        }
        return "\(message)"
    }

    private func prepareError(_ error: Error) -> String {
        let nsError = error as NSError
        var result: [String] = []
        result.append("Code : \(nsError.code)")
        result.append("Description : \(nsError.localizedDescription)")
        if let reason = nsError.localizedFailureReason {
            result.append("Reason : \(reason)")
        }
        result.append("UserInfo : \(nsError.userInfo.description)")
        return result.joined(separator: "\n")
    }
}
