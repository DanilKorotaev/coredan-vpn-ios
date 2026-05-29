import Foundation

protocol SharedProfileStoreProtocol: Sendable {
    func writeActiveProfile(_ profile: ServerProfile, singBoxJSON: String) throws
    func readActiveProfile() throws -> ServerProfile?
    func readSingBoxConfig() throws -> String?
    func writeLastTunnelError(_ message: String) throws
    func readLastTunnelError() throws -> String?
    func clearLastTunnelError() throws
}

/// Writes profile + generated sing-box config into the App Group container for the tunnel extension.
final class SharedProfileStore: SharedProfileStoreProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private var containerURL: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier)
    }

    func writeActiveProfile(_ profile: ServerProfile, singBoxJSON: String) throws {
        guard let base = containerURL else {
            throw SharedProfileStoreError.appGroupUnavailable
        }
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        let profileURL = base.appendingPathComponent(AppConstants.profileFileName)
        let configURL = base.appendingPathComponent(AppConstants.singBoxConfigFileName)
        let profileData = try encoder.encode(profile)
        try profileData.write(to: profileURL, options: .atomic)
        try singBoxJSON.data(using: .utf8)?.write(to: configURL, options: .atomic)
    }

    func readActiveProfile() throws -> ServerProfile? {
        guard let base = containerURL else { throw SharedProfileStoreError.appGroupUnavailable }
        let url = base.appendingPathComponent(AppConstants.profileFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(ServerProfile.self, from: data)
    }

    func readSingBoxConfig() throws -> String? {
        guard let base = containerURL else { throw SharedProfileStoreError.appGroupUnavailable }
        let url = base.appendingPathComponent(AppConstants.singBoxConfigFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func writeLastTunnelError(_ message: String) throws {
        guard let base = containerURL else { throw SharedProfileStoreError.appGroupUnavailable }
        let url = base.appendingPathComponent(AppConstants.lastTunnelErrorFileName)
        try message.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    func readLastTunnelError() throws -> String? {
        guard let base = containerURL else { throw SharedProfileStoreError.appGroupUnavailable }
        let url = base.appendingPathComponent(AppConstants.lastTunnelErrorFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func clearLastTunnelError() throws {
        guard let base = containerURL else { throw SharedProfileStoreError.appGroupUnavailable }
        let url = base.appendingPathComponent(AppConstants.lastTunnelErrorFileName)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

enum SharedProfileStoreError: Error {
    case appGroupUnavailable
}
