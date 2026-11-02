#!/bin/sh
# Builds build/CaffeineWatch.app (menu-bar only, ad-hoc signed).
set -eu
cd "$(dirname "$0")"

swift build -c release
APP=build/CaffeineWatch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CaffeineWatch "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>CaffeineWatch</string>
  <key>CFBundleIdentifier</key><string>dev.omarh.caffeine-watch</string>
  <key>CFBundleExecutable</key><string>CaffeineWatch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force -s - "$APP"
echo "built $APP"
