#!/usr/bin/env bash
# Prepares the tree for Xcode build / Fastlane on CI or locally.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ ! -f Config/Secrets.xcconfig ]]; then
  cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
  echo "Created Config/Secrets.xcconfig from example"
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen…"
  brew install xcodegen
fi

if [[ ! -d ThirdParty/Libbox.xcframework ]]; then
  echo "Building Libbox.xcframework…"
  ./scripts/install_libbox.sh
else
  echo "Libbox.xcframework present"
fi

xcodegen generate
echo "Bootstrap done."
