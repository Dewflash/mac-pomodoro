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
check("T1 four theme presets listed", app.el("themeStyle").children.length, 4);
check("T1 midnight theme applied", app.documentElement.getAttribute("data-theme"), "midnight-glass");
check("T1 settings open on load", app.el("app").classList.contains("focus-mode"), false);
check("T1 history log empty state", app.el("historyLog").children[0].textContent, "No completed sessions yet");

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

// T3b — full theme preset + surface tone
app.el("themeStyle").value = "graphite";
app.fire("themeStyle", "change");
check("T3b theme persisted", app.savedState().selectedThemeId, "graphite");
check("T3b graphite theme applied", app.documentElement.getAttribute("data-theme"), "graphite");
app.el("surfaceTone").value = "15";
app.fire("surfaceTone", "input");
app.fire("surfaceTone", "change");
check("T3b surface tone persisted", app.savedState().surfaceTone, 15);
check("T3b tone label updates", app.el("surfaceToneValue").textContent, "Bright");

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
check("T6 completion appears in log", app.el("historyLog").children.length, 1);
check("T6 log shows session duration", app.el("historyLog").children[0].children[2].textContent, "25m");

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
check("T13 seven chart bars rendered", weekly.el("historyChart").children.length, 7);
check("T13 one active day", weekly.el("historyActiveDays").textContent, "1 of 7");
check("T13 daily average", weekly.el("historyAverage").textContent, "9m avg");
check("T13 best day duration", weekly.el("historyBestDay").textContent.includes("1.0h"), true);
check("T13 chart scale maximum", weekly.el("historyChartMax").textContent, "1.0h");
check("T13 today is final chart bar", weekly.el("historyChart").children[6].className.includes("is-today"), true);
check("T13 chart bar has accessible value", weekly.el("historyChart").children[6].getAttribute("aria-label").includes("1.0h focus across 1 session"), true);
check("T13 log includes full stored history", weekly.el("historyLog").children.length, 2);
check("T13 log count", weekly.el("historyLogCount").textContent, "2 sessions");

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

// ---------------------------------------------------------------- summary
if (failures > 0) {
  console.error(`SMOKE FAIL: ${failures}/${checks} checks failed`);
  process.exit(1);
}
console.log(`SMOKE PASS (${checks} checks)`);
