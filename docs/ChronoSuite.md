# Chrono Suite 1.1.2

Chrono Suite provides timing, audit, cleanup, data-import, and workflow tools.

Menu root: `Chrono Suite`

Namespace: `kite.ChronoSuite`

Public URL: <https://github.com/Kitherow/Kite-Aegisub-Scripts/blob/main/docs/ChronoSuite.md>

## Main areas

- Audit markers with presets and configurable thresholds.
- Utility groups for case, punctuation, tags, smart cleanup, split/join, timing, and karaoke.
- Data Import modes for Effects, Text, Actor, initial Tags, and Song Sync.
- Cue Timer with optional data-file auto-search on open.
- Auto Timing with Lazy, Busy, and Legacy workflows.
- Extra tools including AE Export, Text Replacer, mpv QC, Remover Assistant, and Style Filter.

## Dedicated entries

- `Chrono Suite/Config`
- `Chrono Suite/Help`
- `Chrono Suite/Cue Timer`
- `Chrono Suite/Auto Timing`
- `Chrono Suite/Extract KF (SCXvid)`
- `Chrono Suite/Scream Detector`
- `Chrono Suite/Audit/Markers`

Additional utility and tool entries are registered beneath the same root for direct hotkey assignment.
Hotkey-oriented entries are also registered under `: Kite Hotkeys :/Chrono Suite/...`.

## Auto Timing

- Lazy uses waveform JSON directly.
- Busy uses the `kite.Timing` module and Busy timing files; waveform JSON is optional.
- Legacy uses the `kite.Timing` module and the legacy silence-based path.

## Configuration and external tools

Settings persist in the Aegisub user directory as `chrono_suite_config.lua`. FFmpeg, SCXvid, keyframes, and external timing-analysis files are required only by the features that use them.

- FFmpeg download: <https://ffmpeg.org/download.html>
- Chrono Generators: <https://github.com/Kitherow/Chrono-Generators-Scripts>
- Timing guide: <https://kitherow.github.io/Arquitectura-del-Timing/>

The script includes English, Spanish, and Portuguese interface text.
