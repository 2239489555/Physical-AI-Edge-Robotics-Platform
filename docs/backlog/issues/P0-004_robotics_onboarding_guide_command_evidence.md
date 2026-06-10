# P0-004 Robotics Onboarding Guide And Command Evidence

Type: HITL

User stories covered: 1, 14, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Turn the minimal ROS 2 slice into a beginner onboarding guide with command evidence and short explanations the user can later use in interviews.

## Acceptance criteria

- [ ] Guide explains node, topic, message, service, action, launch, parameter, QoS, timestamp, frame_id, sequence_id, TF, and rosbag in beginner terms.
- [ ] Guide includes exact commands from the minimal package.
- [ ] Evidence section records successful command outputs or sanitized summaries.
- [ ] `interview_artifacts.md` answers why each concept matters in robotics systems.
- [ ] User-facing explanations avoid pretending the user has prior robotics experience.

## Blocked by

- P0-003

## Verification commands

- Re-run the listed onboarding commands on Jetson or compatible ROS 2 environment.
- Manually explain the concepts without reading generated text verbatim.

## Runtime artifact location

`runtime/artifacts/onboarding/` for screenshots, sanitized command output, or small evidence files.

## Cleanup and rollback

Remove only onboarding evidence under runtime artifacts. Keep long-term docs.

## Out of scope

- Implementing production pipeline nodes.
- TensorRT, Nav2, or Isaac ROS.
