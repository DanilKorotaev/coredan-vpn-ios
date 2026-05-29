import Foundation

struct LoggerTag: Equatable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(for type: Any.Type) {
        rawValue = String(describing: type)
    }
}

extension LoggerTag {
    static let common = LoggerTag(rawValue: "Common")
    static let vpn = LoggerTag(rawValue: "VPN")
    static let tunnel = LoggerTag(rawValue: "Tunnel")
    static let libbox = LoggerTag(rawValue: "Libbox")
    static let profile = LoggerTag(rawValue: "Profile")
    static let config = LoggerTag(rawValue: "Config")
    static let debug = LoggerTag(rawValue: "Debug")
    static let userDefaultsService = LoggerTag(rawValue: "UserDefaultsService")
}
