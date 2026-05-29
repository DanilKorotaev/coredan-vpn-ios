import Foundation

/// User-configured proxy server (no defaults tied to a specific host).
struct ServerProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var method: String
    var password: String
    var plugin: ProxyPlugin?

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        method: String,
        password: String,
        plugin: ProxyPlugin? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.method = method
        self.password = password
        self.plugin = plugin
    }

    /// SIP002-style URI (plugin query when present).
    func shareURI() throws -> String {
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
}
