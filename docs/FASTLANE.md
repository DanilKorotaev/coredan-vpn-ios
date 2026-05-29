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

```bash
export TEAM_ID="..."
export ASC_KEY_ID="..."
export ASC_ISSUER_ID="..."
export ASC_KEY_CONTENT="$(cat AuthKey_XXX.p8)"
export MATCH_PASSWORD="..."
export MATCH_GIT_URL="..."

bundle exec fastlane beta
```
