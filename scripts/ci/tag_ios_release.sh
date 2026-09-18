#!/usr/bin/env bash
# Create annotated tag ios/v{VERSION} after a successful TestFlight upload (once per marketing version).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="ios/v${VERSION}"

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "Tag ${TAG} already exists locally; skip."
  exit 0
fi

git fetch --tags --force origin 2>/dev/null || true

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists on origin; skip."
  exit 0
fi

git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git config user.email "${GIT_AUTHOR_EMAIL:-github-actions[bot]@users.noreply.github.com}"

BUILD=""
META="$ROOT/fastlane/test_output/ci_testflight.json"
if [[ -f "$META" ]]; then
  BUILD="$(python3 -c "import json,pathlib; print(json.loads(pathlib.Path('$META').read_text()).get('build_number',''))" 2>/dev/null || true)"
fi

MSG="iOS ${VERSION}"
if [[ -n "$BUILD" ]]; then
  MSG="iOS ${VERSION} (build ${BUILD})"
fi

git tag -a "$TAG" -m "$MSG"
git push origin "refs/tags/${TAG}"
echo "Created and pushed tag ${TAG}"
