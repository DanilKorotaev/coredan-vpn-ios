# CoreDan VPN (iOS)

[![CI](https://github.com/DanilKorotaev/coredan-vpn-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/DanilKorotaev/coredan-vpn-ios/actions/workflows/ci.yml)

Open-source iOS client for **Shadowsocks** (`obfs-local`, `v2ray-plugin`) and **OpenFlux VOLGA** (Yandex Docs transport → your exit-node). Import a `ss://` link, enter SS fields, or paste an OpenFlux document URL. No server credentials are bundled in the app.

## Requirements

- Xcode 16+
- iOS 18+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Apple Developer account with **Network Extension (Packet Tunnel)** capability

## Quick start

```bash
cd coredan-vpn-ios
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Optional: cp Config/Secrets.xcconfig.example → Secrets.xcconfig (team ID is in project.yml)
brew install go          # once, for Libbox + OpenFlux builds
./scripts/install_libbox.sh
./scripts/install_openflux.sh
xcodegen generate
open CoreDanVPN.xcodeproj
```

1. Enable **Packet Tunnel** on App IDs `com.coredan.CoreDanVPN`, `…PacketTunnel`, and `…OpenFluxTunnel`.
2. Run on a **physical device** (VPN extensions are limited on Simulator).
3. Add a profile (`ss://…` or OpenFlux URL) → Connect.

## Status

| Area | Status |
|------|--------|
| `ss://` parser + manual profile model | Done |
| sing-box JSON builder (for Libbox) | Done |
| UI: list, import, manual form | Done |
| Packet Tunnel + Libbox runtime | Done (build Libbox via `scripts/install_libbox.sh`) |

## Documentation

| Doc | Description |
|-----|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Modules, tunnel boundary |
| [docs/SETUP.md](docs/SETUP.md) | Signing, capabilities |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | XcodeGen, tests |
| [docs/CI_CD.md](docs/CI_CD.md) | GitHub Actions, TestFlight secrets |
| [docs/FASTLANE.md](docs/FASTLANE.md) | Fastlane lanes |
| [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md) | Protocol-first, no secrets in git |

## Security

- Profiles (passwords) stored in **Keychain** and App Group only on device.
- Do not commit real `ss://` links or server IPs to this repository.
- Use your private notes (e.g. Nextcloud) for production URIs.

## License

App source: [MIT](LICENSE). **Libbox** (sing-box) is [GPL-3.0](https://github.com/SagerNet/sing-box/blob/main/LICENSE); build it locally and comply if you distribute binaries.
