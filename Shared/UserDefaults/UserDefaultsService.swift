import Foundation

protocol UserDefaultsServiceSettingsDescription: AnyObject {
    var isVerboseLoggingEnabled: Bool { get }
    var ignoredAddOrUpdateKeys: [String] { get }
    func shouldIgnoreAddOrUpdate(for key: String) -> Bool
}

enum UserDefaultsServiceOperation: String {
    case object, value, string, array, dictionary, data, integer, bool, float, double, url, set, setValue, removeObject, removePersistentDomain, dictionaryRepresentation
}

struct UserDefaultsServiceEvent {
    let operation: UserDefaultsServiceOperation
    let key: String?
    let value: Any?
    let isWrite: Bool
    let isIgnored: Bool
}

extension Notification.Name {
    static let userDefaultsServiceDidHandleOperation = Notification.Name("cdvpn.userDefaultsService.didHandleOperation")
}

protocol UserDefaultsServiceDescription: AnyObject {
    func object(forKey key: String) -> Any?
    func object(forKey key: UserDefaultsKey) -> Any?
    func string(forKey key: String) -> String?
    func string(forKey key: UserDefaultsKey) -> String?
    func bool(forKey key: String) -> Bool
    func bool(forKey key: UserDefaultsKey) -> Bool
    func integer(forKey key: String) -> Int
    func integer(forKey key: UserDefaultsKey) -> Int
    func set(_ value: Any?, forKey key: String)
    func set(_ value: Any?, forKey key: UserDefaultsKey)
    func setValue(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    func removeObject(forKey key: UserDefaultsKey)
    func dictionaryRepresentation() -> [String: Any]
}

final class UserDefaultsService: UserDefaultsServiceDescription {
    static var shared: UserDefaultsServiceDescription = UserDefaultsService()

    private let storage: UserDefaults
    private let notificationCenter: NotificationCenter
    private let settings: UserDefaultsServiceSettingsDescription?

    init(
        storage: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        settings: UserDefaultsServiceSettingsDescription? = nil
    ) {
        self.storage = storage
        self.notificationCenter = notificationCenter
        self.settings = settings
    }

    func object(forKey key: String) -> Any? {
        let value = storage.object(forKey: key)
        postEvent(operation: .object, key: key, value: value, isWrite: false)
        return value
    }

    func object(forKey key: UserDefaultsKey) -> Any? { object(forKey: key.rawValue) }

    func string(forKey key: String) -> String? {
        let value = storage.string(forKey: key)
        postEvent(operation: .string, key: key, value: value, isWrite: false)
        return value
    }

    func string(forKey key: UserDefaultsKey) -> String? { string(forKey: key.rawValue) }

    func bool(forKey key: String) -> Bool {
        let value = storage.bool(forKey: key)
        postEvent(operation: .bool, key: key, value: value, isWrite: false)
        return value
    }

    func bool(forKey key: UserDefaultsKey) -> Bool { bool(forKey: key.rawValue) }

    func integer(forKey key: String) -> Int {
        let value = storage.integer(forKey: key)
        postEvent(operation: .integer, key: key, value: value, isWrite: false)
        return value
    }

    func integer(forKey key: UserDefaultsKey) -> Int { integer(forKey: key.rawValue) }

    func set(_ value: Any?, forKey key: String) {
        if shouldIgnoreWrite(forKey: key) {
            postEvent(operation: .set, key: key, value: value, isWrite: true, isIgnored: true)
            return
        }
        storage.set(value, forKey: key)
        postEvent(operation: .set, key: key, value: value, isWrite: true)
    }

    func set(_ value: Any?, forKey key: UserDefaultsKey) { set(value, forKey: key.rawValue) }

    func setValue(_ value: Any?, forKey key: String) {
        if shouldIgnoreWrite(forKey: key) {
            postEvent(operation: .setValue, key: key, value: value, isWrite: true, isIgnored: true)
            return
        }
        storage.setValue(value, forKey: key)
        postEvent(operation: .setValue, key: key, value: value, isWrite: true)
    }

    func removeObject(forKey key: String) {
        storage.removeObject(forKey: key)
        postEvent(operation: .removeObject, key: key, value: nil, isWrite: true)
    }

    func removeObject(forKey key: UserDefaultsKey) { removeObject(forKey: key.rawValue) }

    func dictionaryRepresentation() -> [String: Any] {
        let value = storage.dictionaryRepresentation()
        postEvent(operation: .dictionaryRepresentation, key: nil, value: "count=\(value.count)", isWrite: false)
        return value
    }

    private func postEvent(
        operation: UserDefaultsServiceOperation,
        key: String?,
        value: Any?,
        isWrite: Bool,
        isIgnored: Bool = false
    ) {
        let event = UserDefaultsServiceEvent(
            operation: operation,
            key: key,
            value: value,
            isWrite: isWrite,
            isIgnored: isIgnored
        )
        notificationCenter.post(
            name: .userDefaultsServiceDidHandleOperation,
            object: self,
            userInfo: ["event": event]
        )
    }

    private func shouldIgnoreWrite(forKey key: String) -> Bool {
        settings?.shouldIgnoreAddOrUpdate(for: key) ?? false
    }
}
