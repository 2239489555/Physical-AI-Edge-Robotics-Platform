# P1-006 Nav2 And TurtleBot3 Feasibility Spike

Type: AFK

User stories covered: 8, 20, 24

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Run a bounded feasibility spike for TurtleBot3/Nav2 on the single Jetson, with a fallback to command-level, rosbag, or log-based validation if GUI simulation is too heavy.

## Acceptance criteria

- [ ] Feasibility report records whether TurtleBot3/Gazebo/Nav2 can run acceptably on the Jetson.
- [ ] Report distinguishes GUI feasibility from headless or bag-based validation.
- [ ] Key topics are identified: scan, odom, tf, cmd_vel, map, plan, local_plan, and costmap-related topics where available.
- [ ] Resource usage is recorded with tegrastats if a live run is attempted.
- [ ] Fallback path is documented if Gazebo or RViz is not practical.
- [ ] No x86 RTX workstation is assumed.

## Blocked by

- P0-018

## Verification commands

- Nav2/TurtleBot3 setup commands selected during the task.
- `ros2 topic list`
- `ros2 topic hz <topic>`
- `tegrastats`

## Runtime artifact location

`runtime/artifacts/nav2_spike/`, `runtime/logs/nav2/`

## Cleanup and rollback

Document installed packages and cleanup steps. Remove project-local logs and bags only by default.

## Out of scope

- Full autonomous navigation project.
- Real robot base.
