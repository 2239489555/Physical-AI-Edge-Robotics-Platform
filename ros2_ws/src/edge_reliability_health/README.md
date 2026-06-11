# Edge Reliability Health

The `health_monitor` node subscribes to `/edge/metrics/pipeline` as `edge_reliability_msgs/msg/PipelineMetrics` and publishes `/edge/health/state` as `edge_reliability_msgs/msg/HealthState`.

It converts metric thresholds into a coarse state:

- `HEALTHY`: pipeline metrics are within configured thresholds.
- `WARNING`: at least one warning threshold is crossed.
- `UNHEALTHY`: at least one unhealthy threshold is crossed.

## Parameters

- `metrics_topic`: input `PipelineMetrics` topic. Default: `/edge/metrics/pipeline`.
- `health_topic`: output `HealthState` topic. Default: `/edge/health/state`.
- `min_receive_rate_hz_warning`: warning floor for receive rate.
- `min_receive_rate_hz_unhealthy`: unhealthy floor for receive rate.
- `max_drop_rate_warning`: warning ceiling for `drop_rate`.
- `max_drop_rate_unhealthy`: unhealthy ceiling for `drop_rate`.
- `max_p95_latency_ms_warning`: warning ceiling for `p95_latency_ms`.
- `max_p95_latency_ms_unhealthy`: unhealthy ceiling for `p95_latency_ms`.
- `max_p99_latency_ms_warning`: warning ceiling for `p99_latency_ms`.
- `max_p99_latency_ms_unhealthy`: unhealthy ceiling for `p99_latency_ms`.
- `min_expected_count`: warmup count before a run is treated as fully evaluated.

Default P0 thresholds keep the normal 100Hz pipeline healthy, make the P0-009 drop fault unhealthy, and make the P0-009 subscriber delay warning.

## Run

```bash
cd ~/chengwei/ros2_ws
source /opt/ros/humble/setup.bash
colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor edge_reliability_health --symlink-install
source install/setup.bash
ros2 launch edge_reliability_health health_monitor.launch.py
```

Echo health state:

```bash
ros2 topic echo --once /edge/health/state edge_reliability_msgs/msg/HealthState
```

Run the P0-010 smoke:

```bash
cd ~/chengwei
bash scripts/run_p0_010_health_monitor_smoke.sh
```
