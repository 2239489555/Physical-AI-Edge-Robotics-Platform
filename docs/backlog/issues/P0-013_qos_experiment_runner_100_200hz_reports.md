# P0-013 QoS Experiment Runner And 100/200Hz Reports

Type: AFK

Status: completed, Jetson verified 2026-06-12

User stories covered: 6, 7, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create the first QoS experiment runner that compares normal 100Hz and 200Hz behavior across selected QoS settings and writes CSV results.

## Acceptance criteria

- [x] Experiment runner can execute named scenarios for 100Hz and 200Hz.
- [x] Reliable and BestEffort profiles are compared where applicable.
- [x] KeepLast depths are configurable and recorded.
- [x] CSV includes scenario name, frequency, QoS, queue depth, receive rate, drop rate, avg latency, p95 latency, p99 latency, CPU/RAM/temperature fields where available, and notes.
- [x] Markdown report explains observed tradeoffs.
- [x] Runtime result files stay under project-local runtime results.

## Implementation notes

- `sensor_processor` now exposes `sensor_qos_reliability` while keeping the default `best_effort` behavior.
- `scripts/run_p0_013_qos_experiment_smoke.sh` generates per-scenario YAML under `runtime/tmp/p0-013/configs/`.
- The runner executes 8 scenarios: `100Hz/200Hz x best_effort/reliable x depth 10/50`.
- CSV output is written to `runtime/results/qos/p0_013_qos_results.csv`.
- Markdown output is written to `runtime/results/qos/p0_013_qos_report.md`.
- Scenario launch logs are written under `runtime/logs/qos/`.

## Jetson verification evidence

Returned P0-013 smoke evidence from Jetson HEAD `c9de283` completed with `SMOKE_EXIT_STATUS=0`, no timeout, and no residual `fake_sensor_adapter`, `sensor_processor`, `system_metrics_node`, or related launch processes.

Summary:

- Build completed for `edge_reliability_msgs`, `edge_reliability_fake_sensor`, `edge_reliability_processor`, and `edge_reliability_system`.
- Unit tests completed with `Summary: 3 tests, 0 errors, 0 failures, 0 skipped`.
- scenario count: 8.
- Experiment matrix completed all 8 scenarios: `100Hz/200Hz x best_effort/reliable x depth 10/50`.
- CSV output was written to `runtime/results/qos/p0_013_qos_results.csv`.
- Markdown report was written to `runtime/results/qos/p0_013_qos_report.md`.
- Runtime hygiene stayed clean: only ignored `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/` outputs were present.

Observed highlights:

- 100Hz scenarios measured approximately 100Hz receive rate across both QoS profiles.
- 200Hz Reliable scenarios measured approximately 200Hz receive rate with zero reported drops.
- 200Hz BestEffort scenarios recorded nonzero drop-rate evidence, including a depth-50 run at 197.404Hz with p99 latency at 166.005ms, which is useful input for P0-014 pressure analysis.

## Blocked by

- P0-012

## Verification commands

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_013_qos_experiment.ps1`
- `bash scripts/run_p0_013_qos_experiment_smoke.sh`
- `ros2 topic info <topic>`
- Inspect generated CSV.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_013_smoke_report.ps1 -ReportPath runtime\results\p0_013_smoke_report.txt`

## Runtime artifact location

`runtime/results/qos/`, `runtime/logs/qos/`

## Cleanup and rollback

Remove only QoS experiment outputs under runtime directories.

## Out of scope

- 500Hz and 1000Hz pressure runs.
- HTML dashboard.
