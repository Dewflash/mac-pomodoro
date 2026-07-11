# Pomodewro 1.1 — Release QA

Run against `release/Pomodewro-1.1.dmg` installed to a scratch directory (commit `bffd806` plus
the final release working tree). Rule: PASS only from actually performing the check — an honest
FAIL is worth more than a green lie. `N/A (plan blocked)` is used only for rows whose feature
plan is in BLOCKERS.md.

| # | Check | Steps | Expected | Result | Notes |
|---|-------|-------|----------|--------|-------|
| 1 | Launch | `open` the scratch copy | Tomato icon appears in menu bar; no Dock icon; no windows | FAIL | The packaged process launched, but macOS denied screen capture and Accessibility inspection, so the visible conditions could not be verified. |
| 2 | Popover open/close | Left-click icon; then click the desktop | Popover opens under the icon; clicking outside closes it | FAIL | UI interaction and observation were unavailable because assistive access and display capture were denied. |
| 3 | Play | Click Play | Settings panel collapses; timer counts down each second | FAIL | Could not operate or observe the packaged app UI. |
| 4 | Pause/resume | Pause, wait 5s, Play | Display freezes at pause; resumes from the same remaining time | FAIL | Could not operate or observe the packaged app UI. |
| 5 | Reset | Click Reset mid-session | Timer returns to full duration; settings panel reopens | FAIL | Could not operate or observe the packaged app UI. |
| 6 | Mode pills | Click Break, then Focus | Each switch resets the display to that mode's duration | FAIL | Could not operate or observe the packaged app UI. |
| 7 | Duration clamp | Type 999 in Focus (min), click outside; then type abc | 999 clamps to 180:00; abc falls back to 25:00 | FAIL | Could not type into or observe the packaged app UI. |
| 8 | Auto-cycle | Focus = 1 min, Cycle ON, Play, wait | At zero: chime + toast; Break starts running automatically | FAIL | Could not configure the session, observe completion, or hear machine output. |
| 9 | Cycle off | Cycle OFF, Focus = 1 min, Play, wait | At zero: chime; stays in Focus, idle at 01:00, settings reopen | FAIL | Could not configure the session, observe completion, or hear machine output. |
| 10 | Default chime audible | Row 8/9 completion with speakers on | Soft Bell / Gentle Ping actually audible | FAIL | The execution context cannot hear the Mac's audio output; no audible claim was made. |
| 11 | Custom sound import | Timer & Sounds → + Add → pick /System/Library/Sounds/Glass.aiff; complete a 1-min session | Native file panel opens; "Sound saved" toast; Glass plays at completion | FAIL | Could not operate the native file panel or hear completion audio. |
| 12 | Stop Alarm | Import the `say`-generated long-alarm.aiff as Focus chime; complete a session; click Stop Alarm while it plays | Stop Alarm button visible during playback; click silences immediately + "Alarm stopped" toast | FAIL | The deterministic long-alarm file was generated, but the UI/audio flow could not be performed. |
| 13 | Menu bar countdown | Start a session; look at the menu bar | MM:SS ticks beside the icon once per second | N/A (plan blocked) | PLAN-menubar-countdown is logged in BLOCKERS.md and was reverted. |
| 14 | Countdown clears | Pause, then Reset | Menu bar time disappears; icon-only look returns | N/A (plan blocked) | PLAN-menubar-countdown is logged in BLOCKERS.md and was reverted. |
| 15 | Rings while closed | 1-min Focus, close popover, hands off 60s | Chime fires with popover closed (countdown build: title flips to 05:00 break) | FAIL | Could not configure/close the popover or hear machine output, so the required real packaged-app behavior is unverified. |
| 16 | Relaunch mid-session | Start 5-min session, Quit app, relaunch scratch copy | Countdown build: menu bar time reappears without opening the popover. Blocked variant: open popover — timer restored at correct remaining | N/A (plan blocked) | The plan explicitly assigns this row N/A when PLAN-menubar-countdown is blocked. |
| 17 | Appearance | Change font preset; set accent hex to 3aF; then type ZZZ | Font + colours update; ZZZ shows "Use a hex colour" toast and keeps old colour | FAIL | Could not operate or observe the packaged app UI. |
| 18 | Background & shade | Upload any image; move Darkness and Timer Shade sliders; Reset Appearance | Image applies; sliders visibly change tint/shade; reset restores Mountain Lake defaults | FAIL | Could not operate or visually inspect the packaged app UI. |
| 19 | History & JSON | Open History after row 8; Copy JSON; `pbpaste \| python3 -m json.tool`; then Clear History | Session counted in stats + today's row; JSON parses; clear zeroes stats | FAIL | Row 8 could not be completed and the UI/clipboard flow could not be performed. |
| 20 | Version coherence | `/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$QA_DIR/Pomodewro.app/Contents/Info.plist"`; check README + INSTALL.txt | Prints 1.1; docs reference 1.1 filenames only | PASS | The packaged scratch app printed `1.1`; README and INSTALL.txt contain the 1.1 filenames and no stale `1.0` references. |

## Verdict

**DO-NOT-SHIP**

Rows 1–12, 15, and 17–19 failed because the current execution context cannot capture the display,
use macOS Accessibility, or hear machine audio. Rows 13, 14, and 16 are N/A only because the
menu-bar countdown plan is documented as blocked and reverted. No `v1.1` tag may be created.
