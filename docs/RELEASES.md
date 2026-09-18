# iOS releases

Mapping of marketing SemVer ↔ TestFlight build ↔ git tag.

Rows are appended by `scripts/ci/prepare_release.py` on each successful
main→TestFlight ship (commit lands after upload).

| Version | Build (CI) | Git tag | Date | Notes |
|---------|------------|---------|------|-------|
| 1.1.1 | 13 | `ios/v1.1.1` | 2026-09-18 | Stop NE jetsam from Volga memory pressure. |
| 1.1.0 | 12 | `ios/v1.1.0` | 2026-09-18 | Set marketing version to 1.1.0 |
| 0.1.0 | 11 | `ios/v0.1.0` | 2026-09-18 | Auto TestFlight after green CI with SemVer releases. |
