# Development

## Layout

- `CoreDanVPNApp/` — application target
- `CoreDanVPNExtension/` — packet tunnel
- `Shared/` — code shared with extension
- `CoreDanVPNAppTests/` — unit tests
- `project.yml` — XcodeGen

## Regenerate project

```bash
xcodegen generate
```

## Tests

```bash
./scripts/ci/bootstrap.sh
bundle exec fastlane test
```

Or directly:

```bash
xcodebuild -scheme CoreDanVPNApp -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO
```

CI/CD: [CI_CD.md](CI_CD.md).

## Git

Repository is prepared for git later (`.gitignore` present). Do not commit `Config/Secrets.xcconfig` or real profile URIs.
