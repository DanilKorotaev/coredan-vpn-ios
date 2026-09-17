# Setup

## 1. Secrets (optional)

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Signing uses **Team ID `66C9VGAZR5`** (CoreDan Apple account) from `project.yml`, same as Knowledge Base App. Use `Secrets.xcconfig` only for local overrides; CI can set `DEVELOPMENT_TEAM` via the `TEAM_ID` secret when deploying TestFlight.

## 2. Libbox + OpenFlux

```bash
brew install go   # if needed
./scripts/install_libbox.sh
./scripts/install_openflux.sh
```

- Libbox → `ThirdParty/Libbox.xcframework` (Shadowsocks; no Tailscale).
- OpenFlux → `ThirdParty/OpenFlux/` (`liboflux.a` + header; VOLGA/`vyandex` patched).

Neither binary is committed. Rebuild: `FORCE_LIBBOX_REBUILD=1` / `FORCE_OPENFLUX_REBUILD=1`.

## 3. Xcode project

```bash
xcodegen generate
open CoreDanVPN.xcodeproj
```

## 4. Apple Developer

1. Register App ID `com.coredan.CoreDanVPN` with capabilities:
   - **Network Extensions** → Packet Tunnel
   - **App Groups** → `group.com.coredan.CoreDanVPN`
2. Register App ID `com.coredan.CoreDanVPN.PacketTunnel` with the same capabilities.
3. Register App ID `com.coredan.CoreDanVPN.OpenFluxTunnel` with the same capabilities (second Packet Tunnel for OpenFlux).
4. Provisioning profiles for **app** and **both extensions** (automatic signing is enough for dev).

## 5. Run

- After `xcodegen generate`, confirm `CoreDanVPNExtension/Info.plist` contains **`NSExtension`** (packet-tunnel). Without it, install on device fails with IXUserPresentableErrorDomain.
- Product → **Clean Build Folder**, then Run again.
- Use a **physical iPhone** (tunnel on Simulator is unreliable; iOS **18+** for this project).
- Add profile via your private `ss://` link (not stored in git).
- Connect → allow VPN configuration → check IP (e.g. Safari → `https://api.ipify.org` should show server IP).
- Test on **Wi‑Fi and cellular (Tele2)** vs Shadowrocket.

## 6. Production URIs

Keep working links in private notes (e.g. Nextcloud `VPN/`), not in this repo.
