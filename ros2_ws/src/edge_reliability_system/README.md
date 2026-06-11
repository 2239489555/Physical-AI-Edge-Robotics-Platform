# Edge Reliability System

The `system_metrics_node` publishes Jetson system metrics on `/edge/metrics/system` as `edge_reliability_msgs/msg/SystemMetrics`.

The parser targets `tegrastats` because Jetson devices expose GPU, thermal, memory, and power details there. `nvidia-smi` is not enough for this project because it is not the primary Jetson observability surface and may omit the embedded GPU, thermal, and rail-power details that matter for edge robotics.

## Inputs

The node supports two input modes:

- `sample_file`: read saved tegrastats lines and publish them repeatedly. This is the default smoke-test mode and does not require live Jetson tegrastats.
- `live_command`: run a bounded command such as `timeout 2s tegrastats --interval 1000` and publish the latest captured line.

Raw input lines can be appended to a project-local log under `runtime/logs/tegrastats/`.

## Published Fields

The parser maps tegrastats into `SystemMetrics`:

- `cpu_percent`: average of per-core CPU utilization values in the `CPU [...]` block.
- `memory_used_mb`: used RAM from `RAM used/totalMB`.
- `memory_total_mb`: total RAM from `RAM used/totalMB`.
- `gpu_percent`: `GR3D_FREQ` percentage when present.
- `temperature_c`: highest nonnegative temperature token.
- `power_w`: sum of current mW values from `VDD_*` and `VIN_*` power rails, converted to watts.
- `source`: `tegrastats_sample_file` or `tegrastats_live_command`.

## Run

```bash
cd ~/chengwei/ros2_ws
source /opt/ros/humble/setup.bash
colcon build --packages-select edge_reliability_msgs edge_reliability_system --symlink-install
source install/setup.bash
ros2 launch edge_reliability_system system_metrics.launch.py
```

Echo one sample:

```bash
ros2 topic echo --once /edge/metrics/system edge_reliability_msgs/msg/SystemMetrics
```

Run the P0-011 smoke:

```bash
cd ~/chengwei
bash scripts/run_p0_011_system_metrics_smoke.sh
```
