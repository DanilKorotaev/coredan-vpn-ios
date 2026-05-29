import Foundation

/// Builds a minimal sing-box config JSON for Libbox (Packet Tunnel / iOS).
/// See https://sing-box.sagernet.org/
struct SingBoxConfigBuilder: Sendable {
    private let tunInboundTag = "tun-in"
    /// UTUN headroom on iOS Network Extension (sing-box default when MTU is unset).
    private let iosTunnelMTU = 4064

    func build(profile: ServerProfile) throws -> String {
        var outbound: [String: Any] = [
            "type": "shadowsocks",
            "tag": "proxy",
            "server": profile.host,
            "server_port": profile.port,
            "method": profile.method,
            "password": profile.password,
        ]

        if let plugin = profile.plugin {
            outbound["plugin"] = plugin.pluginName
            outbound["plugin_opts"] = plugin.pluginOptions
            // SIP003 plugins (obfs-local, v2ray-plugin) only wrap TCP — no native UDP through obfs.
            outbound["network"] = "tcp"
        }

        var routeRules: [[String: Any]] = [
            // Port-based: catches DNS to TUN gateway 172.19.0.2 before ip_is_private would steal it.
            [
                "port": [53],
                "action": "hijack-dns",
            ],
        ]
        if let serverCIDR = ipv4CIDR(for: profile.host) {
            routeRules.append([
                "ip_cidr": [serverCIDR],
                "outbound": "direct",
            ])
        }
        // Home LAN only — do not use ip_is_private (172.19.0.0/30 TUN DNS is also "private").
        routeRules.append([
            "ip_cidr": ["10.0.0.0/8", "192.168.0.0/16"],
            "outbound": "direct",
        ])
        routeRules.append([
            "inbound": tunInboundTag,
            "action": "sniff",
        ])

        var tunInbound: [String: Any] = [
            "type": "tun",
            "tag": tunInboundTag,
            "address": ["172.19.0.1/30"],
            "mtu": iosTunnelMTU,
            "auto_route": true,
            // strict_route is not implemented on iOS (sing-box Apple client docs).
            "strict_route": false,
            "stack": "gvisor",
        ]
        if let serverCIDR = ipv4CIDR(for: profile.host) {
            tunInbound["route_exclude_address"] = [serverCIDR]
        }

        let config: [String: Any] = [
            "log": ["level": logLevel()],
            "dns": [
                "servers": [
                    [
                        "tag": "dns-remote",
                        "type": "tcp",
                        "server": "8.8.8.8",
                        "server_port": 53,
                        "detour": "proxy",
                    ],
                ],
                "strategy": "ipv4_only",
                "final": "dns-remote",
            ],
            "inbounds": [tunInbound],
            "outbounds": [
                outbound,
                ["type": "direct", "tag": "direct"],
                ["type": "block", "tag": "block"],
            ],
            "route": [
                "rules": routeRules,
                "final": "proxy",
                "auto_detect_interface": true,
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw SingBoxConfigBuilderError.encodingFailed
        }
        return json
    }

    private func logLevel() -> String {
        AppLoggerSettings.shared.isVerboseLog ? "debug" : "info"
    }

    private func ipv4CIDR(for host: String) -> String? {
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return nil }
        for part in parts {
            guard let value = Int(part), value >= 0, value <= 255 else { return nil }
        }
        return "\(host)/32"
    }
}

enum SingBoxConfigBuilderError: Error {
    case encodingFailed
}
