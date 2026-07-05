# Cope Optimizer 1.0.2

Cope Optimizer reduces selected PNG2ASS color drawing lines by merging similar colors or simplifying detected gradients.

Menu root: `Cope Optimizer`

Hotkey path: `: Kite Hotkeys :/Cope Optimizer/Execute`

Namespace: `kite.CopeOptimizer`

Cope Optimizer is a standalone top-level macro.

## Modes

- Auto
- Colores similares
- Gradiente completo

## Options

- Intensity: `Equilibrado`, `Fidelidad`, or `Agresivo`.
- OKLab threshold.
- Maximum gradient bands.
- Optional summary before applying changes.

The optimizer is conservative around unsupported animation, clipping, alpha, or incompatible drawing-scale cases.
