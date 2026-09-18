# iOS releases

Mapping of marketing SemVer ↔ TestFlight build ↔ git tag.

Rows are appended by `scripts/ci/prepare_release.py` on each successful
main→TestFlight ship (commit lands after upload).

| Version | Build (CI) | Git tag | Date | Notes |
|---------|------------|---------|------|-------|
| 1.1.4 | 16 | `ios/v1.1.4` | 2026-09-18 | Stop starving the tunnel — remove soft memory caps. |
| 1.1.3 | 15 | `ios/v1.1.3` | 2026-09-18 | Shrink Volga 16MiB buffers that jetsam the NE. |
| 1.1.2 | 14 | `ios/v1.1.2` | 2026-09-18 | Undo GC thrash that froze the phone. |
| 1.1.1 | 13 | `ios/v1.1.1` | 2026-09-18 | Stop NE jetsam from Volga memory pressure. |
| 1.1.0 | 12 | `ios/v1.1.0` | 2026-09-18 | Set marketing version to 1.1.0 |
| 0.1.0 | 11 | `ios/v0.1.0` | 2026-09-18 | Auto TestFlight after green CI with SemVer releases. |
