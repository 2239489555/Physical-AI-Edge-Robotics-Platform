# M2 ROS 2 Humble Baseline

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

- demo_nodes_cpp talker and listener communicate.
- `ros2 topic hz` shows expected frequency.
- A custom C++ package builds with colcon.
- A launch file starts the custom package.
- rosbag records and replays a sample topic.
- Installation and environment changes are recorded in the change ledger.

## Verification Commands

- `ros2 run demo_nodes_cpp talker`
- `ros2 run demo_nodes_cpp listener`
- `ros2 topic list`
- `ros2 topic echo /chatter`
- `ros2 topic hz /chatter`
- `colcon build`
- `ros2 bag record /chatter`
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
