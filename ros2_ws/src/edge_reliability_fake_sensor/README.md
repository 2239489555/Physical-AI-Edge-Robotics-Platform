# edge_reliability_fake_sensor

100Hz fake sensor adapter for P0-006.

This package publishes `edge_reliability_msgs/msg/SensorSample` on `/edge/sensors/fake_primary`. It is the first real P0 data-source slice and intentionally owns only adapter behavior. Subscriber metrics, fault injection, and full rosbag workflow checks belong to later tasks.

## Build

Run from the repository root on Jetson:

```bash
source /opt/ros/humble/setup.bash
cd ros2_ws
colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor --symlink-install \
  2>&1 | tee ../runtime/artifacts/preflight/p0_006_colcon_build.txt
source install/setup.bash
```

For the full P0-006 smoke check, run the project script from the repository root on Jetson:

```bash
bash scripts/run_p0_006_fake_sensor_smoke.sh
cat runtime/results/p0_006_smoke_report.txt
```

It builds the package, launches the node, checks topic metadata, echoes one sample, measures frequency, records a short bag, and writes a `P0-006_RESULT` summary under `runtime/results/`.

After the report is copied back to a Windows checkout, verify it with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_006_smoke_report.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_006_completion_gate.ps1
```

`verify_p0_006_smoke_report.ps1` checks the runtime evidence, and `verify_p0_006_completion_gate.ps1` runs both the static implementation gate and returned-report gate.

If the build output scrolls away, inspect the saved log:

```bash
tail -n 40 ../runtime/artifacts/preflight/p0_006_colcon_build.txt
grep -E '^(Starting|Finished|Summary:)' ../runtime/artifacts/preflight/p0_006_colcon_build.txt
```

## Launch

```bash
ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py
```

Override the config file without rebuilding:

```bash
ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py config_file:=$(pwd)/src/edge_reliability_fake_sensor/config/fake_sensor.yaml
```

The default config publishes at 100Hz with `fault_mode: "off"`.

## Topic Checks

Run these in another sourced shell from `ros2_ws`:

```bash
source /opt/ros/humble/setup.bash
source install/setup.bash

ros2 daemon stop
ros2 daemon start
sleep 2

ros2 topic list -t
ros2 topic info /edge/sensors/fake_primary -v
ros2 topic echo --once /edge/sensors/fake_primary edge_reliability_msgs/msg/SensorSample --qos-reliability best_effort
timeout --signal=INT 10s ros2 topic hz /edge/sensors/fake_primary --qos-reliability best_effort
```

Expected evidence:

- Topic type is `edge_reliability_msgs/msg/SensorSample`.
- Publisher node is `fake_sensor_adapter`.
- `ros2 topic hz` reports approximately 100Hz.
- Echoed samples include `header.stamp`, `sequence_id`, `sensor_id`, `value`, `status`, and `status_detail`.

## Rosbag Smoke

Keep runtime artifacts under the project-local ignored `runtime/` tree:

```bash
mkdir -p ../runtime/bags/p0-006
ros2 bag record /edge/sensors/fake_primary -o ../runtime/bags/p0-006/fake_sensor_smoke
ros2 bag info ../runtime/bags/p0-006/fake_sensor_smoke
```

Do not commit generated bags, logs, `build/`, `install/`, or `log/`.
