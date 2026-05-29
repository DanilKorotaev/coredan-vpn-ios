import XCTest
@testable import CoreDanVPNApp

final class SingBoxConfigBuilderTests: XCTestCase {
    func testBuildContainsShadowsocksOutbound() throws {
        let profile = ServerProfile(
            name: "Unit",
            host: "10.0.0.1",
            port: 1080,
            method: "aes-256-gcm",
            password: "pw",
            plugin: .obfsLocal(mode: "tls", host: "www.example.com")
        )
        let json = try SingBoxConfigBuilder().build(profile: profile)
        XCTAssertTrue(json.contains("\"type\" : \"shadowsocks\"") || json.contains("\"type\": \"shadowsocks\""))
        XCTAssertTrue(json.contains("10.0.0.1"))
        XCTAssertTrue(json.contains("obfs-local"))
        XCTAssertTrue(json.contains("obfs=tls;obfs-host=www.example.com"))
        XCTAssertTrue(json.contains("gvisor"), json)
        XCTAssertTrue(json.contains("hijack-dns"), json)
        XCTAssertTrue(json.contains("\"network\" : \"tcp\"") || json.contains("\"network\": \"tcp\""), json)
        XCTAssertTrue(json.contains("\"type\" : \"tcp\"") || json.contains("\"type\": \"tcp\""), json)
        XCTAssertFalse(json.contains("udp_over_tcp"), json)
        XCTAssertFalse(json.contains("ip_is_private"), json)
        XCTAssertTrue(json.contains("4064"), json)
        XCTAssertTrue(json.contains("ip_cidr") || json.contains("route_exclude_address"), json)
        XCTAssertFalse(json.contains("inet4_address"), json)
        XCTAssertFalse(json.contains("inet4_route_exclude_address"), json)
        XCTAssertFalse(json.contains("\"sniff\": true"), json)
        XCTAssertTrue(json.contains("\"action\" : \"sniff\"") || json.contains("\"action\": \"sniff\""), json)
        XCTAssertTrue(json.contains("172.19.0.1"), json)
        XCTAssertTrue(json.contains("\"strict_route\" : false") || json.contains("\"strict_route\": false"), json)
    }

    func testV2rayPluginOptionsIncludeWebSocketMode() throws {
        let profile = ServerProfile(
            name: "V2",
            host: "10.0.0.2",
            port: 8390,
            method: "aes-256-gcm",
            password: "pw",
            plugin: .v2rayPlugin(host: "www.bing.com", path: "/vpn", tls: false)
        )
        let json = try SingBoxConfigBuilder().build(profile: profile)
        XCTAssertTrue(json.contains("mode=websocket"), json)
        XCTAssertTrue(json.contains("host=www.bing.com"), json)
    }
}
