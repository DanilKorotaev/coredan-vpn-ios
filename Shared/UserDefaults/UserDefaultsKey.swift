import Foundation

struct UserDefaultsKey: ExpressibleByStringLiteral, Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

struct UserDefaultsKeyPrefix: Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    func appending(_ suffix: String) -> String {
        rawValue + suffix
    }
}

extension UserDefaultsKey {
    static let loggerDebugConsole = UserDefaultsKey("cdvpn.logger.isDebugLogger")
    static let loggerFileEnabled = UserDefaultsKey("cdvpn.logger.isFileLoggerEnabled")
    static let loggerVerboseNetwork = UserDefaultsKey("cdvpn.logger.isVerboseLog")
    static let loggerMaxLogFiles = UserDefaultsKey("cdvpn.logger.maxFilesToStorage")
    static let loggerSessionId = UserDefaultsKey("cdvpn.logger.session.currentId")

    static let inspectorVerboseLogging = UserDefaultsKey("cdvpn.userdefaults.inspector.verboseLogging")
    static let inspectorIgnoredUpdateKeys = UserDefaultsKey("cdvpn.userdefaults.inspector.ignoredUpdateKeys")
}

extension UserDefaultsKeyPrefix {
    static let loggerTag = UserDefaultsKeyPrefix("cdvpn.logger.tag.")
}
