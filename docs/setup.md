# Setup

## Prerequisites
- macOS 13 (Ventura) or later
- Xcode command-line tools with `swiftc` + `swift` (build & tests). No
  runtime dependencies.

## Clone & build
```bash
git clone git@github.com:CorentinGC/iota-tah-monitor.git
cd iota-tah-monitor
swift test        # runs the core tests
./build.sh        # produces "IOTA Monitor.app"
open "IOTA Monitor.app"
```

To keep the app: drag `IOTA Monitor.app` into `/Applications`.

## Environment variables
None. The only external path is the log directory, hard-coded in
`LogReader.logDir`:
`~/Library/Logs/IOTA Train at Home/`.

## Launch at login
App menu → *Launch at Login*, or the *Preferences…* window. Uses
`SMAppService`; macOS may request approval in *System Settings →
General → Login Items*.

## Commands
| Purpose | Command |
|-----|----------|
| Tests | `swift test` |
| Build | `./build.sh` |
| Launch | `open "IOTA Monitor.app"` |
| Kill the instance | `pkill -f "IOTA Monitor"` |
