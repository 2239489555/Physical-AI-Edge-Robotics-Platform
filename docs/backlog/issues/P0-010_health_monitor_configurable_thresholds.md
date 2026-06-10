# P0-010 Health Monitor With Configurable Thresholds

Type: AFK

User stories covered: 5, 7, 10, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Add a C++ health monitor that turns pipeline metrics into healthy, warning, or unhealthy states using configurable thresholds.

## Acceptance criteria

- [ ] Health monitor subscribes to pipeline metrics.
- [ ] Health thresholds for receive rate, drop rate, p95 latency, and p99 latency are YAML-configurable.
- [ ] Health monitor publishes health state and reason fields.
- [ ] Normal 100Hz run remains healthy under P0 thresholds.
- [ ] Drop and delay faults move health to warning or unhealthy.
- [ ] Health rules are unit-tested or otherwise isolated for automated testing.

## Blocked by

- P0-009

## Verification commands

- `colcon build`
- Unit test command for health rules.
- `ros2 launch <package> <launch_file>`
- `ros2 topic echo <health_topic>`

## Runtime artifact location

`runtime/results/` for health samples and reports.

## Cleanup and rollback

Delete generated health samples only.

## Out of scope

- Jetson CPU, RAM, temperature, or GPU health.
- Runtime scripts.
