import Foundation

final class UserDefaultsInspectorLogger {
    static let shared = UserDefaultsInspectorLogger()

    private lazy var logger = makeLogger(tag: .userDefaultsService)
    private let processingQueue = DispatchQueue(
        label: "com.coredan.CoreDanVPN.UserDefaultsInspectorLogger.queue",
        qos: .utility
    )
    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?
    private let isVerboseLoggingEnabled: Bool
    private let ignoredKeys: [UserDefaultsKey] = [
        .loggerDebugConsole,
        .loggerFileEnabled,
        .loggerVerboseNetwork,
        .loggerMaxLogFiles,
        .loggerSessionId,
    ]

    private init(
        settings: UserDefaultsServiceSettingsDescription = UserDefaultsInspectorSettings.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.isVerboseLoggingEnabled = settings.isVerboseLoggingEnabled
        self.notificationCenter = notificationCenter
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }

    func start() {
        guard observer == nil else {
            return
        }

        observer = notificationCenter.addObserver(
            forName: .userDefaultsServiceDidHandleOperation,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.processingQueue.async {
                self?.handle(notification)
            }
        }
    }

    private func handle(_ notification: Notification) {
        guard
            let event = notification.userInfo?["event"] as? UserDefaultsServiceEvent,
            !ignoredKeys.contains(where: { $0.rawValue == event.key })
        else {
            return
        }
        let operation = event.isWrite ? "write" : "read"
        let ignoredSuffix = event.isIgnored ? " [ignored]" : ""
        if isVerboseLoggingEnabled, let valueDescription = makeValueDescription(from: event.value) {
            logger.debugInfo("[\(operation)] \(event.operation.rawValue)\(ignoredSuffix) key=\(event.key ?? "nil") value=\n\(valueDescription)")
        } else {
            logger.debugInfo("[\(operation)] \(event.operation.rawValue)\(ignoredSuffix) key=\(event.key ?? "nil")")
        }
    }

    private func makeValueDescription(from value: Any?) -> String? {
        guard let value else {
            return nil
        }
        return UserDefaultsDebugValueCodec.makeSnapshot(from: value).valuePreviewText
    }
}
