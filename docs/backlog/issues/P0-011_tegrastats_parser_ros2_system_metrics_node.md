# P0-011 tegrastats Parser And ROS 2 System Metrics Node

Type: AFK

Status: completed, Jetson verified on 2026-06-11

User stories covered: 5, 10, 12, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Implement Jetson system observability by parsing tegrastats output and publishing structured system metrics into ROS 2.

## Acceptance criteria

- [x] Parser handles representative tegrastats sample lines from the target Jetson stack.
- [x] Parser extracts RAM, SWAP if present, CPU per-core summary, GR3D_FREQ or equivalent GPU indicator, temperatures, and power fields where available.
- [x] ROS 2 node publishes structured system metrics.
- [x] Raw tegrastats logs can be saved under project-local runtime logs.
- [x] README explains why tegrastats is primary on Jetson and nvidia-smi is not enough.
- [x] Parser can be tested with saved sample text without requiring live tegrastats.

## Implementation notes

- `ros2_ws/src/edge_reliability_system` owns the P0-011 `system_metrics_node` and tegrastats parser.
- `ros2_ws/src/edge_reliability_system/include/edge_reliability_system/tegrastats_parser.hpp` parses saved and live tegrastats lines without requiring ROS graph timing.
- `ros2_ws/src/edge_reliability_system/testdata/tegrastats_samples.txt` provides representative sample lines for unit tests and smoke tests.
- `system_metrics_node` supports `sample_file` mode for deterministic verification and `live_command` mode for bounded live tegrastats probes.
- `scripts/run_p0_011_system_metrics_smoke.sh` launches the node, verifies `/edge/metrics/system`, writes raw logs under `runtime/logs/tegrastats`, and records live tegrastats availability.
- Completion requires returned Jetson smoke evidence with `PASS/FAIL: PASS`.

## Blocked by

- P0-002
- P0-003

## Verification commands

- `colcon build --packages-select edge_reliability_msgs edge_reliability_system --symlink-install`
- `colcon test --packages-select edge_reliability_system`
- `tegrastats` or `timeout 4s tegrastats --interval 1000` if available.
- `ros2 launch edge_reliability_system system_metrics.launch.py`
- `ros2 topic echo --once /edge/metrics/system edge_reliability_msgs/msg/SystemMetrics`
- `bash scripts/run_p0_011_system_metrics_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_011_smoke_report.ps1 -ReportPath runtime\results\p0_011_smoke_report.txt`

## Implementation evidence

- System package: `ros2_ws/src/edge_reliability_system`.
- Parser: `ros2_ws/src/edge_reliability_system/include/edge_reliability_system/tegrastats_parser.hpp`.
- ROS node: `ros2_ws/src/edge_reliability_system/src/system_metrics_node.cpp`.
- Sample data: `ros2_ws/src/edge_reliability_system/testdata/tegrastats_samples.txt`.
- Jetson smoke script: `scripts/run_p0_011_system_metrics_smoke.sh`.
- Returned-report verifier: `scripts/verify_p0_011_smoke_report.ps1`.
- Completion gate: `scripts/verify_p0_011_completion_gate.ps1`.

## Jetson verification evidence

Verified on Jetson on 2026-06-11 with `SMOKE_EXIT_STATUS=0`.

- Build: `colcon build --packages-select edge_reliability_msgs edge_reliability_system --symlink-install` completed with `Summary: 2 packages finished [13.8s]`.
- Unit tests: `colcon test --packages-select edge_reliability_system` completed with `Summary: 4 tests, 0 errors, 0 failures, 0 skipped`.
- Topic: `/edge/metrics/system` was published by `system_metrics_node` as `edge_reliability_msgs/msg/SystemMetrics` with reliable QoS.
- Sample-file metrics: 6 messages were captured with `cpu_percent: 2.500`, `memory_used_mb: 3300.000`, `memory_total_mb: 62832.000`, `gpu_percent: 14.000`, `temperature_c: 42.000`, `power_w: 6.190`, and `source: tegrastats_sample_file`.
- Raw logs: `runtime/logs/tegrastats/p0_011_system_metrics_raw.log` contained 11 raw sample lines.
- Live probe: live `tegrastats` was available and produced three sample lines in `runtime/logs/tegrastats/p0_011_live_tegrastats_probe.log`.
- Runtime hygiene: only ignored `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/` outputs were produced.
- Local report verification passed with `scripts/verify_p0_011_smoke_report.ps1` against the returned Jetson report.

## Runtime artifact location

`runtime/logs/tegrastats/`

## Cleanup and rollback

Stop any tegrastats process started by this task. Remove only project-local tegrastats logs.

## Out of scope

- TensorRT inference.
- Docker/systemd service installation.
