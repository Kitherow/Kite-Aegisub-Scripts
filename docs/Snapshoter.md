# Snapshoter 1.5.9

Snapshoter captures subtitle frames, frame lists, frame sequences, and clip crops from the loaded video.

Menu root: `Snapshoter`

Hotkey path: `: Kite Hotkeys :/Snapshoter/Execute`

Namespace: `kite.Snapshoter`

## Capture modes

- Selected lines
- Frame list
- Frame sequence
- Clip crop
- Manual rectangle
- Densest subtitle frame

## Timing modes

- Midpoint
- Start and end
- Start, middle, end
- Current video frame

## Clip crop outputs

- Rectangle crop
- Clip alpha crop
- Clip alpha full frame
- Drawing alpha crop
- Drawing alpha full frame

## Frame sequence outputs

- No subtitles
- With subtitles
- Subtitles only

## Requirements

Snapshoter needs a loaded video and Aegisub frame/time functions. Output paths are selected through the macro interface.

## Configuration

Settings persist through ConfigHandler in `kite-snapshoter.json`.
