# P0-006 100Hz Fake Sensor Publisher Tracer Slice

Type: AFK

Status: completed, Jetson verified on 2026-06-11

User stories covered: 4, 6, 8, 9, 16, 24

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Implement the first real P0 data-source tracer slice: a C++ rclcpp fake sensor publisher that emits robotics-style samples at a configurable frequency.

## Acceptance criteria

- [x] Fake sensor node publishes at 100Hz by default.
- [x] Message includes timestamp, sequence ID, sensor ID, value, and status or equivalent contract fields.
- [x] Frequency, sensor ID, topic name, QoS profile, and fault-off defaults are YAML-configurable.
- [x] Launch file starts the node with config.
- [x] README shows how to inspect frequency and message contents.
- [x] Node writes structured logs useful for debugging startup and parameter loading.

## Blocked by

- P0-005

## Verification commands

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_006_fake_sensor_slice.ps1`
- `bash scripts/run_p0_006_fake_sensor_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_006_smoke_report.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_006_completion_gate.ps1`
- `colcon build`
- `ros2 launch <package> <launch_file>`
- `ros2 topic echo <sensor_topic>`
- best-effort frequency probe inside `scripts/run_p0_006_fake_sensor_smoke.sh`

## Implementation evidence

- Local static gate: `scripts/verify_p0_006_fake_sensor_slice.ps1`.
- Package path: `ros2_ws/src/edge_reliability_fake_sensor`.
- Runtime topic: `/edge/sensors/fake_primary`.
- Runtime type: `edge_reliability_msgs/msg/SensorSample`.
- Jetson smoke script: `scripts/run_p0_006_fake_sensor_smoke.sh`.
- Returned-report verifier: `scripts/verify_p0_006_smoke_report.ps1`.
- Completion gate: `scripts/verify_p0_006_completion_gate.ps1`.

## Jetson verification evidence

Verified on Jetson on 2026-06-11 with `SMOKE_EXIT_STATUS=0`.

- Build: `colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor --symlink-install` completed with `Summary: 2 packages finished [1.36s]`.
- Launch: `ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py` started `fake_sensor_adapter` and logged `event=startup` plus `event=first_publish`.
- Topic: `/edge/sensors/fake_primary` published `edge_reliability_msgs/msg/SensorSample` with publisher node `fake_sensor_adapter` and BEST_EFFORT QoS.
- Echo: sample included `header.stamp`, `frame_id: fake_sensor_frame`, `sequence_id: 604`, `sensor_id: fake_primary`, `value: 0.604`, `status: 0`, and `status_detail: ok`.
- Rate: best-effort probe measured `average rate: 99.998` over 1001 samples in a 10.000s window.
- Rosbag: `runtime/bags/p0-006/fake_sensor_smoke_20260611T002906Z` recorded 765 messages on `/edge/sensors/fake_primary`.
- Runtime hygiene: only ignored `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/` outputs were produced.
- Local returned-report gate: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_006_completion_gate.ps1` passed against the returned Jetson smoke report.

## Runtime artifact location

`runtime/logs/` for node logs if logs are redirected.

## Cleanup and rollback

Remove runtime logs only. Do not remove source unless rolling back the issue.

## Out of scope

- Subscriber metrics.
- Fault injection.
- rosbag workflow.
