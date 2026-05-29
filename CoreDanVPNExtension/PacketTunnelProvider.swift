import Libbox
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let log = makeLogger(tag: .tunnel)
    private let sharedStore = SharedProfileStore()
    private lazy var libboxService = LibboxTunnelService(tunnel: self)
    private var activeConfigJSON: String?

    override init() {
        super.init()
        LoggingBootstrap.startIfNeeded()
    }

    override func startTunnel(options: [String: NSObject]?) async throws {
        try? sharedStore.clearLastTunnelError()
        let config = try resolveConfigJSON(options: options)
        activeConfigJSON = config
        log.releaseInfo("Starting tunnel, config \(config.count) bytes")
        do {
            try libboxService.start(configJSON: config)
            log.releaseInfo("Tunnel started")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            try? sharedStore.writeLastTunnelError(message)
            log.releaseError("Tunnel start failed: \(message)")
            throw error
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        log.releaseInfo("Stopping tunnel, reason: \(String(describing: reason))")
        libboxService.stop()
        activeConfigJSON = nil
    }

    func stopLibboxService() {
        libboxService.stop()
    }

    func reloadLibboxService() async throws {
        guard let config = activeConfigJSON ?? (try? sharedStore.readSingBoxConfig()) else {
            throw TunnelRuntimeError.missingConfig
        }
        libboxService.stop()
        try libboxService.start(configJSON: config)
    }

    private func resolveConfigJSON(options: [String: NSObject]?) throws -> String {
        if let raw = options?["configContent"] {
            let content = raw as? String ?? (raw as? NSString).map(\.description) ?? ""
            if !content.isEmpty { return content }
        }
        guard let config = try sharedStore.readSingBoxConfig(), !config.isEmpty else {
            throw TunnelRuntimeError.missingConfig
        }
        return config
    }
}

enum TunnelRuntimeError: LocalizedError {
    case missingConfig

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            "Нет конфигурации. Добавьте профиль в приложении и подключитесь снова."
        }
    }
}
