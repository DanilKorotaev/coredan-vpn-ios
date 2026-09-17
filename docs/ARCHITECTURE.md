# Architecture

## Modules

| Module | Responsibility |
|--------|----------------|
| `CoreDanVPNApp` | SwiftUI, profiles, Keychain, `NETunnelProviderManager` |
| `CoreDanVPNExtension` | `NEPacketTunnelProvider` + **Libbox** (sing-box) for Shadowsocks |
| `CoreDanOpenFluxExtension` | `NEPacketTunnelProvider` + **liboflux** (OpenFlux VOLGA / Yandex Docs) |
| `Shared` | `ServerProfile`, parsers, App Group I/O, OpenFlux bypass routes |

Libbox and liboflux each embed a **Go runtime**, so they live in **separate** Packet Tunnel extensions. The app starts exactly one manager per connect.

## Data flow

### Shadowsocks

```text
ss:// or manual fields → ServerProfile (kind=shadowsocks)
  → SingBoxConfigBuilder → JSON
  → App Group + VPNController → CoreDanVPNExtension → Libbox
```

### OpenFlux (VOLGA)

```text
Document URL → ServerProfile (kind=openflux, transport=vyandex, codec=legacy)
  → VPNController providerConfiguration
  → CoreDanOpenFluxExtension → OpenFluxStartPacketTunnel
  → Yandex VOLGA ↔ exit-node on VPS
```

## Disconnect / Control Center

`VPNController.disconnect()` clears **On Demand**, sets `isEnabled = false`, stops the tunnel, and saves preferences for **both** extensions so toggling VPN off in Control Center does not bounce it back on.

## Dependencies

- Apple: NetworkExtension, Security
- Libbox / sing-box (GPL) — `scripts/install_libbox.sh`
- OpenFlux liboflux (GPL-3.0) — `scripts/install_openflux.sh` (patches `vyandex` into packet-tunnel export)

## Security

- No server hosts/passwords in repository.
- Profiles only on device (Keychain + App Group).
