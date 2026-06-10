# P1-004 TensorRT Inference Node Vertical Slice

Type: AFK

User stories covered: 4, 5, 8, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Implement the first TensorRT perception tracer slice: consume image input, run preprocess, inference, and postprocess, and publish detections or debug output with metrics.

## Acceptance criteria

- [ ] Node consumes the documented camera or image topic.
- [ ] Node loads a TensorRT engine or documented inference artifact from runtime cache.
- [ ] Node publishes detections, debug image, or equivalent perception output.
- [ ] Metrics include preprocess latency, inference latency, postprocess latency, end-to-end latency, and FPS.
- [ ] FP32 and FP16 modes are supported if the selected model and platform allow it.
- [ ] tegrastats is captured during inference.
- [ ] README explains TensorRT advantages and limitations relative to CPU or PyTorch-style inference.

## Blocked by

- P1-003

## Verification commands

- `colcon build`
- TensorRT engine build command.
- `ros2 launch <package> <inference_launch>`
- `ros2 topic echo <perception_metrics_topic>`
- `tegrastats`

## Runtime artifact location

`runtime/cache/models/`, `runtime/results/tensorrt/`, `runtime/logs/tensorrt/`

## Cleanup and rollback

Delete generated engines, downloaded models, logs, and results only from runtime directories.

## Out of scope

- Training models.
- Isaac ROS DNN inference.
- Real camera requirement.
