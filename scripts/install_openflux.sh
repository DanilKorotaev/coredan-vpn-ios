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

# 1c) REMOVE soft memory cap. Upstream SetMemoryLimit(40MiB) + our tighter
# caps caused GC thrash (phone freezes) and still jetsammed under Volga.
# Let the process use memory normally; iOS hard jetsam remains the ceiling.
text2, nmem = re.subn(
    r"\t// Keep the extension well under the NE memory cap\.\n\tdebug\.SetMemoryLimit\(40 << 20\)\n\tdebug\.SetGCPercent\(20\)\n\n",
    "\t// iOS CoreDan: do NOT SetMemoryLimit — soft caps thrash GC / freeze the phone.\n\n",
    text,
    count=1,
)
if nmem == 0:
    # Fallback if comment text drifts
    text2, nmem = re.subn(
        r"\tdebug\.SetMemoryLimit\(40 << 20\)\n\tdebug\.SetGCPercent\(20\)\n",
        "\t// iOS CoreDan: SetMemoryLimit removed (GC thrash).\n",
        text,
        count=1,
    )
if nmem == 0:
    raise SystemExit("export_ios_packet.go: could not remove SetMemoryLimit")
text = text2
print(f"Removed SetMemoryLimit/GCPercent ({nmem})")

# Drop unused debug import if it becomes unused — keep import; Go compiler
# will fail if debug is unused. Re-add a harmless reference or remove import.
if "debug." not in text.split("func OpenFluxStartPacketTunnel")[1].split("//export OpenFluxTunWritePacket")[0]:
    text2, nimp = re.subn(
        r"\t\"runtime/debug\"\n",
        "",
        text,
        count=1,
    )
    if nimp:
        text = text2
        print("Removed unused runtime/debug import")

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

# 2) Fix NE footguns only:
# - b64BufPool 16MiB pre-alloc (instant pressure)
# - QueueSize 1e6 empty channel slots
# - WorkerCount 2000 (VPS exit default — freezes a phone on Start; 64 is enough)
# Do NOT SetMemoryLimit / starve batch sizes.
vtext = volga.read_text()
replacements = [
    (
        r"New: func\(\) interface\{\} \{ return make\(\[\]byte, 0, 16\*1024\*1024\) \},",
        "New: func() interface{} { return make([]byte, 0, 256*1024) }, // iOS NE: was 16MiB footgun",
    ),
    (r"WorkerCount:\s*2000,", "WorkerCount: 64, // iOS NE: VPS default 2000 freezes Start()"),
    (r"QueueSize:\s*1000000,", "QueueSize: 8192, // iOS NE: channel slots (was 1000000)"),
    (r"MaxIdleConnsPerHost:\s*2000,", "MaxIdleConnsPerHost: 64,"),
    (r"MaxIdleConns:\s*4000,", "MaxIdleConns: 128,"),
]
counts = []
for pat, rep in replacements:
    vtext, n = re.subn(pat, rep, vtext, count=1)
    counts.append(n)
if counts[0] == 0 or counts[1] == 0:
    raise SystemExit(f"vyandex.go: critical NE patches failed: {counts}")
volga.write_text(vtext)
print(f"Patched Volga NE footguns {counts}")
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
