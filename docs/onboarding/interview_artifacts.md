# Interview Artifacts

Use this file to turn the P0-003 tracer slice into short, honest interview answers. The tone should be direct: you are not claiming years of robotics experience; you are showing that you can learn the stack, build a reproducible slice, and reason from evidence.

## One-Minute Project Story

I started from zero robotics background and built a Jetson-based ROS 2 learning platform without physical robot hardware. The first milestone was a minimal C++ ROS 2 tracer package: one publisher, one subscriber, a launch file, YAML parameters, topic inspection, and rosbag recording. It proves the core robot software loop before adding fake sensors, metrics, QoS experiments, or hardware.

The important part is not the string message itself. The important part is that I can build, run, inspect, measure, record, and replay a ROS 2 data stream on the Jetson in a controlled way.

## What is a ROS 2 node?

A ROS 2 node is one running program in the robot system. In my tracer slice, `tracer_publisher` is one node and `tracer_subscriber` is another node.

Why it matters: robots are usually not one big process. They are many cooperating nodes for sensors, perception, planning, control, diagnostics, and logging. Splitting the system into nodes makes it easier to isolate failures and replace parts.

Interview phrasing:

```text
I think of a ROS 2 node as one responsibility running inside a distributed robot application. In my first slice I kept it simple: one node publishes tracer samples and another node subscribes, so I could prove the graph and topic flow before adding real sensor logic.
```

## What is the difference between topic, service, and action?

A topic is a stream. Use it for repeated data like sensor frames, robot state, and metrics.

A service is request/response. Use it for quick bounded interactions like "reset this node" or "give me the current setting."

An action is a long-running goal with feedback. Use it for work that takes time, such as navigation or manipulation.

Why it matters: picking the wrong communication pattern makes robot behavior harder to reason about. A camera stream should not be modeled as a service. A long navigation goal should not be modeled as a single topic message.

Interview phrasing:

```text
In my tracer package I used a topic because the data is a continuous stream. If I later add a reset command, I would consider a service. If I add a long-running operation with progress and cancellation, I would consider an action.
```

## Why do robotics messages need timestamps and frame IDs?

A timestamp tells when data was produced. A frame ID tells which coordinate system the data belongs to.

In the current tracer slice, the message is a simple string with `stamp_ns` and `seq`. It does not yet use a real ROS header or `frame_id`; that comes later when the project adds more realistic sensor-style messages.

Why it matters: robots combine data from many sources. Without timestamps, it is hard to know whether two measurements describe the same moment. Without frame IDs and TF, spatial data can be interpreted in the wrong coordinate frame.

Interview phrasing:

```text
My first slice used a simplified timestamp and sequence ID to make timing and drops visible. I intentionally noted that it does not yet include a real frame_id, because spatial reasoning needs proper stamped messages and TF in later milestones.
```

## How does rosbag help reproduce bugs?

rosbag records ROS messages and replays them later. In P0-003, rosbag recorded `77` messages from `/edge/tracer` under `runtime/bags/p0-003/tracer_smoke`.

Why it matters: live robot bugs can be expensive and hard to reproduce. A bag lets you capture one run, then replay it repeatedly while changing subscribers, metrics, or analysis tools.

Interview phrasing:

```text
I use rosbag as the bridge between live robotics behavior and repeatable software debugging. Even without hardware, I can record a stream, replay it, and prove downstream nodes behave consistently.
```

## How would you explain this project in an interview?

Short version:

```text
I am building a Jetson-based edge robotics reliability lab. Because I do not have physical robot hardware, I started with simulation-friendly ROS 2 slices: a C++ publisher/subscriber loop, launch, parameters, topic inspection, frequency measurement, and rosbag record/replay. The goal is to learn the robotics software stack deeply enough to handle future Physical AI roles when hardware or richer simulation is available.
```

More technical version:

```text
The first milestone proves the ROS 2 execution path on the Jetson: colcon builds a custom C++ package, launch starts multiple nodes, the graph exposes /edge/tracer as std_msgs/msg/String, topic hz measures roughly 10 Hz, and rosbag records and replays 77 samples. Next I will turn that tracer into a fake sensor pipeline with explicit message contracts, metrics, health checks, and QoS experiments.
```

## Concept-To-Evidence Map

| Concept | Evidence from P0-003 |
| --- | --- |
| node | `tracer_publisher` and `tracer_subscriber` started by launch |
| topic | `/edge/tracer` appeared in `ros2 topic list -t` |
| message | `/edge/tracer [std_msgs/msg/String]` |
| launch | `ros2 launch edge_reliability_tracer tracer.launch.py` started both nodes |
| parameter | `config/tracer.yaml` controls `publish_hz` |
| timestamp | message data included `stamp_ns=...` |
| sequence_id | message data included `seq=...` |
| QoS | publisher/subscriber used `rclcpp::QoS(10)` |
| rosbag | `ros2 bag info` showed `77` recorded messages |

## Honest Boundaries

- I have not connected real sensors or motors yet.
- I have not built perception, navigation, or control yet.
- I have not used TF with real coordinate frames yet.
- I am deliberately starting with reproducible ROS 2 software loops before adding hardware complexity.

This is a strength, not a weakness: it shows I know robotics development should be staged, observable, and testable.
