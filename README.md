# Pomodewro

A local, offline Pomodoro focus timer that lives in the Mac menu bar. Click the tomato icon for a
wide themed popover with the timer and settings; close it and keep working.

## Install

Use `release/Pomodewro-1.1.dmg` (or the `.zip`) and follow `release/INSTALL.txt`. This is an
unsigned indie build: on first launch macOS may require right-click → Open. Requires macOS 13+.

## Features

- Focus and Break timer modes with play, pause, and reset controls
- Pomodoro Cycle toggle that auto-switches Focus and Break sessions
- Default Web Audio chimes plus separate custom Focus and Break sounds; the native app copies
  imported sounds to local app storage so longer songs work (browser preview caps uploads at 2 MB)
- Stop Alarm control for long completion sounds
- Appearance tab: nine full interface themes — Mac Native, Field Notes, Winter Almanac, Heritage
  Workshop, Darkroom Console, Log Cabin, Orchestra Studio, Pixel Grove, and Country Roadhouse —
  with surface tone, font and accent customisation; Mac Native also supports uploaded wallpaper
  backgrounds and backdrop contrast
- History tab: seven-day focus chart, summary metrics, best-day and active-day insights, a recent
  session log, copy-as-JSON, and clear history
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
