# IOTA T@H Monitor — Agent Guide

@AGENTS.md

> Read this file, `AGENTS.md`, `MEMORY.md` and `llms.txt` **before** any code task.

## What it is
A **macOS menu bar app** (Swift/AppKit) that reads the CLI log of the official IOTA
"Train at Home" app and shows the real queue position / state / work — which the
official UI does not display (its `register.queue_state` handler returns 503).
Read only, no network connection, no runtime dependency.

## Stack
Swift 6 · AppKit (`NSStatusItem`) · ServiceManagement (`SMAppService`, login item) ·
macOS 13+ · SwiftPM (core tests only) · no third-party dependency.

## Commands
| Goal | Command |
|------|---------|
| Tests (core) | `swift test` |
| Build app | `./build.sh` → `IOTA Monitor.app` |
| Run | `open "IOTA Monitor.app"` |
| Test parser against real log | see `README.md` § Maintainability |

## Layout
- `Sources/IOTAMonitorCore/` — pure **tested** logic (`LogReader`, `StateParser`), no AppKit dependency. SwiftPM target.
- `App/` — AppKit app (`main.swift`, `Preferences.swift`). **Outside SwiftPM**, built by `build.sh` via `swiftc` (compiles core + app into a single module).
- `Tests/IOTAMonitorCoreTests/` — parser tests (`@testable import IOTAMonitorCore`).

## Memory & documentation (mandatory)
- **Before coding**: read `MEMORY.md` (current state) + `llms.txt` (doc index).
- **After each edit**: update `MEMORY.md` (state, next steps, gotchas).
- **On any change to architecture/pattern/log format**: update `docs/` + `llms.txt`.
- `MEMORY.md` = short working memory. `docs/` = detailed stable docs. Don't duplicate.

## Code quality
- **DRY / SRP**: 1 file = 1 responsibility. The core stays **AppKit-free** (testable).
- **Size**: warning at 400 LOC, split at 500.
- **Explicit naming**; booleans `is/has/can/should`.
- **Early returns**, max 3 levels of indentation.
- **No dead code**, no `TODO` without follow-up.
- **Defensive parsing**: `StateParser` must **never** throw or crash on an unknown line — fall back to the last raw line.

## Project conventions
- **Tests**: the core (`LogReader`/`StateParser`) is covered by `swift test` — any parsing change must keep the tests green and add a case for the new format. The AppKit app has no automated tests (manual check: `./build.sh` + `open`).
- **Log format = contract**: everything depends on the strings written by the miner. See `docs/architecture.md` and `README.md` § Maintainability for where to touch.
- **Commits**: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`…).
- **Language**: docs and comments in **English** (the repo is international). Keep identifiers and existing code comments in English too.
- **No network**: never add a connection to the `127.0.0.1:8010` ws (rotating token + conflict with the Electron host). Log reading only.

## Subagent parallelization (default)
For any decomposable work, launch several subagents in parallel (one reply, multiple calls):
- Exploration: multiple targeted `Explore`.
- Multi-file editing: one agent per independent file.
- Review: agents by dimension in parallel.
- Optimize the `model` per agent: `haiku` for search/docs/mechanical, `sonnet` for code/review, `opus` for architecture/hard debugging.

## Project agents
- `log-format-watcher` (haiku) — checks that `StateParser`'s matchers still fit the current real log. **Fragility point #1.**
- `swift-reviewer` (sonnet) — Swift/AppKit review (retain cycles, main-thread UI, `NSStatusItem`/`SMAppService` idioms).
- `doc-maintainer` (haiku) — syncs `docs/` + `llms.txt` + `MEMORY.md` after an architecture/pattern change.

## MCP
No `.mcp.json`: native app with no web surface (the `chrome-devtools` MCP does not apply). `context7` (global) remains useful for AppKit/SwiftPM docs.

## Pointers
`AGENTS.md` — agent rules · `llms.txt` — doc index · `docs/` — detailed docs · `MEMORY.md` — working memory · `README.md` — usage + maintainability.
