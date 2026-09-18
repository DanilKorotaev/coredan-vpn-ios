import NetworkExtension

/// System VPN entry — aligned with upstream OpenFlux `ios-app/OpenFluxTunnel/PacketTunnelProvider.swift`.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let log = makeLogger(tag: .tunnel)
    private let sharedStore = SharedProfileStore()
    private lazy var openFluxService = OpenFluxTunnelService(tunnel: self)

    override init() {
        super.init()
        LoggingBootstrap.startIfNeeded()
    }

    override func startTunnel(options: [String: NSObject]?) async throws {
        try? sharedStore.clearLastTunnelError()

        let conf = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration ?? [:]
        let profile = try? sharedStore.readActiveProfile()

        let transport = (conf["transport"] as? String)
            ?? profile?.openfluxTransport
            ?? "vyandex"
        let url = (conf["url"] as? String)
            ?? profile?.openfluxURL
            ?? ""
        let maxToken = (conf["maxToken"] as? String) ?? ""
        let maxUid = (conf["maxUid"] as? String) ?? ""
        let verbose = (conf["debug"] as? Bool)
            ?? profile?.openfluxVerbose
            ?? false

        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let message = OpenFluxTunnelError.missingURL.localizedDescription ?? "missing URL"
            try? sharedStore.writeLastTunnelError(message)
            throw OpenFluxTunnelError.missingURL
        }

        log.releaseInfo("Starting OpenFlux tunnel transport=\(transport)")
        do {
            try await openFluxService.start(
                transport: transport,
                url: url,
                maxToken: maxToken,
                maxUid: maxUid,
                verbose: verbose
            )
            log.releaseInfo("OpenFlux tunnel started")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            try? sharedStore.writeLastTunnelError(message)
            log.releaseError("OpenFlux start failed: \(message)")
            throw error
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        log.releaseInfo("Stopping OpenFlux tunnel, reason: \(String(describing: reason))")
        openFluxService.stop()
    }
}
