# P0-015 Project-local Start And Stop Runtime Scripts

Type: AFK

User stories covered: 3, 11, 13, 16, 21

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create project-local scripts that start and stop the P0 pipeline without installing global services or leaving unmanaged background processes.

## Acceptance criteria

- [ ] Start script launches the P0 pipeline with the documented config.
- [ ] Stop script stops only processes started by the project script.
- [ ] Scripts write logs under project-local runtime logs.
- [ ] Scripts clearly report missing ROS environment or workspace setup.
- [ ] Scripts do not install systemd services, modify shell rc files, or write to global log directories.
- [ ] README documents normal use and known limitations.

## Blocked by

- P0-012

## Verification commands

- `scripts/start.sh` or platform equivalent.
- `scripts/stop.sh` or platform equivalent.
- `ros2 node list`
- Inspect `runtime/logs/`.

## Runtime artifact location

`runtime/logs/`

## Cleanup and rollback

Stop all project-started processes. Delete runtime logs only if requested or through dry-run-reviewed cleanup.

## Out of scope

- Permanent systemd service installation.
- Docker runtime.
