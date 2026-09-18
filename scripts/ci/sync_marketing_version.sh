#!/usr/bin/env bash
# Sync MARKETING_VERSION in project.yml from the root VERSION file, then regenerate the Xcode project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION_FILE="$ROOT/VERSION"
PROJECT_YML="$ROOT/project.yml"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "error: VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "error: VERSION must look like MAJOR.MINOR.PATCH, got: '$VERSION'" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_YML" ]]; then
  echo "error: project.yml not found" >&2
  exit 1
fi

python3 - "$PROJECT_YML" "$VERSION" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text(encoding="utf-8")
updated, count = re.subn(
    r'(MARKETING_VERSION:\s*")[^"]*(")',
    rf"\g<1>{version}\2",
    text,
    count=1,
)
if count != 1:
    print("error: could not update MARKETING_VERSION in project.yml", file=sys.stderr)
    sys.exit(1)
path.write_text(updated, encoding="utf-8")
print(f"project.yml MARKETING_VERSION -> {version}")
PY

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
  echo "xcodegen generate: ok"
else
  echo "warning: xcodegen not found; skipped project regeneration" >&2
fi
