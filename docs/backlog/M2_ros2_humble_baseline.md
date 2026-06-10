# M2 ROS 2 Humble Baseline

Status: completed

## Goal

Verify ROS 2 Humble development basics on the Jetson server.

## Context

This milestone proves the basic ROS 2 toolchain before project-specific packages are built.

## Inputs

- Jetson baseline from M1.
- ROS 2 Humble installation target.

## Expected Outputs

- ROS 2 installation notes.
- Working colcon workspace.
- Minimal C++ package build.
- rosbag record and replay evidence.

## Technical Constraints

- Use ROS 2 Humble on Ubuntu 22.04.
- Avoid ROS 2 Jazzy and Ubuntu 24.04 dependencies.
- Prefer apt-supported packages where possible.

## Acceptance Criteria

- [x] demo_nodes_cpp talker and listener communicate.
- [x] `ros2 topic hz` shows expected frequency.
- [x] A custom C++ package builds with colcon.
- [x] A launch file starts the custom package.
- [x] rosbag records and replays a sample topic.
- [x] Installation and environment changes are recorded in the change ledger.

## Completion Evidence

- ROS 2 Humble minimal host install completed after apt simulation showed `0 to remove`.
- `demo_nodes_cpp` talker/listener communicated on `/chatter`.
- Custom package `edge_reliability_tracer` built successfully with colcon on Jetson.
- `ros2 launch edge_reliability_tracer tracer.launch.py` started publisher and subscriber nodes.
- `/edge/tracer` published `std_msgs/msg/String` samples at approximately `10 Hz`.
- `ros2 bag info` reported `77` recorded messages for `/edge/tracer`.
- Generated build and runtime outputs stayed under ignored project-local paths.

## Verification Commands

- `ros2 run demo_nodes_cpp talker`
- `ros2 run demo_nodes_cpp listener`
- `colcon build --packages-select edge_reliability_tracer --symlink-install`
- `ros2 launch edge_reliability_tracer tracer.launch.py`
- `ros2 topic list -t`
- `ros2 topic echo --once /edge/tracer std_msgs/msg/String`
- `ros2 topic hz /edge/tracer`
- `ros2 bag record /edge/tracer`
- `ros2 bag info <bag_dir>`
- `ros2 bag play <bag_dir>`

## Runtime Artifact Location

Store bags and logs under project-local runtime directories.

## Cleanup and Rollback

Record all installed packages. Project-local build outputs can be deleted from the workspace build, install, and log directories.

## Interview Artifact Questions

- What did the baseline prove?
- What can fail before project code is even involved?
- How does colcon structure ROS 2 development?

## Out of Scope

- Custom metrics.
- Jetson tegrastats integration.
- QoS stress testing.
