# CoreDan VPN (iOS)

Open-source iOS client for **Shadowsocks** profiles with optional plugins (`obfs-local`, `v2ray-plugin`). Import a `ss://` link or enter server fields manually. No server credentials are bundled in the app.

## Requirements

- Xcode 16+
- iOS 18+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Apple Developer account with **Network Extension (Packet Tunnel)** capability

## Quick start

```bash
cd coredan-vpn-ios
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Edit Secrets.xcconfig — set DEVELOPMENT_TEAM to your Team ID
brew install go          # once, for Libbox build
./scripts/install_libbox.sh
xcodegen generate
open CoreDanVPN.xcodeproj
```

1. Enable **Packet Tunnel** capability on App ID `com.coredan.CoreDanVPN` and the extension.
2. Run on a **physical device** (VPN extensions are limited on Simulator).
3. Add a profile (paste `ss://…` or fill fields) → Connect.

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
| [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md) | Protocol-first, no secrets in git |

## Security

- Profiles (passwords) stored in **Keychain** and App Group only on device.
- Do not commit real `ss://` links or server IPs to this repository.
- Use your private notes (e.g. Nextcloud) for production URIs.

## License

App source: [MIT](LICENSE). **Libbox** (sing-box) is [GPL-3.0](https://github.com/SagerNet/sing-box/blob/main/LICENSE); build it locally and comply if you distribute binaries.
