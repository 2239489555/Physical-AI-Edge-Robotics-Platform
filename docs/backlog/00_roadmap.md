# Backlog Roadmap

This backlog is the Markdown source of truth. GitHub Issues are the optional execution queue after a task is reviewed and sanitized.

Progress is task-gated rather than week-gated. Do not move forward just because time has passed. Move forward only when the current milestone gate is met.

Detailed development issues live in [`docs/backlog/issues/INDEX.md`](issues/INDEX.md).

## P0 Mainline

| Milestone | Title | Outcome |
| --- | --- | --- |
| M0 | Robotics onboarding | ROS 2 beginner concepts are understood and verified through a minimal package. |
| M1 | Jetson system inventory | System baseline and change ledger exist before risky changes. |
| M2 | ROS 2 Humble baseline | ROS 2, colcon, package build, launch, topic tools, and rosbag are verified. |
| M3 | Fake sensor pipeline | 100Hz C++ ROS 2 pipeline publishes, processes, and records sensor-style data. |
| M4 | Metrics and health monitor | Latency, rate, drop, and health logic are observable and testable. |
| M5 | tegrastats monitor | Jetson runtime metrics are published into ROS 2 and linked to health state. |
| M6 | QoS latency drop lab | QoS, latency, drop, and pressure experiments generate CSV and reports. |
| M7 | Edge runtime scripts | Project-local start, stop, health check, collect logs, and cleanup scripts exist. |
| M8 | P0 phase gate | P0 evidence is reviewed before P1 work starts. |

## P0.5 Display Enhancement

Build a lightweight HTML dashboard only after P0 data contracts are stable. Dashboard output is useful for demos, but not a P0 gate.

## P1 Priority

TensorRT perception on Jetson is the first enhancement after P0. It should compare CPU baseline, TensorRT FP32, TensorRT FP16, FPS, latency, GR3D_FREQ, CPU, RAM, and temperature.

P1 must also introduce at least one public dataset or public rosbag sample.

## P1 Secondary

Nav2 and TurtleBot3 simulation are secondary P1 work after TensorRT or when TensorRT is blocked. The purpose is to learn scan, odom, tf, cmd_vel, map, costmap, planner, controller, and navigation failure diagnosis.

## P2

Isaac ROS 3.2 is P2 and should be treated as a lightweight compatibility and acceleration lab. It must not block P0 or P1.

## Done Means

Every milestone must produce:

- README or usage notes.
- Architecture or design notes.
- Interface contract for ROS 2 packages.
- Test report with normal and fault scenarios.
- Debug guide or troubleshooting notes.
- Cleanup and rollback notes.
- Interview artifacts.
- Evidence that runtime artifacts stay under the project workspace.
