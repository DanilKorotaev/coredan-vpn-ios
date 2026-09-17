import Foundation

/// User-configured proxy / tunnel profile (no defaults tied to a specific host).
struct ServerProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: ProfileKind
    var name: String
    /// Shadowsocks server host, or a display host for OpenFlux (e.g. `volga`).
    var host: String
    var port: Int
    var method: String
    var password: String
    var plugin: ProxyPlugin?

    /// OpenFlux transport id: `vyandex` (VOLGA), `yandex`, …
    var openfluxTransport: String?
    var openfluxURL: String?
    /// Must match exit-node codec. Packet tunnel uses compressed/legacy.
    var openfluxCodec: String?
    var openfluxVerbose: Bool?

    init(
        id: UUID = UUID(),
        kind: ProfileKind = .shadowsocks,
        name: String,
        host: String,
        port: Int,
        method: String,
        password: String,
        plugin: ProxyPlugin? = nil,
        openfluxTransport: String? = nil,
        openfluxURL: String? = nil,
        openfluxCodec: String? = nil,
        openfluxVerbose: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.host = host
        self.port = port
        self.method = method
        self.password = password
        self.plugin = plugin
        self.openfluxTransport = openfluxTransport
        self.openfluxURL = openfluxURL
        self.openfluxCodec = openfluxCodec
        self.openfluxVerbose = openfluxVerbose
    }

    /// Convenience for VOLGA / Yandex document profiles.
    static func openflux(
        name: String,
        documentURL: String,
        transport: String = "vyandex",
        codec: String = "legacy",
        verbose: Bool = false
    ) -> ServerProfile {
        ServerProfile(
            kind: .openflux,
            name: name,
            host: "volga",
            port: 0,
            method: "openflux",
            password: "",
            openfluxTransport: transport,
            openfluxURL: documentURL,
            openfluxCodec: codec,
            openfluxVerbose: verbose
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, name, host, port, method, password, plugin
        case openfluxTransport, openfluxURL, openfluxCodec, openfluxVerbose
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decodeIfPresent(ProfileKind.self, forKey: .kind) ?? .shadowsocks
        name = try c.decode(String.self, forKey: .name)
        host = try c.decode(String.self, forKey: .host)
        port = try c.decode(Int.self, forKey: .port)
        method = try c.decode(String.self, forKey: .method)
        password = try c.decode(String.self, forKey: .password)
        plugin = try c.decodeIfPresent(ProxyPlugin.self, forKey: .plugin)
        openfluxTransport = try c.decodeIfPresent(String.self, forKey: .openfluxTransport)
        openfluxURL = try c.decodeIfPresent(String.self, forKey: .openfluxURL)
        openfluxCodec = try c.decodeIfPresent(String.self, forKey: .openfluxCodec)
        openfluxVerbose = try c.decodeIfPresent(Bool.self, forKey: .openfluxVerbose)
    }

    /// SIP002-style URI (plugin query when present). OpenFlux profiles are not ss://.
    func shareURI() throws -> String {
        guard kind == .shadowsocks else {
            throw SSURLParserError.invalidCredentials
        }
        let userInfo = "\(method):\(password)"
        guard let userData = userInfo.data(using: .utf8) else {
            throw SSURLParserError.invalidCredentials
        }
        let encoded = userData.base64EncodedString()
        var url = "ss://\(encoded)@\(host):\(port)"
        if let plugin {
            let pluginQuery = "\(plugin.pluginName);\(plugin.pluginOptions)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            url += "?plugin=\(pluginQuery)"
        }
        let fragment = name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? name
        url += "#\(fragment)"
        return url
    }

    var subtitle: String {
        switch kind {
        case .shadowsocks:
            return "\(host):\(port) · \(method)"
        case .openflux:
            let transport = openfluxTransport ?? "vyandex"
            let shortURL = openfluxURL.map { u in
                if u.count > 48 { return String(u.prefix(45)) + "…" }
                return u
            } ?? "—"
            return "OpenFlux · \(transport) · \(shortURL)"
        }
    }
}
