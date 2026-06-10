# P0-003 ROS 2 Workspace Bootstrap And Minimal C++ Slice

Type: AFK

User stories covered: 1, 4, 15, 16, 17

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create the initial ROS 2 workspace and a minimal C++ tracer slice that proves package build, launch, parameters, publisher/subscriber communication, topic tools, and rosbag basics.

## Acceptance criteria

- [ ] `ros2_ws/src/` exists and follows ROS 2 workspace conventions.
- [ ] A minimal C++ ROS 2 package builds with `colcon build`.
- [ ] The package includes a publisher, subscriber, launch file, and YAML config.
- [ ] Publish frequency is configurable without recompilation.
- [ ] README or usage notes show `ros2 topic list`, `echo`, `hz`, `info`, `bag record`, and `bag play`.
- [ ] Runtime bags and logs are written under project-local runtime paths.

## Blocked by

- P0-001

## Verification commands

- `colcon build`
- `ros2 launch <package> <launch_file>`
- `ros2 topic hz <topic>`
- `ros2 bag record <topic>`
- `ros2 bag play <bag_dir>`

## Runtime artifact location

`runtime/bags/`, `runtime/logs/`, `runtime/results/`

## Cleanup and rollback

Delete only workspace build outputs and runtime artifacts. Do not remove source packages.

## Out of scope

- Jetson tegrastats.
- Custom metrics.
- QoS stress experiments.
