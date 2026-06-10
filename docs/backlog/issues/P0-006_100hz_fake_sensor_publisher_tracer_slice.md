# P0-006 100Hz Fake Sensor Publisher Tracer Slice

Type: AFK

Status: implementation ready, Jetson verification pending

User stories covered: 4, 6, 8, 9, 16, 24

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Implement the first real P0 data-source tracer slice: a C++ rclcpp fake sensor publisher that emits robotics-style samples at a configurable frequency.

## Acceptance criteria

- [ ] Fake sensor node publishes at 100Hz by default.
- [ ] Message includes timestamp, sequence ID, sensor ID, value, and status or equivalent contract fields.
- [ ] Frequency, sensor ID, topic name, QoS profile, and fault-off defaults are YAML-configurable.
- [ ] Launch file starts the node with config.
- [ ] README shows how to inspect frequency and message contents.
- [ ] Node writes structured logs useful for debugging startup and parameter loading.

## Blocked by

- P0-005

## Verification commands

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_006_fake_sensor_slice.ps1`
- `colcon build`
- `ros2 launch <package> <launch_file>`
- `ros2 topic echo <sensor_topic>`
- `ros2 topic hz <sensor_topic>`

## Implementation evidence

- Local static gate: `scripts/verify_p0_006_fake_sensor_slice.ps1`.
- Package path: `ros2_ws/src/edge_reliability_fake_sensor`.
- Runtime topic: `/edge/sensors/fake_primary`.
- Runtime type: `edge_reliability_msgs/msg/SensorSample`.
- Jetson evidence still needed: `colcon build`, launch logs, typed topic info, one echoed sample, 100Hz frequency evidence, and short rosbag smoke evidence.

## Runtime artifact location

`runtime/logs/` for node logs if logs are redirected.

## Cleanup and rollback

Remove runtime logs only. Do not remove source unless rolling back the issue.

## Out of scope

- Subscriber metrics.
- Fault injection.
- rosbag workflow.
