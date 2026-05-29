# CI/CD

GitHub Actions + Fastlane (same pattern as [knowledge-base-app-ios](https://github.com/DanilKorotaev/knowledge-base-app-ios)).

## Workflows

| Workflow | Trigger | What it does |
|----------|---------|----------------|
| [CI](../.github/workflows/ci.yml) | PR + push to `main` | Build Libbox → XcodeGen → unit tests + coverage gate (≥15%) |
| [Deploy TestFlight](../.github/workflows/deploy-testflight.yml) | Manual | Match signing → archive → TestFlight |

Libbox is **not** in git; CI caches `ThirdParty/Libbox.xcframework` and builds it on cache miss (~1–3 min).

## Local CI dry-run

```bash
brew install go xcodegen
bundle install
./scripts/ci/bootstrap.sh
bundle exec fastlane test
```

Simulator name (optional):

```bash
SCAN_DEVICE="iPhone 16" bundle exec fastlane test
```

## GitHub Secrets (TestFlight)

Create a **private empty repo** for Match (e.g. `coredan-vpn-certificates`). Register both bundle IDs in Apple Developer / App Store Connect:

- `com.coredan.CoreDanVPN` (app)
- `com.coredan.CoreDanVPN.PacketTunnel` (Packet Tunnel — enable **Network Extensions** / Packet Tunnel)

| Secret | Required | Description |
|--------|----------|-------------|
| `TEAM_ID` | Yes | Apple Developer Team ID (10 chars) |
| `MATCH_PASSWORD` | Yes | Passphrase for Match encrypted repo |
| `MATCH_GIT_URL` | Yes | HTTPS URL of private certs repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | If private HTTPS | `base64` of `x-access-token:GITHUB_PAT` |
| `ASC_KEY_ID` | Yes | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | Yes | ASC Issuer ID |
| `ASC_KEY_CONTENT` | Yes | Contents of `.p8` API key file |
| `APP_IDENTIFIER` | Optional | Default `com.coredan.CoreDanVPN` |
| `EXTENSION_IDENTIFIER` | Optional | Default `com.coredan.CoreDanVPN.PacketTunnel` |
| `TELEGRAM_BOT_TOKEN` | Optional | Telegram Bot API token (CI / TestFlight notify) |
| `TELEGRAM_CHAT_ID` | Optional | Chat id for notifications |

### First-time Match (on your Mac)

```bash
export MATCH_PASSWORD='your-strong-passphrase'
export MATCH_GIT_URL='https://github.com/YOU/coredan-vpn-certificates.git'
export TEAM_ID='XXXXXXXXXX'

bundle exec fastlane match appstore
```

Then add secrets in GitHub → **Settings → Secrets and variables → Actions**, and run **Actions → Deploy TestFlight → Run workflow**.

## Telegram notifications

If `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are set in GitHub Secrets, CI sends a message after **tests** and **Deploy TestFlight** (same as Knowledge Base App).

1. Create a bot via [@BotFather](https://t.me/BotFather).
2. Get chat id (message the bot → `https://api.telegram.org/bot<TOKEN>/getUpdates`, or [@userinfobot](https://t.me/userinfobot)).
3. Add repository secrets `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`.

Without these secrets, the notify step is skipped (workflow still succeeds).

Local dry-run (no network):

```bash
TELEGRAM_NOTIFY_DISABLED=1 python3 scripts/ci/telegram_notify.py tests --outcome success
```

## Coverage gate

Default minimum line coverage for `CoreDanVPNApp.app`: **15%** (`MIN_COVERAGE` env in CI). Raise as you add tests.

### Current tests (6)

| Area | Tests |
|------|--------|
| `SSURLParser` | plain `ss://`, obfs-local, v2ray-plugin, round-trip URI |
| `SingBoxConfigBuilder` | obfs JSON shape, v2ray `mode=websocket` |

UI, VPNController, Keychain, and extension code are **not** covered yet — hence ~17% line coverage on the app target is normal for now. Add tests when stabilizing those layers; consider raising `MIN_COVERAGE` gradually (e.g. 25–35%).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| CI: `Libbox not found` | Cache miss — ensure `setup-go` step runs; check `install_libbox.sh` log |
| CI: no simulator | Workflow auto-picks an iPhone simulator; set `SCAN_DEVICE` locally |
| TestFlight: extension signing | Match must include **both** app + extension profiles; enable capabilities on App ID |
| `YOUR_TEAM_ID` in archive | Deploy workflow writes `Config/Secrets.xcconfig` from `TEAM_ID` secret |

See also [FASTLANE.md](FASTLANE.md) and [SETUP.md](SETUP.md).
