# P2-002 Isaac ROS Lightweight Acceleration Comparison

Type: AFK

User stories covered: 5, 14, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Run one lightweight Isaac ROS demo or comparison and document what acceleration or NITROS-style workflow contributes relative to the plain ROS 2 pipeline.

## Acceptance criteria

- [ ] One lightweight Isaac ROS package or demo is attempted.
- [ ] Plain ROS 2 baseline and Isaac ROS result are compared where possible.
- [ ] Report records FPS, latency, CPU, GPU indicator, RAM, temperature, and setup friction.
- [ ] Report explains what Isaac ROS solves and what complexity it adds.
- [ ] If demo fails, failure is documented with logs and next steps.
- [ ] Isaac ROS remains P2 and does not become a P0/P1 blocker.

## Blocked by

- P2-001

## Verification commands

- Selected Isaac ROS demo commands.
- `ros2 topic list`
- `ros2 topic hz <topic>`
- `tegrastats`

## Runtime artifact location

`runtime/results/isaac_ros/`, `runtime/logs/isaac_ros/`

## Cleanup and rollback

Stop containers or nodes started by the demo. Remove project-local logs and results by default.

## Out of scope

- Building a production Isaac ROS stack.
- Isaac Sim.
