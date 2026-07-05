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

## Install into /Applications

```bash
./build.sh --install
```

`--install` symlinks `/Applications/IOTA Monitor.app` → the built bundle in the
repo. Spotlight/Launchpad then find it, and because `build.sh` rebuilds at the
same path the symlink always points at the latest build (run `--install` once,
then plain `./build.sh`). Caveats:

- After a rebuild, quit + relaunch the running monitor to load the new version.
- The symlink is absolute — don't move the repo folder (re-run `--install` to fix).
- Remove with `rm "/Applications/IOTA Monitor.app"` (link only, not the build).
- `--install` won't overwrite a real (non-symlink) bundle already at that path.

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
