import Foundation

protocol UserDefaultsInspectorSettingsDescription: AnyObject, UserDefaultsServiceSettingsDescription {
    var isVerboseLoggingEnabled: Bool { get set }
    var ignoredAddOrUpdateKeys: [String] { get set }
}

final class UserDefaultsInspectorSettings: UserDefaultsInspectorSettingsDescription {
    static let shared = UserDefaultsInspectorSettings()

    @UserDefaultWithSelf(
        key: .inspectorVerboseLogging,
        defaultValue: { (_: UserDefaultsInspectorSettings) in true }
    )
    var isVerboseLoggingEnabled: Bool

    @UserDefault(key: .inspectorIgnoredUpdateKeys, defaultValue: [String]())
    var ignoredAddOrUpdateKeys: [String]

    private init() {}

    func shouldIgnoreAddOrUpdate(for key: String) -> Bool {
        if key == UserDefaultsKey.inspectorVerboseLogging.rawValue
            || key == UserDefaultsKey.inspectorIgnoredUpdateKeys.rawValue {
            return false
        }
        return ignoredAddOrUpdateKeys.contains(key)
    }
}
