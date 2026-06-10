# M4 Metrics And Health Monitor

## Goal

Add metrics and health-state logic to the fake sensor pipeline.

## Context

The project must be observable and diagnosable. "It runs" is not enough; the system must report rate, latency, drop behavior, and health state.

## Inputs

- Fake sensor pipeline from M3.
- Metric definitions from the PRD.

## Expected Outputs

- Metrics publisher.
- Health monitor node.
- Configurable thresholds.
- Unit tests for pure metric and health logic where practical.
- Interface contract.
- Test report covering normal and fault scenarios.

## Technical Constraints

- Core runtime nodes use C++17 and rclcpp.
- Thresholds must be configurable.
- Metrics must include avg latency, p95 latency, p99 latency, receive rate, drop count, and drop rate.
- Health states are healthy, warning, and unhealthy.

## Acceptance Criteria

- 100Hz normal run has receive rate at least 99Hz.
- Normal-run drop rate is 0.
- p95 latency is at most 20ms in the normal run.
- p99 latency is at most 50ms in the normal run.
- Random dropped frames increase drop count.
- Subscriber sleep increases tail latency.
- Health changes state when configured thresholds are crossed.

## Verification Commands

- `colcon build`
- Unit test command for the selected ROS 2 test framework.
- `ros2 launch <package> <launch_file>`
- `ros2 topic echo <metrics_topic>`
- `ros2 topic echo <health_topic>`
- `ros2 bag play <bag_dir>`

## Runtime Artifact Location

Store result CSV, logs, and bags under project-local runtime directories.

## Cleanup and Rollback

Remove generated result files only from the project runtime directory by default.

## Interview Artifact Questions

- Why use p95 and p99 instead of only average latency?
- What health thresholds are reasonable for P0?
- How can a rosbag reproduce metrics?

## Out of Scope

- Jetson tegrastats parsing.
- TensorRT performance metrics.
- Web dashboard.
