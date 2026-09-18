import Foundation
import NetworkExtension

/// Bridges NEPacketTunnelProvider packet flow to liboflux (OpenFluxStartPacketTunnel).
final class OpenFluxTunnelService {
    private let log = makeLogger(tag: .openflux)
    /// Strong retain while the tunnel is up — matches upstream OpenFlux write loop.
    private var tunnel: NEPacketTunnelProvider?
    private var writeLoopRunning = false
    private var heartbeat: DispatchSourceTimer?

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
        startHeartbeat()
        startReadLoop()
        startWriteLoop()
    }

    func stop() {
        heartbeat?.cancel()
        heartbeat = nil
        writeLoopRunning = false
        OpenFluxStopPacketTunnel()
        tunnel = nil
        log.releaseInfo("OpenFlux packet tunnel stopped")
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            self?.log.releaseInfo("OpenFlux heartbeat alive")
        }
        heartbeat = timer
        timer.resume()
    }

    private func startReadLoop() {
        guard let tunnel else { return }
        tunnel.packetFlow.readPackets { [weak self] packets, _ in
            guard let self else { return }
            for packet in packets {
                packet.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                    OpenFluxTunWritePacket(UnsafeMutablePointer(mutating: base), Int32(packet.count))
                }
            }
            self.startReadLoop()
        }
    }

    private func startWriteLoop() {
        guard !writeLoopRunning else { return }
        writeLoopRunning = true
        // Retain provider for the lifetime of the blocking Go read (upstream pattern).
        let tunnel = self.tunnel
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let maxLen: Int32 = 4096
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLen))
            defer { buf.deallocate() }
            var written = 0
            var emptySkips = 0
            while true {
                guard let self, self.writeLoopRunning else { break }
                let n = OpenFluxTunReadPacket(buf, maxLen)
                if n < 0 {
                    break
                }
                if n == 0 {
                    emptySkips += 1
                    if emptySkips == 1 || emptySkips % 50 == 0 {
                        self.log.releaseInfo("OpenFlux TunRead empty skip=\(emptySkips)")
                    }
                    continue
                }
                emptySkips = 0
                let data = Data(bytes: buf, count: Int(n))
                tunnel?.packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
                written += 1
                if written == 1 || written % 200 == 0 {
                    self.log.releaseInfo("OpenFlux downlink packets written=\(written)")
                }
            }
            self?.log.releaseInfo("OpenFlux write loop ended (written=\(written))")
            self?.writeLoopRunning = false
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
