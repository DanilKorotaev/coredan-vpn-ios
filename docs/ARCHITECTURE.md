# Architecture

## Modules

| Module | Responsibility |
|--------|----------------|
| `CoreDanVPNApp` | SwiftUI, profiles, Keychain, `NETunnelProviderManager` |
| `CoreDanVPNExtension` | `NEPacketTunnelProvider` + **Libbox** (sing-box) runtime |
| `Shared` | `ServerProfile`, `SSURLParser`, `SingBoxConfigBuilder`, App Group I/O |

## Data flow

```text
User pastes ss:// or manual fields
        → ServerProfile
        → SingBoxConfigBuilder → JSON
        → App Group (active-profile.json, sing-box.json)
        → VPNController.startVPNTunnel()
        → PacketTunnelProvider reads JSON → Libbox
```

## Libbox integration

1. Build `ThirdParty/Libbox.xcframework` via `./scripts/install_libbox.sh` (from [sing-box](https://github.com/SagerNet/sing-box) `make lib_apple`).
2. App writes `sing-box.json` to App Group; `VPNController` also passes `configContent` in `startVPNTunnel(options:)`.
3. `PacketTunnelProvider` → `LibboxTunnelService` → `LibboxCommandServer` + `LibboxPlatformInterface` (TUN fd from `NEPacketTunnelProvider`).

**Next validation:** obfs profile on device (Wi‑Fi + Tele2). If `obfs-local` fails, try v2ray profile or server-side ShadowTLS.

## Security

- No server hosts/passwords in repository.
- Profiles only on device (Keychain + App Group).

## Dependencies

- Apple: NetworkExtension, Security
- Planned: Libbox (GPL — comply in README/LICENSE)
