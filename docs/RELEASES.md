# iOS releases

Mapping of marketing SemVer ↔ TestFlight build ↔ git tag.

Rows are appended by `scripts/ci/prepare_release.py` on each successful
main→TestFlight ship (commit lands after upload).

| Version | Build (CI) | Git tag | Date | Notes |
|---------|------------|---------|------|-------|
| 0.1.0 | 11 | `ios/v0.1.0` | 2026-09-18 | Auto TestFlight after green CI with SemVer releases. |
