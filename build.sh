#!/bin/bash
# Builds "IOTA Monitor.app" — a standalone menu bar bundle. No dependencies.
#
# Usage:
#   ./build.sh              build the app in place
#   ./build.sh --install    build, then symlink it into /Applications so Spotlight
#                           finds it and it stays in sync with every rebuild
set -euo pipefail
cd "$(dirname "$0")"

INSTALL=0
[ "${1:-}" = "--install" ] && INSTALL=1

APP="IOTA Monitor.app"
BIN="$APP/Contents/MacOS/IOTA Monitor"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>IOTA Monitor</string>
  <key>CFBundleDisplayName</key>     <string>IOTA Monitor</string>
  <key>CFBundleIdentifier</key>      <string>local.iota.tah.monitor</string>
  <key>CFBundleVersion</key>         <string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleExecutable</key>      <string>IOTA Monitor</string>
  <key>LSUIElement</key>            <true/>
  <key>LSMinimumSystemVersion</key>  <string>13.0</string>
</dict>
</plist>
PLIST

echo "Compiling…"
swiftc -O \
  Sources/IOTAMonitorCore/LogReader.swift \
  Sources/IOTAMonitorCore/StateParser.swift \
  App/Preferences.swift \
  App/OfficialApp.swift \
  App/main.swift \
  -o "$BIN"

codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built: $APP"

if [ "$INSTALL" = "1" ]; then
  LINK="/Applications/IOTA Monitor.app"
  TARGET="$PWD/$APP"
  if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
    echo "Skip install: $LINK exists and is a real bundle, not a symlink. Remove it first."
  else
    ln -sfn "$TARGET" "$LINK" && echo "Linked: $LINK -> $TARGET"
  fi
fi
echo "Run:   open \"$APP\"   (or double-click it in Finder)"
