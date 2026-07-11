# PLAN-menubar-countdown — live remaining time in the menu bar + native keep-alive

- **Rank:** 2 of 4
- **Dependencies:** run AFTER PLAN-verify (its gate and smoke harness must exist). Independent of
  PLAN-package-release.
- **Effort:** medium (every code block below was applied to a copy of this repo and validated:
  the Swift file typechecks, the smoke suite passes at 56 checks)
- **Files touched:** `macos/PomodewroApp.swift`, `index.html` (one insertion inside `saveState`),
  `scripts/smoke-test.js` (one appended block). Nothing else.

## Goal

The product promise is a glanceable menu bar Pomodoro that reliably counts down and rings even
when the popover is closed. Today the menu bar shows only a static tomato — checking remaining
time costs a click, and nothing outside the web view guarantees the alarm fires on time if WebKit
throttles a hidden page or macOS App-Naps the process. This plan closes both gaps with one
mechanism:

1. The web app already funnels every timer state change through `saveState()`
   (index.html, defined near line 1193). We add a single `postNativeMessage` push there.
2. The Swift shell renders a live `MM:SS` title next to the status icon, driven by its own 1-second
   native timer computed from the pushed wall-clock target (so the title ticks even if page JS is
   throttled).
3. While a session runs, the shell holds a `ProcessInfo.beginActivity` token so App Nap cannot
   stall the countdown; when the native clock hits zero it pokes the page
   (`webViewController.refreshTimer()`) so `completeTimer()` fires the alarm on time.
4. The web view now loads eagerly at launch (`loadIfNeeded()` in
   `applicationDidFinishLaunching`), so a timer that was running when the app quit resumes — and
   rings — even if the user never opens the popover after relaunch.

## Steps

### Step 0 — precondition

Run `/bin/zsh scripts/verify.sh`. It must print `VERIFY PASS` (with `SMOKE PASS (51 checks)`)
before you change anything. If it does not: STOP and report — do not improvise.

### Step 1 — index.html: push timer state from `saveState()`

Find this exact block (it is unique in the file; it is the end of the `saveState` function):

```js
        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...state, isRunning, remainingSeconds: restSeconds, targetEndTime: isRunning ? targetEndTime : 0 }));
        } catch {
          showToast("Could not save settings");
        }
      }
```

Replace it with:

```js
        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...state, isRunning, remainingSeconds: restSeconds, targetEndTime: isRunning ? targetEndTime : 0 }));
        } catch {
          showToast("Could not save settings");
        }
        postNativeMessage({
          type: "timerState",
          running: isRunning,
          mode: state.mode,
          targetEndTime: isRunning ? targetEndTime : 0
        });
      }
```

Why `saveState` is the hook: it is already called at every timer state transition — `startTimer`,
`pauseTimer`, `resetTimer`, `setMode`, `completeTimer` (both cycle branches), and the running
branch of `restoreRunningTimer` — and it already computes the normalized `isRunning` local and has
the module-level `targetEndTime` in scope. `postNativeMessage` (defined near line 1207) is a
no-op returning `false` when the native bridge is absent, so the browser preview is unaffected.

### Step 2 — scripts/smoke-test.js: add the T14 bridge assertions

Find this exact line (unique):

```js
// ---------------------------------------------------------------- summary
```

Insert the following block immediately BEFORE it (keep the summary section itself unchanged):

```js
// ================================================================ instance 5
// Timer state is pushed to the native bridge (PLAN-menubar-countdown).
const storageE = new Map();
const bridge = createInstance(storageE);
bridge.fire("playButton");
const startMsg = bridge.nativeMessages.filter((m) => m.type === "timerState").pop();
check("T14 start pushes running timerState", Boolean(startMsg && startMsg.running), true);
check("T14 start pushes focus mode", startMsg ? startMsg.mode : "(none)", "focus");
check("T14 start pushes future target", Boolean(startMsg && startMsg.targetEndTime > fakeNowMs), true);
bridge.fire("pauseButton");
const pauseMsg = bridge.nativeMessages.filter((m) => m.type === "timerState").pop();
check("T14 pause pushes stopped timerState", pauseMsg ? pauseMsg.running : "(none)", false);
check("T14 pause zeroes target", pauseMsg ? pauseMsg.targetEndTime : "(none)", 0);

```

This changes the expected smoke output from `SMOKE PASS (51 checks)` to `SMOKE PASS (56 checks)`.
That is the only assertion change this plan makes; do not renumber or edit T1–T13.

### Step 3 — macos/PomodewroApp.swift: apply these seven edits

Each edit is given as an exact old → new pair. Every anchor occurs exactly once in the file.

**Edit 1 — status item must have variable length so a title fits.** Replace:

```swift
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
```

with:

```swift
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
```

**Edit 2 — AppDelegate state + launch wiring + eager load.** Replace:

```swift
    private let webViewController = WebViewController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
    }
```

with:

```swift
    private let webViewController = WebViewController()
    private var countdownTimer: Timer?
    private var activityToken: NSObjectProtocol?
    private var timerState: TimerState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        webViewController.onTimerStateChange = { [weak self] state in
            self?.applyTimerState(state)
        }
        webViewController.loadIfNeeded()
    }
```

**Edit 3 — countdown display, keep-alive, and completion poke.** Replace:

```swift
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

with:

```swift
    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func applyTimerState(_ state: TimerState) {
        if state == timerState { return }
        timerState = state
        if state.running {
            beginKeepAlive()
            startCountdownDisplay()
        } else {
            stopCountdownDisplay()
            endKeepAlive()
        }
    }

    private func startCountdownDisplay() {
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusTitle()
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
        updateStatusTitle()
    }

    private func stopCountdownDisplay() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        updateStatusButton(title: "")
    }

    private func updateStatusTitle() {
        guard let state = timerState, state.running else { return }
        let remaining = max(0, Int(ceil(state.targetEndTimeMs / 1000 - Date().timeIntervalSince1970)))
        updateStatusButton(title: Self.formatRemaining(remaining))
        if remaining <= 0 {
            webViewController.refreshTimer()
        }
    }

    private func updateStatusButton(title: String) {
        guard let button = statusItem.button else { return }
        if title.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
        } else {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])
            button.imagePosition = .imageLeft
        }
    }

    private static func formatRemaining(_ totalSeconds: Int) -> String {
        String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func beginKeepAlive() {
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Pomodewro timer running"
        )
    }

    private func endKeepAlive() {
        guard let token = activityToken else { return }
        ProcessInfo.processInfo.endActivity(token)
        activityToken = nil
    }
}
```

**Edit 4 — the TimerState value type.** Replace:

```swift
private struct NativeSound {
```

with:

```swift
private struct TimerState: Equatable {
    let running: Bool
    let mode: String
    let targetEndTimeMs: Double
}

private struct NativeSound {
```

**Edit 5 — callback property on WebViewController.** Replace:

```swift
    private var didLoad = false
```

with:

```swift
    fileprivate var onTimerStateChange: ((TimerState) -> Void)?
    private var didLoad = false
```

**Edit 6 — allow programmatic audio playback.** Replace:

```swift
        configuration.websiteDataStore = .default()
```

with:

```swift
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = []
```

**Edit 7 — handle the new message type.** Replace:

```swift
        case "clearSounds":
            clearStoredSounds()
```

with:

```swift
        case "clearSounds":
            clearStoredSounds()
        case "timerState":
            let running = body["running"] as? Bool ?? false
            let mode = body["mode"] as? String ?? "focus"
            let targetEndTimeMs = body["targetEndTime"] as? Double ?? 0
            onTimerStateChange?(TimerState(running: running, mode: mode, targetEndTimeMs: targetEndTimeMs))
```

After Edit 7 there is nothing more to change in the Swift file.

### Step 4 — run the gate

```sh
/bin/zsh scripts/verify.sh
```

Expected: `SMOKE PASS (56 checks)` and `VERIFY PASS`. The patched Swift file was pre-validated
with `swiftc -typecheck` — if typecheck fails you mistyped a hunk; diff against this document.

### Step 5 — manual verification (real app)

Launch the freshly built app: `open build/Pomodewro.app`, then perform the checks in the
Acceptance section. Quit the app afterwards (right-click the tomato icon → Quit Pomodewro).

## Edge cases a weaker model would miss

- **Use the local `isRunning` const in the JS push, not `state.isRunning`.** `saveState` computes
  `isRunning = Boolean(state.isRunning && targetEndTime > 0)` — the normalized truth. Raw
  `state.isRunning` can be `true` with a zero target during restore edge states, which would make
  the native side count down from epoch zero.
- **The push goes AFTER the try/catch, inside `saveState`.** Inside the `try` it would be skipped
  whenever localStorage write fails (quota), silently freezing the menu bar title.
- **`saveState` also fires on appearance tweaks** (e.g. every accent-color drag event). That is
  why `applyTimerState` starts with `if state == timerState { return }` — the Equatable dedupe.
  Removing it makes the status title flicker and restarts the native timer on every slider move.
- **`TimerState` is `private` at file scope, so the callback property must be `fileprivate`.**
  Writing `var onTimerStateChange` (internal) fails to compile: "property must be declared
  fileprivate because its type uses a private type". Do not "fix" that by making TimerState
  internal; match the file's existing `private struct NativeSound` style.
- **The native timer is created with `Timer(timeInterval:repeats:block:)` and added to
  `RunLoop.main` in `.common` mode — not `Timer.scheduledTimer`.** Scheduled timers run only in
  the default mode, which pauses during menu/popover event tracking: the countdown would visibly
  freeze while the popover or any menu is open.
- **`targetEndTime` arrives in epoch milliseconds (JS `Date.now()` basis); Swift compares against
  `Date().timeIntervalSince1970` in seconds.** The `/ 1000` in `updateStatusTitle` is
  load-bearing. Dropping it shows a huge frozen title and the completion poke never fires.
- **Cast the target with `as? Double`, never `as? Int`.** WebKit bridges JS numbers as NSNumber,
  frequently double-backed; an Int cast can fail, defaulting the target to 0, which makes the
  shell believe the timer expired and poke the page in a loop.
- **The `remaining <= 0` poke repeating every 0.5s is safe by design.** `refreshTimer()` in the
  page runs `tick()` only while `state.isRunning`; `completeTimer()` sets `isRunning = false`
  synchronously before playing the alarm, so repeated pokes cannot double-record history. Do not
  add native-side "fire once" latching — the repetition is the self-healing path when the first
  poke lands while WebKit is still waking the page.
- **Do not compute the next session natively.** After completion, the page's `completeTimer`
  either auto-starts the break (cycle on) — which calls `startTimer` → `saveState` → a fresh push
  with the new target — or goes idle and pushes `running: false`. The shell only mirrors.
- **Keep `loadIfNeeded()` inside `statusItemClicked` too.** It is guarded by `didLoad`, so the
  double call is free, and it protects popover behavior if the eager launch call is ever moved.
- **Eager load costs a WebContent process at launch (~tens of MB).** That is the accepted price
  for the relaunch-mid-session promise (manual check E). Do not "optimize" it away.
- **`mediaTypesRequiringUserActionForPlayback = []` exists for the zero-gesture alarm.** With
  eager load, a stored timer can expire and ring before the user ever interacts with the page
  (T12's scenario, live). Default WebKit policy may block `audio.play()` for custom sounds in
  that state; the empty set permits programmatic playback.
- **`beginActivity` uses `.userInitiatedAllowingIdleSystemSleep`, and the token must be
  begin/end-balanced.** The guards (`activityToken == nil` / `guard let token`) prevent
  double-begin leaks. Do not use plain `.userInitiated` — it also disables idle system sleep, and
  a pomodoro timer must never keep the whole Mac awake.
- **T14 must stay AFTER T13 and BEFORE the summary block.** It reads the module-level `fakeNowMs`,
  which earlier tests have advanced; moving it above them changes the arithmetic and can flake.

## Acceptance criteria

1. `/bin/zsh scripts/verify.sh` exits 0; output contains `SMOKE PASS (56 checks)` and ends with
   `VERIFY PASS`.
2. `git status --porcelain` shows exactly three modified files: `index.html`,
   `macos/PomodewroApp.swift`, `scripts/smoke-test.js`.
3. Manual, against `open build/Pomodewro.app` (each has an observable pass condition):
   - **A.** Open the popover, press Play → within 1 second the menu bar shows `MM:SS` in
     monospaced digits beside the tomato icon, ticking once per second. If no title appears:
     STOP and report — do not improvise.
   - **B.** Press Pause → the title disappears; the status item returns to icon-only.
   - **C.** Start again, click the desktop to close the popover → the title keeps ticking with
     the popover closed.
   - **D.** Set Focus to 1 minute, cycle ON, start, close the popover, wait ~60s without touching
     anything → at zero the chime plays and the title flips to `05:00` (break) and keeps ticking,
     all without the popover open.
   - **E.** With a session running, right-click → Quit. Relaunch `build/Pomodewro.app` and do NOT
     click the icon → within ~2 seconds the menu bar title reappears with the correct remaining
     time. (Proves eager load + restore + push.)
   - **F.** Cycle OFF, 1-minute focus, popover closed, wait for zero → chime plays and the title
     clears (idle).
4. Quit the app after testing.

Suggested commit message:

```
feat: live menu bar countdown with native keep-alive
```
