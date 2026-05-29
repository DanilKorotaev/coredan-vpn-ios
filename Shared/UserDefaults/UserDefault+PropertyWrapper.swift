import Foundation

/// Usage: `@UserDefault(key: .loggerFileEnabled, defaultValue: true) var isFileLoggerEnabled: Bool`
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    init(key: UserDefaultsKey, defaultValue: T) {
        self.key = key.rawValue
        self.defaultValue = defaultValue
    }

    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            UserDefaultsService.shared.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaultsService.shared.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct UserDefaultWithSelf<Value, SelfType: AnyObject> {
    let key: String
    let defaultValue: (SelfType) -> Value
    weak var owner: SelfType?

    init(key: UserDefaultsKey, defaultValue: @escaping (SelfType) -> Value) {
        self.key = key.rawValue
        self.defaultValue = defaultValue
    }

    var wrappedValue: Value {
        get {
            guard let owner else { fatalError("UserDefaultWithSelf owner is not set") }
            return (UserDefaultsService.shared.object(forKey: key) as? Value) ?? defaultValue(owner)
        }
        set {
            UserDefaultsService.shared.set(newValue, forKey: key)
        }
    }

    static subscript(
        _enclosingInstance instance: SelfType,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<SelfType, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<SelfType, Self>
    ) -> Value {
        get {
            instance[keyPath: storageKeyPath].owner = instance
            return instance[keyPath: storageKeyPath].wrappedValue
        }
        set {
            instance[keyPath: storageKeyPath].owner = instance
            instance[keyPath: storageKeyPath].wrappedValue = newValue
        }
    }
}
