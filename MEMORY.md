# MEMORY — IOTA T@H Monitor

> Working memory. READ before coding, UPDATE after every edit.
> Concise (< 150 lines). Detailed docs → `llms.txt` / `docs/`.

## Current state
- Working v1: menu bar shows position/state/work/speedtest/backend,
  *launch at login* toggle (`SMAppService`) + Preferences window.
- Published on GitHub `CorentinGC/iota-tah-monitor` (`main` branch).
- Core restructured into a testable SwiftPM target; `swift test` = 6 green tests.
- Agent configuration in place (CLAUDE.md, AGENTS.md, docs/, llms.txt, agents).

## Next steps
- [ ] Refine `StateParser.workDescription` once the front of the queue is reached
      (capture a real training line — never observed to date).
- [ ] Optional: `.icns` icon + colored status by phase.

## Recent decisions
- 2026-07-05 — Read the CLI log only, no ws (rotating token + Electron host
  conflict). See `docs/decisions/0001`.
- 2026-07-05 — Core without AppKit in `Sources/IOTAMonitorCore/` (SwiftPM/tests),
  AppKit app in `App/` (built via `build.sh`/swiftc, outside SwiftPM).

## Pitfalls / gotchas
- **Log format = contract**: a wording change on the Macrocosmos side breaks
  parsing silently. Run the `log-format-watcher` agent when in doubt.
- Restarting the official app = new `queue_id` = back of the queue. Do not restart.
- `main.swift` does NOT import `IOTAMonitorCore`: in the app build, swiftc compiles
  core + App together into a single module.
- `swift test` does NOT build the app (AppKit) — only the core.

## Pointers
- Architecture: `docs/architecture.md` · Setup: `docs/setup.md` · Index: `llms.txt`
