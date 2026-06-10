# P0-009 Fault Injection For Drop And Subscriber Delay

Type: AFK

User stories covered: 7, 16, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Introduce controlled fault injection for random dropped samples and subscriber delay so the pipeline can demonstrate abnormal behavior.

## Acceptance criteria

- [ ] Random drop injection can be enabled and configured through YAML.
- [ ] Subscriber sleep or processing delay can be enabled and configured through YAML.
- [ ] Drop injection increases drop count and drop rate in metrics.
- [ ] Subscriber delay increases p95 and p99 latency.
- [ ] Fault scenarios can be recorded and replayed with rosbag.
- [ ] Test report includes normal vs fault metric comparison.

## Blocked by

- P0-007

## Verification commands

- `colcon build`
- `ros2 launch <package> <fault_config_launch>`
- `ros2 topic echo <metrics_topic>`
- `ros2 bag record <topics>`
- `ros2 bag play <fault_bag_dir>`

## Runtime artifact location

`runtime/bags/`, `runtime/results/`, `runtime/logs/`

## Cleanup and rollback

Delete only fault-run artifacts under runtime directories.

## Out of scope

- QoS mismatch experiments.
- CPU pressure experiments.
- Health-state integration.
