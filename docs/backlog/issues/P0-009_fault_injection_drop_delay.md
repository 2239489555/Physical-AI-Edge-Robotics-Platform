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

## Implementation notes

- `ros2_ws/src/edge_reliability_fake_sensor/config/fake_sensor_drop.yaml` enables deterministic random drops with `fault_mode: "drop"`, `drop_enabled: true`, `drop_probability: 0.2`, and `drop_seed: 42`.
- `ros2_ws/src/edge_reliability_processor/config/processor_delay.yaml` enables subscriber delay with `processing_delay_enabled: true` and `processing_delay_ms: 8.0`.
- `scripts/run_p0_009_fault_injection_smoke.sh` is the Jetson evidence script. It compares normal, drop-fault, and subscriber-delay scenarios and records fault bags under `runtime/bags/p0-009`.
- `scripts/verify_p0_009_smoke_report.ps1` validates the returned report before the issue can be marked complete.
- Completion requires returned Jetson smoke evidence with `PASS/FAIL: PASS`.

## Blocked by

- P0-007

## Verification commands

- `bash scripts/run_p0_009_fault_injection_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_009_smoke_report.ps1 -ReportPath runtime\results\p0_009_smoke_report.txt`
- `ros2 bag info <fault_bag_dir>`
- `ros2 bag play <fault_bag_dir>`

## Runtime artifact location

`runtime/bags/`, `runtime/results/`, `runtime/logs/`

## Cleanup and rollback

Delete only fault-run artifacts under runtime directories.

## Out of scope

- QoS mismatch experiments.
- CPU pressure experiments.
- Health-state integration.
