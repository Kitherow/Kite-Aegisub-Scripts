# Wave2json 1.2.0

Wave2json exports the active audio waveform to JSON.

Menu root: `Wave2json`

Hotkey path: `: Kite Hotkeys :/Wave2json/Execute`

Namespace: `kite.Wave2json`

Wave2json is a direct top-level macro with no dialog.

## Behavior

- Uses the active audio file from the current Aegisub project.
- Assumes `ffmpeg` is available from PATH.
- Exports the complete active audio only.
- Writes the JSON beside the script file when possible, otherwise beside the audio file.

## Output

The exporter decodes mono 48 kHz PCM through FFmpeg and writes waveform pyramid data to JSON.

## Requirements

Wave2json requires a loaded audio file and FFmpeg.
