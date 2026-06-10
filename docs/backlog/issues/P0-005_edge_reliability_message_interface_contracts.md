# P0-005 Edge Reliability Message And Interface Contracts

Status: completed

Type: AFK

User stories covered: 4, 6, 9, 10, 16, 24

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Define the stable ROS 2 topic and message contracts for the P0 reliability lab so fake, replayed, and future real hardware inputs can use the same core pipeline.

## Acceptance criteria

- [x] Message package or documented standard-message mapping exists for sensor sample, pipeline metrics, system metrics, and health state.
- [x] Interface contract documents node names, published topics, subscribed topics, message types, QoS, parameters, logs, metrics, health rules, rosbag topics, and failure modes.
- [x] Contracts distinguish adapter nodes from processor, metrics, health, and runtime nodes.
- [x] Future adapter examples include USB camera, CSI camera, LiDAR, IMU, odometry, and base driver boundaries.
- [x] Contracts are stable enough for subsequent tasks to implement against them.

## Implementation evidence

- Added message package: `ros2_ws/src/edge_reliability_msgs`.
- Added custom messages: `SensorSample`, `PipelineMetrics`, `SystemMetrics`, and `HealthState`.
- Added interface contract: `docs/interfaces/edge_reliability_contract.md`.
- Contract defines topics `/edge/sensors/fake_primary`, `/edge/metrics/pipeline`, `/edge/metrics/system`, and `/edge/health/state`.
- Contract documents adapter, processor, metrics, health, and runtime boundaries.
- Contract includes future adapter boundaries for USB camera, CSI camera, LiDAR, IMU, odometry, and base driver.
- Added local verifier: `scripts/verify_p0_005_interface_contracts.ps1`.
- Local verifier passed: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_005_interface_contracts.ps1`.

## Jetson verification evidence

- Jetson `colcon build --packages-select edge_reliability_msgs --symlink-install` completed with `Summary: 1 package finished [10.1s]`.
- `ros2 interface show edge_reliability_msgs/msg/SensorSample` showed `STATUS_OK`, `STATUS_WARN`, `STATUS_ERROR`, `std_msgs/Header header`, `sequence_id`, `sensor_id`, `value`, `status`, and `status_detail`.
- `ros2 interface show edge_reliability_msgs/msg/PipelineMetrics` showed received, expected, dropped, out-of-order, rate, latency, p95, p99, and drop-rate fields.
- `ros2 interface show edge_reliability_msgs/msg/SystemMetrics` showed CPU, memory, GPU, temperature, power, and source fields.
- `ros2 interface show edge_reliability_msgs/msg/HealthState` showed `HEALTHY`, `WARNING`, `UNHEALTHY`, `state`, `reason`, and `active_rules`.
- `git status --short --ignored` showed generated ROS build outputs and runtime artifacts ignored: `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/`.

## Blocked by

- P0-003

## Verification commands

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_005_interface_contracts.ps1`
- `colcon build --packages-select edge_reliability_msgs --symlink-install`
- `ros2 interface show edge_reliability_msgs/msg/SensorSample`
- `ros2 interface show edge_reliability_msgs/msg/PipelineMetrics`
- `ros2 interface show edge_reliability_msgs/msg/SystemMetrics`
- `ros2 interface show edge_reliability_msgs/msg/HealthState`
- Manual review of interface contract completeness.

## Runtime artifact location

No bulky runtime artifacts expected.

## Cleanup and rollback

Remove only message package or contract files created by this issue if rolling back.

## Out of scope

- Implementing fake sensor logic.
- Implementing health rules.
