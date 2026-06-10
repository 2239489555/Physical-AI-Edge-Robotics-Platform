# M5 tegrastats Monitor

## Goal

Parse Jetson tegrastats and publish structured system metrics into ROS 2.

## Context

Jetson-specific observability is central to edge robotics work. tegrastats is the primary source for CPU, RAM, GPU, temperature, and power information on Jetson.

## Inputs

- Jetson system baseline from M1.
- Metrics and health monitor from M4.
- tegrastats sample output.

## Expected Outputs

- ROS 2 node that reads or tails tegrastats output.
- Structured system metrics topic.
- Health integration for system thresholds.
- Raw tegrastats logging under project-local runtime logs.
- Interface contract.
- Test report.

## Technical Constraints

- Core runtime node uses C++17 and rclcpp unless parsing constraints justify a helper script.
- No reliance on nvidia-smi as the primary GPU metric source.
- Logs stay under the project workspace.

## Acceptance Criteria

- Structured topic includes RAM, CPU, GR3D_FREQ or GPU-related frequency/utilization indicator, temperature, and power fields where available.
- `ros2 topic echo` shows system metrics.
- Threshold crossings can move health state to warning or unhealthy.
- Raw tegrastats output is saved for debugging.
- The user can explain what tegrastats adds over generic ROS metrics.

## Verification Commands

- `tegrastats`
- `ros2 launch <package> <launch_file>`
- `ros2 topic echo <system_metrics_topic>`
- `ros2 topic echo <health_topic>`

## Runtime Artifact Location

Store raw tegrastats logs under project-local runtime logs.

## Cleanup and Rollback

Ensure any tegrastats process started by the project is stopped. Cleanup only project-local logs by default.

## Interview Artifact Questions

- Why is tegrastats preferred on Jetson?
- What indicates that GPU inference is or is not using the GPU?
- How can system pressure affect ROS 2 latency?

## Out of Scope

- TensorRT inference.
- Docker/systemd service installation.
- Long-term dashboard.
