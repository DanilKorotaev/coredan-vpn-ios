import Foundation

protocol LoggerSettingsProviderDescription: AnyObject {
    var isDebugLogger: Bool { get }
    var isFileLoggerEnabled: Bool { get }
    var isVerboseLog: Bool { get }
}

protocol ExcludedLoggerTagsProviderDescription: AnyObject {
    var excludedTags: Set<LoggerTag> { get }
}

struct LoggerConfig {
    let excludedTagProvider: ExcludedLoggerTagsProviderDescription
    let settings: LoggerSettingsProviderDescription

    init(
        excludedTagProvider: ExcludedLoggerTagsProviderDescription,
        settings: LoggerSettingsProviderDescription
    ) {
        self.excludedTagProvider = excludedTagProvider
        self.settings = settings
    }
}

extension LoggerConfig {
    static let shared = LoggerConfig(
        excludedTagProvider: AppLoggerTagsProvider.shared,
        settings: AppLoggerSettings.shared
    )
}
