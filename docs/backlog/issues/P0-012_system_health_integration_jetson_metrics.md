# P0-012 System Health Integration For Jetson Metrics

Type: AFK

Status: implementation prepared, awaiting Jetson smoke evidence

User stories covered: 5, 7, 10, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Extend health monitoring so Jetson CPU, RAM, disk, temperature, and GPU-related signals can affect system health alongside pipeline metrics.

## Acceptance criteria

- [x] Health monitor subscribes to system metrics from the tegrastats node.
- [x] System thresholds are YAML-configurable.
- [x] Health output includes reason codes for pipeline and system warnings.
- [x] CPU, RAM, disk, or temperature threshold crossings can move health to warning or unhealthy.
- [ ] Test report includes at least one simulated or real threshold crossing.
- [x] Interface contract documents system health rules and units.

## Implementation notes

- `edge_reliability_msgs/msg/SystemMetrics` now includes `disk_used_mb`, `disk_total_mb`, and `disk_used_percent`.
- `system_metrics_node` samples disk usage through the configured `disk_path` while keeping tegrastats as the source for CPU, RAM, GPU, temperature, and power.
- `health_monitor` subscribes to `/edge/metrics/pipeline` and `/edge/metrics/system`, combines the latest rule evaluations, and publishes the highest severity on `/edge/health/state`.
- Default system thresholds live in `ros2_ws/src/edge_reliability_health/config/health_monitor.yaml`.
- `ros2_ws/src/edge_reliability_health/config/health_monitor_system_nominal.yaml` relaxes pipeline thresholds for deterministic P0-012 system-health smoke verification.
- `ros2_ws/src/edge_reliability_health/config/health_monitor_system_pressure.yaml` intentionally lowers temperature and power thresholds for deterministic P0-012 smoke verification.
- `scripts/run_p0_012_system_health_smoke.sh` runs default healthy and system-pressure scenarios and writes the report to `runtime/results/p0_012_smoke_report.txt`.
- Completion requires returned Jetson smoke evidence with `PASS/FAIL: PASS`.

## Blocked by

- P0-010
- P0-011

## Verification commands

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_012_system_health.ps1`
- `colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor edge_reliability_system edge_reliability_health --symlink-install`
- `colcon test --packages-select edge_reliability_processor edge_reliability_system edge_reliability_health`
- `ros2 topic echo --once /edge/metrics/system edge_reliability_msgs/msg/SystemMetrics`
- `ros2 topic echo --once /edge/health/state edge_reliability_msgs/msg/HealthState`
- `bash scripts/run_p0_012_system_health_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_012_smoke_report.ps1 -ReportPath runtime\results\p0_012_smoke_report.txt`

## Runtime artifact location

`runtime/results/`, `runtime/logs/`

## Cleanup and rollback

Remove only generated result and log files.

## Out of scope

- Automatic process recovery.
- systemd service installation.
