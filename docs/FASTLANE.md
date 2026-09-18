# Fastlane

## Install

```bash
bundle install
bundle exec which fastlane   # must not be /usr/local/bin/fastlane from system Ruby
```

Ruby **3.3.x** (see `.ruby-version`). Use Homebrew Ruby or rbenv, not macOS system Ruby.

## Lanes

### `test`

Runs **scan** on `CoreDanVPNApp` (simulator, `CODE_SIGNING_ALLOWED=NO`). Requires `./scripts/ci/bootstrap.sh` first.

```bash
./scripts/ci/bootstrap.sh
bundle exec fastlane test
```

### `beta`

App Store archive + TestFlight. Requires Match + ASC API key — see [CI_CD.md](CI_CD.md).

Marketing version comes from root [`VERSION`](../VERSION) (synced into `project.yml` via `scripts/ci/sync_marketing_version.sh`). Build number is `GITHUB_RUN_NUMBER` in CI.

```bash
export TEAM_ID="66C9VGAZR5"
export ASC_KEY_ID="..."
export ASC_ISSUER_ID="..."
export ASC_KEY_CONTENT="$(cat AuthKey_XXX.p8)"
export MATCH_PASSWORD="..."
export MATCH_GIT_URL="..."

bundle exec fastlane beta
```

## Releases

Default path: **push to `main`** → CI → Deploy TestFlight → **auto PATCH** + changelog from commits → tag `ios/v*`. No PR required. Full rules: [RELEASE_PROCESS.md](RELEASE_PROCESS.md).

- Human-readable history: [`CHANGELOG.md`](../CHANGELOG.md)
- Build ↔ tag mapping: [`docs/RELEASES.md`](RELEASES.md)
- Intentional **minor/major**: edit `VERSION`, or commit trailer `release-bump: minor|major`, or Actions → Deploy TestFlight → bump input
