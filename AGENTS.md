# AGENTS.md — IOTA T@H Monitor

Rules for AI agents. Included by `CLAUDE.md` (`@AGENTS.md`).

## Before coding
- Read `MEMORY.md` + `llms.txt`. Update `MEMORY.md` after each edit.
- Official docs take precedence over your training data. For AppKit /
  ServiceManagement / SwiftPM, verify the API via Apple's docs or the `context7`
  MCP rather than guessing (`SMAppService` is macOS 13+, a recent API).

## The log format is the contract
- The project only **reads and parses** the official app's log. All behavior
  depends on the strings the miner writes to
  `~/Library/Logs/IOTA Train at Home/<date>-cli.log`.
- Before modifying `StateParser`, look at a current real log to confirm the
  format. After changes: `swift test` must stay green + add a test case for any
  new pattern.
- Parsing the **actual work** is *best-effort*: no real training line observed to
  date. When a real one appears (queue front reached), capture the exact line and
  enrich `workDescription`.

## Non-negotiable invariants
- **Read only**: never write to the logs, never modify the official app, never
  connect to the `127.0.0.1:8010` ws.
- **`StateParser` never throws** and does not crash on an unknown line.
- **AppKit-free core**: `Sources/IOTAMonitorCore/` stays importable/testable
  without UI. The UI lives in `App/`.

## Tooling
- No third-party dependency, and that's a goal: prefer the stdlib/Foundation.
  Add a dependency only with a documented reason (ADR in `docs/decisions/`).
- Build app = `./build.sh` (swiftc → `.app`). Tests = `swift test`.

## Workflow
- Parallelize independent work (see `CLAUDE.md`).
- Never commit/push without explicit approval. Follow Conventional Commits.
- Respect the implicit lint: no `swiftc` warnings, idiomatic code.
