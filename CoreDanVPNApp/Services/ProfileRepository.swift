import Foundation

protocol ProfileRepositoryProtocol: Sendable {
    func loadProfiles() throws -> [ServerProfile]
    func saveProfiles(_ profiles: [ServerProfile]) throws
    func loadSelectedProfileID() -> UUID?
    func saveSelectedProfileID(_ id: UUID?)
}

/// Persists profile list in Keychain (generic passwords per profile id).
final class ProfileRepository: ProfileRepositoryProtocol, @unchecked Sendable {
    private let keychain: KeychainStoreProtocol
    private let selectedIDKey = "selected-profile-id"

    init(keychain: KeychainStoreProtocol = KeychainStore()) {
        self.keychain = keychain
    }

    func loadProfiles() throws -> [ServerProfile] {
        guard let data = try keychain.read(key: "profiles-list") else { return [] }
        return try JSONDecoder().decode([ServerProfile].self, from: data)
    }

    func saveProfiles(_ profiles: [ServerProfile]) throws {
        let data = try JSONEncoder().encode(profiles)
        try keychain.save(key: "profiles-list", data: data)
    }

    func loadSelectedProfileID() -> UUID? {
        guard let raw = try? keychain.readString(key: selectedIDKey) else { return nil }
        return UUID(uuidString: raw)
    }

    func saveSelectedProfileID(_ id: UUID?) {
        if let id {
            try? keychain.saveString(key: selectedIDKey, value: id.uuidString)
        } else {
            try? keychain.delete(key: selectedIDKey)
        }
    }
}
