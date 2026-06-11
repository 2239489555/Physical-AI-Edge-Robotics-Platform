# P0-010 Health Monitor With Configurable Thresholds

Type: AFK

Status: completed, Jetson verified on 2026-06-11

User stories covered: 5, 7, 10, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Add a C++ health monitor that turns pipeline metrics into healthy, warning, or unhealthy states using configurable thresholds.

## Acceptance criteria

- [x] Health monitor subscribes to pipeline metrics.
- [x] Health thresholds for receive rate, drop rate, p95 latency, and p99 latency are YAML-configurable.
- [x] Health monitor publishes health state and reason fields.
- [x] Normal 100Hz run remains healthy under P0 thresholds.
- [x] Drop and delay faults move health to warning or unhealthy.
- [x] Health rules are unit-tested or otherwise isolated for automated testing.

## Implementation notes

- `ros2_ws/src/edge_reliability_health` owns the P0-010 `health_monitor` node and isolated health rules.
- `ros2_ws/src/edge_reliability_health/include/edge_reliability_health/health_rules.hpp` evaluates `PipelineMetrics`-like inputs without ROS graph timing.
- `ros2_ws/src/edge_reliability_health/config/health_monitor.yaml` defines configurable thresholds for receive rate, drop rate, p95 latency, and p99 latency.
- `scripts/run_p0_010_health_monitor_smoke.sh` compares normal, drop-fault, and subscriber-delay scenarios against `/edge/health/state`.
- Completion requires returned Jetson smoke evidence with `PASS/FAIL: PASS`.

## Blocked by

- P0-009

## Verification commands

- `colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor edge_reliability_health --symlink-install`
- `colcon test --packages-select edge_reliability_health`
- `ros2 launch edge_reliability_health health_monitor.launch.py`
- `ros2 topic echo --once /edge/health/state edge_reliability_msgs/msg/HealthState`
- `bash scripts/run_p0_010_health_monitor_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_010_smoke_report.ps1 -ReportPath runtime\results\p0_010_smoke_report.txt`

## Implementation evidence

- Health package: `ros2_ws/src/edge_reliability_health`.
- Rule engine: `ros2_ws/src/edge_reliability_health/include/edge_reliability_health/health_rules.hpp`.
- ROS node: `ros2_ws/src/edge_reliability_health/src/health_monitor.cpp`.
- Threshold config: `ros2_ws/src/edge_reliability_health/config/health_monitor.yaml`.
- Launch file: `ros2_ws/src/edge_reliability_health/launch/health_monitor.launch.py`.
- Jetson smoke script: `scripts/run_p0_010_health_monitor_smoke.sh`.
- Returned-report verifier: `scripts/verify_p0_010_smoke_report.ps1`.
- Completion gate: `scripts/verify_p0_010_completion_gate.ps1`.

## Jetson verification evidence

Verified on Jetson on 2026-06-11 with `SMOKE_EXIT_STATUS=0`; `timeout 260s` did not trigger and no residual fake sensor, processor, health monitor, launch, or rosbag processes remained.

- Build: `colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor edge_reliability_health --symlink-install` completed with `Summary: 4 packages finished [15.2s]` after the warning-clean fix.
- Build hygiene: final build tail was clean with no `package had stderr output` and no `%d`/`%ld` format warning.
- Unit tests: the smoke script completed its `colcon test` stage and the earlier full returned report showed `Summary: 6 tests, 0 errors, 0 failures, 0 skipped`.
- Normal scenario: `/edge/health/state` ended in `HEALTHY`.
- Drop fault scenario: `/edge/health/state` ended in `UNHEALTHY` with `drop_rate_unhealthy` active in the full report.
- Delay fault scenario: `/edge/health/state` ended in `WARNING` with `p95_latency_warning` active in the full report.
- Runtime hygiene: only ignored `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/` outputs were produced.

## Runtime artifact location

`runtime/results/` for health samples and reports.

## Cleanup and rollback

Delete generated health samples only.

## Out of scope

- Jetson CPU, RAM, temperature, or GPU health.
- Runtime scripts.
