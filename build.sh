#!/bin/bash
# Builds "IOTA Monitor.app" — a standalone menu bar bundle. No dependencies.
set -euo pipefail
cd "$(dirname "$0")"

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
  Sources/LogReader.swift \
  Sources/StateParser.swift \
  Sources/Preferences.swift \
  Sources/main.swift \
  -o "$BIN"

codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built: $APP"
echo "Run:   open \"$APP\"   (or double-click it in Finder)"
