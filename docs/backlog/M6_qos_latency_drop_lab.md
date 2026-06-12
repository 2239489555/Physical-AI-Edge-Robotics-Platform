# M6 QoS Latency Drop Lab

## Goal

Run controlled QoS, latency, drop, and pressure experiments and generate evidence.

## Context

Robot communication reliability depends on QoS, queue depth, subscriber speed, publish rate, CPU pressure, and topic compatibility. This milestone makes those tradeoffs visible.

## Inputs

- Fake sensor pipeline from M3.
- Metrics and health monitor from M4.
- Jetson monitor from M5.

## Expected Outputs

- Experiment runner or launch configurations.
- CSV results for multiple experiments.
- Markdown report explaining results.
- Fault injection scenarios.
- Interface contract updates.
- Interview artifacts.

## Current Progress

- P0-013 QoS experiment runner is completed and Jetson verified with `SMOKE_EXIT_STATUS=0` on HEAD `c9de283`.
- `scripts/run_p0_013_qos_experiment_smoke.sh` ran 8 scenarios across 100Hz/200Hz, BestEffort/Reliable, and KeepLast depth 10/50.
- Results are written to `runtime/results/qos/p0_013_qos_results.csv` and `runtime/results/qos/p0_013_qos_report.md`.
- Generated per-scenario YAML stays under `runtime/tmp/p0-013/configs/`; launch logs stay under `runtime/logs/qos/`.
- P0-013 evidence shows 100Hz and 200Hz Reliable runs tracking the target rate closely, while 200Hz BestEffort produced nonzero drop-rate and one high p99-latency run that should feed P0-014 pressure analysis.

## Technical Constraints

- Use project-local runtime results directory.
- Do not require GUI tools.
- Do not make 500Hz or 1000Hz stability a P0 pass condition.

## Acceptance Criteria

- Experiments cover 100Hz, 200Hz, 500Hz, and 1000Hz.
- Experiments compare Reliable and BestEffort where applicable.
- Experiments compare KeepLast depths where applicable.
- Subscriber sleep raises p95 and p99 latency.
- Random drops raise drop count and drop rate.
- QoS mismatch is reproduced and explained.
- CSV output includes enough columns for later charting.
- System metrics are recorded alongside communication metrics where practical.

## Verification Commands

- `ros2 launch <package> <experiment_launch>`
- `ros2 topic hz <topic>`
- `ros2 topic info <topic>`
- Script command for generating CSV results.

## Runtime Artifact Location

Store CSV, logs, and bags under project-local runtime directories.

## Cleanup and Rollback

Cleanup experiment outputs only under project-local runtime directories. Document any stress tools used and how they were stopped.

## Interview Artifact Questions

- When should Reliable be preferred over BestEffort?
- Why can queue depth increase latency?
- What did 500Hz and 1000Hz reveal about bottlenecks?

## Out of Scope

- TensorRT.
- Real sensor drivers.
- Full dashboard.
