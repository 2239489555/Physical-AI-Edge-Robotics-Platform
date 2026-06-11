# M3 Fake Sensor Pipeline

## Goal

Build a 100Hz C++ ROS 2 fake sensor pipeline that resembles a real robotics data stream.

## Context

The project has no real sensors. The fake sensor must still train real concepts: timestamp, sequence continuity, publish rate, receive rate, latency, drop detection, parameters, QoS, launch, and rosbag.

## Inputs

- ROS 2 Humble baseline from M2.
- Stable topic naming and message contract from `docs/interfaces/edge_reliability_contract.md`.
- Message package `ros2_ws/src/edge_reliability_msgs`.

## Expected Outputs

- Fake sensor publisher.
- Processor subscriber.
- Launch files.
- YAML config.
- Interface contract.
- Test report.
- Debug guide.
- Interview artifacts.

## Current Progress

- P0-006 fake sensor publisher is completed and Jetson verified on 2026-06-11.
- `ros2_ws/src/edge_reliability_fake_sensor` publishes `/edge/sensors/fake_primary` as `edge_reliability_msgs/msg/SensorSample`.
- Jetson smoke evidence passed with `SMOKE_EXIT_STATUS=0`, 99.998Hz measured rate, one valid echoed sample, and a short rosbag containing 765 messages.
- Local completion verification passes with `scripts/verify_p0_006_completion_gate.ps1` against the returned Jetson smoke report.
- Remaining M3 work starts at P0-007 for processor metrics, receive rate, sequence continuity, latency, and drop detection.

## Technical Constraints

- Core runtime nodes use C++17 and rclcpp.
- Parameters must be YAML-configurable.
- Runtime outputs stay under the project workspace.
- No real hardware dependency.

## Acceptance Criteria

- Default publish frequency is 100Hz.
- Messages include timestamp, sequence ID, sensor ID, value, and status.
- Processor computes receive rate and sequence continuity.
- rosbag can record and replay the raw sensor topic.
- Pipeline runs for 10 minutes without crashing.
- Runtime artifacts are organized under the project workspace.

## Verification Commands

- `colcon build`
- `ros2 launch <package> <launch_file>`
- `ros2 topic hz <sensor_topic>`
- `ros2 topic echo <sensor_topic>`
- `ros2 bag record <sensor_topic>`
- `ros2 bag play <bag_dir>`

## Runtime Artifact Location

Store bags, logs, and results under project-local runtime directories.

## Cleanup and Rollback

Cleanup only project-local bags, logs, and build outputs unless explicitly instructed otherwise.

## Interview Artifact Questions

- Why does fake data still teach real robotics reliability concepts?
- Which part becomes a hardware adapter later?
- What evidence proves the pipeline is stable?

## Out of Scope

- Camera images.
- TensorRT.
- Nav2.
- HTML dashboard.
