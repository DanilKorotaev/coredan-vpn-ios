import Foundation
import NetworkExtension

enum VPNStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)
}

protocol VPNControllerProtocol: Sendable {
    func status() async -> VPNStatus
    func connect(profile: ServerProfile, singBoxJSON: String) async throws
    func disconnect() async throws
    func lastTunnelError() async -> String?
}

/// Manages `NETunnelProviderManager` for the packet tunnel extension.
final class VPNController: VPNControllerProtocol, @unchecked Sendable {
    private let log = makeLogger(tag: .vpn)
    private let sharedStore: SharedProfileStoreProtocol
    private let bundleIdentifier: String

    init(
        sharedStore: SharedProfileStoreProtocol = SharedProfileStore(),
        bundleIdentifier: String = AppConstants.tunnelProviderBundleIdentifier
    ) {
        self.sharedStore = sharedStore
        self.bundleIdentifier = bundleIdentifier
    }

    func status() async -> VPNStatus {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            guard let manager = managers.first(where: { tunnelBundleID($0) == bundleIdentifier }),
                  let connection = manager.connection as? NETunnelProviderSession else {
                return .disconnected
            }
            switch connection.status {
            case .connected: return .connected
            case .connecting, .reasserting: return .connecting
            case .disconnecting: return .disconnecting
            case .disconnected: return .disconnected
            case .invalid: return .error("Invalid tunnel session")
            @unknown default: return .disconnected
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func connect(profile: ServerProfile, singBoxJSON: String) async throws {
        log.releaseInfo("Connect \(profile.name) \(profile.host):\(profile.port)")
        try sharedStore.writeActiveProfile(profile, singBoxJSON: singBoxJSON)

        let manager = try await loadOrCreateManager()
        manager.isEnabled = true
        let proto = manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = bundleIdentifier
        proto.serverAddress = profile.host
        proto.providerConfiguration = ["profileName": profile.name]
        if #available(iOS 16.4, *) {
            proto.includeAllNetworks = true
            proto.enforceRoutes = true
        }
        manager.protocolConfiguration = proto
        manager.localizedDescription = profile.name
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        let startOptions: [String: NSObject] = [
            "configContent": singBoxJSON as NSString,
            "manualStart": NSNumber(value: true),
        ]
        try manager.connection.startVPNTunnel(options: startOptions)

        try await waitForTunnelSession(manager: manager, timeoutSeconds: 12)
        log.releaseInfo("Tunnel status: \(manager.connection.status.rawValue)")
    }

    func lastTunnelError() async -> String? {
        let stored: String? = try? sharedStore.readLastTunnelError()
        if let message = stored, !message.isEmpty {
            return message
        }
        return await fetchDisconnectError()
    }

    func disconnect() async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let manager = managers.first(where: { tunnelBundleID($0) == bundleIdentifier }) else {
            return
        }
        manager.connection.stopVPNTunnel()
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existing = managers.first(where: { tunnelBundleID($0) == bundleIdentifier }) {
            return existing
        }
        let manager = NETunnelProviderManager()
        return manager
    }

    private func tunnelBundleID(_ manager: NETunnelProviderManager) -> String? {
        (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
    }

    private func waitForTunnelSession(manager: NETunnelProviderManager, timeoutSeconds: Int) async throws {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        let startedAt = Date()
        while Date() < deadline {
            switch manager.connection.status {
            case .connected:
                return
            case .disconnected, .invalid:
                // Ignore a brief initial disconnected state right after startVPNTunnel().
                if Date().timeIntervalSince(startedAt) > 2 {
                    if let message = await lastTunnelError() {
                        throw VPNControllerError.tunnelFailed(message)
                    }
                    throw VPNControllerError.tunnelFailed("Туннель отключился сразу после запуска")
                }
            case .connecting, .reasserting, .disconnecting:
                break
            @unknown default:
                break
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        if manager.connection.status != .connected {
            throw VPNControllerError.tunnelFailed("Таймаут подключения (\(timeoutSeconds) с)")
        }
    }

    private func fetchDisconnectError() async -> String? {
        let managers = try? await NETunnelProviderManager.loadAllFromPreferences()
        guard let manager = managers?.first(where: { tunnelBundleID($0) == bundleIdentifier }),
              let session = manager.connection as? NETunnelProviderSession else {
            return nil
        }
        if #available(iOS 16.0, *) {
            do {
                try await session.fetchLastDisconnectError()
            } catch {
                return error.localizedDescription
            }
        }
        return nil
    }
}

enum VPNControllerError: LocalizedError {
    case tunnelFailed(String)

    var errorDescription: String? {
        switch self {
        case let .tunnelFailed(message): message
        }
    }
}
