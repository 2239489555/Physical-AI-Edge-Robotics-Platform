# P0-003 ROS 2 Workspace Bootstrap And Minimal C++ Slice

Status: completed

Type: AFK

User stories covered: 1, 4, 15, 16, 17

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create the initial ROS 2 workspace and a minimal C++ tracer slice that proves package build, launch, parameters, publisher/subscriber communication, topic tools, and rosbag basics.

## Acceptance criteria

- [x] `ros2_ws/src/` exists and follows ROS 2 workspace conventions.
- [x] A minimal C++ ROS 2 package builds with `colcon build`.
- [x] The package includes a publisher, subscriber, launch file, and YAML config.
- [x] Publish frequency is configurable without recompilation.
- [x] README or usage notes show `ros2 topic list`, `echo`, `hz`, `info`, `bag record`, and `bag play`.
- [x] Runtime bags and logs are written under project-local runtime paths.

## Completion evidence

- Added package: `ros2_ws/src/edge_reliability_tracer`.
- Jetson `colcon build --packages-select edge_reliability_tracer --symlink-install` completed with `Summary: 1 package finished [0.63s]`.
- `ros2 launch edge_reliability_tracer tracer.launch.py` started `tracer_publisher` and `tracer_subscriber`.
- Launch logs show publisher on `edge/tracer` at `10.00 Hz` and subscriber receiving `seq=0`.
- `ros2 topic list -t` showed `/edge/tracer [std_msgs/msg/String]`.
- `ros2 topic info /edge/tracer -v` showed one publisher and one subscription.
- `ros2 topic echo --once /edge/tracer std_msgs/msg/String` returned a tracer sample.
- `ros2 topic hz /edge/tracer` reported approximately `10.000 Hz`.
- `ros2 bag record /edge/tracer` wrote project-local bag data under `runtime/bags/p0-003/tracer_smoke`.
- `ros2 bag info` reported `77` messages for `/edge/tracer` with type `std_msgs/msg/String`.
- `ros2 bag play` opened the recorded bag for playback.
- `git status --short --ignored` showed generated ROS build outputs and runtime artifacts ignored: `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/`.

## Blocked by

- P0-001

## Verification commands

- `colcon build --packages-select edge_reliability_tracer --symlink-install`
- `ros2 launch edge_reliability_tracer tracer.launch.py`
- `ros2 topic list -t`
- `ros2 topic info /edge/tracer -v`
- `ros2 topic echo --once /edge/tracer std_msgs/msg/String`
- `ros2 topic hz /edge/tracer`
- `ros2 bag record /edge/tracer -o ../runtime/bags/p0-003/tracer_smoke`
- `ros2 bag info ../runtime/bags/p0-003/tracer_smoke`
- `ros2 bag play ../runtime/bags/p0-003/tracer_smoke`

## Runtime artifact location

`runtime/bags/`, `runtime/logs/`, `runtime/results/`

## Cleanup and rollback

Delete only workspace build outputs and runtime artifacts. Do not remove source packages.

## Out of scope

- Jetson tegrastats.
- Custom metrics.
- QoS stress experiments.
