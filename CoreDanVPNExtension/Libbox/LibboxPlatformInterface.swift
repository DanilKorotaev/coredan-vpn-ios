import Foundation
import Libbox
import Network
import NetworkExtension

/// sing-box platform hooks for iOS Network Extension (Libbox v1.13+).
final class LibboxPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    private let log = makeLogger(tag: .libbox)
    private weak var tunnel: PacketTunnelProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var pathMonitor: NWPathMonitor?

    init(tunnel: PacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func reset() {
        networkSettings = nil
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    // MARK: - TUN

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try libboxRunBlocking { [self] in
            try await openTunAsync(options, ret0_: ret0_)
        }
    }

    private func openTunAsync(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) async throws {
        guard let options, let ret0_, let tunnel else {
            throw NSError(domain: "LibboxPlatformInterface", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Missing TUN options or tunnel",
            ])
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())

            let dnsBox = try options.getDNSServerAddress()
            if !dnsBox.value.isEmpty {
                let servers = dnsBox.value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if !servers.isEmpty {
                    settings.dnsSettings = NEDNSSettings(servers: servers)
                }
            }

            var ipv4Address: [String] = []
            var ipv4Mask: [String] = []
            let addrIter = options.getInet4Address()!
            while addrIter.hasNext() {
                let prefix = addrIter.next()!
                ipv4Address.append(prefix.address())
                ipv4Mask.append(prefix.mask())
            }

            let ipv4 = NEIPv4Settings(addresses: ipv4Address, subnetMasks: ipv4Mask)
            var routes: [NEIPv4Route] = []
            let routeIter = options.getInet4RouteAddress()!
            if routeIter.hasNext() {
                while routeIter.hasNext() {
                    let prefix = routeIter.next()!
                    routes.append(NEIPv4Route(
                        destinationAddress: prefix.address(),
                        subnetMask: prefix.mask()
                    ))
                }
            } else {
                routes.append(NEIPv4Route.default())
            }
            ipv4.includedRoutes = routes
            settings.ipv4Settings = ipv4

            let v6Iter = options.getInet6Address()!
            if v6Iter.hasNext() {
                var ipv6Address: [String] = []
                var ipv6Prefixes: [NSNumber] = []
                while v6Iter.hasNext() {
                    let prefix = v6Iter.next()!
                    ipv6Address.append(prefix.address())
                    ipv6Prefixes.append(NSNumber(value: prefix.prefix()))
                }
                let ipv6 = NEIPv6Settings(addresses: ipv6Address, networkPrefixLengths: ipv6Prefixes)
                var v6Routes: [NEIPv6Route] = []
                let v6RouteIter = options.getInet6RouteAddress()!
                if v6RouteIter.hasNext() {
                    while v6RouteIter.hasNext() {
                        let prefix = v6RouteIter.next()!
                        v6Routes.append(NEIPv6Route(
                            destinationAddress: prefix.address(),
                            networkPrefixLength: NSNumber(value: prefix.prefix())
                        ))
                    }
                } else {
                    v6Routes.append(NEIPv6Route.default())
                }
                ipv6.includedRoutes = v6Routes
                settings.ipv6Settings = ipv6
            }
        }

        if options.isHTTPProxyEnabled() {
            let proxy = NEProxySettings()
            let server = NEProxyServer(
                address: options.getHTTPProxyServer(),
                port: Int(options.getHTTPProxyServerPort())
            )
            proxy.httpServer = server
            proxy.httpsServer = server
            proxy.httpEnabled = true
            proxy.httpsEnabled = true
            settings.proxySettings = proxy
        }

        networkSettings = settings
        try await tunnel.setTunnelNetworkSettings(settings)

        if let fd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }
        let fd = LibboxGetTunnelFileDescriptor()
        if fd != -1 {
            ret0_.pointee = fd
            return
        }
        throw NSError(domain: "LibboxPlatformInterface", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Missing tunnel file descriptor",
        ])
    }

    // MARK: - LibboxPlatformInterfaceProtocol

    func usePlatformAutoDetectControl() -> Bool { false }

    func autoDetectControl(_: Int32) throws {}

    func useProcFS() -> Bool { false }

    func underNetworkExtension() -> Bool { true }

    func includeAllNetworks() -> Bool { false }

    func findConnectionOwner(
        _: Int32,
        sourceAddress _: String?,
        sourcePort _: Int32,
        destinationAddress _: String?,
        destinationPort _: Int32
    ) throws -> LibboxConnectionOwner {
        throw NSError(domain: "LibboxPlatformInterface", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Not implemented",
        ])
    }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        let semaphore = DispatchSemaphore(value: 0)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.notifyDefaultInterface(listener, path: path)
            semaphore.signal()
            monitor.pathUpdateHandler = { [weak self] path in
                self?.notifyDefaultInterface(listener, path: path)
            }
        }
        monitor.start(queue: DispatchQueue.global())
        semaphore.wait()
    }

    private func notifyDefaultInterface(_ listener: LibboxInterfaceUpdateListenerProtocol, path: Network.NWPath) {
        guard path.status != .unsatisfied, let iface = path.availableInterfaces.first else {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
            return
        }
        listener.updateDefaultInterface(
            iface.name,
            interfaceIndex: Int32(iface.index),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let pathMonitor else {
            throw NSError(domain: "LibboxPlatformInterface", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Interface monitor not started",
            ])
        }
        let path = pathMonitor.currentPath
        if path.status == .unsatisfied {
            return NetworkInterfaceArray([])
        }
        var interfaces: [LibboxNetworkInterface] = []
        for iface in path.availableInterfaces {
            let item = LibboxNetworkInterface()
            item.name = iface.name
            item.index = Int32(iface.index)
            switch iface.type {
            case .wifi: item.type = LibboxInterfaceTypeWIFI
            case .cellular: item.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: item.type = LibboxInterfaceTypeEthernet
            default: item.type = LibboxInterfaceTypeOther
            }
            interfaces.append(item)
        }
        return NetworkInterfaceArray(interfaces)
    }

    func clearDNSCache() {
        guard let networkSettings, let tunnel else { return }
        libboxRunBlocking {
            tunnel.reasserting = true
            defer { tunnel.reasserting = false }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                tunnel.setTunnelNetworkSettings(nil) { _ in cont.resume() }
            }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                tunnel.setTunnelNetworkSettings(networkSettings) { _ in cont.resume() }
            }
        }
    }

    func readWIFIState() -> LibboxWIFIState? {
        libboxRunBlocking {
            await NEHotspotNetwork.fetchCurrent().flatMap { LibboxWIFIState($0.ssid, wifiBSSID: $0.bssid) }
        }
    }

    func send(_: LibboxNotification?) throws {}

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }

    func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }

    // MARK: - LibboxCommandServerHandlerProtocol

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        guard let proxy = networkSettings?.proxySettings, proxy.httpServer != nil else {
            return status
        }
        status.available = true
        status.enabled = proxy.httpEnabled
        return status
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {
        guard let networkSettings, let proxy = networkSettings.proxySettings, proxy.httpServer != nil else {
            return
        }
        if proxy.httpEnabled == enabled { return }
        proxy.httpEnabled = enabled
        proxy.httpsEnabled = enabled
        networkSettings.proxySettings = proxy
        self.networkSettings = networkSettings
        try libboxRunBlocking { [weak self] in
            try await self?.tunnel?.setTunnelNetworkSettings(networkSettings)
        }
    }

    func serviceStop() throws {
        tunnel?.stopLibboxService()
    }

    func serviceReload() throws {
        try libboxRunBlocking { [weak self] in
            try await self?.tunnel?.reloadLibboxService()
        }
    }

    func writeDebugMessage(_ message: String?) {
        guard let message else { return }
        log.debugInfo(message)
    }
}

private final class NetworkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    private var nextValue: LibboxNetworkInterface?

    init(_ array: [LibboxNetworkInterface]) {
        iterator = array.makeIterator()
    }

    func hasNext() -> Bool {
        nextValue = iterator.next()
        return nextValue != nil
    }

    func next() -> LibboxNetworkInterface? {
        nextValue
    }
}
