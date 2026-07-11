#!/bin/zsh
# Builds the app and packages release/Pomodewro-<version>.dmg and .zip.
# Version comes from CFBundleShortVersionString in macos/Info.plist.
# DMG contains the app + Applications symlink + INSTALL.txt (drag-install).
# ZIP contains the app + INSTALL.txt, matching the 1.0 release layout.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Pomodewro.app"
RELEASE_DIR="$ROOT_DIR/release"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT_DIR/macos/Info.plist")"

/bin/zsh "$ROOT_DIR/scripts/build-mac-app.sh" >/dev/null

STAGE_ROOT="$(mktemp -d)"
DMG_STAGE="$STAGE_ROOT/dmg/Pomodewro"
ZIP_STAGE="$STAGE_ROOT/zip"
mkdir -p "$DMG_STAGE" "$ZIP_STAGE" "$RELEASE_DIR"

cp -R "$APP_DIR" "$DMG_STAGE/Pomodewro.app"
cp "$RELEASE_DIR/INSTALL.txt" "$DMG_STAGE/INSTALL.txt"
ln -s /Applications "$DMG_STAGE/Applications"

cp -R "$APP_DIR" "$ZIP_STAGE/Pomodewro.app"
cp "$RELEASE_DIR/INSTALL.txt" "$ZIP_STAGE/INSTALL.txt"

DMG_PATH="$RELEASE_DIR/Pomodewro-$VERSION.dmg"
ZIP_PATH="$RELEASE_DIR/Pomodewro-$VERSION.zip"
rm -f "$DMG_PATH" "$ZIP_PATH"

hdiutil create -volname "Pomodewro $VERSION" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null
ditto -c -k "$ZIP_STAGE" "$ZIP_PATH"

rm -rf "$STAGE_ROOT"
echo "$DMG_PATH"
echo "$ZIP_PATH"
