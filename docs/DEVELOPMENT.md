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
xcodebuild -scheme CoreDanVPNApp -destination 'platform=iOS Simulator,name=iPhone 16' test
```

(Fastlane can be added later like Knowledge Base App.)

## Git

Repository is prepared for git later (`.gitignore` present). Do not commit `Config/Secrets.xcconfig` or real profile URIs.
