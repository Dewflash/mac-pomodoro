# PLAN-final-polish — 1.1 release: docs, version bump, packaged artifacts, manual QA, verdict

- **Rank:** 4 of 4 (run LAST)
- **Dependencies:** requires PLAN-verify and PLAN-package-release (hard — cannot run without
  them). Adapts to PLAN-menubar-countdown: if that plan is logged in `BLOCKERS.md`, use the
  "countdown blocked" variants below and mark QA rows 13, 14, 16 as `N/A (plan blocked)`.
- **Effort:** medium (mostly careful manual QA; all file edits are spelled out)
- **Files touched:** `README.md`, `macos/Info.plist`, `release/INSTALL.txt`, creates
  `RELEASE-QA.md`, creates `release/Pomodewro-1.1.dmg` + `release/Pomodewro-1.1.zip`, deletes
  `release/Pomodewro-1.0.dmg` + `release/Pomodewro-1.0.zip`. Nothing else.

## Goal

Turn the repo into a shipped, honestly-vetted 1.1: a README that documents only behavior that
actually shipped, a bumped version, packaged artifacts built by the reproducible script, and a
~20-row manual QA run against the REAL packaged artifact (not the dev build) with an explicit
SHIP / DO-NOT-SHIP verdict committed to the repo. This is the vet no human will do afterwards —
its value is exactly as high as its honesty.

> PASS only from actually performing the check — an honest FAIL committed is worth more than a
> green lie.

## Steps

### Step 0 — determine what landed

Run `git log --oneline` and read `BLOCKERS.md` if it exists. Set your working assumption:
`COUNTDOWN_LANDED` is true iff the PLAN-menubar-countdown commit is present and not reverted.
Every "(countdown)" item below follows this flag. Then run `/bin/zsh scripts/verify.sh` — it must
print `VERIFY PASS` before you start. If not: STOP and report.

### Step 1 — bump the version in `macos/Info.plist`

Edit the file as TEXT (do NOT use PlistBuddy or plutil to write — they rewrite the header and
this file's hand formatting). Two replacements:

Replace:

```xml
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
```

with:

```xml
  <key>CFBundleShortVersionString</key>
  <string>1.1</string>
```

Replace:

```xml
  <key>CFBundleVersion</key>
  <string>1</string>
```

with:

```xml
  <key>CFBundleVersion</key>
  <string>2</string>
```

Then run `plutil -lint macos/Info.plist` (must print `OK`).

### Step 2 — update `release/INSTALL.txt`

Three exact replacements:
- `Pomodewro 1.0 Install Notes` → `Pomodewro 1.1 Install Notes`
- `1. Open Pomodewro-1.0.dmg.` → `1. Open Pomodewro-1.1.dmg.`
- `1. Unzip Pomodewro-1.0.zip.` → `1. Unzip Pomodewro-1.1.zip.`

### Step 3 — replace `README.md` entirely

Use exactly this content. It documents shipped behavior only — note the old README claimed a
"skip" control that does not exist in the UI; do not reintroduce it. Include the two lines marked
`(countdown)` only if `COUNTDOWN_LANDED`; delete them otherwise.

~~~~markdown
# Pomodewro

A local, offline Pomodoro focus timer that lives in the Mac menu bar. Click the tomato icon for a
wide glassmorphism popover with the timer and settings; close it and keep working.

## Install

Use `release/Pomodewro-1.1.dmg` (or the `.zip`) and follow `release/INSTALL.txt`. This is an
unsigned indie build: on first launch macOS may require right-click → Open. Requires macOS 13+.

## Features

- Focus and Break timer modes with play, pause, and reset controls
- Pomodoro Cycle toggle that auto-switches Focus and Break sessions
- Live remaining-time countdown in the menu bar while a session runs (countdown)
- Runs reliably with the popover closed: the shell blocks App Nap during a session and restores a
  running timer at relaunch (countdown)
- Default Web Audio chimes plus separate custom Focus and Break sounds; the native app copies
  imported sounds to local app storage so longer songs work (browser preview caps uploads at 2 MB)
- Stop Alarm control for long completion sounds
- Appearance tab: font presets, UI colour control, timer shade, wallpaper-style backgrounds with a
  darkness/tint slider, and reset controls
- History tab: past-week focus hours and sessions, daily log, copy-as-JSON, clear history
- Toast feedback instead of native alerts

## Build from source

```sh
/bin/zsh scripts/build-mac-app.sh    # → build/Pomodewro.app
```

## Verify

```sh
/bin/zsh scripts/verify.sh           # plist lint, shell syntax, Swift typecheck, JS smoke tests, full build
```

## Package a release

```sh
/bin/zsh scripts/package-release.sh  # → release/Pomodewro-<version>.dmg and .zip
```

## Data & privacy

Fully offline — the app makes no network requests. Settings and history live in the app's local
web storage; imported sounds are copied under `~/Library/Application Support/Pomodewro/Sounds`.
Quit via right-click on the menu bar icon → Quit Pomodewro.

## Browser preview

Open `index.html` in a browser to preview the UI. Native-only features (long custom sounds, the
menu bar shell) need the built app.
~~~~

### Step 4 — build the 1.1 artifacts

```sh
/bin/zsh scripts/package-release.sh
git rm release/Pomodewro-1.0.dmg release/Pomodewro-1.0.zip
git add release/Pomodewro-1.1.dmg release/Pomodewro-1.1.zip
```

The script reads the plist, so after Step 1 it emits `Pomodewro-1.1.*` automatically. The 1.0
binaries stay in git history; the working tree carries only the current release.

### Step 5 — gate

`/bin/zsh scripts/verify.sh` → must end `VERIFY PASS`.

### Step 6 — manual QA against the PACKAGED artifact

**6a. Protect real user data first.** The packaged app shares its bundle id
(`com.dewflash.pomodewro`) with any daily-use install, so it shares WebKit localStorage and the
Application Support sounds folder. Destructive QA rows (Clear History, Clear Audio, Reset
Appearance) would wipe the owner's real data. Back it up:

```sh
QA_BACKUP="$(mktemp -d)"
[ -d "$HOME/Library/WebKit/com.dewflash.pomodewro" ] && cp -R "$HOME/Library/WebKit/com.dewflash.pomodewro" "$QA_BACKUP/webkit"
[ -d "$HOME/Library/Application Support/Pomodewro" ] && cp -R "$HOME/Library/Application Support/Pomodewro" "$QA_BACKUP/appsupport"
echo "backup at: $QA_BACKUP"
```

**6b. Install from the DMG to a scratch location** (never test `build/Pomodewro.app` — QA must
exercise the bits users get):

```sh
QA_DIR="$(mktemp -d)"
hdiutil attach -readonly -nobrowse -mountpoint "$QA_DIR/mnt" release/Pomodewro-1.1.dmg >/dev/null
cp -R "$QA_DIR/mnt/Pomodewro.app" "$QA_DIR/Pomodewro.app"
hdiutil detach "$QA_DIR/mnt" >/dev/null
open "$QA_DIR/Pomodewro.app"
```

**6c. Prepare QA audio** (deterministic, no personal media): short sound =
`/System/Library/Sounds/Glass.aiff`; long sound:

```sh
say -o "$QA_DIR/long-alarm.aiff" "Pomodewro long alarm test. Pomodewro long alarm test. Pomodewro long alarm test. Pomodewro long alarm test. Pomodewro long alarm test. Pomodewro long alarm test."
```

**6d. Create `RELEASE-QA.md` at repo root** from the template below and fill the Result column
row by row, actually performing each check on the running packaged app.

**6e. Afterwards:** quit the app (right-click tomato → Quit Pomodewro), then restore the backup:

```sh
[ -d "$QA_BACKUP/webkit" ] && rm -rf "$HOME/Library/WebKit/com.dewflash.pomodewro" && cp -R "$QA_BACKUP/webkit" "$HOME/Library/WebKit/com.dewflash.pomodewro"
[ -d "$QA_BACKUP/appsupport" ] && rm -rf "$HOME/Library/Application Support/Pomodewro" && cp -R "$QA_BACKUP/appsupport" "$HOME/Library/Application Support/Pomodewro"
```

### RELEASE-QA.md template

~~~~markdown
# Pomodewro 1.1 — Release QA

Run against `release/Pomodewro-1.1.dmg` installed to a scratch directory (commit `<sha>`).
Rule: PASS only from actually performing the check — an honest FAIL committed is worth more than
a green lie. `N/A (plan blocked)` is allowed only for rows whose feature plan is in BLOCKERS.md.

| # | Check | Steps | Expected | Result | Notes |
|---|-------|-------|----------|--------|-------|
| 1 | Launch | `open` the scratch copy | Tomato icon appears in menu bar; no Dock icon; no windows | | |
| 2 | Popover open/close | Left-click icon; then click the desktop | Popover opens under the icon; clicking outside closes it | | |
| 3 | Play | Click Play | Settings panel collapses; timer counts down each second | | |
| 4 | Pause/resume | Pause, wait 5s, Play | Display freezes at pause; resumes from the same remaining time | | |
| 5 | Reset | Click Reset mid-session | Timer returns to full duration; settings panel reopens | | |
| 6 | Mode pills | Click Break, then Focus | Each switch resets the display to that mode's duration | | |
| 7 | Duration clamp | Type 999 in Focus (min), click outside; then type abc | 999 clamps to 180:00; abc falls back to 25:00 | | |
| 8 | Auto-cycle | Focus = 1 min, Cycle ON, Play, wait | At zero: chime + toast; Break starts running automatically | | |
| 9 | Cycle off | Cycle OFF, Focus = 1 min, Play, wait | At zero: chime; stays in Focus, idle at 01:00, settings reopen | | |
| 10 | Default chime audible | Row 8/9 completion with speakers on | Soft Bell / Gentle Ping actually audible | | |
| 11 | Custom sound import | Timer & Sounds → + Add → pick /System/Library/Sounds/Glass.aiff; complete a 1-min session | Native file panel opens; "Sound saved" toast; Glass plays at completion | | |
| 12 | Stop Alarm | Import the `say`-generated long-alarm.aiff as Focus chime; complete a session; click Stop Alarm while it plays | Stop Alarm button visible during playback; click silences immediately + "Alarm stopped" toast | | |
| 13 | Menu bar countdown | Start a session; look at the menu bar | MM:SS ticks beside the icon once per second | | |
| 14 | Countdown clears | Pause, then Reset | Menu bar time disappears; icon-only look returns | | |
| 15 | Rings while closed | 1-min Focus, close popover, hands off 60s | Chime fires with popover closed (countdown build: title flips to 05:00 break) | | |
| 16 | Relaunch mid-session | Start 5-min session, Quit app, relaunch scratch copy | Countdown build: menu bar time reappears without opening the popover. Blocked variant: open popover — timer restored at correct remaining | | |
| 17 | Appearance | Change font preset; set accent hex to 3aF; then type ZZZ | Font + colours update; ZZZ shows "Use a hex colour" toast and keeps old colour | | |
| 18 | Background & shade | Upload any image; move Darkness and Timer Shade sliders; Reset Appearance | Image applies; sliders visibly change tint/shade; reset restores Mountain Lake defaults | | |
| 19 | History & JSON | Open History after row 8; Copy JSON; `pbpaste \| python3 -m json.tool`; then Clear History | Session counted in stats + today's row; JSON parses; clear zeroes stats | | |
| 20 | Version coherence | `/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$QA_DIR/Pomodewro.app/Contents/Info.plist"`; check README + INSTALL.txt | Prints 1.1; docs reference 1.1 filenames only | | |

## Verdict

**SHIP / DO-NOT-SHIP** (delete one)

SHIP requires: every row PASS, or N/A (plan blocked) for rows 13/14/16 only. Any FAIL, any
unperformed row, or any N/A without a blocker entry → DO-NOT-SHIP with the reason in Notes.
~~~~

### Step 7 — commit and (only on SHIP) tag

One atomic release commit containing all of: README.md, macos/Info.plist, release/INSTALL.txt,
the artifact swap (1.0 removed, 1.1 added), RELEASE-QA.md.

```sh
git add README.md macos/Info.plist release/INSTALL.txt RELEASE-QA.md release/Pomodewro-1.1.dmg release/Pomodewro-1.1.zip
git commit -m "release: Pomodewro 1.1"
```

If and only if the verdict is SHIP:

```sh
git tag v1.1
```

Do not push anything.

## Edge cases a weaker model would miss

- **QA the packaged copy, not `build/Pomodewro.app`.** The packaged artifact is what users get;
  testing the dev build proves nothing about the DMG contents, signature survival, or layout.
- **The data-backup step (6a/6e) is not optional.** Same bundle id ⇒ same WKWebView localStorage
  and Application Support folder as the owner's real install. Skipping it means row 19's Clear
  History erases the owner's genuine focus history. Restore only AFTER the QA app has quit —
  restoring while it runs gets overwritten on exit.
- **Do not fix anything mid-QA.** A FAIL is recorded, the verdict becomes DO-NOT-SHIP, and the
  failure goes to BLOCKERS.md. Editing source during QA invalidates every row already performed
  (the artifact under test no longer matches HEAD).
- **Number inputs commit on blur/Enter, not per keystroke** (`change` listeners in index.html).
  For row 7, click outside the field before judging — otherwise the clamp looks broken.
- **The audible rows (10, 15) require actually listening.** The Stop Alarm button appearing is
  evidence the audio code path ran, but "audible" means heard. If you cannot hear the machine's
  output, write FAIL with a note — per the rule above, that honest FAIL (and DO-NOT-SHIP) is the
  correct outcome, and the owner can re-run those two rows and flip the verdict themselves.
- **Use `say` + system sounds for QA audio.** Never reach into the owner's music or media
  folders: privacy, plus the run must be reproducible on any Mac.
- **Locally built artifacts carry no quarantine attribute**, so QA cannot exercise the
  Gatekeeper right-click flow. That is why row 20 checks the documentation instead of simulating
  Gatekeeper — do not `xattr` the app to fake it.
- **Text-edit the plist; never PlistBuddy-write it.** PlistBuddy/plutil rewrite the XML header
  (this file uses an https DTD) and reorder formatting — a noisy diff that obscures the two-line
  version change.
- **README documents shipped behavior only.** If PLAN-menubar-countdown is blocked, the two
  `(countdown)` bullets must be absent. Check BLOCKERS.md, not your memory of what "should" have
  landed. Strip the literal `(countdown)` markers from kept lines.
- **Keep the release commit atomic** (docs + version + artifacts + QA verdict together) so the
  tag points at a self-consistent tree. Tag only on SHIP; a DO-NOT-SHIP tree is still committed —
  the honest verdict is part of the handover — but never tagged.

## Acceptance criteria

1. `/bin/zsh scripts/verify.sh` exits 0 and ends `VERIFY PASS`.
2. `plutil -lint macos/Info.plist` prints OK;
   `/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' macos/Info.plist` prints `1.1`.
3. `ls release/` shows exactly: `INSTALL.txt`, `Pomodewro-1.1.dmg`, `Pomodewro-1.1.zip` (no 1.0
   artifacts).
4. `grep -c "1.0" README.md release/INSTALL.txt` finds no stale 1.0 version references (filenames
   or version strings).
5. `RELEASE-QA.md` exists, every row's Result is filled (PASS / FAIL / N/A (plan blocked)), and
   the Verdict line reads exactly one of SHIP or DO-NOT-SHIP.
6. On SHIP: `git tag --list v1.1` prints `v1.1`. On DO-NOT-SHIP: no tag exists and the failing
   rows are mirrored into `BLOCKERS.md`.
7. The release commit exists with the suggested message and contains all touched files listed in
   the header.

Suggested commit message:

```
release: Pomodewro 1.1
```
