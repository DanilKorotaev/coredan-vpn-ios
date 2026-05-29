import Foundation

/// Log files in App Group (shared between app and packet tunnel extension) or app Documents.
final class LogFilesProvider {
    static let shared = LogFilesProvider(session: LogSession.shared)

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH_mm_ss"
        return formatter
    }()

    private let session: LogSession
    private let directoryName = "Logs"
    private let fileManager = FileManager.default
    private let processLabel: String

    private(set) var maxFileToStorage: Int {
        get {
            let stored = UserDefaultsService.shared.object(forKey: .loggerMaxLogFiles) as? Int
            return stored ?? Constants.maxFilesDefault
        }
        set {
            UserDefaultsService.shared.set(newValue, forKey: .loggerMaxLogFiles)
            removeLogFilesIfNeeded()
        }
    }

    var currentSessionLogFilePath: URL? {
        let dateText = Self.formatter.string(from: session.startedAt)
        let fileName = "\(processLabel)-\(session.id) \(dateText)"
        return logsDirectory()?
            .appendingPathComponent(fileName)
            .appendingPathExtension("log")
    }

    var logFileUrls: [URL] {
        guard let directory = logsDirectory(),
              let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }

        return files
            .filter { $0.pathExtension == "log" }
            .compactMap { url -> (URL, Date)? in
                guard let date = try? fileManager.attributesOfItem(atPath: url.path)[.creationDate] as? Date else {
                    return nil
                }
                return (url, date)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    init(session: LogSession, processLabel: String? = nil) {
        self.session = session
        if let processLabel {
            self.processLabel = processLabel
        } else if Bundle.main.bundlePath.hasSuffix(".appex") {
            self.processLabel = "tunnel"
        } else {
            self.processLabel = "app"
        }
        removeLogFilesIfNeeded()
    }

    func setMaxFileToStorage(_ maxCount: Int) throws {
        guard maxCount >= 0 else { throw LogFilesProviderError.invalidMaxCount }
        maxFileToStorage = maxCount
    }

    private func removeLogFilesIfNeeded() {
        let limit = max(1, maxFileToStorage)
        let files = logFileUrls
        guard files.count > limit else { return }
        files.suffix(from: limit).forEach { try? fileManager.removeItem(at: $0) }
    }

    private func logsDirectory() -> URL? {
        let base: URL?
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) {
            base = group
        } else if var documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let bundle = Bundle.main.bundleIdentifier {
                documents.appendPathComponent(bundle)
            }
            base = documents
        } else {
            base = nil
        }

        guard var directory = base else { return nil }
        directory.appendPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }
        return directory
    }

    private enum Constants {
        static let maxFilesDefault = 20
    }

    enum LogFilesProviderError: Error {
        case invalidMaxCount
    }
}
