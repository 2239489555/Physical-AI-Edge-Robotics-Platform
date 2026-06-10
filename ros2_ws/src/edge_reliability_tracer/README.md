# edge_reliability_tracer

Minimal ROS 2 C++ tracer slice for P0-003.

## Build

Run from the repository root on Jetson:

```bash
source /opt/ros/humble/setup.bash
cd ros2_ws
colcon build --packages-select edge_reliability_tracer --symlink-install
source install/setup.bash
```

## Launch

```bash
ros2 launch edge_reliability_tracer tracer.launch.py
```

Override the publish frequency without recompiling:

```bash
ros2 launch edge_reliability_tracer tracer.launch.py config_file:=$(pwd)/src/edge_reliability_tracer/config/tracer.yaml
```

Edit `config/tracer.yaml` and change `publish_hz`.

## Topic Checks

Run these in another sourced shell from `ros2_ws`:

```bash
source /opt/ros/humble/setup.bash
source install/setup.bash

ros2 topic list
ros2 topic info /edge/tracer
ros2 topic echo /edge/tracer --once
ros2 topic hz /edge/tracer
```

## Rosbag Smoke

Keep runtime artifacts under the project-local ignored `runtime/` tree:

```bash
mkdir -p ../runtime/bags/p0-003
ros2 bag record /edge/tracer -o ../runtime/bags/p0-003/tracer_smoke
ros2 bag play ../runtime/bags/p0-003/tracer_smoke
```
