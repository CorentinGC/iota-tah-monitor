# 0001 — Read the log, do not hit the ws

- **Status**: accepted
- **Date**: 2026-07-05

## Context
The official app exposes a local ws server (`ws://127.0.0.1:8010/ws?token=…`) that
carries the real-time state (queue position, training.state…). We could hook into
it for a richer display. Alternatively, all of that state also flows through
the CLI log `~/Library/Logs/IOTA Train at Home/<date>-cli.log`.

## Decision
Single **source = the CLI log**, read-only. No connection to the ws.

## Rationale
- The **ws token changes on every restart** of the app (observed: 4 different
  tokens over 3 days) → impossible to wire up in a stable way.
- The **Electron host already occupies the connection**; a second client could
  interfere with mining.
- The log already contains everything needed (position, state, speedtest, backend
  errors). Reading a file is robust and side-effect free.

## Consequences
- Refresh by polling (5 s) rather than real-time push — acceptable.
- Behavior depends on the **log line format** (implicit contract) → covered
  by the `StateParser` tests and watched by the `log-format-watcher` agent.
- If sub-second display ever becomes necessary, re-evaluate the ws (reading the
  token from the current log, and read-only on the protocol side).
