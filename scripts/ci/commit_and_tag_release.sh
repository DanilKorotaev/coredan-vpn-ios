#!/usr/bin/env bash
# After a successful TestFlight upload: commit VERSION/CHANGELOG/RELEASES and push tag ios/v*.
#
# Does NOT rebase a release commit onto main (that conflicts when another deploy already
# pushed the same files). Instead: snapshot prepared metadata → reset to origin/main tip →
# merge metadata onto tip → commit → tag.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BRANCH="${GITHUB_REF_NAME:-main}"
if [[ "$BRANCH" == "refs/heads/"* ]]; then
  BRANCH="${BRANCH#refs/heads/}"
fi
# workflow_run checkouts are detached at head_sha; publish release metadata to main tip
if [[ "${GITHUB_EVENT_NAME:-}" == "workflow_run" ]]; then
  BRANCH="main"
fi

git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git config user.email "${GIT_AUTHOR_EMAIL:-github-actions[bot]@users.noreply.github.com}"

BUILD=""
META="$ROOT/fastlane/test_output/ci_testflight.json"
if [[ -f "$META" ]]; then
  BUILD="$(python3 -c "import json,pathlib; print(json.loads(pathlib.Path('fastlane/test_output/ci_testflight.json').read_text()).get('build_number',''))" 2>/dev/null || true)"
fi

INTENDED_VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="ios/v${INTENDED_VERSION}"

if [[ ! -f VERSION || ! -f CHANGELOG.md || ! -f docs/RELEASES.md ]]; then
  echo "error: expected VERSION, CHANGELOG.md, docs/RELEASES.md from prepare_release" >&2
  exit 1
fi

SNAPSHOT="$(mktemp -d "${TMPDIR:-/tmp}/vpn-release-meta.XXXXXX")"
cleanup() { rm -rf "$SNAPSHOT"; }
trap cleanup EXIT

mkdir -p "$SNAPSHOT/docs"
cp VERSION CHANGELOG.md "$SNAPSHOT/"
cp docs/RELEASES.md "$SNAPSHOT/docs/RELEASES.md"
echo "Snapshotted release metadata for ${INTENDED_VERSION} (build ${BUILD:-—})"

discard_deploy_working_tree() {
  # prepare_release / fastlane beta touch tracked files we must not push (xcodeproj, project.yml).
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Discarding local deploy-only changes before syncing to ${BRANCH}:"
    git status --porcelain
    git reset --hard HEAD
    git clean -fd --exclude=.git --exclude=vendor --exclude=fastlane/test_output --exclude=fastlane/build_logs 2>/dev/null || git clean -fd
  fi
}

discard_deploy_working_tree

git fetch origin "${BRANCH}"
git fetch --tags --force origin 2>/dev/null || true

if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
  git checkout -B "${BRANCH}" "origin/${BRANCH}"
  echo "Checked out origin/${BRANCH} at $(git rev-parse --short HEAD)"
else
  echo "error: origin/${BRANCH} not found" >&2
  exit 1
fi

python3 scripts/ci/apply_release_metadata.py \
  --snapshot-dir "$SNAPSHOT" \
  --build "${BUILD}" \
  --date "$(date -u +%F)"

git add VERSION CHANGELOG.md docs/RELEASES.md
if [[ -n "$(git status --porcelain -- VERSION CHANGELOG.md docs/RELEASES.md)" ]]; then
  MSG="chore(release): ios/v${INTENDED_VERSION}"
  if [[ -n "$BUILD" ]]; then
    MSG="${MSG} (build ${BUILD})"
  fi
  MSG="${MSG} [skip ci]"
  git commit -m "$MSG"
  echo "Created release commit on $(git rev-parse --short HEAD)"
  git push origin "HEAD:${BRANCH}"
  echo "Pushed release commit for ${INTENDED_VERSION} -> ${BRANCH}"
else
  echo "No release metadata changes to commit (already on ${BRANCH})."
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists on origin; skip create."
  exit 0
fi

MSG="iOS ${INTENDED_VERSION}"
if [[ -n "$BUILD" ]]; then
  MSG="iOS ${INTENDED_VERSION} (build ${BUILD})"
fi
git tag -a "$TAG" -m "$MSG"
git push origin "refs/tags/${TAG}"
echo "Created and pushed tag ${TAG}"
