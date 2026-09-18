import Foundation
import NetworkExtension

/// Bridges NEPacketTunnelFlow ↔ liboflux.
/// Logic mirrors upstream OpenFlux `ios-app/OpenFluxTunnel/PacketTunnelProvider.swift`
/// (network settings, bypass routes, read/write loops). Transport defaults to
/// `vyandex` because our exit is Volga; upstream UI defaults to `yandex`.
final class OpenFluxTunnelService {
    private let log = makeLogger(tag: .openflux)
    private let tunnel: NEPacketTunnelProvider

    init(tunnel: NEPacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func start(transport: String, url: String, maxToken: String, maxUid: String, verbose: Bool) async throws {
        if verbose {
            OpenFluxSetDebug(1)
        }
        log.releaseInfo("OpenFlux NE settings (transport=\(transport))")

        // Same virtual interface as upstream ios-app.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let ipv4 = NEIPv4Settings(addresses: ["10.10.10.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = OpenFluxBypassRoutes.ipv4
        settings.ipv4Settings = ipv4
        settings.mtu = 1500
        let dns = NEDNSSettings(servers: ["198.18.0.1"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        try await tunnel.setTunnelNetworkSettings(settings)
        log.releaseInfo("OpenFlux NE settings applied, calling liboflux…")

        // Volga Start() does network I/O — keep it off the cooperative pool that
        // services NE callbacks (upstream runs it inline on the completion queue).
        let rc: Int32 = await Task.detached(priority: .userInitiated) {
            transport.withCString { tt in
                url.withCString { u in
                    maxToken.withCString { tok in
                        maxUid.withCString { uid in
                            OpenFluxStartPacketTunnel(
                                UnsafeMutablePointer(mutating: tt),
                                UnsafeMutablePointer(mutating: u),
                                UnsafeMutablePointer(mutating: tok),
                                UnsafeMutablePointer(mutating: uid)
                            )
                        }
                    }
                }
            }
        }.value

        guard rc == 0 else {
            throw OpenFluxTunnelError.startFailed(Int(rc))
        }

        log.releaseInfo("OpenFlux packet tunnel started (\(transport))")
        startReadLoop()
        startWriteLoop()
    }

    func stop() {
        OpenFluxStopPacketTunnel()
        log.releaseInfo("OpenFlux packet tunnel stopped")
    }

    /// Device → Go (upstream `startReadLoop`).
    private func startReadLoop() {
        tunnel.packetFlow.readPackets { [weak self] packets, _ in
            guard let self else { return }
            for packet in packets {
                packet.withUnsafeBytes { raw in
                    if let base = raw.bindMemory(to: CChar.self).baseAddress {
                        OpenFluxTunWritePacket(UnsafeMutablePointer(mutating: base), Int32(packet.count))
                    }
                }
            }
            self.startReadLoop()
        }
    }

    /// Go → device (upstream `startWriteLoop`). Strongly retains `tunnel`
    /// for the lifetime of the blocking Go read, same as upstream `self`.
    private func startWriteLoop() {
        let packetFlow = tunnel.packetFlow
        let log = self.log
        DispatchQueue.global(qos: .userInitiated).async {
            let maxLen: Int32 = 4096
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLen))
            defer { buf.deallocate() }
            var written = 0
            while true {
                let n = OpenFluxTunReadPacket(buf, maxLen)
                // Upstream breaks on <=0. Our Go patch returns -1 on real stop
                // and skips empty frames internally; treat <=0 as end.
                if n <= 0 { break }
                let data = Data(bytes: buf, count: Int(n))
                packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
                written += 1
                if written == 1 || written % 500 == 0 {
                    log.releaseInfo("OpenFlux downlink packets written=\(written)")
                }
            }
            log.releaseInfo("OpenFlux write loop ended (written=\(written))")
        }
    }
}

enum OpenFluxTunnelError: LocalizedError {
    case tunnelDeallocated
    case startFailed(Int)
    case missingURL

    var errorDescription: String? {
        switch self {
        case .tunnelDeallocated:
            "OpenFlux tunnel deallocated"
        case let .startFailed(code):
            "OpenFlux start failed (code \(code))"
        case .missingURL:
            "Нет URL документа OpenFlux"
        }
    }
}
