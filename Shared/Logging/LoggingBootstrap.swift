import Foundation

/// Call once per process (app or packet tunnel extension) to enable file/console logging.
enum LoggingBootstrap {
    private static let lock = NSLock()
    private static var didStart = false

    static func startIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didStart else { return }
        didStart = true
        _ = UserDefaultsService.shared
        _ = LogFilesProvider.shared
        _ = LogSession.shared
        makeLogger(tag: .common).releaseInfo("Logging started (\(Bundle.main.bundleURL.lastPathComponent))")
    }
}
