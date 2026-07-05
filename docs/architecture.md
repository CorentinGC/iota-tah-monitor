# Architecture

## Overview

A single Swift/AppKit process, **read-only**, with no networking. A timer (5 s) reads
the tail of the official app's CLI log, parses it, and repaints the menu bar.

```
~/Library/Logs/IOTA Train at Home/<YYYY-MM-DD>-cli.log
        │  (tail, 64 KB)
        ▼
   LogReader ──► StateParser ──► MinerState ──► MenuBarApp (NSStatusItem)
```

## Modules

| File | Role | Dependencies |
|---------|------|-------------|
| `Sources/IOTAMonitorCore/LogReader.swift` | Resolves the current day's log, reads the tail (64 KB), handles a missing/empty file plus date rotation at midnight. | Foundation |
| `Sources/IOTAMonitorCore/StateParser.swift` | Regex over the tail → `MinerState`. Defensive, never throws. | Foundation |
| `App/main.swift` | `NSStatusItem`, timer loop, title + menu rendering. | AppKit, ServiceManagement |
| `App/Preferences.swift` | *Launch at Login* toggle (`SMAppService`) + Preferences window. | AppKit, ServiceManagement |

## Core / app boundary

The **core** (`Sources/IOTAMonitorCore/`) depends only on Foundation → testable via
SwiftPM (`swift test`, `@testable import`). The **app** (`App/`) holds all of AppKit.
`build.sh` compiles both directories together into a single module via `swiftc`
(so `main.swift` does not import `IOTAMonitorCore` — same module in the app build).
SwiftPM only knows about the core + the tests.

## Data flow

1. `LogReader.readTail()` → `.ok(text, mtime)` / `.empty` / `.missing`.
2. `StateParser.parse(text:now:)` → `MinerState { position, trendPerMin, phase,
   workLine, speedtestOk, queueStateErrors, notFoundErrors, uptime, lastLogTime,
   lastRawLine }`.
3. `MenuBarApp` maps `phase` → title (`⛏ <pos> ▼/▲`, `off`, `…`, `▶︎`, `?`) and
   builds the drop-down menu.

## Structural decisions
- **Log-only, no ws**: the ws token for `127.0.0.1:8010` rotates on every
  restart and the Electron host occupies the connection. See `decisions/0001`.
- **State machine** derived from the log: `off → starting → resetting → speedtest →
  queued → working`. Also `off` if the last line is > 120 s old (stalled log).

## Point of fragility
The **log line format** is the implicit contract. A wording change on the
Macrocosmos side breaks parsing silently — hence the `log-format-watcher` agent
and the test coverage on `StateParser`.
