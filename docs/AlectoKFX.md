# Alecto KFX 1.0.0

Alecto KFX generates karaoke by syllable with Intro, Active, and Outro phases from commented setup lines.

Menu root: `Alecto KFX`

Hotkey path: `: Kite Hotkeys :/Alecto KFX/Execute`

Namespace: `kite.AlectoKFX`

Alecto KFX is a direct top-level macro with no dialog.

## Workflow

- Prepare karaoke lines with `\k` syllable timing.
- Add commented setup lines when a line needs phase overrides.
- Run `Alecto KFX` on the target lines.

Generated lines leave `Effect` empty.

## Requirements

Alecto KFX uses `karaskel` for syllable preprocessing.
