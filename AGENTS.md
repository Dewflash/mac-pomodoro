# AGENTS.md — execution contract for the Pomodewro handover roadmap

You are executing a pre-planned roadmap. The plans were written against commit `b2dc8ae` after
reading the entire codebase; every code block in them was applied to a copy of this repo and
validated (typecheck / smoke / packaging) before being written down. Your job is faithful
execution and honest gating — not redesign.

**Product promise (judge every decision against it):** a glanceable, always-within-reach Mac
menu bar Pomodoro timer that reliably counts down and rings — even when the popover is closed.

## Step 0 — first session only

Commit the roadmap documents themselves before any other work:

```sh
git add AGENTS.md PLAN-verify.md PLAN-menubar-countdown.md PLAN-package-release.md PLAN-final-polish.md
git commit -m "docs: add execution roadmap"
```

## Execution order

One plan per session. Finish and commit a plan before starting the next. Never interleave.

```
PLAN-verify                (rank 1, independent — run first)
   ├── PLAN-menubar-countdown   (rank 2, needs verify)
   ├── PLAN-package-release     (rank 3, needs verify; independent of rank 2)
   └── PLAN-final-polish        (rank 4, needs verify + package-release;
                                 adapts if menubar-countdown is blocked)
```

## The hard gate (after every plan)

A plan is DONE only when all three hold:

1. `/bin/zsh scripts/verify.sh` exits 0 and ends with `VERIFY PASS`
   (exception: this script does not exist until PLAN-verify itself lands — that plan's gate is
   its own acceptance criteria).
2. Every acceptance criterion in that plan's file passes, including the manual checks with their
   observable pass conditions.
3. The work is committed with the plan's suggested commit message.

Gates may never be weakened, skipped, or reinterpreted on your own authority. If a gate seems
wrong, that is a blocker to log, not a rule to bend. Never edit `scripts/verify.sh` or
`scripts/smoke-test.js` except where a plan explicitly instructs it (PLAN-menubar-countdown adds
the T14 block and changes the expected count 51 → 56; nothing else touches them).

## Failure protocol

If a step fails and the plan's own instructions don't resolve it:

1. Revert the working tree to the last green commit (`git reset --hard <last-green>`). Never
   leave a plan half-landed; never commit a red tree.
2. Append an entry to `BLOCKERS.md` (create it if absent): the plan name, the exact failing
   command, its FULL output verbatim, and what you tried.
3. Continue only with plans that do not depend on the failed one (see the graph). Where a plan
   says "STOP and report — do not improvise", that instruction is absolute.

## House rules

- **No new runtime dependencies.** No npm packages, no SwiftPM, no frameworks beyond
  AppKit/WebKit/UniformTypeIdentifiers already imported. Node is used for dev verification only.
- **Match existing style.** index.html: 2-space indent, double quotes, no semicolon omission;
  Swift: 4-space indent, `private` file-scope types; scripts: zsh with `set -euo pipefail`.
- **Never commit:** `build/` output, `.DS_Store`, secrets, or any personal media/audio files.
  The only binary artifacts ever committed are `release/Pomodewro-*.dmg/.zip`, and only within
  PLAN-final-polish's release commit.
- **Architecture invariants:**
  - The entire web app lives in `index.html` with exactly ONE `<script>` block (the smoke-test
    extraction depends on this).
  - The app is fully offline — never add a network call, CDN reference, or telemetry.
  - `macPomodoroState.v1` is the localStorage persistence contract; never rename it.
  - The JS↔Swift bridge names are load-bearing: message handler `pomodewroNative`, custom URL
    scheme `pomodewro-sound`, callbacks `pomodewroNativeSoundImported` /
    `pomodewroNativeSoundImportFailed` / `pomodewroNativeSoundsCleared`,
    hook `window.pomodewroRefreshTimer`.
- `scripts/verify.sh` is headless-safe (builds, never launches). The manual checks in
  PLAN-menubar-countdown and PLAN-final-polish require the real GUI and (two rows) audible sound
  on this Mac — run them for real; report honestly what you observed.
- Do not push to any remote. Commits and tags stay local.

## Definition of done (whole engagement)

- All four plans landed with green gates and their suggested commit messages — or any that could
  not land are cleanly reverted and documented in `BLOCKERS.md` with full failing output.
- `/bin/zsh scripts/verify.sh` is green at final HEAD.
- `RELEASE-QA.md` is committed with every row filled and an explicit SHIP or DO-NOT-SHIP verdict.
- `v1.1` is tagged if and only if the verdict is SHIP.
- The working tree is clean (`git status --porcelain` empty).
