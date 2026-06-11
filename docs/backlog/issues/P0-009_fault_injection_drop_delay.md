# P0-009 Fault Injection For Drop And Subscriber Delay

Type: AFK

Status: completed, Jetson verified on 2026-06-11

User stories covered: 7, 16, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Introduce controlled fault injection for random dropped samples and subscriber delay so the pipeline can demonstrate abnormal behavior.

## Acceptance criteria

- [x] Random drop injection can be enabled and configured through YAML.
- [x] Subscriber sleep or processing delay can be enabled and configured through YAML.
- [x] Drop injection increases drop count and drop rate in metrics.
- [x] Subscriber delay increases p95 and p99 latency.
- [x] Fault scenarios can be recorded and replayed with rosbag.
- [x] Test report includes normal vs fault metric comparison.

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

## Implementation evidence

- Drop config: `ros2_ws/src/edge_reliability_fake_sensor/config/fake_sensor_drop.yaml`.
- Delay config: `ros2_ws/src/edge_reliability_processor/config/processor_delay.yaml`.
- Jetson smoke script: `scripts/run_p0_009_fault_injection_smoke.sh`.
- Returned-report verifier: `scripts/verify_p0_009_smoke_report.ps1`.
- Completion gate: `scripts/verify_p0_009_completion_gate.ps1`.
- Fault bag root: `runtime/bags/p0-009`.

## Jetson verification evidence

Verified on Jetson on 2026-06-11 with `SMOKE_EXIT_STATUS=0`; `timeout 240s` did not trigger and no residual fake sensor, processor, launch, or rosbag processes remained.

- Build: `colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor --symlink-install` completed with `Summary: 3 packages finished [22.4s]`.
- Unit tests: `colcon test --packages-select edge_reliability_processor` completed with `Summary: 3 tests, 0 errors, 0 failures, 0 skipped`.
- Normal scenario: 1400 received of 1400 expected, `drop_rate: 0.000000`, `receive_rate_hz: 99.996`, `p95_latency_ms: 0.580`, `p99_latency_ms: 0.635`.
- Drop fault scenario: 1212 received of 1500 expected, 288 dropped, `drop_rate: 0.192000`, drop-rate increase `0.192000`, and bag `runtime/bags/p0-009/drop_fault_20260611T054410Z` contained 784 messages across sensor and metrics topics.
- Delay fault scenario: 1500 received of 1500 expected, zero drops, `p95_latency_ms: 8.436`, `p99_latency_ms: 8.624`, p95 latency increase `7.856ms`, and bag `runtime/bags/p0-009/subscriber_delay_20260611T054410Z` contained 938 messages across sensor and metrics topics.
- Local report verification passed with `scripts/verify_p0_009_smoke_report.ps1` against the returned Jetson report.

## Runtime artifact location

`runtime/bags/`, `runtime/results/`, `runtime/logs/`

## Cleanup and rollback

Delete only fault-run artifacts under runtime directories.

## Out of scope

- QoS mismatch experiments.
- CPU pressure experiments.
- Health-state integration.
