import Foundation

enum UserDefaultsValueType: String, CaseIterable, Identifiable {
    case string = "String"
    case bool = "Bool"
    case integer = "Int"
    case double = "Double"
    case date = "Date"
    case data = "Data"
    case json = "JSON"
    case unknown = "Unknown"

    var id: String { rawValue }

    static var addableCases: [UserDefaultsValueType] {
        [.string, .bool, .integer, .double, .date, .json]
    }
}

enum UserDefaultsKeyCategory: String, CaseIterable, Identifiable {
    case logs = "Logs"
    case loggerTags = "Logger Tags"
    case inspector = "Inspector"

    var id: String { rawValue }
    var title: String { rawValue }
}

struct KnownUserDefaultsKey: Identifiable, Hashable {
    let key: UserDefaultsKey
    let description: String
    let category: UserDefaultsKeyCategory
    let valueType: UserDefaultsValueType

    var id: String { key.rawValue }
}

struct KnownUserDefaultsPrefix: Hashable, Equatable {
    let prefix: UserDefaultsKeyPrefix
    let description: String
    let category: UserDefaultsKeyCategory
    let valueType: UserDefaultsValueType
}

enum UserDefaultsKeyRegistry {
    static let allKeys: [KnownUserDefaultsKey] = [
        .init(
            key: .loggerDebugConsole,
            description: "Log to console (os_log)",
            category: .logs,
            valueType: .bool
        ),
        .init(
            key: .loggerFileEnabled,
            description: "Log to file (App Group)",
            category: .logs,
            valueType: .bool
        ),
        .init(
            key: .loggerVerboseNetwork,
            description: "Verbose logs (reserved)",
            category: .logs,
            valueType: .bool
        ),
        .init(
            key: .loggerMaxLogFiles,
            description: "Max log files to keep on disk",
            category: .logs,
            valueType: .integer
        ),
        .init(
            key: .loggerSessionId,
            description: "Current log session UUID",
            category: .logs,
            valueType: .string
        ),
        .init(
            key: .inspectorVerboseLogging,
            description: "Verbose UserDefaults service logging",
            category: .inspector,
            valueType: .bool
        ),
        .init(
            key: .inspectorIgnoredUpdateKeys,
            description: "Keys ignored on write (inspector only)",
            category: .inspector,
            valueType: .json
        ),
    ]

    static let knownPrefixes: [KnownUserDefaultsPrefix] = [
        .init(
            prefix: .loggerTag,
            description: "Per-tag logger enable flag",
            category: .loggerTags,
            valueType: .bool
        ),
    ]

    static func knownKey(for key: String) -> KnownUserDefaultsKey? {
        if let exact = allKeys.first(where: { $0.key.rawValue == key }) {
            return exact
        }
        if let prefix = knownPrefixes.first(where: { key.hasPrefix($0.prefix.rawValue) }) {
            return KnownUserDefaultsKey(
                key: UserDefaultsKey(key),
                description: prefix.description,
                category: prefix.category,
                valueType: prefix.valueType
            )
        }
        return nil
    }
}
