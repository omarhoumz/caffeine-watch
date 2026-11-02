#!/bin/sh
# Builds build/CaffeineWatch.app (menu-bar only, universal arm64 + x86_64, ad-hoc signed).
set -eu
cd "$(dirname "$0")"

# Version comes from the release tag (CI sets VERSION from it); local builds use the latest tag.
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}"
VERSION="${VERSION:-0.0.0}"

swift build -c release --arch arm64 --arch x86_64
APP=build/CaffeineWatch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R completions "$APP/Contents/Resources/"
cp .build/apple/Products/Release/CaffeineWatch "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>CaffeineWatch</string>
  <key>CFBundleIdentifier</key><string>io.github.omarhoumz.caffeine-watch</string>
  <key>CFBundleExecutable</key><string>CaffeineWatch</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force -s - "$APP"
echo "built $APP ($VERSION)"
