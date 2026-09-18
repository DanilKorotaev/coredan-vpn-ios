# Changelog

All notable changes to the CoreDan VPN iOS app are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Marketing version (`CFBundleShortVersionString`) comes from the root [`VERSION`](VERSION) file.
Build number (`CFBundleVersion`) is the CI run number (`GITHUB_RUN_NUMBER`) and is listed in [`docs/RELEASES.md`](docs/RELEASES.md).

On each successful **main → TestFlight** deploy, CI auto-bumps **PATCH** (unless a minor/major was requested), folds commit subjects + `[Unreleased]` into a new section below, then tags `ios/v*`. See [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md).

## [Unreleased]

## [0.1.0] - 2026-09-18

### Changed

- OpenFlux VOLGA profiles alongside Shadowsocks
- Automatic TestFlight deploy after green CI on main (SemVer + changelog + `ios/v*` tags)
- OpenFlux VPN badge flap from NE reasserts (`includeAllNetworks`, memory limit)
- OpenFlux downlink dying on empty packets
- OpenFlux VOLGA jetsam in the packet tunnel
- Initial commit: CoreDan VPN iOS client with Libbox tunnel.
- Add GitHub Actions CI and Fastlane TestFlight pipeline.
- Add Telegram CI notifications for tests and TestFlight.
- Align signing with CoreDan team ID (66C9VGAZR5).
- Add CoreDan VPN app icon asset catalog.
- Add OpenFlux VOLGA profiles alongside Shadowsocks.
- Harden OpenFlux tunnel capture and downlink path.
- Stop OpenFlux VPN badge flap from NE reasserts.
- Auto TestFlight after green CI with SemVer releases.

### Fixed

- Fix OpenFlux iOS build script under bash set -u.
- Fix OpenFlux VOLGA jetsam in the packet tunnel.
- Fix OpenFlux downlink dying on empty packets.

[Unreleased]: https://github.com/DanilKorotaev/coredan-vpn-ios/compare/ios/v0.1.0...HEAD
[0.1.0]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v0.1.0

### Added

- OpenFlux VOLGA profiles alongside Shadowsocks
- Automatic TestFlight deploy after green CI on main (SemVer + changelog + `ios/v*` tags)

### Fixed

- OpenFlux VPN badge flap from NE reasserts (`includeAllNetworks`, memory limit)
- OpenFlux downlink dying on empty packets
- OpenFlux VOLGA jetsam in the packet tunnel

[Unreleased]: https://github.com/DanilKorotaev/coredan-vpn-ios/compare/ios/v0.1.0...HEAD
[0.1.0]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v0.1.0
