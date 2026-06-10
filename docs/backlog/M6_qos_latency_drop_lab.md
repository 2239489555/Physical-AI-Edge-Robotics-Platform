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
