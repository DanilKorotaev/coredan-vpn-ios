import Foundation

enum AppConstants {
    /// App Group for sharing profile JSON between app and Packet Tunnel extension.
    static let appGroupIdentifier = "group.com.coredan.CoreDanVPN"

    static let profileFileName = "active-profile.json"
    static let singBoxConfigFileName = "sing-box.json"
    static let lastTunnelErrorFileName = "last-tunnel-error.txt"

    static let tunnelProviderBundleIdentifier = "com.coredan.CoreDanVPN.PacketTunnel"
    /// Separate extension: Libbox and liboflux both embed a Go runtime and cannot share one binary.
    static let openFluxTunnelProviderBundleIdentifier = "com.coredan.CoreDanVPN.OpenFluxTunnel"

    static var allTunnelProviderBundleIdentifiers: [String] {
        [tunnelProviderBundleIdentifier, openFluxTunnelProviderBundleIdentifier]
    }

    static func tunnelProviderBundleIdentifier(for kind: ProfileKind) -> String {
        switch kind {
        case .shadowsocks: tunnelProviderBundleIdentifier
        case .openflux: openFluxTunnelProviderBundleIdentifier
        }
    }
}
