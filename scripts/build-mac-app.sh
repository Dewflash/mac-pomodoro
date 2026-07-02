#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Pomodewro.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc "$ROOT_DIR/macos/PomodewroApp.swift" \
  -framework AppKit \
  -framework WebKit \
  -o "$MACOS_DIR/Pomodewro"

cp "$ROOT_DIR/macos/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/index.html" "$RESOURCES_DIR/index.html"

chmod +x "$MACOS_DIR/Pomodewro"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "$APP_DIR"
