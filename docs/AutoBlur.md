# Auto Blur 2.0.3

Auto Blur matches a sign's `\blur` to frame sharpness with fixed or tracked sample points and time-varying blur curves.

Menu root: `Auto Blur`

Hotkey path: `: Kite Hotkeys :/Auto Blur/Execute`

Namespace: `kite.AutoBlur`

Auto Blur is a standalone top-level macro.

## Workflow

- Load video and select one dialogue line.
- Choose a background sample point from a fixed coordinate, clip pin, `\pos`, `\move`, or clipboard coordinates.
- Set patch radius, smoothing window, minimum run length, maximum blur, curve, quantization, and transition handling.
- Apply a continuous blur transform or discrete blur runs.

## Requirements

Auto Blur needs a loaded video and Aegisub frame/time functions. Tracking-data mode additionally uses `a-mo.DataWrapper`.
