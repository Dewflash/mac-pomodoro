#!/bin/zsh
# One-command verification: plist lint, shell syntax, Swift typecheck,
# JS logic smoke test, and a full app build with signature check.
# Headless-safe: opens no windows. Run from anywhere.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "── Info.plist lint"
plutil -lint "$ROOT_DIR/macos/Info.plist"

echo "── shell script syntax"
for script in "$ROOT_DIR"/scripts/*.sh; do
  zsh -n "$script"
  echo "$(basename "$script"): syntax OK"
done

echo "── swift typecheck"
swiftc -typecheck "$ROOT_DIR/macos/PomodewroApp.swift"
swiftc -typecheck "$ROOT_DIR/scripts/render-app-icon.swift"
echo "swift: typecheck OK"

echo "── js smoke test"
NODE_BIN="$(command -v node || true)"
if [[ -z "$NODE_BIN" ]]; then
  for candidate in "$HOME"/.nvm/versions/node/*/bin/node(N); do
    NODE_BIN="$candidate"
  done
fi
if [[ -z "$NODE_BIN" ]]; then
  echo "verify: node not found on PATH or under ~/.nvm" >&2
  exit 1
fi
"$NODE_BIN" "$ROOT_DIR/scripts/smoke-test.js"

echo "── full app build"
/bin/zsh "$ROOT_DIR/scripts/build-mac-app.sh" >/dev/null
codesign --verify --deep "$ROOT_DIR/build/Pomodewro.app"
test -f "$ROOT_DIR/build/Pomodewro.app/Contents/MacOS/Pomodewro"
test -f "$ROOT_DIR/build/Pomodewro.app/Contents/Resources/index.html"
test -f "$ROOT_DIR/build/Pomodewro.app/Contents/Resources/Pomodewro.icns"
echo "build: OK"

echo ""
echo "VERIFY PASS"
