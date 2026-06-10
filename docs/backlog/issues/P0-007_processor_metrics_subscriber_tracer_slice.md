# P0-007 Processor Metrics Subscriber Tracer Slice

Type: AFK

User stories covered: 4, 6, 7, 10, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Add a C++ processor subscriber that consumes fake sensor samples and publishes observable pipeline metrics.

## Acceptance criteria

- [ ] Processor subscribes to the fake sensor topic using configurable QoS.
- [ ] Processor computes receive rate and sequence continuity.
- [ ] Processor computes avg latency, p95 latency, and p99 latency over a documented window.
- [ ] Processor publishes metrics to a documented metrics topic.
- [ ] Pure metric logic is unit-testable or isolated enough for tests.
- [ ] Interface contract and README are updated with metric fields and units.

## Blocked by

- P0-006

## Verification commands

- `colcon build`
- Unit test command for metric logic.
- `ros2 launch <package> <launch_file>`
- `ros2 topic echo <metrics_topic>`
- `ros2 topic hz <sensor_topic>`

## Runtime artifact location

`runtime/results/` for optional small metric samples.

## Cleanup and rollback

Remove only generated runtime results.

## Out of scope

- Health state decisions.
- Fault injection.
- Jetson tegrastats.
