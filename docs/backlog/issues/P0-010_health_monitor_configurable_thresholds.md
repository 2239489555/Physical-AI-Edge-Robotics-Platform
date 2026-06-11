# P0-010 Health Monitor With Configurable Thresholds

Type: AFK

User stories covered: 5, 7, 10, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Add a C++ health monitor that turns pipeline metrics into healthy, warning, or unhealthy states using configurable thresholds.

## Acceptance criteria

- [ ] Health monitor subscribes to pipeline metrics.
- [ ] Health thresholds for receive rate, drop rate, p95 latency, and p99 latency are YAML-configurable.
- [ ] Health monitor publishes health state and reason fields.
- [ ] Normal 100Hz run remains healthy under P0 thresholds.
- [ ] Drop and delay faults move health to warning or unhealthy.
- [ ] Health rules are unit-tested or otherwise isolated for automated testing.

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

## Runtime artifact location

`runtime/results/` for health samples and reports.

## Cleanup and rollback

Delete generated health samples only.

## Out of scope

- Jetson CPU, RAM, temperature, or GPU health.
- Runtime scripts.
