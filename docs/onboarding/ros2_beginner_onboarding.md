# ROS 2 Beginner Onboarding

This guide assumes no robotics background. The goal is not to memorize ROS 2 commands. The goal is to build a mental model for how robot software moves information between small programs, how we inspect that flow, and how we record it for debugging.

The current project uses a simulated tracer topic instead of real hardware. That is intentional: before attaching a robot, camera, LiDAR, or motor controller, a robotics team usually proves the data path in software first because hardware mistakes are slow, expensive, and sometimes unsafe.

## What You Built

The first custom ROS 2 package is:

```text
ros2_ws/src/edge_reliability_tracer
```

It contains:

- `tracer_publisher`: a C++ node that publishes text samples.
- `tracer_subscriber`: a C++ node that receives those samples.
- `tracer.launch.py`: one launch file that starts both nodes.
- `config/tracer.yaml`: parameters for topic name and publish frequency.
- `/edge/tracer`: the topic carrying `std_msgs/msg/String` messages.

This is a small but real robotics software loop:

```text
publisher node -> topic -> subscriber node
                 |
                 +-> topic tools
                 +-> rosbag recording
```

## Core Concepts

### node

A node is one running piece of robot software. In this project, `tracer_publisher` and `tracer_subscriber` are separate nodes. A real robot might have separate nodes for camera capture, object detection, localization, path planning, motor control, logging, and health monitoring.

Why it matters: nodes make a robot system modular. One node can fail, restart, or be replaced without rewriting the whole robot.

### topic

A topic is a named stream of messages. A publisher writes to a topic, and subscribers read from it. Here the topic is `/edge/tracer`.

Why it matters: sensor data is usually a stream. Cameras, IMUs, LiDAR, joint states, and telemetry all behave more like continuous topics than one-off function calls.

### message

A message is the typed data sent on a topic. `/edge/tracer` uses `std_msgs/msg/String`, so each sample is text like:

```text
data: seq=98 stamp_ns=1781072578569798119
```

Why it matters: robots are distributed systems. Message types are the contract between nodes.

### service

A service is a request/response interaction. Use it when one node asks another node for a bounded answer, such as "reset this counter" or "return the current calibration state."

Why it matters: not all robot communication is streaming. Some commands need a direct answer.

### action

An action is a long-running goal with feedback and a final result. Navigation is the classic example: "go to this pose" might take many seconds, report progress, and eventually succeed or fail.

Why it matters: robots often do work that takes time. Actions fit those tasks better than a simple service.

### launch

A launch file starts a group of nodes with a shared configuration. `tracer.launch.py` starts the publisher and subscriber together.

Why it matters: robot behavior usually depends on many nodes running together. Launch files make startup repeatable.

### parameter

A parameter is runtime configuration. `config/tracer.yaml` sets:

```yaml
publish_hz: 10.0
```

Why it matters: parameters let you change behavior, such as frequency or topic name, without recompiling C++.

### QoS

QoS means Quality of Service. It controls communication behavior such as queue depth, reliability, durability, and whether old messages can be dropped.

In the tracer package both nodes use:

```cpp
rclcpp::QoS(10)
```

Why it matters: robotics data streams are not all equal. A camera can drop old frames if processing is late; a safety status message may need stronger delivery guarantees.

### timestamp

A timestamp says when data was produced. The tracer message includes `stamp_ns`, the node's current ROS time in nanoseconds.

Why it matters: robots combine signals from many sources. If a camera frame and robot pose are not time-aligned, perception and control can become wrong even if every individual message looks valid.

### frame_id

A `frame_id` names the coordinate frame where data is valid, such as `base_link`, `camera_link`, or `map`. The current tracer message is a plain string, so it does not include a real `frame_id` yet.

Why it matters: spatial data is meaningless without a coordinate frame. A point in the camera frame is not the same as a point in the robot base frame.

### sequence_id

A sequence_id is a monotonically increasing sample number. The tracer message includes `seq=...`.

Why it matters: sequence IDs make drops, duplicates, and ordering problems visible. This becomes important in the later fake sensor and reliability metrics tasks.

### TF

TF is ROS's transform system. It tracks relationships between coordinate frames over time, such as `map -> odom -> base_link -> camera_link`.

Why it matters: TF lets a robot answer questions like "where was this camera pixel relative to the robot base at that time?"

### rosbag

rosbag records ROS messages to disk and replays them later. In this project, bag files stay under:

```text
runtime/bags/
```

Why it matters: rosbag turns a live robot problem into a reproducible software problem. You can record once, replay many times, and debug without the real hardware running.

## Commands Used In P0-003

Run from the repository root on Jetson.

### Build The Package

```bash
source /opt/ros/humble/setup.bash
cd ros2_ws
colcon build --packages-select edge_reliability_tracer --symlink-install \
  2>&1 | tee ../runtime/artifacts/preflight/p0_003_colcon_build.txt
source install/setup.bash
```

Inspect build evidence if the terminal scrolled:

```bash
tail -n 40 ../runtime/artifacts/preflight/p0_003_colcon_build.txt
grep -E '^(Starting|Finished|Summary:)' ../runtime/artifacts/preflight/p0_003_colcon_build.txt
```

### Start The Nodes

```bash
ros2 launch edge_reliability_tracer tracer.launch.py \
  > ../runtime/logs/p0_003_tracer_launch.txt 2>&1
```

### Inspect The Topic

Use another terminal:

```bash
cd ~/chengwei/ros2_ws
source /opt/ros/humble/setup.bash
source install/setup.bash

ros2 daemon stop
ros2 daemon start
sleep 2

ros2 topic list -t
ros2 topic info /edge/tracer -v
ros2 topic echo --once /edge/tracer std_msgs/msg/String
timeout --signal=INT 10s ros2 topic hz /edge/tracer
```

### Record And Replay

```bash
rm -rf ../runtime/bags/p0-003/tracer_smoke
mkdir -p ../runtime/bags/p0-003
timeout --signal=INT 8s ros2 bag record /edge/tracer -o ../runtime/bags/p0-003/tracer_smoke
ros2 bag info ../runtime/bags/p0-003/tracer_smoke
ros2 bag play ../runtime/bags/p0-003/tracer_smoke
```

## Evidence From The Jetson Run

### Build

```text
Starting >>> edge_reliability_tracer
Finished <<< edge_reliability_tracer [0.26s]
Summary: 1 package finished [0.63s]
```

### Launch

```text
[tracer_subscriber]: Listening for tracer samples on 'edge/tracer'
[tracer_publisher]: Publishing tracer samples on 'edge/tracer' at 10.00 Hz
[tracer_subscriber]: Received tracer sample: 'seq=0 stamp_ns=1781072568769728582'
```

### Topic List

```text
/chatter [std_msgs/msg/String]
/edge/tracer [std_msgs/msg/String]
/parameter_events [rcl_interfaces/msg/ParameterEvent]
/rosout [rcl_interfaces/msg/Log]
```

### Topic Info

```text
Type: std_msgs/msg/String
Publisher count: 1
Node name: tracer_publisher
Subscription count: 1
Node name: tracer_subscriber
```

### Topic Echo

```text
data: seq=98 stamp_ns=1781072578569798119
---
```

### Topic Frequency

```text
average rate: 10.000
min: 0.100s max: 0.101s std dev: 0.00016s window: 65
```

Sanitized summary: `/edge/tracer` ran at approximately `10.000 Hz`.

### Rosbag

```text
Files:             tracer_smoke_0.db3
Bag size:          33.0 KiB
Duration:          7.600519545s
Messages:          77
Topic information: Topic: /edge/tracer | Type: std_msgs/msg/String | Count: 77 | Serialization Format: cdr
```

Runtime path:

```text
runtime/bags/p0-003/tracer_smoke
```

### Runtime Hygiene

Generated files stayed ignored:

```text
!! ros2_ws/build/
!! ros2_ws/install/
!! ros2_ws/log/
!! runtime/
```

## What This Proves

- The Jetson can build a custom ROS 2 C++ package.
- Two custom nodes can communicate through a topic.
- The topic has a declared message type.
- Runtime parameters can configure behavior without recompiling.
- ROS CLI tools can inspect graph, type, sample data, and frequency.
- rosbag can record and replay the simulated data stream.
- The project can generate useful runtime evidence without committing large artifacts.

## What This Does Not Prove Yet

- It does not prove camera, LiDAR, motor, or robot hardware integration.
- It does not prove real-time performance.
- It does not prove QoS behavior under pressure.
- It does not prove spatial transforms with TF.
- It does not prove perception, planning, or control.

Those are later tasks. This step proves the basic software loop is alive.
