# edge_reliability_msgs

ROS 2 message contracts for the Edge Robotics Reliability Lab.

## Messages

- `SensorSample`: fake, replayed, and future adapter sensor samples.
- `PipelineMetrics`: rate, latency, drop, and sequence metrics.
- `SystemMetrics`: Jetson runtime metrics.
- `HealthState`: coarse health state and active rule reasons.

## Build On Jetson

```bash
cd ~/chengwei/ros2_ws
source /opt/ros/humble/setup.bash
colcon build --packages-select edge_reliability_msgs --symlink-install \
  2>&1 | tee ../runtime/artifacts/preflight/p0_005_msgs_colcon_build.txt
source install/setup.bash
```

## Inspect Interfaces

```bash
ros2 interface show edge_reliability_msgs/msg/SensorSample
ros2 interface show edge_reliability_msgs/msg/PipelineMetrics
ros2 interface show edge_reliability_msgs/msg/SystemMetrics
ros2 interface show edge_reliability_msgs/msg/HealthState
```
