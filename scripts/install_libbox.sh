#!/usr/bin/env bash
# Builds Libbox.xcframework from sing-box (GPL). Run once before opening Xcode.
# Uses an extension-safe tag set (no Tailscale — it references UIApplication).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ThirdParty/Libbox.xcframework"
VERSION="${SING_BOX_VERSION:-v1.13.12}"

if [[ -d "$DEST" && "${FORCE_LIBBOX_REBUILD:-0}" != "1" ]]; then
  echo "Libbox already installed: $DEST"
  echo "Set FORCE_LIBBOX_REBUILD=1 to rebuild."
  exit 0
fi

if ! command -v go >/dev/null 2>&1; then
  echo "Go is required. Install: brew install go"
  exit 1
fi

export PATH="$(go env GOPATH)/bin:$PATH"

echo "Cloning sing-box $VERSION (shallow)…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth=1 --branch "$VERSION" https://github.com/SagerNet/sing-box.git "$TMP/sing-box"

echo "Building extension-safe Libbox.xcframework (no Tailscale)…"
(
  cd "$TMP/sing-box"
  make lib_install
  gomobile init

  VERSION_TAG="$(go run github.com/sagernet/sing-box/cmd/internal/read_tag@latest 2>/dev/null || echo dev)"
  LDFLAGS="-X github.com/sagernet/sing-box/constant.Version=${VERSION_TAG} -X internal/godebug.defaultGODEBUG=multipathtcp=0 -s -w -buildid= -checklinkname=0"

  # SS + obfs in Network Extension. with_clash_api required for Libbox CommandServer (sing-box 1.13+).
  # No Tailscale — it pulls UIApplication and breaks Packet Tunnel linking.
  TAGS="with_gvisor,with_utls,with_clash_api,badlinkname,tfogo_checklinkname0,with_low_memory"

  gomobile bind -v \
    -target ios,iossimulator \
    -libname=box \
    -tags "$TAGS" \
    -trimpath -buildvcs=false \
    -ldflags "$LDFLAGS" \
    ./experimental/libbox
)

rm -rf "$DEST"
mkdir -p "$ROOT/ThirdParty"
mv "$TMP/sing-box/Libbox.xcframework" "$DEST"
echo "Done: $DEST"
echo "Run: xcodegen generate && open CoreDanVPN.xcodeproj"
