# Blockers

## PLAN-menubar-countdown — manual GUI and audible acceptance gate unavailable

The implementation passed the mechanical gate with `SMOKE PASS (56 checks)` and `VERIFY PASS`,
but acceptance checks A–F could not be observed or operated in the current execution context.
Per the failure protocol, the plan changes were reverted to the last green commit, `a8f3877`.

### Failing command 1

```sh
screencapture -x /private/tmp/pomodewro-menubar-launch.png
```

Full output:

```text
could not create image from display
```

### Failing command 2

```sh
osascript -e 'tell application "System Events" to get name of every process whose name is "Pomodewro"' -e 'tell application "System Events" to tell process "Pomodewro" to get description of every menu bar item of menu bar 1'
```

Full output:

```text
156:167: execution error: System Events got an error: osascript is not allowed assistive access. (-1719)
```

### What was tried

- Ran the required precondition verifier successfully at `a8f3877`.
- Applied only the three prescribed plan changes.
- Confirmed exactly three modified files and 56 smoke assertions.
- Ran the post-change verifier successfully: Swift typecheck, `SMOKE PASS (56 checks)`, full app
  build, signature verification, and `VERIFY PASS`.
- Launched the freshly built `build/Pomodewro.app` with `open`.
- Tried screen capture to inspect the menu-bar title; macOS could not create an image from the
  display.
- Tried System Events accessibility inspection; macOS denied assistive access.
- Quit the launched Pomodewro process and reverted the plan changes to `a8f3877`.

The real menu-bar behaviors and audible chimes in checks A–F remain unverified. The plan must not
be committed until those checks can be performed on a GUI session with screen-recording and
Accessibility access, plus audible output available to the operator.

## PLAN-final-polish — release QA verdict DO-NOT-SHIP

The packaged `release/Pomodewro-1.1.dmg` was installed to a scratch directory and its app process
launched. Release QA rows 1–12, 15, and 17–19 are recorded as FAIL in `RELEASE-QA.md`. Rows 13,
14, and 16 are `N/A (plan blocked)` because PLAN-menubar-countdown is blocked and reverted. Row
20 passed. The verdict is DO-NOT-SHIP and no `v1.1` tag was created.

### Failing command 1

```sh
screencapture -x /private/tmp/pomodewro-1.1-release-qa.png
```

Full output:

```text
could not create image from display
```

### Failing command 2

```sh
osascript -e 'tell application "System Events" to tell process "Pomodewro" to get description of every menu bar item of menu bar 1'
```

Full output:

```text
68:79: execution error: System Events got an error: osascript is not allowed assistive access. (-1719)
```

### Failing QA rows mirrored from RELEASE-QA.md

- Rows 1–7: visible launch, popover, timer controls, mode pills, and duration clamping could not
  be operated or observed.
- Rows 8–10: auto-cycle, cycle-off, and default audible completion could not be configured,
  observed, or heard.
- Rows 11–12: native custom-sound import and Stop Alarm could not be operated or heard.
- Row 15: the popover-closed completion chime could not be configured or heard.
- Rows 17–18: appearance, background, shade, and reset behavior could not be operated or visually
  observed.
- Row 19: history, clipboard JSON parsing, and clear-history behavior could not be performed.

### What was tried

- Backed up the owner's WebKit and Application Support data before launching QA.
- Mounted `release/Pomodewro-1.1.dmg`, confirmed its root contains `Applications`, `INSTALL.txt`,
  and `Pomodewro.app`, then copied the packaged app to a scratch directory.
- Verified the scratch app's ad-hoc signature and embedded version `1.1`.
- Generated the deterministic long-alarm AIFF with `say`.
- Launched the packaged scratch app and confirmed its native process was running.
- Tried display capture and System Events accessibility inspection; macOS denied both paths.
- Quit the QA process and restored the owner's backed-up data. The initial copy-back attempt hit
  `No space left on device`; after deleting only the created scratch QA directory, the intact
  backup was restored by same-volume move and both restored directory sizes were verified.

The failed QA rows require a real interactive Mac GUI session with Screen Recording and
Accessibility permission for the executor, plus an operator who can hear the Mac's audio output.
