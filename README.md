# Pomodewro

A local Pomodoro focus timer designed for a compact Mac menu bar popover.

Open `index.html` in a browser to preview it, or build the native menu bar app with:

```sh
/bin/zsh scripts/build-mac-app.sh
```

The built app appears at `build/Pomodewro.app`. It bundles the HTML locally, so it does not need internet. Custom sounds and backgrounds are saved in local storage as Base64 strings, with uploads limited to 2 MB.

## Features

- Focus and break timer modes with play, pause, reset, and skip controls
- Native Mac menu bar wrapper with a monochrome tomato status icon
- Pomodoro Cycle toggle that auto-switches Focus and Break sessions
- Wide rectangular glassmorphism layout with a collapsible settings panel while running
- Default Web Audio soft bell, plus separate custom Focus and Break chimes
- Appearance tab with font presets, UI colour control, wallpaper-style backgrounds, and cover cropping
- Darkness/Tint slider for readability over uploaded images
- Reset controls for custom audio and background settings
- History tab with past-week focus hours, daily logs, JSON export, and clear history
- Toast feedback instead of native alerts
