# OpenFlux upstream `ios-app` — what we took from it

Source: https://github.com/p1neappleXpress/OpenFlux/tree/main/ios-app

## Two modes in their app

| Mode | API | UI |
|------|-----|----|
| Local SOCKS5 | `OpenFluxStartClient` in the **app** process | Start / Stop / Test |
| System VPN | `OpenFluxStartPacketTunnel` in **NE** extension | Start VPN / Stop VPN |

Their README still says “first build is SOCKS-only”, but `OpenFluxTunnel/` + `VPNController` are already in tree (System VPN).

## Public GitHub vs working TestFlight

- Public UI transports: **`yandex`** (Docs) and **`oneme`** (MAX) only — no VOLGA picker.
- Our exit + docs use **`vyandex` / Volga** (`balancer_url missing` on classic `yandex` for these docs).
- Working TestFlight (join link in KB) has a **VOLGA** tab — that build is ahead of public `ios-app` sources.

So we keep transport=`vyandex`, but copy their **System VPN plumbing**.

## What we aligned to

1. NE settings: `10.10.10.2`, default IPv4 route, Yandex/DoT **excludedRoutes**, DNS `198.18.0.1`.
2. No `includeAllNetworks` / `enforceRoutes` for OpenFlux.
3. `startVPNTunnel()` **without** Libbox-style options.
4. Write/read loops like their `PacketTunnelProvider` (strong flow retain, break on `n <= 0`).
5. `NSAllowsArbitraryLoads` on the OpenFlux extension (ATS), `-lresolv` already present.

## What we intentionally do not copy

- In-app SOCKS as the primary product path (CoreDan is system VPN + SS).
- Their Individual team / bundle IDs.
- Default transport `yandex` (wrong for our Volga exit).
