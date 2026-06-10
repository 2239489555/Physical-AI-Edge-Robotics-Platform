# P0-005 Edge Reliability Message And Interface Contracts

Type: AFK

User stories covered: 4, 6, 9, 10, 16, 24

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Define the stable ROS 2 topic and message contracts for the P0 reliability lab so fake, replayed, and future real hardware inputs can use the same core pipeline.

## Acceptance criteria

- [ ] Message package or documented standard-message mapping exists for sensor sample, pipeline metrics, system metrics, and health state.
- [ ] Interface contract documents node names, published topics, subscribed topics, message types, QoS, parameters, logs, metrics, health rules, rosbag topics, and failure modes.
- [ ] Contracts distinguish adapter nodes from processor, metrics, health, and runtime nodes.
- [ ] Future adapter examples include USB camera, CSI camera, LiDAR, IMU, odometry, and base driver boundaries.
- [ ] Contracts are stable enough for subsequent tasks to implement against them.

## Blocked by

- P0-003

## Verification commands

- `colcon build` if a message package is created.
- `ros2 interface show <message_type>` if custom messages are created.
- Manual review of interface contract completeness.

## Runtime artifact location

No bulky runtime artifacts expected.

## Cleanup and rollback

Remove only message package or contract files created by this issue if rolling back.

## Out of scope

- Implementing fake sensor logic.
- Implementing health rules.
