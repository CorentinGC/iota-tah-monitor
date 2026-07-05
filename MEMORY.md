# MEMORY — IOTA T@H Monitor

> Working memory. READ before coding, UPDATE after every edit.
> Concise (< 150 lines). Detailed docs → `llms.txt` / `docs/`.

## Current state
- Working v1: menu bar shows a colored status dot (🔴 off · 🟡 queued · 🟢 working,
  non-template `NSImage`) + compact text, plus position/state/work/speedtest/backend,
  *launch at login* toggle (`SMAppService`) + Preferences window.
- Official-app lifecycle control (`App/OfficialApp.swift`): Launch / Quit /
  Restart the official signed app + reap the `main_pool` workers it orphans on
  quit (a bug in its own will-quit cleanup). Launch uses `open -gj` (background,
  hidden) to keep the Chromium window/renderer out of the way (~300 MB).
- Published on GitHub `CorentinGC/iota-tah-monitor` (`main` branch).
- Core is a testable SwiftPM target; `swift test` = 6 green tests.
- Agent configuration in place (CLAUDE.md, AGENTS.md, docs/, llms.txt, agents).

## Direction (decided)
- **Stay on the Mac + official app.** We monitor + manage the official signed
  app; it keeps doing the mining and Secure Enclave signing. No bypass.
- **Full host replacement (palier 3) = ruled out.** A spike proved the worker's
  ws control channel *accepts* a third-party host, but the official KeySigner
  refuses to sign for any caller not carrying Macrocosmos's Apple Team ID /
  bundle (`team identifier mismatch; caller not allowlisted`). Defeating that
  gate = circumventing device attestation on a rewards network — out of scope.
  Official docs document no custom-host/allowlist mechanism. A sanctioned
  no-Electron path exists but is the open-source `macrocosm-os/iota` headless
  miner (Linux + NVIDIA CUDA GPU), not the Mac.

## Next steps
- [ ] Refine `StateParser.workDescription` once the front of the queue is reached
      (capture a real training line — never observed to date).
- [ ] Optional: `.icns` icon + colored status by phase.
- [ ] If Macrocosmos later exposes an official host allowlist, the ws host is
      already understood (local reverse notes) — revisit then.

## Recent decisions
- 2026-07-05 — Read the CLI log only, no ws (rotating token + Electron host
  conflict). See `docs/decisions/0001`.
- 2026-07-05 — Core without AppKit in `Sources/IOTAMonitorCore/` (SwiftPM/tests),
  AppKit app in `App/` (built via `build.sh`/swiftc, outside SwiftPM).

## Install
- `./build.sh --install` symlinks `/Applications/IOTA Monitor.app` → repo build
  (Spotlight-findable, always current). After a rebuild: quit + relaunch the
  running monitor to load new code. Don't move the repo (absolute symlink).

## Pitfalls / gotchas
- **Log format = contract**: a wording change on the Macrocosmos side breaks
  parsing silently. Run the `log-format-watcher` agent when in doubt.
- Restarting the official app = new `queue_id` = back of the queue. Do not restart.
- `main.swift` does NOT import `IOTAMonitorCore`: in the app build, swiftc compiles
  core + App together into a single module.
- `swift test` does NOT build the app (AppKit) — only the core.

## Pointers
- Architecture: `docs/architecture.md` · Setup: `docs/setup.md` · Index: `llms.txt`
