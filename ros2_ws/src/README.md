# ROS 2 Packages

ROS 2 packages for the Edge Robotics Reliability Lab will live under this directory.

Planned P0 packages include:

- `edge_reliability_msgs`: message contracts for fake sensors, metrics, system metrics, and health state.
- `edge_reliability_tracer`: minimal C++ publisher/subscriber slice for P0-003.
- `edge_reliability_fake_sensor`: 100Hz fake sensor adapter for P0-006.
- `edge_reliability_processor`: processor metrics subscriber for P0-007.
- Health monitor.
- Jetson system monitor.
- QoS stress lab.

Do not place runtime bags, logs, datasets, or generated build outputs here.
