import Foundation

/// Shadowsocks client plugin (server must use matching plugin).
enum ProxyPlugin: Codable, Equatable, Sendable {
    case obfsLocal(mode: String, host: String)
    case v2rayPlugin(host: String, path: String, tls: Bool)

    var pluginName: String {
        switch self {
        case .obfsLocal: "obfs-local"
        case .v2rayPlugin: "v2ray-plugin"
        }
    }

    /// `plugin_opts` query / sing-box plugin_opts string.
    var pluginOptions: String {
        switch self {
        case let .obfsLocal(mode, host):
            return "obfs=\(mode);obfs-host=\(host)"
        case let .v2rayPlugin(host, path, tls):
            var parts = ["mode=websocket", "host=\(host)", "path=\(path)"]
            if tls { parts.append("tls") }
            return parts.joined(separator: ";")
        }
    }
}
