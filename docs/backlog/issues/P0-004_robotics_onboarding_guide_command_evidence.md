# P0-004 Robotics Onboarding Guide And Command Evidence

Status: docs completed, user rehearsal pending

Type: HITL

User stories covered: 1, 14, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Turn the minimal ROS 2 slice into a beginner onboarding guide with command evidence and short explanations the user can later use in interviews.

## Acceptance criteria

- [x] Guide explains node, topic, message, service, action, launch, parameter, QoS, timestamp, frame_id, sequence_id, TF, and rosbag in beginner terms.
- [x] Guide includes exact commands from the minimal package.
- [x] Evidence section records successful command outputs or sanitized summaries.
- [x] `interview_artifacts.md` answers why each concept matters in robotics systems.
- [x] User-facing explanations avoid pretending the user has prior robotics experience.

## Completion evidence

- Added beginner guide: `docs/onboarding/ros2_beginner_onboarding.md`.
- Added interview artifacts: `docs/onboarding/interview_artifacts.md`.
- Added onboarding index: `docs/onboarding/README.md`.
- The guide maps P0-003 evidence to ROS 2 beginner concepts.
- The guide includes commands for `colcon build`, `ros2 launch`, `ros2 topic list/info/echo/hz`, `ros2 bag record`, `ros2 bag info`, and `ros2 bag play`.
- Evidence records the Jetson run: `Summary: 1 package finished`, `/edge/tracer [std_msgs/msg/String]`, `10.000 Hz`, `77` bag messages, and `runtime/bags/p0-003/tracer_smoke`.
- Added static verifier: `scripts/verify_p0_004_onboarding_docs.ps1`.
- Verifier passed locally with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_004_onboarding_docs.ps1`.

## HITL follow-up

The remaining human step is rehearsal: explain node, topic, message, launch, parameter, QoS, timestamp, frame_id, sequence_id, TF, and rosbag in your own words without reading the generated text verbatim.

## Blocked by

- P0-003

## Verification commands

- Re-run the listed onboarding commands on Jetson or compatible ROS 2 environment.
- Manually explain the concepts without reading generated text verbatim.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_004_onboarding_docs.ps1`

## Runtime artifact location

`runtime/artifacts/onboarding/` for screenshots, sanitized command output, or small evidence files.

## Cleanup and rollback

Remove only onboarding evidence under runtime artifacts. Keep long-term docs.

## Out of scope

- Implementing production pipeline nodes.
- TensorRT, Nav2, or Isaac ROS.
