import Foundation

enum SSURLParserError: Error, Equatable {
    case invalidScheme
    case invalidFormat
    case invalidCredentials
    case invalidPort
    case unsupportedPlugin(String)
}

/// Parses Shadowsocks URIs (SIP002 + common `plugin=` extensions).
struct SSURLParser: Sendable {
    func parse(_ raw: String) throws -> ServerProfile {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed) else {
            throw SSURLParserError.invalidFormat
        }
        guard components.scheme?.lowercased() == "ss" else {
            throw SSURLParserError.invalidScheme
        }

        let (method, password) = try decodeUserInfo(components)
        let host = components.host ?? ""
        guard !host.isEmpty else { throw SSURLParserError.invalidFormat }
        guard let port = components.port, port > 0, port < 65536 else {
            throw SSURLParserError.invalidPort
        }

        let name = components.fragment?.removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? host

        let plugin = try parsePluginQuery(components.queryItems)

        return ServerProfile(
            name: name,
            host: host,
            port: port,
            method: method,
            password: password,
            plugin: plugin
        )
    }

    private func decodeUserInfo(_ components: URLComponents) throws -> (String, String) {
        if let user = components.user, let pass = components.password {
            return (user, pass)
        }
        let part = components.user ?? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let data = Data(base64Encoded: base64Padded(part)),
              let decoded = String(data: data, encoding: .utf8) else {
            throw SSURLParserError.invalidCredentials
        }
        let parts = decoded.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw SSURLParserError.invalidCredentials
        }
        return (parts[0], parts[1])
    }

    private func base64Padded(_ value: String) -> String {
        var s = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = s.count % 4
        if pad != 0 { s += String(repeating: "=", count: 4 - pad) }
        return s
    }

    private func parsePluginQuery(_ items: [URLQueryItem]?) throws -> ProxyPlugin? {
        guard let pluginValue = items?.first(where: { $0.name == "plugin" })?.value,
              !pluginValue.isEmpty else {
            return nil
        }
        let decoded = pluginValue.removingPercentEncoding ?? pluginValue
        let segments = decoded.split(separator: ";", maxSplits: 1).map(String.init)
        let name = segments[0].lowercased()
        let opts = segments.count > 1 ? segments[1] : ""
        let map = parseSemicolonOptions(opts)

        switch name {
        case "obfs-local", "obfs":
            let mode = map["obfs"] ?? "tls"
            guard let host = map["obfs-host"] ?? map["host"], !host.isEmpty else {
                throw SSURLParserError.unsupportedPlugin("obfs-local requires obfs-host")
            }
            return .obfsLocal(mode: mode, host: host)
        case "v2ray-plugin":
            guard let host = map["host"], !host.isEmpty else {
                throw SSURLParserError.unsupportedPlugin("v2ray-plugin requires host")
            }
            let path = map["path"] ?? "/"
            let tls = map["tls"] != nil
            return .v2rayPlugin(host: host, path: path, tls: tls)
        default:
            throw SSURLParserError.unsupportedPlugin(name)
        }
    }

    private func parseSemicolonOptions(_ value: String) -> [String: String] {
        var result: [String: String] = [:]
        for part in value.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                result[pair[0].trimmingCharacters(in: .whitespaces)] = pair[1].trimmingCharacters(in: .whitespaces)
            } else if pair.count == 1, !pair[0].isEmpty {
                result[pair[0].trimmingCharacters(in: .whitespaces)] = ""
            }
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
