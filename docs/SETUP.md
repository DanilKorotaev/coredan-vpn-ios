# Setup

## 1. Secrets

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Set `DEVELOPMENT_TEAM` to your 10-character Team ID.

## 2. Libbox (sing-box runtime)

The tunnel extension links **Libbox.xcframework** (not in git — GPL, ~100 MB). Build once:

```bash
brew install go   # if needed
./scripts/install_libbox.sh
```

This clones [sing-box](https://github.com/SagerNet/sing-box) at `v1.13.12` and builds an **extension-safe** `Libbox.xcframework` (minimal tags, no Tailscale — Tailscale pulls `UIApplication`, which Network Extensions cannot link). Output: `ThirdParty/Libbox.xcframework`.

Rebuild after script changes: `FORCE_LIBBOX_REBUILD=1 ./scripts/install_libbox.sh`

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
3. Provisioning profiles for **app** and **extension** (automatic signing is enough for dev).

## 5. Run

- After `xcodegen generate`, confirm `CoreDanVPNExtension/Info.plist` contains **`NSExtension`** (packet-tunnel). Without it, install on device fails with IXUserPresentableErrorDomain.
- Product → **Clean Build Folder**, then Run again.
- Use a **physical iPhone** (tunnel on Simulator is unreliable; iOS **18+** for this project).
- Add profile via your private `ss://` link (not stored in git).
- Connect → allow VPN configuration → check IP (e.g. Safari → `https://api.ipify.org` should show server IP).
- Test on **Wi‑Fi and cellular (Tele2)** vs Shadowrocket.

## 6. Production URIs

Keep working links in private notes (e.g. Nextcloud `VPN/`), not in this repo.
