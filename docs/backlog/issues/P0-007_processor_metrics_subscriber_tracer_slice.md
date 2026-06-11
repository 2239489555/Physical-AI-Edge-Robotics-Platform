# P0-007 Processor Metrics Subscriber Tracer Slice

Type: AFK

Status: completed, Jetson verified on 2026-06-11

User stories covered: 4, 6, 7, 10, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Add a C++ processor subscriber that consumes fake sensor samples and publishes observable pipeline metrics.

## Implementation notes

- Package: `ros2_ws/src/edge_reliability_processor`.
- Node: `sensor_processor`.
- Input topic: `/edge/sensors/fake_primary`.
- Output topic: `/edge/metrics/pipeline`.
- Metric logic is isolated in `PipelineMetricsAccumulator` so sequence gaps, out-of-order samples, rate, and latency can be tested without ROS graph timing.
- Completion requires returned Jetson smoke evidence from `scripts/run_p0_007_processor_smoke.sh`.

## Acceptance criteria

- [x] Processor subscribes to the fake sensor topic using configurable QoS.
- [x] Processor computes receive rate and sequence continuity.
- [x] Processor computes avg latency, p95 latency, and p99 latency over a documented window.
- [x] Processor publishes metrics to a documented metrics topic.
- [x] Pure metric logic is unit-testable or isolated enough for tests.
- [x] Interface contract and README are updated with metric fields and units.

## Blocked by

- P0-006

## Verification commands

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_007_processor_metrics_slice.ps1`
- `colcon build`
- `colcon test --packages-select edge_reliability_processor`
- `bash scripts/run_p0_007_processor_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_007_smoke_report.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_007_completion_gate.ps1`
- `ros2 launch edge_reliability_processor processor.launch.py`
- `ros2 topic echo /edge/metrics/pipeline edge_reliability_msgs/msg/PipelineMetrics`
- best-effort sensor frequency probe inside `scripts/run_p0_007_processor_smoke.sh`

## Implementation evidence

- Local static gate: `scripts/verify_p0_007_processor_metrics_slice.ps1`.
- Package path: `ros2_ws/src/edge_reliability_processor`.
- Runtime input topic: `/edge/sensors/fake_primary`.
- Runtime output topic: `/edge/metrics/pipeline`.
- Runtime output type: `edge_reliability_msgs/msg/PipelineMetrics`.
- Metric accumulator test: `ros2_ws/src/edge_reliability_processor/test/pipeline_metrics_accumulator_test.cpp`.
- Jetson smoke script: `scripts/run_p0_007_processor_smoke.sh`.
- Returned-report verifier: `scripts/verify_p0_007_smoke_report.ps1`.
- Completion gate: `scripts/verify_p0_007_completion_gate.ps1`.

## Jetson verification evidence

Verified on Jetson on 2026-06-11 with `SMOKE_EXIT_STATUS=0`.

- Build: `colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor --symlink-install` completed with `Summary: 3 packages finished [1.61s]`.
- Unit tests: `colcon test --packages-select edge_reliability_processor` completed with `Summary: 3 tests, 0 errors, 0 failures, 0 skipped`.
- Launch: `fake_sensor_adapter` and `sensor_processor` both started; processor logs included `event=startup`, `event=first_receive`, and `event=first_metrics_publish`.
- Topics: `/edge/sensors/fake_primary` published `edge_reliability_msgs/msg/SensorSample`; `/edge/metrics/pipeline` published `edge_reliability_msgs/msg/PipelineMetrics` from `sensor_processor`.
- Metrics echo: `received_count: 700`, `expected_count: 700`, `dropped_count: 0`, `out_of_order_count: 0`, `receive_rate_hz: 100.0027183138903`, `expected_rate_hz: 100.0`, `average_latency_ms: 0.18729719428571412`, `p95_latency_ms: 0.378961`, and `p99_latency_ms: 0.480782`.
- Rate: sensor probe measured `average rate: 100.003` over 1001 samples in a 10.000s window; metrics probe measured `average rate: 1.000` over 6 samples in a 5.001s window.
- Rosbag: `runtime/bags/p0-007/processor_smoke_20260611T015104Z` recorded 772 messages: 764 sensor messages and 8 pipeline metrics messages.
- Runtime hygiene: only ignored `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/` outputs were produced.
- Follow-up hardening: the smoke script cleanup was changed to bounded INT/TERM/KILL shutdown after a manual run reported launch cleanup could hang.
- Cleanup recheck: after pulling the hardened script, `timeout 120s bash scripts/run_p0_007_processor_smoke.sh` finished normally in about 50 seconds with `SMOKE_EXIT_STATUS=0`, clean launch shutdown logs, no `fake_sensor_adapter` or `sensor_processor` residual processes, and a fresh rosbag at `runtime/bags/p0-007/processor_smoke_20260611T020959Z` with 772 messages.

## Runtime artifact location

`runtime/results/` for optional small metric samples.

## Cleanup and rollback

Remove only generated runtime results, logs, bags, and ROS 2 build outputs.

## Out of scope

- Health state decisions.
- Fault injection.
- Jetson tegrastats.
