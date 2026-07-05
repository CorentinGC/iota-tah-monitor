# IOTA T@H Monitor — Design

**Date:** 2026-07-05
**Status:** Approved

## Problem

The official IOTA "Train at Home" macOS app has a UI blind to real state. Its
Electron host advertises the `register.queue_state` capability but has no
handler, so every position push from the CLI fails:

```
register_set_queue_state exhausted retries (3): POST /register/queue_state failed 503:
{"detail":"unsupported: No handler for register.queue_state"}
```

Result: the UI freezes on the last visible step ("Running speedtest...") while
the miner is actually progressing through the registration queue. The only place
the truth exists is the CLI log.

The speedtest failure itself (`Failed to run speedtest: Unable to connect to
servers to test latency.`) is logged at DEBUG and is non-fatal — registration
continues past it. Not the blocker.

## Goal

A lightweight macOS menu bar app showing the essentials at a glance:
current queue position (+ trend), real miner state, effective work status when
assigned, plus speedtest/backend health flags. Read-only. Zero interference with
the official app.

## Non-goals

- No control (start/stop) of the miner.
- No connection to the local ws protocol server (token rotates each restart;
  the Electron host already owns the single connection — tapping risks conflict).
- No modification of the official app or its logs.

## Data source

Single source: `~/Library/Logs/IOTA Train at Home/<YYYY-MM-DD>-cli.log`.
Tail only (last ~64 KB), re-scanned on a timer. Date rotation handled at midnight
by re-resolving the filename.

Fields extracted:

| Field | Log signal |
|---|---|
| Position + trend | `'position': N` → delta between reads → ▼/▲ per min |
| Phase / state | `status': 'queued'`, `state: 'resetting'`, `Miner Ready`, `run_speedtest`, `best_run`, `training.state` |
| Work (effective) | training lines if present (layer/batch/loss/step) — else "idle (not assigned)" |
| Speedtest | `Failed to run speedtest` → fail (cosmetic) |
| Backend health | count of recent `503 ... queue_state` / `404` |
| Uptime | first `Starting miner` timestamp of current session |

Note: no training/work line has ever appeared in the observed logs (miner never
reached the queue front in 3 days). Work parsing is best-effort against probable
patterns; refined once assignment is actually observed. Unknown lines render raw,
never crash.

## Architecture

Single Swift/AppKit process. `NSStatusItem` in the menu bar. A `Timer` (~5 s)
drives: read tail → parse → update title + dropdown menu. No writes, no network.

Three components:

- **LogReader** — resolves today's log file, reads the tail, handles date
  rotation and missing/empty file.
- **StateParser** — regex over known lines → `MinerState { position, trend,
  phase, workLine, speedtestOk, backendErrors, uptime, lastUpdate }`. Defensive:
  unrecognized patterns fall back to the last raw line.
- **MenuBarApp** — owns `NSStatusItem`, renders title `⛏ 1580` and the dropdown
  (State / Since / Work / Speedtest / Backend / Open log / Quit).

## State machine (displayed)

`off` (app not running / log stale) → `starting` → `queued (N)` →
`assigned/working` → `error`. Staleness: last log line older than 2 min ⇒ title
`⛏ ?` dimmed. File absent/empty ⇒ `⛏ off`.

## Error handling

Missing/empty file, official app stopped, or unparseable lines never crash.
Degrade to `⛏ off` / `⛏ ?` with an explanatory menu line.

## Build / run

`build.sh` → `swiftc` → `IOTA Monitor.app` bundle in the project. Double-click to
launch. Optional LaunchAgent for auto-start added later if wanted.
