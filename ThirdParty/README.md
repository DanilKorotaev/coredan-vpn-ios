# ThirdParty

Place **Libbox.xcframework** here after running:

```bash
./scripts/install_libbox.sh
```

The framework is not committed (GPL, large binary).

Built for **Packet Tunnel extensions** (no Tailscale; includes `with_clash_api` for Libbox CommandServer). Shadowsocks + `obfs-local` / `v2ray-plugin` are supported.

After changing build tags, rebuild with:

```bash
FORCE_LIBBOX_REBUILD=1 ./scripts/install_libbox.sh
```
