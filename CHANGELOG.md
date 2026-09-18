# Changelog

All notable changes to the CoreDan VPN iOS app are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Marketing version (`CFBundleShortVersionString`) comes from the root [`VERSION`](VERSION) file.
Build number (`CFBundleVersion`) is the CI run number (`GITHUB_RUN_NUMBER`) and is listed in [`docs/RELEASES.md`](docs/RELEASES.md).

On each successful **main → TestFlight** deploy, CI auto-bumps **PATCH** (unless a minor/major was requested), folds commit subjects + `[Unreleased]` into a new section below, then tags `ios/v*`. See [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md).

## [Unreleased]

## [1.1.5] - 2026-09-18

### Changed

- Release packaging / TestFlight upload.

## [1.1.4] - 2026-09-18

### Fixed

- Stop starving the tunnel — remove soft memory caps.

## [1.1.3] - 2026-09-18

### Fixed

- Shrink Volga 16MiB buffers that jetsam the NE.

## [1.1.2] - 2026-09-18

### Fixed

- Undo GC thrash that froze the phone.

## [1.1.1] - 2026-09-18

### Fixed

- Stop NE jetsam from Volga memory pressure.

## [1.1.0] - 2026-09-18

### Changed

- Bump marketing version to 1.1.0 (was incorrectly seeded as 0.1.0)
- Set marketing version to 1.1.0

### Changed

- Bump marketing version to 1.1.0 (was incorrectly seeded as 0.1.0)

## [0.1.0] - 2026-09-18

### Added

- OpenFlux VOLGA profiles alongside Shadowsocks
- Automatic TestFlight deploy after green CI on main (SemVer + changelog + `ios/v*` tags)
- CoreDan VPN iOS client with Libbox tunnel, CI, and TestFlight pipeline

### Fixed

- OpenFlux VPN badge flap from NE reasserts (`includeAllNetworks`, memory limit)
- OpenFlux downlink dying on empty packets
- OpenFlux VOLGA jetsam in the packet tunnel
- OpenFlux iOS build script under bash `set -u`

[Unreleased]: https://github.com/DanilKorotaev/coredan-vpn-ios/compare/ios/v1.1.5...HEAD
[1.1.5]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v1.1.5
[1.1.4]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v1.1.4
[1.1.3]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v1.1.3
[1.1.2]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v1.1.2
[1.1.1]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v1.1.1
[1.1.0]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v1.1.0
[0.1.0]: https://github.com/DanilKorotaev/coredan-vpn-ios/releases/tag/ios/v0.1.0
