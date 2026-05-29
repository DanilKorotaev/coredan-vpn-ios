import Foundation
import Libbox

enum LibboxTunnelError: LocalizedError {
    case setupFailed(String)
    case commandServerFailed(String)
    case startServiceFailed(String)

    var errorDescription: String? {
        switch self {
        case let .setupFailed(message): "Libbox setup: \(message)"
        case let .commandServerFailed(message): "Libbox command server: \(message)"
        case let .startServiceFailed(message): "Libbox start: \(message)"
        }
    }
}

/// Runs sing-box inside the packet tunnel via Libbox.
final class LibboxTunnelService {
    private let log = makeLogger(tag: .libbox)
    private weak var tunnel: PacketTunnelProvider?
    private var commandServer: LibboxCommandServer?
    private var platformInterface: LibboxPlatformInterface?

    init(tunnel: PacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func start(configJSON: String) throws {
        try TunnelPaths.ensureDirectories()

        var configError: NSError?
        guard LibboxCheckConfig(configJSON, &configError) else {
            let message = configError?.localizedDescription ?? "invalid sing-box config"
            log.releaseError("Config check failed: \(message)")
            throw LibboxTunnelError.startServiceFailed(message)
        }

        let setup = LibboxSetupOptions()
        setup.basePath = TunnelPaths.sharedDirectory.path
        setup.workingPath = TunnelPaths.workingDirectory.path
        setup.tempPath = TunnelPaths.cacheDirectory.path
        setup.logMaxLines = 3000
        setup.debug = AppLoggerSettings.shared.isVerboseLog || AppLoggerSettings.shared.isDebugLogger

        var setupError: NSError?
        guard LibboxSetup(setup, &setupError) else {
            throw LibboxTunnelError.setupFailed(setupError?.localizedDescription ?? "setup failed")
        }

        guard let tunnel else {
            throw LibboxTunnelError.setupFailed("Tunnel deallocated")
        }

        let platform = LibboxPlatformInterface(tunnel: tunnel)
        platformInterface = platform

        var serverError: NSError?
        guard let server = LibboxNewCommandServer(platform, platform, &serverError) else {
            throw LibboxTunnelError.commandServerFailed(serverError?.localizedDescription ?? "nil server")
        }

        do {
            try server.start()
            try server.startOrReloadService(configJSON, options: LibboxOverrideOptions())
        } catch {
            log.releaseError("startOrReloadService: \(error.localizedDescription)")
            throw LibboxTunnelError.startServiceFailed(error.localizedDescription)
        }

        commandServer = server
        log.releaseInfo("sing-box service started")
    }

    func stop() {
        if let server = commandServer {
            do {
                try server.closeService()
            } catch {
                log.warning("closeService: \(error.localizedDescription)")
            }
            server.close()
        }
        platformInterface?.reset()
        commandServer = nil
        platformInterface = nil
        log.releaseInfo("sing-box service stopped")
    }
}
