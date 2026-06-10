# M0 Robotics Onboarding

## Goal

Create the zero-baseline ROS 2 learning layer needed before building the Edge Robotics Reliability Lab.

## Context

The user has no prior robotics stack experience. This milestone prevents later implementation from becoming a pile of generated code that the user cannot explain.

## Inputs

- Jetson server.
- ROS 2 Humble target.
- C++17 and rclcpp target.

## Expected Outputs

- A minimal ROS 2 C++ package with publisher, subscriber, launch file, YAML config, and rosbag commands.
- Notes explaining ROS 2 node, topic, message, service, action, launch, parameter, QoS, timestamp, frame_id, sequence_id, and TF at beginner level.
- `interview_artifacts.md` explaining what was learned and why it matters.

## Technical Constraints

- Use ROS 2 Humble.
- Use C++17 and rclcpp for the runtime package.
- Keep generated runtime data under the project workspace.

## Acceptance Criteria

- The user can run a minimal publisher and subscriber.
- `ros2 topic list`, `ros2 topic echo`, `ros2 topic hz`, and `ros2 topic info` are demonstrated.
- A launch file starts both nodes.
- YAML parameters change publish frequency without recompilation.
- rosbag can record and replay the sample topic.
- The user can explain timestamp, sequence ID, and QoS at a beginner level.

## Verification Commands

- `colcon build`
- `ros2 launch <package> <launch_file>`
- `ros2 topic hz <topic>`
- `ros2 bag record <topic>`
- `ros2 bag play <bag_dir>`

## Runtime Artifact Location

Use project-local runtime directories for bags, logs, and temporary outputs.

## Cleanup and Rollback

Document any package installation or shell environment change. Cleanup should remove only project-local generated data by default.

## Interview Artifact Questions

- What is a ROS 2 node?
- What is the difference between topic, service, and action?
- Why do robotics messages need timestamps and frame IDs?
- How does rosbag help reproduce bugs?

## Out of Scope

- TensorRT.
- Nav2.
- Isaac ROS.
- Real hardware.
