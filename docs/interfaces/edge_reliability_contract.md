# Edge Reliability Interface Contract

Status: P0 stable contract, P0-006 through P0-011 Jetson verified

This document defines the ROS 2 interfaces for the Edge Robotics Reliability Lab. It is the implementation boundary for fake inputs, replayed bags, and future hardware adapters.

The current project has no physical robot hardware. That means the first contract must be simulation-friendly while still resembling real robot data flow.

## Message Package

Custom messages live in:

```text
ros2_ws/src/edge_reliability_msgs
```

Message types:

- `edge_reliability_msgs/msg/SensorSample`
- `edge_reliability_msgs/msg/PipelineMetrics`
- `edge_reliability_msgs/msg/SystemMetrics`
- `edge_reliability_msgs/msg/HealthState`

## Topics

| Topic | Type | Publisher | Subscribers | QoS | Purpose |
| --- | --- | --- | --- | --- | --- |
| `/edge/sensors/fake_primary` | `edge_reliability_msgs/msg/SensorSample` | `fake_sensor_adapter` | `sensor_processor`, rosbag | Sensor data QoS, keep last 10, best effort acceptable for high-rate streams | Primary fake sensor stream for P0 |
| `/edge/metrics/pipeline` | `edge_reliability_msgs/msg/PipelineMetrics` | `sensor_processor` for P0-007 | `health_monitor`, dashboards, rosbag | Reliable, keep last 10 | Rate, latency, drop, and sequence metrics |
| `/edge/metrics/system` | `edge_reliability_msgs/msg/SystemMetrics` | `system_metrics_node` | `health_monitor`, dashboards, rosbag | Reliable, keep last 10 | Jetson CPU, memory, GPU, temperature, and power metrics |
| `/edge/health/state` | `edge_reliability_msgs/msg/HealthState` | `health_monitor` | dashboards, runtime scripts, rosbag | Reliable, transient local optional, keep last 1 | Coarse health state and active rule reasons |

The existing P0-003 tracer topic `/edge/tracer` is a bootstrap topic only. New pipeline tasks should use the contracts above.

## Message Contracts

### SensorSample

Use `SensorSample` for fake, replayed, and future adapter inputs.

Required semantics:

- `header.stamp`: production time of the sample.
- `header.frame_id`: source coordinate frame or logical frame. For the fake sensor, use a stable logical value such as `fake_sensor_frame`.
- `sequence_id`: monotonically increasing per `sensor_id`.
- `sensor_id`: stable source identifier such as `fake_primary`.
- `value`: scalar sample value used by the P0 fake pipeline.
- `status`: one of `STATUS_OK`, `STATUS_WARN`, or `STATUS_ERROR`.
- `status_detail`: short human-readable detail for fault injection and debugging.

### PipelineMetrics

Use `PipelineMetrics` for metrics computed from `SensorSample` traffic. P0-007 publishes this message from the `sensor_processor` node.

Required semantics:

- `header.stamp`: end time of the aggregation window.
- `received_count`: total samples received since the processor node started.
- `expected_count`: `received_count + dropped_count` for the same processor run.
- `dropped_count`: sequence-gap-derived drop count when sequence tracking is active.
- `out_of_order_count`: samples where `sequence_id` moves backward or duplicates unexpectedly.
- `receive_rate_hz`: measured subscriber rate over the rolling rate window.
- `expected_rate_hz`: configured target rate.
- `average_latency_ms`: average publish-to-receive latency in milliseconds.
- `p95_latency_ms`: 95th percentile latency in milliseconds.
- `p99_latency_ms`: 99th percentile latency in milliseconds.
- `drop_rate`: dropped_count divided by expected_count.

P0-007 window definition:

- `receive_rate_hz` uses the `rate_window_seconds` parameter, defaulting to a 5 second rolling window.
- `average_latency_ms`, `p95_latency_ms`, and `p99_latency_ms` use the `latency_window_size` parameter, defaulting to the latest 1000 samples.
- Health decisions are intentionally out of scope for P0-007; the metrics topic only exposes evidence.

### SystemMetrics

Use `SystemMetrics` for Jetson runtime metrics.

Required semantics:

- `header.stamp`: sample time.
- `cpu_percent`: CPU utilization percentage.
- `memory_used_mb`: memory used in MiB.
- `memory_total_mb`: total memory in MiB.
- `gpu_percent`: GPU utilization percentage when available.
- `temperature_c`: primary thermal reading in Celsius.
- `power_w`: power draw in watts when available.
- `source`: collector source, for example `tegrastats` or `unknown`.

### HealthState

Use `HealthState` for coarse system status.

Required semantics:

- `header.stamp`: time the health state was evaluated.
- `state`: one of `HEALTHY`, `WARNING`, or `UNHEALTHY`.
- `reason`: one-line summary suitable for logs and dashboards.
- `active_rules`: health rules that contributed to the current state.

## Node Roles

### Adapter Nodes

Adapter nodes translate a source into the stable project contract. They should publish `SensorSample` or future sensor-specific contracts without embedding downstream processing logic.

Current P0 adapter:

- `fake_sensor_adapter`: publishes `/edge/sensors/fake_primary`.

Future adapter boundaries:

- USB camera adapter: owns camera device access, frame capture, and camera-specific errors.
- CSI camera adapter: owns Jetson camera pipeline access and CSI-specific configuration.
- LiDAR adapter: owns scan acquisition and LiDAR-specific status.
- IMU adapter: owns inertial sample acquisition and IMU-specific status.
- odometry adapter: owns odometry input conversion.
- base driver adapter: owns base driver communication and actuator/controller status.

Adapters must not own pipeline metrics, health state, dashboard formatting, or runtime cleanup.

### Processor And Metrics Nodes

- `sensor_processor`: subscribes to `/edge/sensors/fake_primary`, validates sequence continuity, measures latency, and publishes `/edge/metrics/pipeline` for the P0-007 vertical slice.
- `pipeline_metrics_node`: optional future split if metrics publication needs to move out of `sensor_processor`.
- `system_metrics_node`: publishes `/edge/metrics/system`.

These nodes must not own hardware access. They should work from live topics or rosbag replay.

### Health And Runtime Nodes

- `health_monitor`: subscribes to `/edge/metrics/pipeline` and `/edge/metrics/system`, then publishes `/edge/health/state`.
- Runtime scripts may start, stop, check, and collect logs, but they should not change message definitions.

## Parameters

Recommended P0 parameters:

| Node | Parameter | Default | Purpose |
| --- | --- | --- | --- |
| `fake_sensor_adapter` | `sensor_id` | `fake_primary` | Stable ID in `SensorSample.sensor_id` |
| `fake_sensor_adapter` | `frame_id` | `fake_sensor_frame` | Logical frame in `header.frame_id` |
| `fake_sensor_adapter` | `publish_hz` | `100.0` | Target fake sensor rate |
| `fake_sensor_adapter` | `status_mode` | `ok` | Fault injection status behavior |
| `fake_sensor_adapter` | `drop_enabled` | `false` | P0-009 synthetic drop injection switch |
| `fake_sensor_adapter` | `drop_probability` | `0.0` | P0-009 synthetic drop probability from 0.0 to 1.0 |
| `fake_sensor_adapter` | `drop_seed` | `1` | P0-009 deterministic random seed for repeatable drop runs |
| `sensor_processor` | `expected_hz` | `100.0` | Target rate for metrics |
| `sensor_processor` | `latency_warn_ms` | `20.0` | Warning threshold for latency |
| `sensor_processor` | `latency_unhealthy_ms` | `50.0` | Unhealthy threshold for latency |
| `sensor_processor` | `sensor_topic` | `/edge/sensors/fake_primary` | Input `SensorSample` topic |
| `sensor_processor` | `metrics_topic` | `/edge/metrics/pipeline` | Output `PipelineMetrics` topic |
| `sensor_processor` | `metrics_publish_hz` | `1.0` | Metrics publication rate |
| `sensor_processor` | `rate_window_seconds` | `5.0` | Rolling receive-rate window |
| `sensor_processor` | `latency_window_size` | `1000` | Rolling latency sample window |
| `sensor_processor` | `processing_delay_enabled` | `false` | P0-009 subscriber delay injection switch |
| `sensor_processor` | `processing_delay_ms` | `0.0` | P0-009 per-sample delay used to increase `p95_latency_ms` and `p99_latency_ms` |
| `health_monitor` | `metrics_topic` | `/edge/metrics/pipeline` | P0-010 input `PipelineMetrics` topic |
| `health_monitor` | `health_topic` | `/edge/health/state` | P0-010 output `HealthState` topic |
| `health_monitor` | `min_receive_rate_hz_warning` | `95.0` | Warning floor for receive rate |
| `health_monitor` | `min_receive_rate_hz_unhealthy` | `80.0` | Unhealthy floor for receive rate |
| `health_monitor` | `max_drop_rate_warning` | `0.001` | Warning drop-rate threshold |
| `health_monitor` | `max_drop_rate_unhealthy` | `0.01` | Unhealthy drop-rate threshold |
| `health_monitor` | `max_p95_latency_ms_warning` | `5.0` | Warning p95 latency threshold for P0-010 |
| `health_monitor` | `max_p95_latency_ms_unhealthy` | `20.0` | Unhealthy p95 latency threshold for P0-010 |
| `health_monitor` | `max_p99_latency_ms_warning` | `10.0` | Warning p99 latency threshold for P0-010 |
| `health_monitor` | `max_p99_latency_ms_unhealthy` | `50.0` | Unhealthy p99 latency threshold for P0-010 |
| `system_metrics_node` | `metrics_topic` | `/edge/metrics/system` | P0-011 output `SystemMetrics` topic |
| `system_metrics_node` | `input_mode` | `sample_file` | `sample_file` for deterministic smoke or `live_command` for bounded live tegrastats |
| `system_metrics_node` | `sample_file` | package testdata sample | Saved tegrastats lines used by parser tests and smoke tests |
| `system_metrics_node` | `live_command` | `timeout 2s tegrastats --interval 1000` | Bounded live tegrastats command |
| `system_metrics_node` | `raw_log_enabled` | `true` | Whether to append raw tegrastats lines under project-local logs |
| `system_metrics_node` | `raw_log_path` | `runtime/logs/tegrastats/...` | Project-local raw tegrastats log destination |

## Logs

Each node should log:

- startup configuration,
- topic names and message types,
- parameter values,
- first successful publish or receive,
- health state transitions,
- fault injection state changes,
- shutdown reason.

Logs must be written to normal ROS output and collected under project-local `runtime/logs/` by scripts.

## Metrics And Health Rules

Initial P0 health rules:

- `HEALTHY`: receive rate is close to expected, drop rate is zero or within threshold, and p95/p99 latency are within thresholds.
- `WARNING`: receive rate degraded, nonzero drops, p95 latency above warning threshold, or system metrics near limits.
- `UNHEALTHY`: sustained high drop rate, p99 latency above unhealthy threshold, no sensor messages for a configured timeout, or system metrics over hard limits.

Health output must use `edge_reliability_msgs/msg/HealthState`.

P0-010 `edge_reliability_health` rule mapping:

- normal 100Hz metrics should publish `HEALTHY`;
- drop-fault metrics should publish `UNHEALTHY` with `drop_rate_unhealthy`;
- subscriber-delay metrics should publish `WARNING` or `UNHEALTHY` with a p95 latency rule;
- `HealthState.reason` must summarize the highest active severity;
- `HealthState.active_rules` must include machine-readable rule names.

P0-011 `edge_reliability_system` mapping:

- `system_metrics_node` publishes `/edge/metrics/system` as `edge_reliability_msgs/msg/SystemMetrics`;
- parser input is Jetson `tegrastats` text, either from `sample_file` or a bounded `live_command`;
- `cpu_percent` is the average of per-core CPU percentages from the `CPU [...]` block;
- `gpu_percent` comes from `GR3D_FREQ` when present;
- `temperature_c` is the highest nonnegative temperature token;
- `power_w` is the sum of current `VDD_*` and `VIN_*` rail values converted from mW to watts;
- raw tegrastats input must stay under project-local `runtime/logs/tegrastats`.

## QoS

P0 default QoS policy:

- Sensor sample stream: keep last 10, volatile, best effort acceptable for high-rate simulated sensor data.
- Metrics streams: keep last 10, volatile, reliable.
- Health stream: keep last 1, reliable; transient local may be used later if dashboards need the last state immediately on subscribe.

Any QoS change must be recorded in the node README and experiment results because QoS directly affects drop and latency behavior.

## rosbag Topics

Default P0 bag set:

```text
/edge/sensors/fake_primary
/edge/metrics/pipeline
/edge/metrics/system
/edge/health/state
```

Runtime location:

```text
runtime/bags/
```

Bags should not be committed to git.

P0-008 normal replay:

- record raw sensor bags under `runtime/bags/p0-008`;
- use scenario/timestamp naming such as `normal_replay_YYYYMMDDTHHMMSSZ`;
- record `/edge/sensors/fake_primary` only when the goal is replaying into `sensor_processor`;
- do not replay `/edge/metrics/pipeline` while `sensor_processor` is publishing fresh metrics, because that creates ambiguous metrics evidence.
- Rule: do not replay /edge/metrics/pipeline while `sensor_processor` is publishing.

P0-009 fault injection bags:

- record drop and delay scenarios under `runtime/bags/p0-009`;
- include `/edge/sensors/fake_primary` and `/edge/metrics/pipeline`;
- use the report to compare normal vs fault `drop_rate`, `p95_latency_ms`, and `p99_latency_ms`;
- keep fault bags out of git.

## Failure Modes

The P0 pipeline should make these failure modes visible:

- no publisher on `/edge/sensors/fake_primary`,
- subscriber not receiving messages,
- sequence gap or duplicate `sequence_id`,
- receive rate below expected rate,
- p95 or p99 latency above threshold,
- drop rate above threshold,
- system metrics unavailable,
- system temperature or power unavailable,
- malformed status or unknown `sensor_id`,
- rosbag replay missing required topics.

Each failure should map to either `PipelineMetrics`, `SystemMetrics`, or `HealthState` evidence.

P0-009 injected failure modes:

- `drop_enabled` plus `drop_probability` creates sequence gaps while keeping generated sequence IDs monotonic;
- `processing_delay_enabled` plus `processing_delay_ms` increases subscriber-side latency without changing the message contract;
- `sensor_processor` must expose the effect through `dropped_count`, `drop_rate`, `p95_latency_ms`, and `p99_latency_ms`.

## Stability Rules

- Do not rename topics without updating this contract and downstream tasks.
- Do not remove message fields after downstream nodes depend on them.
- Add fields only when a concrete task needs them.
- Keep adapter nodes separate from processor, metrics, health, and runtime nodes.
- Prefer project-local runtime evidence over global system changes.

## Verification

Verified on Jetson:

- `colcon build --packages-select edge_reliability_msgs --symlink-install` completed with `Summary: 1 package finished [10.1s]`.
- `ros2 interface show` succeeded for `SensorSample`, `PipelineMetrics`, `SystemMetrics`, and `HealthState`.
- Generated outputs remained ignored under `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/`.
- P0-007 processor smoke completed with `SMOKE_EXIT_STATUS=0`: `/edge/metrics/pipeline` published `PipelineMetrics` from `sensor_processor`, sensor rate measured 100.003Hz, metrics rate measured 1.000Hz, and rosbag recorded both `/edge/sensors/fake_primary` and `/edge/metrics/pipeline`.
- P0-008 normal replay completed with `SMOKE_EXIT_STATUS=0`: a raw sensor bag under `runtime/bags/p0-008/normal_replay_20260611T023316Z` recorded 764 samples, replay drove `sensor_processor` to receive 763 samples, and replay metrics reported 99.989Hz, zero drops, and zero out-of-order samples.
- P0-009 fault injection completed with `SMOKE_EXIT_STATUS=0`: normal `drop_rate` was 0.000000, drop-fault `drop_rate` reached 0.192000 with 288 sequence-gap drops, subscriber delay increased p95 latency from 0.580ms to 8.436ms, and fault bags were recorded under `runtime/bags/p0-009`.
- P0-010 health monitor completed with `SMOKE_EXIT_STATUS=0`: normal metrics produced `HEALTHY`, drop fault produced `UNHEALTHY`, subscriber delay produced `WARNING`, and the final warning-clean rerun had no package stderr output.
- P0-011 system metrics completed with `SMOKE_EXIT_STATUS=0`: `/edge/metrics/system` published `SystemMetrics` from `system_metrics_node`, sample-file metrics included CPU, RAM, GR3D, temperature, power, and `source: tegrastats_sample_file`, raw logs were written under `runtime/logs/tegrastats`, and live `tegrastats` was available.

Re-run commands:

```bash
cd ~/chengwei/ros2_ws
source /opt/ros/humble/setup.bash
colcon build --packages-select edge_reliability_msgs --symlink-install
source install/setup.bash
ros2 interface show edge_reliability_msgs/msg/SensorSample
ros2 interface show edge_reliability_msgs/msg/PipelineMetrics
ros2 interface show edge_reliability_msgs/msg/SystemMetrics
ros2 interface show edge_reliability_msgs/msg/HealthState
```
