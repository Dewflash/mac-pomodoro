# PLAN-verify — one-command mechanical verification

- **Rank:** 1 of 4 (run FIRST — every other plan's gate depends on it)
- **Dependencies:** none (independent)
- **Effort:** small (both files below are complete and were validated green against this exact repo — copy them verbatim)
- **Files touched:** creates `scripts/verify.sh` and `scripts/smoke-test.js`. Nothing else.

## Goal

The repo has zero mechanical verification: no typecheck command, no lint, no tests. Every later
change to the timer logic or the Swift shell lands blind. This plan adds a single headless-safe
command — `/bin/zsh scripts/verify.sh` — that lints the plist, syntax-checks every shell script,
typechecks both Swift files, runs a 51-check logic smoke test against the real `index.html`
JavaScript, and performs a full app build with signature verification. It is the hard gate for
every subsequent plan.

## Steps

### Step 1 — create `scripts/verify.sh` with exactly this content

```zsh
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
```

### Step 2 — create `scripts/smoke-test.js` with exactly this content

```js
#!/usr/bin/env node
// Pomodewro smoke test — no dependencies.
// Loads the inline <script> from index.html into a vm sandbox with a minimal
// DOM stub and a fake Date.now clock, then drives the real timer logic:
// defaults, clamping, hex normalization, start/pause/resume, completion,
// auto-cycle, history recording, weekly aggregation, and wall-clock restore.
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const htmlPath = path.join(__dirname, "..", "index.html");
const html = fs.readFileSync(htmlPath, "utf8");

const scriptTags = html.split("<script>").length - 1;
if (scriptTags !== 1) {
  console.error(`FAIL extraction: expected exactly 1 <script> block, found ${scriptTags}`);
  process.exit(1);
}
const source = html.split("<script>")[1].split("</script>")[0];
if (source.length < 10000) {
  console.error("FAIL extraction: script block suspiciously small");
  process.exit(1);
}
const lineOffset = html.slice(0, html.indexOf("<script>")).split("\n").length;

// ---------------------------------------------------------------- fake clock
const RealDateNow = Date.now;
let fakeNowMs = RealDateNow();

// ---------------------------------------------------------------- DOM stubs
function makeClassList() {
  const set = new Set();
  return {
    add: (...cs) => cs.forEach((c) => set.add(c)),
    remove: (...cs) => cs.forEach((c) => set.delete(c)),
    toggle(c, force) {
      const on = force === undefined ? !set.has(c) : Boolean(force);
      if (on) set.add(c);
      else set.delete(c);
      return on;
    },
    contains: (c) => set.has(c)
  };
}

function makeStyle() {
  const props = new Map();
  return {
    setProperty: (k, v) => props.set(k, String(v)),
    getPropertyValue: (k) => (props.has(k) ? props.get(k) : ""),
    removeProperty: (k) => props.delete(k)
  };
}

function makeEl(tag, id) {
  const el = {
    tagName: String(tag || "div").toUpperCase(),
    id: id || "",
    className: "",
    textContent: "",
    value: "",
    hidden: false,
    scrollTop: 0,
    children: [],
    classList: makeClassList(),
    style: makeStyle(),
    _handlers: {},
    _attrs: {},
    addEventListener(type, fn) {
      this._handlers[type] = fn;
    },
    setAttribute(k, v) {
      this._attrs[k] = String(v);
    },
    getAttribute(k) {
      return k in this._attrs ? this._attrs[k] : null;
    },
    appendChild(child) {
      this.children.push(child);
      return child;
    },
    append(...nodes) {
      nodes.forEach((n) => this.children.push(n));
    },
    remove() {},
    select() {},
    focus() {},
    click() {}
  };
  Object.defineProperty(el, "innerHTML", {
    get() {
      return "";
    },
    set(v) {
      if (v === "") el.children.length = 0;
    }
  });
  return el;
}

function createInstance(sharedStorage) {
  const elementsById = new Map();
  const doc = {
    hidden: false,
    documentElement: makeEl("html"),
    body: makeEl("body"),
    _handlers: {},
    getElementById(id) {
      if (!elementsById.has(id)) elementsById.set(id, makeEl("div", id));
      return elementsById.get(id);
    },
    createElement(tag) {
      return makeEl(tag);
    },
    addEventListener(type, fn) {
      this._handlers[type] = fn;
    }
  };

  const storage = sharedStorage;
  const localStorageStub = {
    getItem: (k) => (storage.has(k) ? storage.get(k) : null),
    setItem: (k, v) => storage.set(k, String(v)),
    removeItem: (k) => storage.delete(k),
    clear: () => storage.clear()
  };

  const timers = { nextId: 1, fns: new Map() };
  const nativeMessages = [];

  const windowStub = {
    location: { search: "" },
    setInterval: (fn, _ms) => {
      const tid = timers.nextId++;
      timers.fns.set(tid, fn);
      return tid;
    },
    setTimeout: (_fn, _ms) => timers.nextId++,
    addEventListener(type, fn) {
      (this._handlers ||= {})[type] = fn;
    },
    webkit: {
      messageHandlers: {
        pomodewroNative: { postMessage: (m) => nativeMessages.push(m) }
      }
    }
  };

  const sandbox = {
    window: windowStub,
    document: doc,
    localStorage: localStorageStub,
    navigator: {},
    URLSearchParams,
    console,
    clearInterval: (tid) => timers.fns.delete(tid),
    clearTimeout: (_tid) => {},
    __fakeNow: () => fakeNowMs
  };
  const context = vm.createContext(sandbox);
  vm.runInContext("Date.now = () => __fakeNow();", context);
  new vm.Script(source, { filename: "index.html<script>", lineOffset }).runInContext(context);

  return {
    documentElement: doc.documentElement,
    el: (id) => doc.getElementById(id),
    fire(id, type = "click") {
      const target = doc.getElementById(id);
      const fn = target._handlers[type];
      if (!fn) throw new Error(`no ${type} handler on #${id}`);
      fn({ target });
    },
    advance(ms) {
      fakeNowMs += ms;
      for (const fn of [...timers.fns.values()]) fn();
    },
    storage,
    nativeMessages,
    toasts: () => doc.getElementById("toastStack").children.map((t) => t.textContent),
    savedState: () => JSON.parse(storage.get("macPomodoroState.v1") || "{}")
  };
}

// ---------------------------------------------------------------- assertions
let failures = 0;
let checks = 0;
function check(name, actual, expected) {
  checks++;
  if (Object.is(actual, expected)) return;
  failures++;
  console.error(`FAIL ${name}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

// ================================================================ instance 1
const storageA = new Map();
const app = createInstance(storageA);

// T1 — defaults on first load
check("T1 timer shows 25:00", app.el("timerDisplay").textContent, "25:00");
check("T1 duration label 25:00", app.el("durationLabel").textContent, "25:00");
check("T1 cycle enabled by default", app.el("cycleToggle").classList.contains("on"), true);
check("T1 two built-in sounds listed", app.el("focusSound").children.length, 2);
check("T1 three built-in backgrounds listed", app.el("backgroundSelect").children.length, 3);
check("T1 six font styles listed", app.el("fontStyle").children.length, 6);
check("T1 settings open on load", app.el("app").classList.contains("focus-mode"), false);

// T2 — duration stepper + clamping
app.fire("focusPlus");
check("T2 stepper increments to 26:00", app.el("timerDisplay").textContent, "26:00");
app.el("focusMinutes").value = "999";
app.fire("focusMinutes", "change");
check("T2 minutes clamp to 180", app.el("timerDisplay").textContent, "180:00");
app.el("focusMinutes").value = "abc";
app.fire("focusMinutes", "change");
check("T2 invalid minutes fall back to 25", app.el("timerDisplay").textContent, "25:00");

// T3 — accent hex normalization
app.el("accentHex").value = "#3aF";
app.fire("accentHex", "change");
check("T3 short hex expands", app.savedState().accentColor, "#33aaff");
check(
  "T3 accent CSS variable applied",
  app.documentElement.style.getPropertyValue("--accent"),
  "#33aaff"
);
check("T3 hex input re-rendered uppercase", app.el("accentHex").value, "#33AAFF");

// T4 — start hides settings, tick counts down on wall clock
app.fire("playButton");
check("T4 running hides settings", app.el("app").classList.contains("focus-mode"), true);
app.advance(61000);
check("T4 display after 61s", app.el("timerDisplay").textContent, "23:59");

// T5 — pause freezes, resume continues from remaining
app.fire("pauseButton");
check("T5 pause reopens settings", app.el("app").classList.contains("focus-mode"), false);
check("T5 saved as not running", app.savedState().isRunning, false);
check("T5 saved remaining seconds", app.savedState().remainingSeconds, 1439);
app.advance(5000);
check("T5 display frozen while paused", app.el("timerDisplay").textContent, "23:59");
app.fire("playButton");
app.advance(59000);
check("T5 resumed countdown", app.el("timerDisplay").textContent, "23:00");

// T6 — focus completes, records history, auto-cycles into running break
app.advance(1381000);
check("T6 auto-switched to break", app.savedState().mode, "break");
check("T6 break is running", app.savedState().isRunning, true);
check("T6 break duration displayed", app.el("timerDisplay").textContent, "05:00");
check("T6 one focus session recorded", app.savedState().history.length, 1);
check("T6 recorded full focus duration", app.savedState().history[0].seconds, 1500);
check("T6 completion toast shown", app.toasts().includes("Focus complete"), true);

// T7 — break completes, cycles back to focus, breaks not recorded
app.advance(301000);
check("T7 back to focus", app.savedState().mode, "focus");
check("T7 focus running again", app.savedState().isRunning, true);
check("T7 breaks not recorded", app.savedState().history.length, 1);
check("T7 week sessions stat", app.el("weekSessions").textContent, "1");
check("T7 week hours stat", app.el("weekHours").textContent, "0.4h");

// T8 — reset returns to full duration and reopens settings
app.fire("resetButton");
check("T8 reset display", app.el("timerDisplay").textContent, "25:00");
check("T8 reset not running", app.savedState().isRunning, false);
check("T8 reset reopens settings", app.el("app").classList.contains("focus-mode"), false);

// T9 — cycle off: completion stays idle in same mode
app.fire("cycleToggle");
check("T9 cycle toggled off", app.savedState().cycleEnabled, false);
app.fire("playButton");
app.advance(1501000);
check("T9 stays in focus mode", app.savedState().mode, "focus");
check("T9 idle after completion", app.savedState().isRunning, false);
check("T9 second session recorded", app.savedState().history.length, 2);
check("T9 display reset after completion", app.el("timerDisplay").textContent, "25:00");

// T10 — tab switching
app.fire("historyTab");
check("T10 history tab activates", app.el("historyPage").classList.contains("active"), true);
check("T10 timer tab deactivates", app.el("timerPage").classList.contains("active"), false);

// ================================================================ instance 2
// Restore of a running timer from storage (relaunch mid-session).
const storageB = new Map();
storageB.set(
  "macPomodoroState.v1",
  JSON.stringify({
    mode: "focus",
    isRunning: true,
    targetEndTime: fakeNowMs + 90000,
    remainingSeconds: 90,
    cycleEnabled: false,
    focusMinutes: 25,
    breakMinutes: 5,
    history: []
  })
);
const restored = createInstance(storageB);
check("T11 restored running display", restored.el("timerDisplay").textContent, "01:30");
check("T11 restored hides settings", restored.el("app").classList.contains("focus-mode"), true);
restored.advance(91000);
check("T11 restored timer completes", restored.savedState().isRunning, false);
check("T11 restored completion recorded", restored.savedState().history.length, 1);

// ================================================================ instance 3
// Expired running timer completes immediately on load.
const storageC = new Map();
storageC.set(
  "macPomodoroState.v1",
  JSON.stringify({
    mode: "focus",
    isRunning: true,
    targetEndTime: fakeNowMs - 5000,
    remainingSeconds: 0,
    cycleEnabled: false,
    focusMinutes: 25,
    breakMinutes: 5,
    history: []
  })
);
const expired = createInstance(storageC);
check("T12 expired timer completes on load", expired.savedState().isRunning, false);
check("T12 expired session recorded", expired.savedState().history.length, 1);
check("T12 display reset after expiry", expired.el("timerDisplay").textContent, "25:00");

// ================================================================ instance 4
// Weekly aggregation excludes entries older than 7 days.
const storageD = new Map();
storageD.set(
  "macPomodoroState.v1",
  JSON.stringify({
    history: [
      { completedAt: new Date(RealDateNow() - 8 * 86400000).toISOString(), seconds: 3600 },
      { completedAt: new Date(RealDateNow()).toISOString(), seconds: 3600 }
    ]
  })
);
const weekly = createInstance(storageD);
check("T13 old sessions excluded from week hours", weekly.el("weekHours").textContent, "1.0h");
check("T13 old sessions excluded from week count", weekly.el("weekSessions").textContent, "1");
check("T13 seven day rows rendered", weekly.el("historyList").children.length, 7);

// ---------------------------------------------------------------- summary
if (failures > 0) {
  console.error(`SMOKE FAIL: ${failures}/${checks} checks failed`);
  process.exit(1);
}
console.log(`SMOKE PASS (${checks} checks)`);
```

### Step 3 — make the verify script executable

```sh
chmod +x scripts/verify.sh
```

### Step 4 — run it

```sh
/bin/zsh scripts/verify.sh
```

Expected: every section prints OK, the smoke line reads `SMOKE PASS (51 checks)`, and the final
line is `VERIFY PASS` with exit code 0. Both files above were run green against this exact repo
before this plan was written — if verify fails, you made a transcription error; diff your files
against this document before touching anything else.

## Edge cases a weaker model would miss

- **`smoke-test.js` must live in `scripts/`.** It locates the app via
  `path.join(__dirname, "..", "index.html")`. Placing it at repo root silently tests the wrong
  path and fails with ENOENT.
- **Only `Date.now` is faked; `new Date()` stays real. Do not "improve" this.** The timer engine
  (`startTimer`, `tick`, `restoreRunningTimer` in index.html) does math on `Date.now()`, which the
  fake clock controls. But `recordFocusSession` stamps history with `new Date().toISOString()` and
  `getWeeklyHistory` buckets by a real `new Date()` "today" — both must use the same real clock or
  the weekly assertions (T7, T13) break as the fake clock drifts hours ahead.
- **The app script runs in a `vm` context, not via `eval` or `require`.** The inline script
  references `document`, `localStorage`, `window`, `clearInterval` as bare globals; the sandbox is
  what resolves them to the stubs. Evaluating it in Node's own global scope would hit Node's real
  globals (or ReferenceErrors) instead.
- **The `webkit` stub must be present from the start.** `nativeBridgeAvailable()` in index.html
  probes `window.webkit?.messageHandlers?.pomodewroNative`. The stub makes the harness exercise
  the native-bridge code path and collects messages into `nativeMessages` — a later plan asserts
  on it. Do not remove it because it "isn't asserted yet".
- **Exactly one `<script>` block in index.html is a repo invariant.** The extraction guard exits
  hard if that changes. If a future edit needs JS, it goes inside the existing block.
- **Do not assert on progress-bar percentages.** They are floating-point strings
  (`"95.93333333333334%"`); the suite deliberately asserts on formatted time text instead.
- **`advance(ms)` snapshots interval callbacks before invoking.** Completion handlers clear the
  old interval and register a new one mid-iteration; iterating the live Map would double-fire.
- **Midnight flake window.** T7/T13 aggregate "today" using the real clock. If (and only if) the
  suite is run exactly astride local midnight, those checks can misalign by a day. If the only
  failures are T7/T13 week stats, rerun once before investigating.
- **The nvm fallback in verify.sh is load-bearing.** Node on this machine is nvm-managed
  (`~/.nvm/versions/node/v24.14.0/bin/node`); non-interactive shells may not have it on PATH. Do
  not simplify the discovery block away.
- **verify.sh must stay headless.** It builds the .app but never opens it. Never add
  `open build/Pomodewro.app` or any GUI step to it — it must be safe to run unattended.
- **The `for script in scripts/*.sh` loop self-checks verify.sh and auto-covers future scripts.**
  That is deliberate; later plans add scripts without editing verify.sh.

## Acceptance criteria

1. `/bin/zsh scripts/verify.sh` exits 0; output contains `SMOKE PASS (51 checks)` and ends with
   `VERIFY PASS`.
2. `node scripts/smoke-test.js` alone exits 0 with `SMOKE PASS (51 checks)`.
3. `git status --porcelain` shows exactly two entries: `?? scripts/smoke-test.js` and
   `?? scripts/verify.sh` (before you commit). `build/` stays untracked (gitignored).
4. `zsh -n scripts/verify.sh` exits 0.

Suggested commit message:

```
test: add one-command verify with JS smoke harness
```
