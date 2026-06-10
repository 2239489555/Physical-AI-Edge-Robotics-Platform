# P2-001 Isaac ROS 3.2 Compatibility Spike

Type: AFK

User stories covered: 5, 8, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Evaluate Isaac ROS 3.2 compatibility with the Jetson stack as a bounded P2 exploration, without letting it block P0 or P1.

## Acceptance criteria

- [ ] Compatibility notes cover JetPack, L4T, ROS 2 Humble, Docker/NVIDIA container runtime, and relevant Isaac ROS package versions.
- [ ] Setup steps are documented, including what is global vs project-local.
- [ ] Risks are recorded before running install-heavy commands.
- [ ] At least one lightweight candidate package is selected for a future demo.
- [ ] If setup is blocked, report the blocker and fallback without expanding scope.

## Blocked by

- P0-018

## Verification commands

- Selected Isaac ROS version check commands.
- Docker/NVIDIA runtime checks if used.
- `tegrastats` if running a demo.

## Runtime artifact location

`runtime/artifacts/isaac_ros_spike/`, `runtime/logs/isaac_ros/`

## Cleanup and rollback

Document all global or container changes. Do not leave long-running containers by default.

## Out of scope

- Isaac Sim.
- Making Isaac ROS a mainline dependency.
