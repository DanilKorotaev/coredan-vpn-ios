# Coding standards

Aligned with [knowledge-base-app-ios](https://github.com/DanilKorotaev/knowledge-base-app-ios):

1. **Protocol-first** services (`VPNControllerProtocol`, `ProfileRepositoryProtocol`, …).
2. **No secrets in git** — hosts/passwords only via user input / Keychain.
3. **Tests** for parsers and config builders.
4. **Injection** in view models for testability.

## Definition of done (feature)

- Behavior implemented
- Unit tests where logic is non-trivial
- `docs/` updated if architecture or setup changes
