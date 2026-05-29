import XCTest
@testable import CoreDanVPNApp

final class SSURLParserTests: XCTestCase {
    private let parser = SSURLParser()

    func testParsePlainShadowsocks() throws {
        let uri = "ss://YWVzLTI1Ni1nY206dGVzdC1wYXNzd29yZA==@example.com:8388#Test"
        let profile = try parser.parse(uri)
        XCTAssertEqual(profile.host, "example.com")
        XCTAssertEqual(profile.port, 8388)
        XCTAssertEqual(profile.method, "aes-256-gcm")
        XCTAssertEqual(profile.password, "test-password")
        XCTAssertEqual(profile.name, "Test")
        XCTAssertNil(profile.plugin)
    }

    func testParseObfsLocalPlugin() throws {
        let uri = """
        ss://YWVzLTI1Ni1nY206cGFzcw==@proxy.example.net:8388?plugin=obfs-local%3Bobfs%3Dtls%3Bobfs-host%3Dwww.example.com#Obfs
        """
        let profile = try parser.parse(uri)
        XCTAssertEqual(profile.plugin, .obfsLocal(mode: "tls", host: "www.example.com"))
    }

    func testParseV2rayPlugin() throws {
        let uri = """
        ss://YWVzLTI1Ni1nY206cGFzcw==@proxy.example.net:8390?plugin=v2ray-plugin%3Bhost%3Dcdn.example.com%3Bpath%3D%2Fvpn%3Btls#V2
        """
        let profile = try parser.parse(uri)
        XCTAssertEqual(
            profile.plugin,
            .v2rayPlugin(host: "cdn.example.com", path: "/vpn", tls: true)
        )
    }

    func testRoundTripShareURI() throws {
        let original = ServerProfile(
            name: "Round",
            host: "vpn.example.org",
            port: 443,
            method: "chacha20-ietf-poly1305",
            password: "secret",
            plugin: .obfsLocal(mode: "tls", host: "www.example.com")
        )
        let uri = try original.shareURI()
        let parsed = try parser.parse(uri)
        XCTAssertEqual(parsed.host, original.host)
        XCTAssertEqual(parsed.port, original.port)
        XCTAssertEqual(parsed.method, original.method)
        XCTAssertEqual(parsed.password, original.password)
        XCTAssertEqual(parsed.plugin, original.plugin)
    }
}
