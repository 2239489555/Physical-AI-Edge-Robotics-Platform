# P0-018 P0 10-minute Gate Evidence Package

Type: HITL

User stories covered: 5, 6, 7, 17, 18, 20, 22

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Collect and review the P0 evidence package that proves the Edge Robotics Reliability Lab main loop works before P1 begins.

## Acceptance criteria

- [ ] 100Hz fake sensor pipeline runs for 10 minutes without crashing.
- [ ] Receive rate is at least 99Hz during the normal run.
- [ ] Normal-run drop rate is 0.
- [ ] p95 latency is at most 20ms during the normal run.
- [ ] p99 latency is at most 50ms during the normal run.
- [ ] Health remains healthy during the normal run.
- [ ] rosbag replay reproduces metrics within explainable tolerance.
- [ ] Dropped-frame, subscriber-delay, and QoS-mismatch fault evidence exists.
- [ ] tegrastats evidence exists.
- [ ] collect_logs and cleanup dry-run evidence exists.
- [ ] Gate report says pass, conditional pass, or fail with honest gaps.

## Blocked by

- P0-014
- P0-017

## Verification commands

Use the exact commands from P0 tasks and cite them in the gate report. Do not summarize without command evidence.

## Runtime artifact location

`runtime/artifacts/p0_gate/`

## Cleanup and rollback

Keep the long-term gate report in docs. Keep bulky evidence under runtime artifacts and out of git.

## Out of scope

- Starting TensorRT, Nav2, or Isaac ROS work.
- Creating resume claims before the gate outcome is known.
