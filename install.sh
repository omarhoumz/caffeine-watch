#!/bin/sh
# Builds the app, installs it to ~/Applications, links the CLI and launches it.
# BIN_DIR overrides where the `caffeine-watch` command goes (default ~/.local/bin).
set -eu
cd "$(dirname "$0")"

./build.sh
APPS="$HOME/Applications"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

pkill -x CaffeineWatch 2>/dev/null || true
mkdir -p "$APPS" "$BIN_DIR"
rm -rf "$APPS/CaffeineWatch.app"
cp -R build/CaffeineWatch.app "$APPS/"
ln -sf "$APPS/CaffeineWatch.app/Contents/MacOS/CaffeineWatch" "$BIN_DIR/caffeine-watch"
open "$APPS/CaffeineWatch.app"

echo "installed $APPS/CaffeineWatch.app"
echo "linked $BIN_DIR/caffeine-watch"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "note: $BIN_DIR is not on your PATH" ;; esac
