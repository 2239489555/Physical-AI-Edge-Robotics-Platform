# P0-013 QoS Experiment Runner And 100/200Hz Reports

Type: AFK

User stories covered: 6, 7, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create the first QoS experiment runner that compares normal 100Hz and 200Hz behavior across selected QoS settings and writes CSV results.

## Acceptance criteria

- [ ] Experiment runner can execute named scenarios for 100Hz and 200Hz.
- [ ] Reliable and BestEffort profiles are compared where applicable.
- [ ] KeepLast depths are configurable and recorded.
- [ ] CSV includes scenario name, frequency, QoS, queue depth, receive rate, drop rate, avg latency, p95 latency, p99 latency, CPU/RAM/temperature fields where available, and notes.
- [ ] Markdown report explains observed tradeoffs.
- [ ] Runtime result files stay under project-local runtime results.

## Blocked by

- P0-012

## Verification commands

- `ros2 launch <package> <experiment_launch>`
- Experiment runner command.
- `ros2 topic info <topic>`
- Inspect generated CSV.

## Runtime artifact location

`runtime/results/qos/`, `runtime/logs/qos/`

## Cleanup and rollback

Remove only QoS experiment outputs under runtime directories.

## Out of scope

- 500Hz and 1000Hz pressure runs.
- HTML dashboard.
