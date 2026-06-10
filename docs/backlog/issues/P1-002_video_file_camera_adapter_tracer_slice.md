# P1-002 Video File Camera Adapter Tracer Slice

Type: AFK

User stories covered: 8, 9, 19, 20, 24

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Build a video-file camera adapter that publishes image data into the same style of observable ROS 2 pipeline, proving that a file can stand in for real camera hardware.

## Acceptance criteria

- [ ] Adapter reads a local video file from project-local runtime or a documented sample path.
- [ ] Adapter publishes image frames to a documented camera topic.
- [ ] Frame rate, loop behavior, frame_id, topic name, and QoS are configurable.
- [ ] Metrics record capture FPS, processing FPS where applicable, latency, and frame drops.
- [ ] README explains how this maps to future USB or CSI camera adapters.
- [ ] No real camera is required.

## Blocked by

- P1-001

## Verification commands

- `colcon build`
- `ros2 launch <package> <video_adapter_launch>`
- `ros2 topic hz <camera_topic>`
- `ros2 bag record <camera_topic>`

## Runtime artifact location

`runtime/datasets/`, `runtime/bags/`, `runtime/results/`

## Cleanup and rollback

Delete local videos, bags, and results only from runtime directories.

## Out of scope

- TensorRT inference.
- Real camera driver support.
