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
VOLGA="$TMP/OpenFlux/transport/yandex/vyandex.go"

echo "Patching OpenFlux for iOS Network Extension (vyandex + low-memory Volga)..."
python3 - <<'PY' "$PACKET" "$VOLGA"
import pathlib, sys, re

packet = pathlib.Path(sys.argv[1])
volga = pathlib.Path(sys.argv[2])

# 1) Packet tunnel: accept vyandex/volga (upstream only has yandex/oneme).
text = packet.read_text()
if 'vyandex' not in text:
    needle = '''\tswitch tt {
\tcase "yandex", "":
\t\tt = transport.NewCompressedTransport(yandex.NewYandexDocsTransport(docURL, config))
\tcase "oneme":'''
    replacement = '''\tswitch tt {
\tcase "yandex", "":
\t\tt = transport.NewCompressedTransport(yandex.NewYandexDocsTransport(docURL, config))
\tcase "vyandex", "volga":
\t\t// VOLGA + legacy LZ4 (CompressedTransport) — must match exit --codec=legacy.
\t\tt = transport.NewCompressedTransport(yandex.NewYandexVolgaTransport(docURL, config))
\tcase "oneme":'''
    if needle not in text:
        raise SystemExit("export_ios_packet.go: unexpected format, cannot patch vyandex")
    text = text.replace(needle, replacement, 1)
    print("Patched export_ios_packet.go (vyandex)")
else:
    print("vyandex already in export_ios_packet.go")

# 1b) TunReadPacket: empty payloads must NOT return 0 — Swift treats <=0 as EOF and
# kills the downlink loop while the VPN stays "connected" (sites never load).
old_read = '''\tselect {
\tcase data := <-outQ:
\t\tn := len(data)
\t\tif n > int(max) {
\t\t\tn = int(max)
\t\t}
\t\tdst := unsafe.Slice((*byte)(unsafe.Pointer(buf)), int(max))
\t\tcopy(dst[:n], data[:n])
\t\treturn C.int(n)
\tcase <-ctx.Done():
\t\treturn 0
\t}'''
new_read = '''\tfor {
\t\tselect {
\t\tcase data := <-outQ:
\t\t\tif len(data) == 0 {
\t\t\t\tcontinue // keepalives / empty frames — not EOF
\t\t\t}
\t\t\tn := len(data)
\t\t\tif n > int(max) {
\t\t\t\tn = int(max)
\t\t\t}
\t\t\tdst := unsafe.Slice((*byte)(unsafe.Pointer(buf)), int(max))
\t\t\tcopy(dst[:n], data[:n])
\t\t\treturn C.int(n)
\t\tcase <-ctx.Done():
\t\t\treturn -1 // real stop
\t\t}
\t}'''
if old_read not in text:
    raise SystemExit("export_ios_packet.go: TunReadPacket select block not found")
if 'keepalives / empty frames' not in text:
    text = text.replace(old_read, new_read, 1)
    print("Patched OpenFluxTunReadPacket (empty!=EOF, stop=-1)")
else:
    print("TunReadPacket already patched")

# 1c) Soft memory cap 40MiB is too tight for VOLGA and jetsams the appex;
# iOS then reasserts the VPN (badge flaps). Raise soft limit / GC.
text2, nmem = re.subn(
    r"debug\.SetMemoryLimit\(40 << 20\)",
    "debug.SetMemoryLimit(120 << 20) // iOS NE: was 40MiB (VOLGA jetsam)",
    text,
    count=1,
)
text2, ngc = re.subn(
    r"debug\.SetGCPercent\(20\)",
    "debug.SetGCPercent(50)",
    text2,
    count=1,
)
if nmem == 0:
    raise SystemExit("export_ios_packet.go: MemoryLimit patch failed")
text = text2
print(f"Patched memory limit/GC ({nmem},{ngc})")

# 1d) Drop empty frames before they hit the TUN read queue.
old_recv = '''\toutQ := make(chan []byte, 1024)
\t// Packets coming back from the exit node -> queue for the device.
\tt.Receive(func(data []byte) {
\t\tselect {
\t\tcase outQ <- append([]byte(nil), data...):
\t\tdefault: // queue full: drop, TCP will retransmit
\t\t}
\t})'''
new_recv = '''\toutQ := make(chan []byte, 1024)
\t// Packets coming back from the exit node -> queue for the device.
\tt.Receive(func(data []byte) {
\t\tif len(data) == 0 {
\t\t\treturn
\t\t}
\t\tselect {
\t\tcase outQ <- append([]byte(nil), data...):
\t\tdefault: // queue full: drop, TCP will retransmit
\t\t}
\t})'''
if old_recv not in text:
    raise SystemExit("export_ios_packet.go: Receive queue block not found")
if 'if len(data) == 0' not in text.split('outQ := make')[1][:400]:
    text = text.replace(old_recv, new_recv, 1)
    print("Patched Receive to drop empty frames")
else:
    print("Receive empty-drop already present")
packet.write_text(text)

# 2) Default VolgaConfig is sized for VPS exit (2000 workers / 1M queue) and
# jetsams NEPacketTunnelProvider (~50MB). Shrink for the iOS client lib.
vtext = volga.read_text()
vtext2, n = re.subn(
    r"WorkerCount:\s*2000,",
    "WorkerCount: 64, // iOS NE: was 2000 (jetsam)",
    vtext,
    count=1,
)
vtext2, n2 = re.subn(
    r"QueueSize:\s*1000000,",
    "QueueSize: 4096, // iOS NE: was 1000000",
    vtext2,
    count=1,
)
vtext2, n3 = re.subn(
    r"MaxIdleConnsPerHost:\s*2000,",
    "MaxIdleConnsPerHost: 32,",
    vtext2,
    count=1,
)
vtext2, n4 = re.subn(
    r"MaxIdleConns:\s*4000,",
    "MaxIdleConns: 64,",
    vtext2,
    count=1,
)
if n + n2 + n3 + n4 == 0:
    raise SystemExit("vyandex.go: could not patch DefaultVolgaConfig for iOS memory")
volga.write_text(vtext2)
print(f"Patched DefaultVolgaConfig (workers/queue/idle conns: {n},{n2},{n3},{n4})")
PY

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
