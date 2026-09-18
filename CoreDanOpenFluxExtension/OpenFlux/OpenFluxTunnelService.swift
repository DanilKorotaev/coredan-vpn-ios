import Foundation
import NetworkExtension

/// Bridges NEPacketTunnelProvider packet flow to liboflux (OpenFluxStartPacketTunnel).
final class OpenFluxTunnelService {
    private let log = makeLogger(tag: .openflux)
    private weak var tunnel: NEPacketTunnelProvider?
    private var writeLoopRunning = false

    init(tunnel: NEPacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func start(transport: String, url: String, maxToken: String, maxUid: String, verbose: Bool) async throws {
        guard let tunnel else {
            throw OpenFluxTunnelError.tunnelDeallocated
        }

        // Always on for NE start path — file log may not flush if Go jetsams the process.
        OpenFluxSetDebug(1)
        log.releaseInfo("OpenFlux NE settings (transport=\(transport))")

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

        let rc = transport.withCString { tt in
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

        guard rc == 0 else {
            throw OpenFluxTunnelError.startFailed(Int(rc))
        }

        log.releaseInfo("OpenFlux packet tunnel started (\(transport))")
        startReadLoop()
        startWriteLoop()
    }

    func stop() {
        OpenFluxStopPacketTunnel()
        writeLoopRunning = false
        log.releaseInfo("OpenFlux packet tunnel stopped")
    }

    private func startReadLoop() {
        guard let tunnel else { return }
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

    private func startWriteLoop() {
        guard !writeLoopRunning else { return }
        writeLoopRunning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let maxLen: Int32 = 4096
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLen))
            defer { buf.deallocate() }
            while true {
                guard let self, self.writeLoopRunning else { break }
                let n = OpenFluxTunReadPacket(buf, maxLen)
                if n <= 0 { break }
                let data = Data(bytes: buf, count: Int(n))
                self.tunnel?.packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
            }
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
