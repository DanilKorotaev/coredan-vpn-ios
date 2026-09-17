# ThirdParty

## Libbox

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

## OpenFlux

```bash
./scripts/install_openflux.sh
```

Produces `ThirdParty/OpenFlux/{device,simulator}/liboflux.a` and `include/liboflux.h`.  
The script patches upstream packet-tunnel export to accept **`vyandex` / VOLGA** (legacy LZ4 codec), matching our exit-node.

Rebuild: `FORCE_OPENFLUX_REBUILD=1 ./scripts/install_openflux.sh`
