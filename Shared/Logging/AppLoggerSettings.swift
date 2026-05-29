import Foundation

/// Logger settings persisted via `UserDefaultsService`.
final class AppLoggerSettings: LoggerSettingsProviderDescription {
    static let shared = AppLoggerSettings()

    @UserDefault(key: .loggerDebugConsole, defaultValue: true)
    var isDebugLogger: Bool

    @UserDefault(key: .loggerFileEnabled, defaultValue: true)
    var isFileLoggerEnabled: Bool

    @UserDefault(key: .loggerVerboseNetwork, defaultValue: false)
    var isVerboseLog: Bool

    private init() {}
}
