# P1-007 First Nav2 Failure Reproduction Report

Type: AFK

User stories covered: 7, 8, 14, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Reproduce and document at least one Nav2-style failure case using simulation, bag replay, or logs, focusing on diagnosis rather than visual polish.

## Acceptance criteria

- [ ] One failure case is selected from scan drop, TF missing, bad initial pose, costmap not updating, planner failure, or controller issue.
- [ ] Failure is reproduced or convincingly simulated with commands, logs, bag, or screenshots.
- [ ] Report explains expected behavior, observed behavior, diagnosis steps, evidence, and fix or mitigation.
- [ ] Relevant topics and commands are listed.
- [ ] Interview artifact explains how this maps to real robot navigation debugging.
- [ ] No claim is made that a real robot was used.

## Blocked by

- P1-006

## Verification commands

- Selected Nav2 launch or replay commands.
- `ros2 topic list`
- `ros2 topic echo /tf` or `tf2_echo` if available.
- `ros2 bag record <selected_topics>` where practical.

## Runtime artifact location

`runtime/bags/nav2/`, `runtime/logs/nav2/`, `runtime/artifacts/nav2_failure/`

## Cleanup and rollback

Remove only generated logs, bags, and local artifacts by default.

## Out of scope

- Five full navigation failure cases.
- Real robot navigation.
