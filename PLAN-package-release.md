# PLAN-package-release — reproducible DMG/ZIP packaging script

- **Rank:** 3 of 4
- **Dependencies:** run AFTER PLAN-verify (the gate must exist). Independent of
  PLAN-menubar-countdown — if that plan is blocked, this one still proceeds.
- **Effort:** small (the script below was run against this exact repo: the DMG mounted with the
  correct layout and the zipped app's ad-hoc signature verified after a round-trip)
- **Files touched:** creates `scripts/package-release.sh`. Nothing else is left modified when the
  plan is done (see the restore step — the validation run intentionally touches tracked artifacts
  and you must restore them).

## Goal

`release/Pomodewro-1.0.dmg` and `.zip` exist in the repo, but no script produces them — the 1.0
artifacts were hand-rolled. That makes the release step unrepeatable and error-prone, and
PLAN-final-polish needs to mint 1.1 artifacts mechanically. This plan adds a one-command packager
that reads the version from `macos/Info.plist`, rebuilds the app, and emits both artifact formats
with the same layout users already received in 1.0 (DMG: app + Applications symlink + INSTALL.txt
for drag-install; ZIP: app + INSTALL.txt).

## Steps

### Step 0 — precondition

Run `/bin/zsh scripts/verify.sh`. It must print `VERIFY PASS`. If not: STOP and report.

### Step 1 — create `scripts/package-release.sh` with exactly this content

```zsh
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
```

### Step 2 — make it executable

```sh
chmod +x scripts/package-release.sh
```

### Step 3 — validation run

The plist version is still `1.0` at this point, so this run OVERWRITES the two tracked 1.0
artifacts. That is expected for validation; Step 5 restores them.

```sh
/bin/zsh scripts/package-release.sh
```

Expected output: the two artifact paths, ending in `Pomodewro-1.0.dmg` and `Pomodewro-1.0.zip`.

### Step 4 — inspect the artifacts

```sh
MNT="$(mktemp -d)"
hdiutil attach -readonly -nobrowse -mountpoint "$MNT" release/Pomodewro-1.0.dmg >/dev/null
ls "$MNT"
test -d "$MNT/Pomodewro.app" && test -L "$MNT/Applications" && test -f "$MNT/INSTALL.txt" && echo "DMG LAYOUT OK"
hdiutil detach "$MNT" >/dev/null

UNZIP_DIR="$(mktemp -d)"
ditto -x -k release/Pomodewro-1.0.zip "$UNZIP_DIR"
ls "$UNZIP_DIR"
codesign --verify --deep "$UNZIP_DIR/Pomodewro.app" && echo "ZIP APP SIGNATURE OK"
rm -rf "$UNZIP_DIR"
```

Expected: `ls "$MNT"` prints exactly `Applications`, `INSTALL.txt`, `Pomodewro.app`; both OK
lines print. If the DMG root instead contains a single `Pomodewro` folder, or anything else
differs: STOP and report — do not improvise.

### Step 5 — restore the tracked 1.0 artifacts

```sh
git restore release/Pomodewro-1.0.dmg release/Pomodewro-1.0.zip
```

Why: the rebuilt artifacts are functionally equivalent but not byte-identical (embedded
timestamps), and committing ~2.7 MB of binary churn for zero source change is waste. The real
regeneration happens once, at version 1.1, in PLAN-final-polish.

### Step 6 — run the gate

```sh
/bin/zsh scripts/verify.sh
```

The `scripts/*.sh` syntax loop in verify.sh picks up the new script automatically — no verify.sh
edit is needed or allowed.

## Edge cases a weaker model would miss

- **`hdiutil create -srcfolder DIR` puts DIR's CONTENTS at the volume root, not DIR itself.**
  The mounted volume shows `Pomodewro.app`, `Applications`, `INSTALL.txt` directly. Do not "fix"
  the script by nesting another folder — the inspection commands in Step 4 encode the correct,
  validated layout.
- **Always `hdiutil detach` after mounting, even when a check fails.** A still-mounted image
  makes every subsequent packaging or inspection run fail with "resource busy", which then looks
  like a script bug.
- **`ditto -c -k` without `--keepParent` is deliberate.** It zips the stage's contents so the
  archive root holds `Pomodewro.app` + `INSTALL.txt` — the exact layout of the shipped 1.0 zip.
  Adding `--keepParent` would nest everything under a `zip/` folder and break the documented
  install steps.
- **The script depends on `release/INSTALL.txt` existing at its current path.** It is a tracked
  file; do not move or rename it.
- **`cp -R` preserves the ad-hoc code signature.** Step 4's `codesign --verify` after a full
  zip round-trip is the proof; if you substitute a different copy mechanism, that check is what
  will catch breakage.
- **`rm -f` of the target artifacts before `hdiutil create` is required.** `-ov` alone is not
  reliable when the previous file is corrupt or partially written.
- **Version is read from the plist, not hardcoded.** When PLAN-final-polish bumps
  `CFBundleShortVersionString` to 1.1, this script starts emitting `Pomodewro-1.1.*` with no
  edits. Do not add a version flag or argument.
- **Do not add this script to verify.sh.** Packaging takes tens of seconds (hdiutil compression);
  verify must stay fast. Its `zsh -n` loop already syntax-checks the new file, and full packaging
  is exercised by PLAN-final-polish.

## Acceptance criteria

1. `/bin/zsh scripts/verify.sh` exits 0, ends with `VERIFY PASS`, and its shell-syntax section
   lists `package-release.sh: syntax OK`.
2. Step 3 printed both artifact paths; Step 4 printed `DMG LAYOUT OK` and `ZIP APP SIGNATURE OK`.
3. After Step 5, `git status --porcelain` shows exactly one entry:
   `?? scripts/package-release.sh` (the 1.0 artifacts show no modification).

Suggested commit message:

```
build: add reproducible release packaging script
```
