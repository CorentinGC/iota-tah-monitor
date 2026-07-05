# IOTA T@H Monitor

A tiny macOS **menu bar** app that shows the *real* status of
[IOTA "Train at Home"](https://docs.macrocosmos.ai/product-and-services/tah)
(Macrocosmos) — the queue position, miner state, and work status that the
official app's UI fails to display.

```
⛏ 1564 ▼          ← menu bar title: queue position + trend
─────────────────
State:     queued
Queue:     1564  (-2.0/min)
Since:     00:12:22
Work:      idle (not assigned)
Speedtest: fail (cosmetic, non-blocking)
Backend:   11×503 queue_state, 11×404
Updated:   17:56:07
Open log · Lancer au démarrage · Préférences… · Quit
```

## Why this exists

The official Electron app advertises a `register.queue_state` capability but its
host has **no handler**, so every position update fails:

```
register_set_queue_state exhausted retries (3): POST /register/queue_state failed 503:
{"detail":"unsupported: No handler for register.queue_state"}
```

The UI therefore freezes on the last visible step (`Running speedtest...`) while
the miner is actually advancing through the registration queue. The real state
only lives in the CLI log. This tool reads that log and surfaces it.

> The `Failed to run speedtest: Unable to connect to servers to test latency.`
> line is logged at **DEBUG** and is **non-fatal** — registration continues past
> it. It is not what blocks you.

## Requirements

- macOS 13 (Ventura) or later
- Xcode command-line tools with `swiftc` (only to build) — no runtime dependencies

## Build & install

```bash
git clone git@github.com:CorentinGC/iota-tah-monitor.git
cd iota-tah-monitor
./build.sh              # build in place
open "IOTA Monitor.app"
```

`build.sh` compiles the sources into a self-contained `IOTA Monitor.app` bundle
(ad-hoc signed) and prints the run command.

### Install into /Applications (recommended)

```bash
./build.sh --install
```

`--install` symlinks `/Applications/IOTA Monitor.app` → the freshly built bundle
in this repo. Benefits:

- **Spotlight / Launchpad find it** (Cmd-Space → "IOTA Monitor").
- **Always current**: `build.sh` rebuilds the bundle at the same path, so the
  symlink keeps pointing at the latest build — no re-copying. Run `--install`
  once; plain `./build.sh` afterwards is enough.
- Works with **Launch at Login** (menu → *Launch at Login*).

Notes / caveats:

- After a rebuild, if the monitor is running, **quit and relaunch it** to load
  the new version (a running process keeps the old code until restarted).
- The symlink is an absolute path to this repo — **don't move the repo folder**
  or the link breaks (re-run `./build.sh --install` to fix it).
- Remove the link with `rm "/Applications/IOTA Monitor.app"` (deletes only the
  symlink, not the build).
- If `/Applications/IOTA Monitor.app` already exists as a real bundle (not a
  symlink), `--install` refuses to touch it — remove it first.

## Usage

The app lives only in the menu bar (no Dock icon). The title shows the current
queue position and a trend arrow:

| Title | Meaning |
|-------|---------|
| `⛏ 1564 ▼` | queued at 1564, **advancing** toward the front (good) |
| `⛏ 1564 ▲` | queued, **falling back** (usually caused by restarting the app) |
| `⛏ ▶︎` | assigned / working |
| `⛏ …` | starting / resetting / running speedtest |
| `⛏ off` | official app not running, or log stale (>2 min) |
| `⛏ ?` | running but state not yet recognized |

Click the icon for the detail menu (state, position + rate, uptime, work,
speedtest, backend error counts, last-update time).

**Launch at login** — toggle it directly from the menu (`Launch at Login`)
or from **Preferences…**. Uses `SMAppService`; the first time, macOS may list it
under *System Settings › General › Login Items* pending approval.

### Operational note

Restarting the official app assigns a **new queue id** and sends you to the back
of the queue. If the trend shows `▲`, stop relaunching — leave it running and the
position drops on its own (~2–4 places/min).

## How it works

Single Swift/AppKit process, **read-only**, no network. A timer (5 s) reads the
tail of today's CLI log, parses it, and repaints the menu.

```
~/Library/Logs/IOTA Train at Home/<YYYY-MM-DD>-cli.log
        │  (tail, last 64 KB)
        ▼
   LogReader ──► StateParser ──► MinerState ──► MenuBarApp (NSStatusItem)
```

| File | Responsibility |
|------|----------------|
| `Sources/LogReader.swift` | Resolve today's log, tail-read last 64 KB, handle missing/empty file and midnight date rotation. |
| `Sources/StateParser.swift` | Regex the tail into a `MinerState` (position, trend, phase, work, speedtest, backend counts, uptime). Defensive — never throws. |
| `Sources/Preferences.swift` | `SMAppService` launch-at-login toggle + the Préférences window. |
| `Sources/main.swift` | `NSStatusItem`, timer loop, title + menu rendering. |

It deliberately does **not** connect to the local ws protocol server
(`ws://127.0.0.1:8010`): the token rotates on every restart and the Electron host
already owns the single connection — tapping it risks interfering with mining.

## Maintainability

**Log format is the contract.** Everything keys off the strings the miner writes.
If Macrocosmos changes the log wording, update the matchers in `StateParser.swift`:

- **Position** — `firstInt(after: "'position':")`. Change the marker if the key
  is renamed.
- **Phase** — `derivePhase(...)` maps signals (`status': 'queued'`,
  `Miner Ready`, `Resetting miner`, `Running speedtest`) to a `Phase`. Add cases
  here for new states.
- **Work status** — `workDescription(in:)` matches `loss`, `batch`, `layer`,
  `step`, `epoch`, `activated`, `assigned`, … These are **best-effort**: no real
  training line has been observed yet (the miner never reached the queue front
  during development). Refine this list once you actually get assigned — capture
  a real training log line and add its pattern.
- **Backend health** — counts `503 … queue_state` and `404 … orchestrator
  request`. Adjust the substrings if endpoints change.

**Common knobs:**

| Want to change | Where |
|----------------|-------|
| Poll interval | `refresh` in `main.swift` (default 5 s) |
| Tail window size | `tailBytes` in `LogReader.swift` (default 64 KB) |
| Staleness threshold | `120` seconds in `StateParser.derivePhase` |
| Trend sensitivity | arrow thresholds in `MenuBarApp.arrow` |
| Log directory | `LogReader.logDir` |

**Testing the parser** against your real log without launching the GUI:

```bash
mkdir -p /tmp/pt && cat > /tmp/pt/main.swift <<'EOF'
import Foundation
if case .ok(let text, _) = LogReader.readTail() {
    let s = StateParser.parse(text: text)
    print("phase=\(s.phase.rawValue) pos=\(s.position.map(String.init) ?? "nil") " +
          "trend=\(s.trendPerMin.map { String(format: "%+.2f", $0) } ?? "nil") " +
          "work=\(s.workLine ?? "idle")")
}
EOF
swiftc -O Sources/LogReader.swift Sources/StateParser.swift /tmp/pt/main.swift -o /tmp/pt/run && /tmp/pt/run
```

`StateParser.parse` takes the text directly, so it is trivial to feed a captured
log fixture for regression checks.

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `⛏ off` while mining | Log not updating — confirm the official app is running; check `~/Library/Logs/IOTA Train at Home/` exists. |
| Login toggle says *requires approval* | Approve under System Settings › General › Login Items. |
| Position climbing (`▲`) | You keep restarting the app; each restart re-queues at the back. Leave it running. |
| Work always `idle` | Expected until you reach the queue front and get assigned. |

## License

[MIT](LICENSE) © 2026 Corentin GC
