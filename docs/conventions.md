# Conventions

## Code
- **Core without AppKit**: `Sources/IOTAMonitorCore/` imports only Foundation. All
  parseable/testable logic lives there. AppKit/ServiceManagement stay in `App/`.
- **Defensive `StateParser`**: never throws, never crashes on an unknown line —
  falls back to `lastRawLine`. An unrecognized format must degrade, not crash.
- **Explicit naming**; booleans `is/has/can/should`; early returns; ≤ 3 levels
  of indentation; no dead code.
- **Code comments in English** (consistency with the existing code). The `docs/` are in English.

## Tests
- The core is covered by `swift test` (`Tests/IOTAMonitorCoreTests/`).
- Any parsing change: keep the tests green **and** add a case for the
  new log pattern. Use fixtures = real log lines.
- The AppKit app has no automated tests → manual check (`./build.sh` + `open`).

## Log format (contract)
The `StateParser` matchers depend on the miner's strings. Where to touch when the
format changes:
| Data | Code point |
|--------|---------------|
| Position | `firstInt(after: "'position':")` |
| Phase | `derivePhase(...)` |
| Work | `workDescription(in:)` (best-effort) |
| Backend | count of `503 … queue_state` / `404 … orchestrator request` |

## Git
- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
- No commit/push without explicit approval.
- `IOTA Monitor.app`, `.build/`, `.mcp/` are gitignored.

## Decisions
Any notable technical decision → an ADR in `docs/decisions/` (see the template).
