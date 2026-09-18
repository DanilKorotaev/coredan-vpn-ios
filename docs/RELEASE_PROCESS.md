# iOS release process (SemVer)

Default flow — **no PR required** (trunk-based):

```text
agent commit on main (good message)
  → CI tests
  → Deploy TestFlight
      → auto PATCH bump (+ CHANGELOG from commits)
      → archive / upload
      → commit VERSION+CHANGELOG+RELEASES [skip ci]
      → tag ios/vX.Y.Z
```

One meaningful push to `main` ≈ one TestFlight SemVer release.

Tag pushes and `[skip ci]` release commits **do not** re-run CI or Deploy.

## Version numbers

| Field | Source | Meaning |
|-------|--------|---------|
| Marketing | Root [`VERSION`](../VERSION) (written by deploy) | SemVer `MAJOR.MINOR.PATCH` |
| Build | `GITHUB_RUN_NUMBER` in Fastlane `beta` | Monotonic integer; **not** the same as PATCH |

### When to bump

| Change | Bump | How |
|--------|------|-----|
| Ordinary fix / small feature (default) | **PATCH** | Automatic on each successful main→TestFlight deploy |
| Notable feature | **MINOR** | Set `VERSION` to `X.Y.0`, **or** trailer `release-bump: minor`, **or** Actions → Deploy → bump=`minor` |
| Breaking / App Store reset | **MAJOR** | Same with `major` |

You do **not** need to edit `VERSION` for routine work — write a clear commit message; deploy turns it into changelog bullets.

### Commit message tips

- Prefer Conventional Commits: `feat:`, `fix:`, `docs:` (mapped to Added / Fixed / Changed).
- Intentional minor/major without editing `VERSION`:

  ```text
  feat: ship OpenFlux VOLGA MVP

  release-bump: minor
  ```

## Agent / local workflow

1. Implement the change.
2. Run tests: `./scripts/ci/bootstrap.sh && bundle exec fastlane test`.
3. Commit with a descriptive subject (this becomes the changelog line).
4. Push to `main`.
5. Wait for CI + TestFlight Telegram notify (`version (build)` + CHANGELOG / tag links).

Optional: draft notes under `## [Unreleased]` in [`CHANGELOG.md`](../CHANGELOG.md); deploy folds them into the cut version.

## Deploy details

1. [`scripts/ci/prepare_release.py`](../scripts/ci/prepare_release.py) runs **before** Fastlane (local working tree only — not pushed yet).
2. Fastlane syncs marketing version from `VERSION`, build from `GITHUB_RUN_NUMBER`.
3. On **upload success**: [`scripts/ci/commit_and_tag_release.sh`](../scripts/ci/commit_and_tag_release.sh) snapshots prepared metadata, resets to **current** `origin/main`, merges VERSION/CHANGELOG/RELEASES onto the tip (no rebase), commits with `[skip ci]`, and pushes tag `ios/v{VERSION}`.
4. Telegram notify runs **after** the tag step and reports a warning if the IPA uploaded but the git tag/commit failed.
5. Failed upload does **not** advance the git tag / release commit (safe to retry).

Concurrent deploys: GHA concurrency queues Deploy jobs on `main`. Metadata is always applied on the latest tip so overlapping VERSION/CHANGELOG edits do not fail the job.

## Traceability

Given `0.1.2 (build 42)` from TestFlight / Telegram:

1. [`CHANGELOG.md`](../CHANGELOG.md) section `0.1.2`
2. Git tag `ios/v0.1.2`
3. [`docs/RELEASES.md`](RELEASES.md) row for build mapping
