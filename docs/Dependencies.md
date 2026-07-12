# Dependencies

## Common requirement

- Aegisub Automation with DependencyControl installed.

## AddTexture

- `ZF.main` 2.3.0
- `l0.ASSFoundation` 0.5.0
- `kite.UI` 1.0.0

## Alecto KFX

- `karaskel`

## Auto Blur

- `karaskel`
- `kite.UI` 1.0.0
- Optional: `a-mo.DataWrapper` 1.0.2 for tracking data.

## Chrono Suite

- `karaskel`
- `l0.ASSFoundation` 0.5.0
- `l0.Functional` 0.6.0
- `aegisub.re`
- `kite.UI` 1.0.0
- Optional: `kite.Timing` 1.0.2

FFmpeg, SCXvid, audio/video media, keyframes, or timing-analysis files are feature-specific external inputs rather than Automation modules.

- FFmpeg download: <https://ffmpeg.org/download.html>
- Chrono Generators: <https://github.com/Kitherow/Chrono-Generators-Scripts>

## Cliptomaniac

- `ZF.main` 2.3.0
- `l0.ASSFoundation` 0.5.0
- `arch.Perspective` 1.2.1
- `arch.Util` 0.1.0
- `kite.UI` 1.0.0
- `a-mo.LineCollection` 1.3.0
- `a-mo.Line` 1.5.3
- `l0.Functional` 0.6.0

## Cope Optimizer

- `kite.UI` 1.0.0

## Fad-Continuity

Fad-Continuity declares no additional modules. DependencyControl is used as the update mechanism and macro registrar.

## Field Group Manager

- `kite.UI` 1.0.0

## Gradient Row

- `a-mo.LineCollection` 1.3.0
- `a-mo.Line` 1.5.3
- `l0.ASSFoundation` 0.5.0
- `arch.Perspective` 1.2.1
- `kite.UI` 1.0.0
- Optional: `SubInspector.Inspector` 0.6.0

## Insert Coñete

Insert Coñete declares no additional modules. DependencyControl is used as the update mechanism and macro registrar.

## Komari

Komari declares no additional modules. DependencyControl is used as the update mechanism and macro registrar.

## Line Mixer

Line Mixer declares no additional modules. DependencyControl is used as the update mechanism and macro registrar.

## Moka Shape

- `ZF.main` 2.3.0
- `l0.ASSFoundation` 0.5.0
- `kite.UI` 1.0.0

## Obake

- `l0.ASSFoundation` 0.5.0
- `a-mo.Line` 1.5.3
- `kite.UI` 1.0.0

## PNG2ASS

- `aka.command` 1.0.2
- `kite.UI` 1.0.0
- External Python package: `kite-png2ass` (module: `ass_png2ass`)

## Rhea Signs

- `karaskel`
- `l0.ASSFoundation` 0.5.0
- `l0.Functional` 0.6.0
- `arch.Perspective` 1.0.0
- `arch.Util` 0.1.0
- `a-mo.LineCollection` 1.3.0
- `a-mo.Line` 1.5.3
- `kite.UI` 1.0.0

## Snapshoter

- `a-mo.LineCollection` 1.3.0
- `kite.UI` 1.0.0
- `a-mo.Tags` 1.3.4
- `a-mo.Log` 1.0.0
- `l0.ASSFoundation` 0.5.0

## Wave2json

Wave2json declares no additional Automation modules. It requires FFmpeg for media decoding.

## Zheus Colormanager

Zheus declares no additional modules. DependencyControl is used as the update mechanism and macro registrar.

## Kite Timing

`kite.Timing` is installed under `automation/include/kite/Timing.lua` and is used by [Chrono Suite](https://github.com/Kitherow/Kite-Aegisub-Scripts/blob/main/docs/ChronoSuite.md) Busy and Legacy timing workflows.

## Kite UI

`kite.UI` is installed under `automation/include/kite/UI.lua`. It stores stable script preferences by namespace in `?user/config/kite.settings.json` and imports supported legacy JSON, Lua-table, and key-value formats without deleting them.
