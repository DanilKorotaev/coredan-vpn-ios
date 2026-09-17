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

/// Manages `NETunnelProviderManager` for Libbox and OpenFlux packet tunnel extensions.
final class VPNController: VPNControllerProtocol, @unchecked Sendable {
    private let log = makeLogger(tag: .vpn)
    private let sharedStore: SharedProfileStoreProtocol

    init(sharedStore: SharedProfileStoreProtocol = SharedProfileStore()) {
        self.sharedStore = sharedStore
    }

    func status() async -> VPNStatus {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            let ours = managers.filter { isOurTunnel($0) }
            if ours.isEmpty { return .disconnected }

            // Prefer any connected / in-flight session.
            var sawConnecting = false
            var sawDisconnecting = false
            for manager in ours {
                guard let connection = manager.connection as? NETunnelProviderSession else { continue }
                switch connection.status {
                case .connected:
                    return .connected
                case .connecting, .reasserting:
                    sawConnecting = true
                case .disconnecting:
                    sawDisconnecting = true
                case .invalid:
                    return .error("Invalid tunnel session")
                case .disconnected:
                    break
                @unknown default:
                    break
                }
            }
            if sawConnecting { return .connecting }
            if sawDisconnecting { return .disconnecting }
            return .disconnected
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func connect(profile: ServerProfile, singBoxJSON: String) async throws {
        switch profile.kind {
        case .shadowsocks:
            log.releaseInfo("Connect SS \(profile.name) \(profile.host):\(profile.port)")
            try sharedStore.writeActiveProfile(profile, singBoxJSON: singBoxJSON)
            try await startTunnel(
                bundleIdentifier: AppConstants.tunnelProviderBundleIdentifier,
                profile: profile,
                providerConfiguration: ["profileName": profile.name, "kind": "shadowsocks"],
                startOptions: [
                    "configContent": singBoxJSON as NSString,
                    "manualStart": NSNumber(value: true),
                ]
            )
        case .openflux:
            let url = profile.openfluxURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !url.isEmpty else {
                throw VPNControllerError.tunnelFailed("Нет URL документа OpenFlux")
            }
            let transport = profile.openfluxTransport ?? "vyandex"
            log.releaseInfo("Connect OpenFlux \(profile.name) transport=\(transport)")
            try sharedStore.writeActiveProfile(profile, singBoxJSON: "")
            var conf: [String: Any] = [
                "profileName": profile.name,
                "kind": "openflux",
                "transport": transport,
                "url": url,
                "codec": profile.openfluxCodec ?? "legacy",
                "maxToken": "",
                "maxUid": "",
                "debug": profile.openfluxVerbose == true,
            ]
            try await startTunnel(
                bundleIdentifier: AppConstants.openFluxTunnelProviderBundleIdentifier,
                profile: profile,
                providerConfiguration: conf,
                startOptions: [
                    "manualStart": NSNumber(value: true),
                    "kind": "openflux" as NSString,
                ]
            )
        }
    }

    func lastTunnelError() async -> String? {
        let stored: String? = try? sharedStore.readLastTunnelError()
        if let message = stored, !message.isEmpty {
            return message
        }
        return await fetchDisconnectError()
    }

    /// Stops every CoreDan tunnel and disables On Demand so Control Center
    /// disconnect cannot bounce the VPN back on.
    func disconnect() async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        for manager in managers where isOurTunnel(manager) {
            await hardenDisabled(manager)
            manager.connection.stopVPNTunnel()
            try await manager.saveToPreferences()
        }
        log.releaseInfo("Disconnected all CoreDan tunnels")
    }

    // MARK: - Private

    private func startTunnel(
        bundleIdentifier: String,
        profile: ServerProfile,
        providerConfiguration: [String: Any],
        startOptions: [String: NSObject]
    ) async throws {
        try await disableOtherTunnels(except: bundleIdentifier)

        let manager = try await loadOrCreateManager(bundleIdentifier: bundleIdentifier)
        await hardenDisabled(manager) // clear any leftover On Demand before enabling
        manager.isEnabled = true
        manager.isOnDemandEnabled = false
        manager.onDemandRules = []

        let proto = manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = bundleIdentifier
        proto.serverAddress = profile.kind == .openflux ? "OpenFlux" : profile.host
        proto.providerConfiguration = providerConfiguration
        if #available(iOS 16.4, *) {
            // Keep false for OpenFlux so Control Center disconnect is reliable;
            // SS still captures full traffic via sing-box TUN.
            proto.includeAllNetworks = profile.kind == .shadowsocks
            proto.enforceRoutes = profile.kind == .shadowsocks
        }
        manager.protocolConfiguration = proto
        manager.localizedDescription = profile.name
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        try manager.connection.startVPNTunnel(options: startOptions)

        try await waitForTunnelSession(manager: manager, timeoutSeconds: 20)
        log.releaseInfo("Tunnel status: \(manager.connection.status.rawValue)")
    }

    private func disableOtherTunnels(except bundleIdentifier: String) async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        for manager in managers where isOurTunnel(manager) {
            guard tunnelBundleID(manager) != bundleIdentifier else { continue }
            await hardenDisabled(manager)
            manager.connection.stopVPNTunnel()
            try await manager.saveToPreferences()
        }
    }

    private func hardenDisabled(_ manager: NETunnelProviderManager) async {
        manager.isOnDemandEnabled = false
        manager.onDemandRules = []
        manager.isEnabled = false
    }

    private func loadOrCreateManager(bundleIdentifier: String) async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existing = managers.first(where: { tunnelBundleID($0) == bundleIdentifier }) {
            return existing
        }
        return NETunnelProviderManager()
    }

    private func isOurTunnel(_ manager: NETunnelProviderManager) -> Bool {
        guard let id = tunnelBundleID(manager) else { return false }
        return AppConstants.allTunnelProviderBundleIdentifiers.contains(id)
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
        let ours = managers?.filter { isOurTunnel($0) } ?? []
        for manager in ours {
            guard let session = manager.connection as? NETunnelProviderSession else { continue }
            if #available(iOS 16.0, *) {
                do {
                    try await session.fetchLastDisconnectError()
                } catch {
                    return error.localizedDescription
                }
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
