import XCTest
@testable import CoreDanVPNApp

final class ServerProfileOpenFluxTests: XCTestCase {
    func testOpenFluxFactoryAndCodableRoundTrip() throws {
        let profile = ServerProfile.openflux(
            name: "Я",
            documentURL: "https://disk.yandex.ru/i/kf1ggt1EAWHFkg",
            verbose: true
        )
        XCTAssertEqual(profile.kind, .openflux)
        XCTAssertEqual(profile.openfluxTransport, "vyandex")
        XCTAssertEqual(profile.openfluxCodec, "legacy")
        XCTAssertEqual(profile.openfluxVerbose, true)

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ServerProfile.self, from: data)
        XCTAssertEqual(decoded, profile)
    }

    func testLegacyShadowsocksJSONDefaultsKind() throws {
        let json = """
        {"id":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","name":"Old","host":"1.2.3.4","port":8388,"method":"aes-256-gcm","password":"x"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ServerProfile.self, from: json)
        XCTAssertEqual(decoded.kind, .shadowsocks)
        XCTAssertEqual(decoded.host, "1.2.3.4")
    }
}
