# P0-014 500/1000Hz Pressure Runs And Bottleneck Report

Type: AFK

User stories covered: 5, 6, 7, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Extend QoS experiments with 500Hz and 1000Hz pressure runs that generate evidence and bottleneck explanations without treating high-frequency stability as a P0 pass gate.

## Acceptance criteria

- [ ] Experiment runner includes 500Hz and 1000Hz scenarios.
- [ ] CSV output is generated even when the pipeline cannot sustain the requested rate.
- [ ] Report separates pass/fail P0 thresholds from pressure observations.
- [ ] Report explains bottlenecks using receive rate, drop rate, latency, and Jetson system metrics.
- [ ] QoS mismatch scenario is reproduced and explained.
- [ ] No claim is made that 500Hz or 1000Hz must be stable for P0 completion.

## Blocked by

- P0-013

## Verification commands

- Experiment runner command for 500Hz.
- Experiment runner command for 1000Hz.
- `ros2 topic hz <topic>`
- Inspect generated CSV and report.

## Runtime artifact location

`runtime/results/qos/`, `runtime/logs/qos/`, `runtime/bags/qos/`

## Cleanup and rollback

Remove only pressure-run outputs under runtime directories.

## Out of scope

- Real-time kernel tuning.
- Hard real-time guarantees.
