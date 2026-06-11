# P0-011 tegrastats Parser And ROS 2 System Metrics Node

Type: AFK

User stories covered: 5, 10, 12, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Implement Jetson system observability by parsing tegrastats output and publishing structured system metrics into ROS 2.

## Acceptance criteria

- [ ] Parser handles representative tegrastats sample lines from the target Jetson stack.
- [ ] Parser extracts RAM, SWAP if present, CPU per-core summary, GR3D_FREQ or equivalent GPU indicator, temperatures, and power fields where available.
- [ ] ROS 2 node publishes structured system metrics.
- [ ] Raw tegrastats logs can be saved under project-local runtime logs.
- [ ] README explains why tegrastats is primary on Jetson and nvidia-smi is not enough.
- [ ] Parser can be tested with saved sample text without requiring live tegrastats.

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

## Runtime artifact location

`runtime/logs/tegrastats/`

## Cleanup and rollback

Stop any tegrastats process started by this task. Remove only project-local tegrastats logs.

## Out of scope

- TensorRT inference.
- Docker/systemd service installation.
