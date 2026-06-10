# Competency Matrix

This matrix maps milestones to future Physical AI, Robotics Software Engineer, Edge AI Engineer, and Robotics Infrastructure competencies.

| Competency | What It Means | Milestones |
| --- | --- | --- |
| ROS 2 core | Nodes, topics, messages, launch, parameters, QoS, rosbag, and topic tools. | M0, M2, M3, M6 |
| C++ robotics runtime | rclcpp, C++17, package structure, CMake, long-running nodes, runtime contracts. | M0, M2, M3, M4, M5 |
| Edge observability | tegrastats, CPU, RAM, GPU, temperature, logs, health state, metrics. | M1, M4, M5, M7 |
| Reliability engineering | Fault injection, tail latency, drop detection, recovery, diagnostics, reproduction. | M3, M4, M6, M7, M8 |
| Data replay and simulation readiness | fake sensor, rosbag, video files, public data, simulation as hardware substitute. | M3, M6, P1 data task |
| Company-server-safe operations | Workspace-bounded artifacts, cleanup, rollback, change ledger, no global pollution. | M1, M7, M8 |
| Edge AI deployment | ONNX, TensorRT, FP32/FP16, FPS, latency, GPU utilization, thermal behavior. | P1 TensorRT |
| Robotics navigation debugging | scan, odom, tf, cmd_vel, map, costmap, planner, controller, Nav2 failure cases. | P1 Nav2 |
| NVIDIA robotics ecosystem | Isaac ROS, NITROS, accelerated image pipeline, NVIDIA dev containers. | P2 Isaac ROS |
| Interview narrative | Architecture explanation, tradeoffs, failure stories, metrics evidence, hardware migration story. | All milestones |

## Milestone Mapping

### M0 Robotics Onboarding

Builds vocabulary and command confidence. Trains the user to explain ROS 2 basics rather than only run generated code.

### M1 Jetson System Inventory

Builds Jetson system literacy and change control. This is directly relevant to edge device handoff and field debugging.

### M2 ROS 2 Humble Baseline

Builds basic development workflow and verifies that the Jetson can support ROS 2 work.

### M3 Fake Sensor Pipeline

Builds the first robotics-style data path and introduces timestamp, sequence ID, frequency, launch, config, and rosbag discipline.

### M4 Metrics And Health Monitor

Builds observability and reliability reasoning. Converts raw message flow into measurable system behavior.

### M5 tegrastats Monitor

Builds Jetson-specific edge observability and prepares for future TensorRT performance analysis.

### M6 QoS Latency Drop Lab

Builds communication tradeoff intuition and failure reproduction skill.

### M7 Edge Runtime Scripts

Builds deployment discipline, diagnostic packaging, and cleanup safety for company-owned infrastructure.

### M8 P0 Phase Gate

Builds evidence-based completion judgment and interview readiness.

## Interview Story Requirements

Every milestone should produce a short story covering:

- The real company problem it simulates.
- The design choice and tradeoff.
- The failure that was injected or observed.
- The evidence used to diagnose it.
- The path from simulated input to future real hardware.
