# Pomodewro — Repository Learning Report

**Evidence date:** 2026-07-20  
**Scope:** repository source, scripts, plans, release notes, smoke tests, and the current mechanical verifier.

## Evidence legend

- **Implemented:** directly present in source/configuration and covered by the current mechanical gate.
- **Partial:** present in source but incomplete, fragile, or not fully verified in the real GUI.
- **Planned:** described by a roadmap, not necessarily implemented.
- **Inferred:** a reasoned interpretation of the code; uncertainty is stated.
- **Unknown:** not established by this repository.

## 1. Executive overview

Pomodewro is a small, offline macOS menu-bar Pomodoro timer. The user clicks a tomato status item,
uses a WebKit popover for Focus/Break timing and settings, then closes the popover while the session
continues. The product is implemented as a native AppKit/WebKit shell around one self-contained
`index.html` file.

**Implemented:** Focus and Break timers, play/pause/reset, automatic cycling, generated chimes,
custom sounds, nine themes, Mac Native background controls, history reporting, local persistence,
native menu-bar countdown plumbing, and DMG/ZIP packaging. `scripts/verify.sh` currently passes:
plist lint, shell syntax checks, Swift typechecks, `SMOKE PASS (86 checks)`, a signed build, and
`VERIFY PASS`.

**Partial:** the native countdown path is present in `macos/PomodewroApp.swift` and tested by T14
smoke assertions, but the repository’s manual GUI/audio gate remains blocked by missing Screen
Recording, Accessibility, and audible-output access (`BLOCKERS.md`, `RELEASE-QA.md`). Relaunch
currently deliberately pauses persisted running state in `restoreRunningTimer()` rather than
resuming it (`index.html:3389–3404`).

## 2. Repository map

| Path | Role | Notes |
|---|---|---|
| `index.html` | Primary web UI, CSS, markup, state, timer, history, and bridge code | Exactly one inline `<script>` is required by the smoke harness. |
| `macos/PomodewroApp.swift` | Native AppKit status item, popover, WebKit bridge, sound import/storage, native timer display | Uses AppKit, WebKit, and UniformTypeIdentifiers only. |
| `macos/Info.plist` | Bundle metadata and platform policy | Version `1.1`, build `2`, bundle id `com.dewflash.pomodewro`, minimum macOS 13, `LSUIElement=true`. |
| `scripts/build-mac-app.sh` | Development/build bundle assembly | Renders icon, compiles Swift, copies `index.html` and plist, ad-hoc signs. |
| `scripts/package-release.sh` | Reproducible DMG/ZIP packager | Includes app plus `INSTALL.txt` in both formats; DMG also includes `/Applications` symlink. |
| `scripts/verify.sh` | Mechanical release gate | No GUI launch; performs lint, typecheck, smoke, build, and signature checks. |
| `scripts/smoke-test.js` | Dependency-free logic integration test | Extracts the real inline script into a VM with a fake DOM, storage, bridge, and clock. |
| `scripts/render-app-icon.swift` | Generates PNG icon sizes | Consumed by `build-mac-app.sh` and `iconutil`. |
| `assets/app-icon-source.jpg` | Icon-generation source asset | Build input, not runtime user data. |
| `release/INSTALL.txt` | Install instructions | Tracked release documentation. |
| `release/Pomodewro-1.1.dmg/.zip` | Current release artifacts | Binary artifacts are intentionally tracked only for the release. |
| `PLAN-*.md` | Roadmap and acceptance criteria | Plans distinguish mechanical gates from manual GUI/audio gates. |
| `RELEASE-QA.md`, `BLOCKERS.md` | Release evidence and blockers | Current verdict is `DO-NOT-SHIP` because manual rows were not observable. |

There is no `package.json`, lockfile, database migration, server, or dependency directory. Node is
used only to execute the smoke test; the runtime has no network dependency.

## 3. System architecture

### Layers

1. **Native shell:** `AppDelegate` owns the status item, transient `NSPopover`, native countdown
   display, and App Nap keep-alive (`macos/PomodewroApp.swift:18–150`).
2. **Web UI/runtime:** `index.html` owns markup, themes, controls, timer state, persistence, audio,
   history, and rendering (`index.html:1–3438`).
3. **Native bridge:** Web JavaScript posts messages through `pomodewroNative`; Swift sends callbacks
   such as `pomodewroNativeSoundImported` and serves imported files through the `pomodewro-sound`
   URL scheme.
4. **Local storage:** WebKit `localStorage` stores settings/history under the load-bearing key
   `macPomodoroState.v1`; native sound bytes live under Application Support.
5. **Build/release layer:** shell scripts convert source into a signed app bundle and then DMG/ZIP.

The dependency direction is intentionally simple: Swift hosts WebKit and handles macOS-only APIs;
the web layer remains usable in a browser with native messages becoming no-ops and file inputs used
as a fallback.

### Sources of truth

- `state` in `index.html` is the web product state.
- `remainingSeconds` and `targetEndTime` are the timer’s in-memory clock values.
- `macPomodoroState.v1` is the persisted settings/history contract.
- Swift’s `TimerState` is a derived native display/keep-alive projection, not a second user-facing
  settings store.
- `SoundStore` owns native imported file bytes; `state.nativeSounds` owns their ids, names, and
  custom URL references.

The main architectural risk is that the web state object and Swift native state must stay in sync via
stringly typed message names and dictionaries. Those names are load-bearing and documented in
`AGENTS.md`.

## 4. Startup and runtime flows

### App startup

1. `applicationDidFinishLaunching` sets the app to accessory-only mode, configures the tomato status
   item and popover, registers `onTimerStateChange`, and eagerly loads the bundled `index.html`.
2. `WebViewController` creates a `WKWebViewConfiguration`, enables media playback, registers the
   `pomodewroNative` message handler, and registers `pomodewro-sound`.
3. JavaScript parses the optional `nativeScale`, loads persisted state, normalises values, renders
   selects, attaches handlers, and exposes `window.pomodewroRefreshTimer`.
4. If persisted state says the timer was running, `restoreRunningTimer()` restores the remaining
   display but forces the session to paused and reopens settings. This avoids an automatic countdown
   on launch, but means “resume across relaunch” is not currently implemented.

### Timer flow

- `startTimer()` sets `state.isRunning`, closes settings, computes `targetEndTime`, starts a 250 ms
  page interval, saves state, and ticks immediately.
- `tick()` derives remaining time from wall-clock `Date.now()`, renders, and calls `completeTimer()`
  at zero.
- `completeTimer()` records Focus history, plays the selected sound, shows a toast, and either
  auto-cycles into the other mode or resets to an idle session.
- Every `saveState()` also pushes `{type:"timerState", running, mode, targetEndTime}` to Swift.
- Swift maintains a 0.5 s native display timer and a `ProcessInfo.beginActivity` token while running;
  at zero it calls back into the page to refresh completion logic.

### Settings and visual flow

The main grid has a timer surface and a settings surface. Settings collapse by changing the app grid
from `1fr 292px` to `1fr 0`; the settings panel fades/translates and becomes non-interactive. The
timer stack is deliberately controlled by shared fixed rows and theme variables so opening settings
changes width without changing the vertical stack’s intended geometry (`index.html:225–289` and
the later material overrides).

The appearance flow chooses a theme preset, computes tone-adjusted RGB values, writes CSS custom
properties, applies font/accent variables, applies background data, and renders controls. Mac Native
is the only theme exposing the background upload and backdrop-contrast section.

### Sound flow

The web fallback reads an audio file as a data URL, caps it at 2 MB, stores it in `state.customSounds`,
and plays it with `Audio`. In the native app, the same “+ Add” control posts `importSound`; Swift’s
`NSOpenPanel` copies the selected file into `~/Library/Application Support/Pomodewro/Sounds`,
returns metadata, and the WebKit scheme handler streams it back to the page. The “Stop Alarm” control
stops either HTML audio or the generated Web Audio context.

### History flow

Only completed Focus sessions are recorded. Each record is `{completedAt: ISO string, seconds}` and
the array is capped at 240 entries. The History tab derives the past seven days, total focus hours,
session count, average, best day, active days, seven chart bars, and the latest eight log entries.
Copy JSON exports both the past-week summary and the full stored session array.

## 5. Module and file guide

### `index.html`

This is intentionally a single-file application rather than a component framework. CSS variables and
theme presets form a lightweight design system; DOM ids form the view model’s selectors; the inline
closure provides module-like private scope. `render()` is the central synchronisation point: it
updates the timer, classes, form values, theme variables, background, accents, and history.

Important functions:

- State/persistence: `loadState`, `saveState`, normalisation near `index.html:2440–2473` and
  `index.html:3389–3434`.
- Timer: `setMode`, `startTimer`, `pauseTimer`, `resetTimer`, `tick`, `completeTimer` near
  `index.html:2677–2753`.
- Audio/backgrounds: `uploadFile`, `requestSoundImport`, native callbacks near
  `index.html:2868–2988`.
- History: `recordFocusSession`, `getWeeklyHistory`, `renderHistory`, export/clear near
  `index.html:2990–3234`.
- Event wiring: `attachEvents` near `index.html:3257–3379`.

Maintainability concern: this file is the UI, data layer, controller, theme system, audio engine,
and test target at once. It is easy to trace for a small app, but changes can unintentionally affect
layout, persistence, and bridge behaviour simultaneously.

### `macos/PomodewroApp.swift`

`AppDelegate` owns application lifecycle and menu-bar behaviour. `WebViewController` owns WebKit
configuration, JavaScript evaluation, native message handling, and open panels. `SoundStore` owns
filesystem persistence. `SoundSchemeHandler` translates a safe sound id into a MIME-typed WebKit
response. `TomatoStatusIcon` generates the status icon procedurally.

The native file is cohesive for the current scope, but it combines lifecycle, UI hosting, timer
projection, bridge protocol, and storage. A future refactor could separate bridge messages and
sound persistence without changing the public bridge names.

### Scripts

`build-mac-app.sh` is the source-to-bundle path. `package-release.sh` calls it and stages the app plus
install instructions. `verify.sh` is the required headless gate. `smoke-test.js` is the most important
test because it executes the actual inline JavaScript rather than a duplicate model.

## 6. Language and framework education

- **Swift/AppKit:** `NSApplicationDelegate` is the process lifecycle object; `NSStatusBarItem` gives
  the menu-bar surface; `NSPopover` supplies the transient panel; `ProcessInfo` prevents App Nap while
  the timer is active.
- **Swift/WebKit bridge:** `WKUserContentController` receives JavaScript dictionaries; JavaScript
  calls `postMessage`; Swift calls page functions with `evaluateJavaScript`. This is a manual protocol,
  so names and payload shapes need compatibility discipline.
- **JavaScript state:** a closure replaces a framework component model. Mutable `state` is persisted;
  `render()` is the explicit state-to-DOM projection. There are no React hooks, TypeScript types,
  dependency injection, or router because the product has one surface and no remote navigation.
- **Promises and async:** `FileReader`, image decoding, clipboard writes, and audio playback expose
  asynchronous operations. Errors become toast messages; there is no retry queue.
- **CSS variables:** theme presets compute runtime tokens such as `--canvas`, `--settings-bg`,
  `--material-blur`, and `--accent`, allowing one markup structure to support nine visual systems.
- **Shell build:** Zsh scripts use `set -euo pipefail`; failures stop the pipeline. Swift and icon
  generation are compiled directly instead of through Xcode or SwiftPM.

## 7. Data architecture, privacy, and recovery

The persisted schema is an object merged with defaults. Key fields include timer mode/durations,
running metadata, selected sounds, selected theme/font/accent, surface/tint values, backgrounds,
and history. Invalid JSON falls back to defaults. Numeric durations are clamped to 1–180 minutes;
background arrays are pruned by data-length checks; legacy theme ids migrate to current theme ids.

This is a local/offline product: no accounts, server, network calls, telemetry, or remote database are
present. The native sound path validates ids before reading files, which limits path traversal through
the custom URL scheme. Data is not encrypted; a local user with filesystem access can inspect sound
files, WebKit storage, and history. That is acceptable for a personal timer but should be disclosed
as a trust boundary.

Recovery is user-driven: failed saves/audio/imports show toasts, invalid colour input keeps the old
colour, missing backgrounds fall back to Mountain Lake, and the app can clear stored audio/history.
There is no automatic backup, migration version field beyond the storage key, or conflict handling.

## 8. UI, accessibility, and reliability

The UI has three settings tabs, explicit empty history text, visible error/toast feedback, stop-alarm
recovery, input constraints, `aria-label` attributes for major controls, and role/labels for history
charts/logs. Buttons that use icons retain `aria-label` and `title` attributes.

**Implemented mechanically:** timer state transitions, history aggregation, theme selection, migration,
background persistence, bridge message assertions, Swift typecheck, build/signature, and 86 smoke
assertions.

**Not verified by the current environment:** visual alignment across all themes, real popover/menu-bar
interaction, native file panels, audible completion, and packaged-app GUI behaviour. `RELEASE-QA.md`
records these as FAIL or blocked rather than claiming success.

## 9. Build and deployment

From the repository root:

```sh
/bin/zsh scripts/verify.sh
/bin/zsh scripts/build-mac-app.sh
/bin/zsh scripts/package-release.sh
```

The build requires macOS tooling (`swift`, `swiftc`, `iconutil`, `codesign`, `hdiutil`) and the
system frameworks AppKit/WebKit/UniformTypeIdentifiers. There are no runtime secrets or environment
variables. The release is ad-hoc signed, not notarized; the install notes warn that macOS may require
right-click → Open. `Info.plist` declares macOS 13 as the minimum.

## 10. Architectural critique and priorities

### Strengths

1. The offline boundary is clear and low-cost.
2. The smoke test executes real application JavaScript and checks persistence/timer/history semantics.
3. The native bridge solves the platform-specific needs without adding a service or dependency.
4. Theme tokens keep visual variation within one stable layout.
5. Release packaging is reproducible and verifies app signature/build contents.

### Risks and confusing areas

1. The single 3,400-line HTML file creates high coupling and makes regressions hard to localise.
2. The JS↔Swift protocol is stringly typed and has no Swift-side schema validation beyond casts/defaults.
3. Launch behaviour intentionally pauses persisted running timers, while the native countdown design
   and roadmap promise relaunch resilience. This product promise is inconsistent and needs a decision.
4. Manual GUI/audio coverage is blocked; visual changes can pass all mechanical tests while still being
   wrong in the packaged app.
5. LocalStorage contains full data URLs for browser-uploaded sounds/backgrounds. Capacity and browser
   quota failures are handled only by a generic toast.
6. Ad-hoc signing and no notarization add installation friction and limit professional distribution.

### Recommended next changes

1. First, enable a real interactive QA environment and settle the relaunch contract (resume vs pause).
2. Add a small bridge contract test for every message/callback and native error path.
3. Split the inline script into logical source modules only after behaviour is locked by tests.
4. Add visual regression checks for the shared timer geometry and theme-specific controls.
5. Add export/import backup for settings, history, and native sound metadata; document that audio bytes
   live outside the app bundle.
6. For distribution beyond personal use, adopt a notarized signing/release process.

## 11. Learning summary

The mental model is: **Swift owns the Mac surface; `index.html` owns the product; local storage owns
user state; the bridge projects timer/audio events across the boundary; scripts build and prove the
bundle.**

A safe first change should begin by tracing its DOM id and event handler, checking whether it calls
`saveState()` and `render()`, checking whether it touches a bridge name or persisted field, running the
86-check smoke test, and then running `scripts/verify.sh`. For visual work, also use the real packaged
app; the current repository explicitly shows that headless verification cannot prove GUI/audio claims.
