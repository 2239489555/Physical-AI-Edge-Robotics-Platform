# Edge Reliability Processor

P0-007 adds the processor metrics subscriber for the fake sensor pipeline.

The `sensor_processor` node subscribes to `/edge/sensors/fake_primary` as `edge_reliability_msgs/msg/SensorSample` and publishes `/edge/metrics/pipeline` as `edge_reliability_msgs/msg/PipelineMetrics`.

## Metrics Window

- `received_count`: total samples received since node start.
- `expected_count`: `received_count + dropped_count`, where drops are inferred from sequence gaps.
- `dropped_count`: missing sequence IDs observed since node start.
- `out_of_order_count`: duplicate or backwards sequence IDs observed since node start.
- `receive_rate_hz`: measured over the rolling `rate_window_seconds` window.
- `expected_rate_hz`: configured target rate.
- `average_latency_ms`: average publish-to-receive latency over the rolling `latency_window_size` sample window.
- `p95_latency_ms`: 95th percentile latency in milliseconds over the same latency window.
- `p99_latency_ms`: 99th percentile latency in milliseconds over the same latency window.
- `drop_rate`: `dropped_count / expected_count`.

## Build And Test

Run from the Jetson workspace:

```bash
cd ~/chengwei/ros2_ws
source /opt/ros/humble/setup.bash
colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor --symlink-install
colcon test --packages-select edge_reliability_processor
colcon test-result --verbose --test-result-base build/edge_reliability_processor
source install/setup.bash
```

## Launch

Start the fake sensor and processor in separate terminals:

```bash
ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py
ros2 launch edge_reliability_processor processor.launch.py
```

Inspect the metrics topic:

```bash
ros2 topic info /edge/metrics/pipeline -v
ros2 topic echo --once /edge/metrics/pipeline edge_reliability_msgs/msg/PipelineMetrics
```

## Smoke Gate

From the repository root on Jetson:

```bash
bash scripts/run_p0_007_processor_smoke.sh
```

The script writes command output under `runtime/results/`, logs under `runtime/logs/`, and bags under `runtime/bags/p0-007`.

After the report is copied back to a Windows checkout, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_007_completion_gate.ps1
```
