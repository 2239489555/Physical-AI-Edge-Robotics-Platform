# P0-012 System Health Integration For Jetson Metrics

Type: AFK

User stories covered: 5, 7, 10, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Extend health monitoring so Jetson CPU, RAM, disk, temperature, and GPU-related signals can affect system health alongside pipeline metrics.

## Acceptance criteria

- [ ] Health monitor subscribes to system metrics from the tegrastats node.
- [ ] System thresholds are YAML-configurable.
- [ ] Health output includes reason codes for pipeline and system warnings.
- [ ] CPU, RAM, disk, or temperature threshold crossings can move health to warning or unhealthy.
- [ ] Test report includes at least one simulated or real threshold crossing.
- [ ] Interface contract documents system health rules and units.

## Blocked by

- P0-010
- P0-011

## Verification commands

- `colcon build`
- Health rule unit test command.
- `ros2 topic echo <system_metrics_topic>`
- `ros2 topic echo <health_topic>`

## Runtime artifact location

`runtime/results/`, `runtime/logs/`

## Cleanup and rollback

Remove only generated result and log files.

## Out of scope

- Automatic process recovery.
- systemd service installation.
