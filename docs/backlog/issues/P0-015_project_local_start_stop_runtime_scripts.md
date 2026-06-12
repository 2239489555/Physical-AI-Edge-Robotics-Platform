# P0-015 Project-local Start And Stop Runtime Scripts

Type: AFK

Status: completed, Jetson verified 2026-06-12

User stories covered: 3, 11, 13, 16, 21

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create project-local scripts that start and stop the P0 pipeline without installing global services or leaving unmanaged background processes.

## Acceptance criteria

- [x] Start script launches the P0 pipeline with the documented config.
- [x] Stop script stops only processes started by the project script.
- [x] Scripts write logs under project-local runtime logs.
- [x] Scripts clearly report missing ROS environment or workspace setup.
- [x] Scripts do not install systemd services, modify shell rc files, or write to global log directories.
- [x] README documents normal use and known limitations.

## Implementation notes

- `scripts/start_runtime.sh` launches `fake_sensor_adapter`, `sensor_processor`, `system_metrics_node`, and `health_monitor`.
- `scripts/stop_runtime.sh` reads only `runtime/run/p0_runtime/manifest.tsv` and stops only recorded process trees.
- Runtime process metadata is stored under `runtime/run/p0_runtime/`.
- Runtime logs are stored under `runtime/logs/runtime/`.
- `scripts/run_p0_015_runtime_lifecycle_smoke.sh` builds the P0 packages, starts runtime, checks ROS nodes and topics, receives one health message, stops runtime, and verifies all manifest PIDs stopped.
- `docs/runbooks/runtime_lifecycle.md` documents normal use and known limitations.

## Jetson verification evidence

Returned P0-015 smoke evidence from Jetson HEAD `2fe7a64` completed with `SMOKE_EXIT_STATUS=0`, no timeout after about 31 seconds, and no residual `fake_sensor_adapter`, `sensor_processor`, `system_metrics_node`, `health_monitor`, runtime scripts, or related launch processes.

The returned report showed:

- `colcon build` passed for `edge_reliability_msgs`, `edge_reliability_fake_sensor`, `edge_reliability_processor`, `edge_reliability_system`, and `edge_reliability_health`.
- `colcon test` passed with 9 tests, 0 errors, 0 failures, and 0 skipped.
- `scripts/start_runtime.sh` and `scripts/stop_runtime.sh` both exited with status 0.
- Runtime nodes were present: `/fake_sensor_adapter`, `/sensor_processor`, `/system_metrics_node`, and `/health_monitor`.
- Runtime topics were present: `/edge/sensors/fake_primary`, `/edge/metrics/pipeline`, `/edge/metrics/system`, and `/edge/health/state`.
- Health state echo returned `state: 0` with reason `healthy: pipeline and system metrics within thresholds`.
- `runtime/run/p0_runtime/status.txt` ended at `status=stopped` with `stop_failed=0`.
- Manifest PID checks reported all four project-started process trees stopped.

## Blocked by

- P0-012

## Verification commands

- `bash scripts/start_runtime.sh`
- `bash scripts/stop_runtime.sh`
- `bash scripts/run_p0_015_runtime_lifecycle_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_015_runtime_scripts.ps1`
- `ros2 node list`
- Inspect `runtime/logs/`.

## Runtime artifact location

`runtime/logs/runtime/`, `runtime/run/p0_runtime/`

## Cleanup and rollback

Stop all project-started processes. Delete runtime logs only if requested or through dry-run-reviewed cleanup.

## Out of scope

- Permanent systemd service installation.
- Docker runtime.
