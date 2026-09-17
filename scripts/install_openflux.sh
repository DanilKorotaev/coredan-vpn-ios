#!/usr/bin/env bash
# Builds liboflux.a (OpenFlux) for iOS device + simulator.
# Patches packet-tunnel export to support VOLGA (vyandex) — required for our docs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ThirdParty/OpenFlux"
OPENFLUX_REF="${OPENFLUX_REF:-main}"
FORCE="${FORCE_OPENFLUX_REBUILD:-0}"

DEVICE_LIB="$DEST/device/liboflux.a"
SIM_LIB="$DEST/simulator/liboflux.a"
HEADER="$DEST/include/liboflux.h"

if [[ -f "$DEVICE_LIB" && -f "$SIM_LIB" && -f "$HEADER" && "$FORCE" != "1" ]]; then
  echo "OpenFlux already installed: $DEST"
  echo "Set FORCE_OPENFLUX_REBUILD=1 to rebuild."
  exit 0
fi

if ! command -v go >/dev/null 2>&1; then
  echo "Go is required. Install: brew install go"
  exit 1
fi

XCODE_PATH="${XCODE_PATH:-/Applications/Xcode.app}"
DEVELOPER_DIR="$XCODE_PATH/Contents/Developer"
CLANG="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
IPHONEOS_SDK="$DEVELOPER_DIR/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
IPHONESIM_SDK="$DEVELOPER_DIR/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"

if [[ ! -d "$IPHONEOS_SDK" || ! -f "$CLANG" ]]; then
  echo "Xcode iPhoneOS SDK / clang not found under $XCODE_PATH"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Cloning OpenFlux (${OPENFLUX_REF})..."
git clone --depth 1 --branch "$OPENFLUX_REF" https://github.com/p1neappleXpress/OpenFlux.git "$TMP/OpenFlux" \
  || git clone --depth 1 https://github.com/p1neappleXpress/OpenFlux.git "$TMP/OpenFlux"

# Pin commit when OPENFLUX_COMMIT is set
if [[ -n "${OPENFLUX_COMMIT:-}" ]]; then
  git -C "$TMP/OpenFlux" fetch --depth 1 origin "$OPENFLUX_COMMIT"
  git -C "$TMP/OpenFlux" checkout "$OPENFLUX_COMMIT"
fi

PACKET="$TMP/OpenFlux/export_ios_packet.go"
if ! grep -q 'vyandex' "$PACKET"; then
  echo "Patching export_ios_packet.go for vyandex (VOLGA)..."
  python3 - <<'PY' "$PACKET"
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
needle = '''\tswitch tt {
\tcase "yandex", "":
\t\tt = transport.NewCompressedTransport(yandex.NewYandexDocsTransport(docURL, config))
\tcase "oneme":'''
replacement = '''\tswitch tt {
\tcase "yandex", "":
\t\tt = transport.NewCompressedTransport(yandex.NewYandexDocsTransport(docURL, config))
\tcase "vyandex", "volga":
\t\t// VOLGA (new Yandex Docs editor). Codec = CompressedTransport (legacy LZ4),
\t\t// matching --codec=legacy on the exit-node.
\t\tt = transport.NewCompressedTransport(yandex.NewYandexVolgaTransport(docURL, config))
\tcase "oneme":'''
if needle not in text:
    raise SystemExit("export_ios_packet.go: unexpected format, cannot patch vyandex")
path.write_text(text.replace(needle, replacement, 1))
print("Patched OK")
PY
else
  echo "vyandex already present in export_ios_packet.go"
fi

build_slice() {
  local sdk="$1"
  local out_dir="$2"
  local min_flag="$3"
  local target_triple="$4"

  mkdir -p "$out_dir"
  (
    cd "$TMP/OpenFlux"
    export GOOS=ios
    export GOARCH=arm64
    export CGO_ENABLED=1
    export SDK_PATH="$sdk"
    export CC="$CLANG -target ${target_triple} -isysroot $sdk $min_flag"
    export CXX="${CLANG}++ -target ${target_triple} -isysroot $sdk $min_flag"
    export CGO_CFLAGS="-target ${target_triple} -isysroot $sdk $min_flag"
    export CGO_LDFLAGS="-target ${target_triple} -isysroot $sdk $min_flag"

    echo "Building liboflux for ${target_triple}..."
    go build \
      -buildmode=c-archive \
      -tags ios \
      -ldflags="-w" \
      -trimpath \
      -o "$out_dir/liboflux.a" \
      .
  )
}

build_slice "$IPHONEOS_SDK" "$TMP/device" "-miphoneos-version-min=15.0" "arm64-apple-ios15.0"
if [[ -d "$IPHONESIM_SDK" ]]; then
  build_slice "$IPHONESIM_SDK" "$TMP/simulator" "-mios-simulator-version-min=15.0" "arm64-apple-ios15.0-simulator"
else
  echo "iPhoneSimulator SDK missing — skipping simulator slice"
  mkdir -p "$TMP/simulator"
  cp "$TMP/device/liboflux.a" "$TMP/simulator/liboflux.a"
  cp "$TMP/device/liboflux.h" "$TMP/simulator/liboflux.h" 2>/dev/null || true
fi

rm -rf "$DEST"
mkdir -p "$DEST/device" "$DEST/simulator" "$DEST/include"
cp "$TMP/device/liboflux.a" "$DEST/device/"
cp "$TMP/simulator/liboflux.a" "$DEST/simulator/"
# Header is generated next to the .a
HDR_SRC="$TMP/device/liboflux.h"
if [[ ! -f "$HDR_SRC" ]]; then
  HDR_SRC="$TMP/OpenFlux/output/ios/liboflux.h"
fi
if [[ ! -f "$HDR_SRC" ]]; then
  # c-archive writes .h beside .a
  HDR_SRC="$(find "$TMP/device" -name 'liboflux.h' | head -1)"
fi
cp "$HDR_SRC" "$DEST/include/liboflux.h"

# Record provenance
{
  echo "OPENFLUX_REF=$OPENFLUX_REF"
  echo "OPENFLUX_COMMIT=$(git -C "$TMP/OpenFlux" rev-parse HEAD)"
  echo "BUILT_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "PATCH=vyandex-packet-tunnel"
} > "$DEST/VERSION.txt"

echo "Done: $DEST"
ls -lh "$DEST/device/liboflux.a" "$DEST/simulator/liboflux.a" "$DEST/include/liboflux.h"
