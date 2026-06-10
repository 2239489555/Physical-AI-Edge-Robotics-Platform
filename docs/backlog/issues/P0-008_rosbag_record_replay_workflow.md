# P0-008 rosbag Record And Replay Workflow

Type: AFK

User stories covered: 6, 7, 8, 16, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Add a reproducible rosbag record and replay workflow for the fake sensor pipeline, proving that metrics can be reproduced from captured data.

## Acceptance criteria

- [ ] Record command or script stores bags under `runtime/bags/`.
- [ ] Replay command or script replays a recorded bag into the processor.
- [ ] README explains which topics to record for normal and fault cases.
- [ ] Bag naming convention includes scenario name and timestamp.
- [ ] Test report records at least one normal replay and whether metrics match within explainable tolerance.
- [ ] Large bags are excluded from git.

## Blocked by

- P0-007

## Verification commands

- `ros2 bag record <topics>`
- `ros2 bag play <bag_dir>`
- `ros2 topic echo <metrics_topic>`
- `git status --short` to confirm bags are ignored.

## Runtime artifact location

`runtime/bags/`, `runtime/results/`

## Cleanup and rollback

Use project-local cleanup only. Do not delete source or docs.

## Out of scope

- Public datasets.
- Nav2 bags.
- TensorRT inputs.
