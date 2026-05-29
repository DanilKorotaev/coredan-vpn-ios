import Foundation

protocol LoggerTagsProviderDescription: AnyObject {
    var tags: [LoggerTag] { get }
    func set(isEnabled: Bool, for tag: LoggerTag)
    func setAll(isEnabled: Bool)
    func resetToDefaults()
    func isEnabled(tag: LoggerTag) -> Bool
}

final class AppLoggerTagsProvider: LoggerTagsProviderDescription, ExcludedLoggerTagsProviderDescription {
    static let shared = AppLoggerTagsProvider()

    let tags: [LoggerTag]
    private(set) var excludedTags: Set<LoggerTag> = []

    private static let allTags: [LoggerTag] = [
        .common, .vpn, .tunnel, .libbox, .profile, .config, .debug, .userDefaultsService,
    ]

    private init() {
        tags = Self.allTags
        excludedTags = Set(tags.filter { !isEnabled(tag: $0) })
    }

    func set(isEnabled: Bool, for tag: LoggerTag) {
        UserDefaultsService.shared.set(isEnabled, forKey: storageKey(for: tag))
        if isEnabled {
            excludedTags.remove(tag)
        } else {
            excludedTags.insert(tag)
        }
    }

    func setAll(isEnabled: Bool) {
        tags.forEach { set(isEnabled: isEnabled, for: $0) }
    }

    func resetToDefaults() {
        tags.forEach { set(isEnabled: true, for: $0) }
    }

    func isEnabled(tag: LoggerTag) -> Bool {
        if UserDefaultsService.shared.object(forKey: storageKey(for: tag)) == nil {
            return true
        }
        return UserDefaultsService.shared.bool(forKey: storageKey(for: tag))
    }

    private func storageKey(for tag: LoggerTag) -> String {
        UserDefaultsKeyPrefix.loggerTag.appending(tag.rawValue) + ".enabled"
    }
}
