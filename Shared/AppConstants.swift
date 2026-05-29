import Foundation

enum AppConstants {
    /// App Group for sharing profile JSON between app and Packet Tunnel extension.
    static let appGroupIdentifier = "group.com.coredan.CoreDanVPN"

    static let profileFileName = "active-profile.json"
    static let singBoxConfigFileName = "sing-box.json"
    static let lastTunnelErrorFileName = "last-tunnel-error.txt"

    static let tunnelProviderBundleIdentifier = "com.coredan.CoreDanVPN.PacketTunnel"
}
