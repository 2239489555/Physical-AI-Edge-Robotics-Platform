# System Change Log

Record every global system change made on the company-owned Jetson server.

Do not use this log for project-local runtime artifacts under `runtime/`; those can be cleaned separately. Use this log for actions that affect the host outside the repository workspace.

## Change Entry Template

```text
Date:
Operator:
Task:
Command:
Reason:
Files changed:
Packages installed:
Packages removed:
Services changed:
Environment changed:
Verification:
Rollback:
Risk:
Notes:
```

## Entries

### 2026-06-10 - Planned ROS 2 Humble minimal install

```text
Date: 2026-06-10
Operator: User on Jetson
Task: P0-003 preparation - install minimal ROS 2 Humble runtime and development tools
Command:
  See docs/ros2_humble_install_plan.md.
Reason:
  Baseline summary shows ROS 2 and colcon are missing. P0-003 requires ROS 2 Humble, colcon, C++ build tooling, demo nodes, and rosbag-capable tooling.
Files changed:
  Expected system-level changes include apt source metadata, apt package database, and /opt/ros/humble.
Packages installed:
  Planned minimal set: ros-humble-ros-base, ros-dev-tools, ros-humble-demo-nodes-cpp, ros-humble-demo-nodes-py.
Packages removed:
  None planned.
Services changed:
  None planned.
Environment changed:
  No shell rc change planned. Source /opt/ros/humble/setup.bash manually during verification.
Verification:
  Run ros2 --help, colcon --version, demo_nodes_cpp talker/listener, ros2 topic list/echo/hz, and ros2 bag record/play after install.
Rollback:
  Do not rollback casually. If needed, plan explicit apt remove/purge after reviewing installed packages and impact on the company server.
Risk:
  Moderate. Adds ROS apt source and host packages, but does not upgrade Ubuntu, install ROS 2 Jazzy, or modify long-running services.
Notes:
  Run apt simulation before real install. Stop if apt proposes removing NVIDIA, CUDA, JetPack, or core system packages.
```

## Rules

- Record the change before or immediately after running it.
- Do not run `dist-upgrade` for this project.
- Do not upgrade Ubuntu to 24.04.
- Do not switch the main ROS target to ROS 2 Jazzy.
- Do not modify apt sources without recording why and how to roll back.
- Do not run global `pip install` into system Python without recording why and how to roll back.
- Prefer project-local outputs under `runtime/`.
- Prefer documented apt packages or NVIDIA-supported packages over random install scripts.
