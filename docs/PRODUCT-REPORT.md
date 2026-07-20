# Pomodewro — Product and Industry Report

**Evidence date:** 2026-07-20  
**Basis:** current repository source, `README.md`, roadmap plans, `RELEASE-QA.md`, `BLOCKERS.md`, and the current mechanical verifier. No external competitor or market research was performed.

## Evidence labels

- **Implemented:** evidenced in current source/configuration and/or the mechanical gate.
- **Partial:** present but fragile, unverified, or inconsistent with the full product promise.
- **Planned:** described in roadmap/product intent, not proven by source alone.
- **Inferred:** reasoned product interpretation, not a measured user fact.
- **Unknown:** not established by this repository.

## 1. Executive summary

**One sentence:** Pomodewro is an offline Mac menu-bar Pomodoro timer with a themed WebKit popover, local sounds, history, and native timer plumbing.

**Elevator pitch:** Start a focus block from the menu bar, close the popover, and keep the timer and completion sound close at hand without a cloud account or recurring service.

**Target users:** people who already work on a Mac and want a lightweight focus/break ritual; the strongest fit is an individual user who values local data, custom ambience, and visual theming.

**Problem solved:** a conventional timer requires opening an app or browser tab and often provides little context about progress or recent focus. Pomodewro reduces that interaction cost through a menu-bar entry point and a persistent local session history.

**Strongest current differentiator:** the combination of a menu-bar surface, nine material themes, native local sound import, and an offline-first storage model. Each part is copyable; the combination is primarily an experience/distribution differentiator rather than a defensible technical moat.

**Current stage:** functional indie release candidate. The verifier is green (`SMOKE PASS (86 checks)`, `VERIFY PASS`), but `RELEASE-QA.md` remains **DO-NOT-SHIP** because GUI, accessibility, and audible manual checks could not be performed in the recorded environment.

## 2. The problem and alternatives

### User problem

The repository supports a clear, modest problem: a Mac user needs a visible focus/break timer that is quick to start, does not require an account, and can provide a completion cue. The code proves the workflow exists; it does not prove market frequency, willingness to pay, or that users prefer it over existing tools.

### Alternatives

- macOS Clock/Reminders or a phone timer: readily available, but not specialised for Focus/Break cycles or desktop-local history.
- Browser Pomodoro sites: fast to try, but often require a tab, may be distracting, and do not offer this app’s native sound storage/menu-bar shell.
- Dedicated commercial focus apps: may offer richer integrations, analytics, sync, and onboarding; Pomodewro is smaller, local, and more customisable but less operationally mature.
- A physical timer or manual calendar: low technical risk, but no automatic history or configurable audio.

These are qualitative comparisons, not current market research. The repository cannot establish market share, competitor pricing, retention, or the size of the opportunity.

## 3. Users and use cases

### Primary: individual Mac knowledge worker or student

**Scenario:** choose a focus duration, choose a theme and chime, click Play, close the popover, work until the completion sound, then review the seven-day chart and session log. The value is lower setup friction and a visible record of consistency.

**Return motivation (inferred):** recurring work blocks, local history, and a preferred visual theme/sound combination encourage repeat use.

### Secondary: ambience/customisation-oriented user

**Scenario:** select Field Notes, Darkroom Console, Orchestra Studio, or another theme; import a local audio file; use the Mac Native background controls where supported. The value is personal ritual and environmental fit rather than a new timing algorithm.

### Professional or team user

**Status: not served by current implementation.** There is no account, sync, team dashboard, shared history, admin policy, calendar integration, or multi-device data model. A team may use it individually, but the repository does not support team-level workflows.

### Users explicitly out of scope

People needing mobile/Windows/Linux clients, cloud backup, cross-device sync, regulated productivity records, or collaborative focus rooms should not treat the current release as a fit.

## 4. Product experience

### Onboarding and first value

There is no account or multi-step onboarding. A DMG/ZIP installs an unsigned app; macOS may require right-click → Open. The first value path is: click the menu-bar tomato, see the 25:00 Focus default, press Play, and close the transient popover. The build requires macOS 13+ (`macos/Info.plist`).

### Main surfaces

- **Menu bar:** tomato status item; when the native timer state is running, Swift can display a live `MM:SS` title next to it (`macos/PomodewroApp.swift:93–130`).
- **Timer & Sounds tab:** Focus/Break duration steppers, Focus/Break sound selectors, Add controls, Clear Audio, and Stop Alarm.
- **Appearance tab:** theme preset, surface tone, font style, accent colour/hex, and Mac Native-only background upload/contrast controls.
- **History tab:** seven-day chart, focus/session totals, average, best day, active days, recent log, Copy JSON, and Clear History.

### Key decisions and recovery

- Play collapses settings; pause/reset reopen them.
- Cycle ON automatically moves Focus → Break → Focus; only completed Focus sessions enter history.
- Invalid minute input is clamped to 1–180; invalid hex colour produces a toast and keeps the previous colour.
- Sound/image size limits reject oversized browser uploads with a toast.
- Stop Alarm stops generated Web Audio or imported HTML audio.
- Missing/invalid stored backgrounds fall back to Mountain Lake; invalid persisted JSON falls back to defaults.
- Native import cancellation is silent; native failures surface through a callback toast.

The experience is compact, but native file-panel operation, real audio, menu-bar rendering, and packaged-app visual layout are not currently verified by the recorded manual QA.

## 5. Product capabilities

| Capability | Beneficiary/value | Status and limitations |
|---|---|---|
| Focus/Break timer | Anyone using work/rest blocks | **Implemented.** Wall-clock target plus 250 ms page tick; current launch path pauses persisted running state. |
| Pomodoro Cycle | Users wanting automatic alternation | **Implemented mechanically.** Completion sound/toast and mode transition are smoke-tested; real audible output is unverified. |
| Menu-bar countdown/keep-alive | Users who close the popover | **Partial.** Swift timer, native title, and App Nap activity token exist; manual GUI acceptance is blocked. |
| Generated chimes | Users needing zero-setup audio | **Implemented mechanically.** Uses Web Audio; actual speaker output is unverified. |
| Custom browser sound | Users previewing `index.html` | **Implemented.** Data URL in local storage, capped at 2 MB. |
| Custom native sound | Users with longer local songs | **Implemented in source.** Copies bytes to Application Support and serves through `pomodewro-sound`; native file/audio flow is manually unverified. |
| Theme system | Users who want visual context | **Implemented.** Nine presets, runtime CSS tokens, surface tone, font, accent; shared markup stays stable. |
| Mac Native background | Users wanting wallpaper-style context | **Implemented.** Mountain Lake default, uploads, compression limits, and 0–100 backdrop contrast; controls hidden for other themes. |
| History report | Users tracking consistency | **Implemented mechanically.** Seven-day aggregation, chart, insights, latest eight sessions, JSON export; GUI/clipboard flow unverified. |
| Offline/local privacy | Users avoiding accounts/cloud | **Implemented.** No network calls or auth; local storage and local sound files are the sources of truth. |

## 6. Product and technical architecture

### Runtime shape

The app is a native AppKit accessory process hosting one local `WKWebView`. The web runtime owns product state and UI; Swift supplies the Mac surface and native-only capabilities. The build uses system frameworks only and produces an ad-hoc signed bundle.

### Data flow

1. User input updates the mutable JavaScript `state` object.
2. `saveState()` writes `{...state, isRunning, remainingSeconds, targetEndTime}` to `localStorage` key `macPomodoroState.v1` and posts a native timer message.
3. `render()` derives visible DOM, CSS variables, theme surfaces, progress, chart, and log from state.
4. Native sound import copies a file to Application Support, then returns an id/name/custom URL to JavaScript; the custom scheme handler reads the file only after validating its id.
5. The native status item receives timer projections and computes its own remaining display from the wall-clock target.

### Security, privacy, and reliability

There is no authentication, server, telemetry, network, or remote API. The app is therefore cheap to operate and easy to reason about offline. It is not a security product: local history, settings, base64 browser uploads, and native audio are unencrypted on the user’s machine. Ad-hoc signing and no notarization create Gatekeeper friction. No automatic backup or cloud recovery exists.

The custom scheme validates ids against `[A-Za-z0-9_-]+`, reducing path traversal risk. JavaScript storage failures and media failures are caught and surfaced as toasts, but the app has no structured logging, telemetry, retry queue, or crash-reporting path.

### Scalability and operating cost

For a single user, the architecture is inexpensive: static local HTML, local persistence, and no servers. The likely limits are WebKit storage quotas for data URLs, the 240-entry history cap, and the maintenance cost of the 3,400-line single-file runtime. Scaling to teams or sync would require a server/account model, conflict resolution, privacy policy changes, and a new data architecture.

## 7. Differentiation and positioning

### Exists today

- Mac menu-bar entry point plus a popover rather than a normal application window.
- Offline-first storage and no account requirement.
- Native local sound import in addition to browser fallback audio.
- Nine complete visual material presets, not merely one accent-colour switch.
- A history view combining aggregate charting with a recent session log.

### Not defensible alone

Timer logic, CSS themes, generated chimes, and local storage are straightforward to reproduce. The advantage is primarily **experiential**: a coherent, highly themed local timer that stays near the user’s work surface. Distribution, polish, reliability, and user habit—not hidden algorithms—would determine whether that positioning matters.

### Validation needed

Run a short comparison study with Mac users who already use browser timers, menu-bar utilities, or physical timers. Measure time-to-first-session, completion rate, repeat use, preference for themes/custom sounds, and whether history changes behaviour. The repository has no user research or analytics, so retention and differentiation remain hypotheses.

## 8. Maturity, quality, and trust

### Strong evidence

- The mechanical verifier passed on 2026-07-20: plist lint, all shell syntax checks, Swift typechecks, 86 logic checks, full build, and ad-hoc signature verification.
- The smoke harness drives the real extracted JavaScript and covers timer transitions, history, migration, custom backgrounds, and the native bridge message.
- Release packaging has deterministic DMG/ZIP staging and includes install instructions.

### Important qualification

`RELEASE-QA.md` records FAIL for most GUI/audio rows and `N/A (plan blocked)` for menu-bar countdown rows. The current environment could not provide screen capture, Accessibility inspection, or audible observation. “Implemented in source” must not be read as “fully validated in the shipped experience.”

### Trust risks

1. A user may expect a running timer to resume after relaunch; current code pauses it.
2. Custom sounds live outside the app bundle, so moving machines requires reimport/backup.
3. An unsigned build may appear suspicious to macOS users.
4. Visual regressions can escape the headless gate.
5. Generic toasts are helpful but do not provide diagnostics or recovery detail.

## 9. Feasibility and longevity

**Technical feasibility: high for a personal Mac utility.** The dependency set is small, offline, and built from Apple frameworks. The core timer/history problem is bounded and inexpensive.

**Distribution feasibility: moderate.** The app can build and package, but ad-hoc signing, no notarized release process, and blocked GUI QA reduce confidence for broad distribution.

**Longevity risks:** macOS/WebKit behaviour changes, local-storage quota limits, audio permission or format differences, single-file maintenance, and the unresolved relaunch contract. There is no vendor API or hosted service risk; that is a meaningful sustainability advantage.

**Privacy/regulatory risk: low but not zero.** The product handles personal productivity history and local audio, not regulated data. It should still document storage, deletion, and backup clearly.

## 10. Roadmap and priorities

### Release-critical

1. Obtain a real interactive Mac QA session with Screen Recording, Accessibility, and audible output; rerun the packaged-artifact rows rather than relying on the current DO-NOT-SHIP record.
2. Decide and document relaunch semantics: resume the wall-clock session, or intentionally pause it and remove any resume promise from product copy/roadmap.
3. Verify custom sound import, playback, stop-alarm, and backup/reimport behaviour on a packaged build.

### High-value next

4. Add visual regression coverage for shared timer geometry and representative themes.
5. Add an explicit local export/import backup for settings, history, and native sound metadata.
6. Improve error messages with actionable file-size, storage, and audio-format guidance.
7. Add a versioned storage migration strategy before adding more persisted fields.

### Defer until demand exists

Cloud sync, accounts, team workspaces, mobile clients, social features, and complex analytics should wait for evidence that the local single-user loop is retained and valuable.

## 11. Communication pack

### Website introduction

Pomodewro is a local Mac menu-bar Pomodoro timer for focused work, deliberate breaks, custom sounds, and a visual environment that feels like yours. It works offline, keeps your history on your Mac, and stays within one click from the task at hand.

### User-facing explanation

Click the tomato, choose Focus or Break, and press Play. Close the popover while you work. When the session ends, Pomodewro plays your chime, records the Focus session, and lets you review your week. Choose a theme, import a local sound, or keep the defaults.

### Technical explanation for peers

Pomodewro is a single-file offline web runtime hosted by a 443-line AppKit/WebKit shell. JavaScript owns persisted state and rendering; a manual WebKit message protocol projects timer state and native sound operations to Swift. The build is dependency-light and reproducible, but the protocol and single-file UI are coupled and the manual packaged-app gate is incomplete.

### 30-second pitch

Pomodewro is a Mac menu-bar Pomodoro timer that feels more like a personal workspace than a generic timer. It is offline, themeable, keeps a useful local history, and supports your own sounds without making you create an account.

### Three user stories

1. As a student, I start a 25-minute block from the menu bar, close the popover, and review my weekly focus total after several sessions.
2. As a writer, I choose Field Notes or Heritage Workshop and use a local chime to make starting and finishing a block feel deliberate.
3. As a privacy-conscious Mac user, I want a timer whose settings, history, and imported sounds remain local rather than being sent to a service.

### FAQ

**Does it require internet?** No runtime network calls are present.  
**Does it sync across Macs?** No. State and sounds are local to one Mac.  
**Where are imported native sounds?** `~/Library/Application Support/Pomodewro/Sounds`.  
**What happens on relaunch?** A persisted running state is currently restored as paused.  
**Is it notarized?** The release is ad-hoc signed; macOS may require right-click → Open.  
**Can I use it on Windows or mobile?** No supported native build is present.  
**How reliable is the menu-bar countdown?** The code and mechanical checks exist, but the repository’s recorded GUI acceptance remains blocked.

### Why this matters

The product’s strongest idea is not a novel timer algorithm; it is reducing the distance between a user’s work surface and a personal focus ritual while avoiding cloud overhead. That idea is credible for a small Mac utility if reliability and installation trust are proven.

### Honest current limitations

No sync, accounts, team features, mobile/Windows build, cloud backup, notarization, automated visual tests, or confirmed real-world audio/menu-bar QA are evidenced. A user who needs those should choose a more mature product.

## 12. Final assessment

**Strongest case:** technically feasible, coherent, offline, visually differentiated, and small enough to maintain for personal use.

**Strongest criticism:** the product promise emphasises reliable closed-popover/relaunch behaviour, but the relaunch path currently pauses and the real GUI/audio acceptance gate remains unresolved.

**Largest unresolved risk:** trust at the exact moment users depend on the timer—when the popover is closed, the app is relaunched, or an imported sound should play.

**Highest-value next step:** complete packaged-app manual QA in a permitted, audible GUI environment, then make the resume/pause contract explicit in code, README, and release QA.

**Verdict:** promising as a focused personal Mac utility; not yet proven enough for a confident broad “ship” claim. The verdict should change after all critical packaged rows pass and repeated users show that themes, local sounds, and history improve return use.
