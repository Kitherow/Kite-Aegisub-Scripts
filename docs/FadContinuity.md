# Fad-Continuity 1.0.0

Fad-Continuity removes internal `\fad` edges between continuous selected timing groups.

Menu root: `Fad-Continuity`

Hotkey path: `: Kite Hotkeys :/Fad-Continuity/Execute`

Namespace: `kite.FadContinuity`

Fad-Continuity is a direct top-level macro with no dialog.

## Behavior

- Groups selected dialogue lines by equal start and end times.
- When one group ends exactly where the next starts, removes fade out from the first group and fade in from the next group.
- Leaves non-continuous groups unchanged.

## Requirements

Fad-Continuity declares no additional modules.
