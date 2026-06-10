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

## Blocked by

- P0-002
- P0-003

## Verification commands

- Parser unit test command.
- `tegrastats`
- `ros2 launch <package> <launch_file>`
- `ros2 topic echo <system_metrics_topic>`

## Runtime artifact location

`runtime/logs/tegrastats/`

## Cleanup and rollback

Stop any tegrastats process started by this task. Remove only project-local tegrastats logs.

## Out of scope

- TensorRT inference.
- Docker/systemd service installation.
