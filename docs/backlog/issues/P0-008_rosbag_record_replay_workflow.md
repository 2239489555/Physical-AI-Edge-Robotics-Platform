# P0-008 rosbag Record And Replay Workflow

Type: AFK

User stories covered: 6, 7, 8, 16, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Add a reproducible rosbag record and replay workflow for the fake sensor pipeline, proving that metrics can be reproduced from captured data.

## Implementation notes

- Main workflow doc: `docs/runbooks/rosbag_record_replay_workflow.md`.
- Jetson smoke script: `scripts/run_p0_008_rosbag_replay_smoke.sh`.
- Default scenario: `normal_replay`.
- Default bag path: `runtime/bags/p0-008/<scenario>_<UTC timestamp>`.
- Normal replay records `/edge/sensors/fake_primary` only, then replays that bag into `sensor_processor` and compares `/edge/metrics/pipeline`.
- Completion requires returned Jetson smoke evidence from `scripts/run_p0_008_rosbag_replay_smoke.sh`.

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

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_008_rosbag_workflow.ps1`
- `ros2 bag record <topics>`
- `ros2 bag play <bag_dir>`
- `ros2 topic echo <metrics_topic>`
- `bash scripts/run_p0_008_rosbag_replay_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_008_smoke_report.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_008_completion_gate.ps1`
- `git status --short` to confirm bags are ignored.

## Runtime artifact location

`runtime/bags/`, `runtime/results/`

## Cleanup and rollback

Use project-local cleanup only. Do not delete source or docs.

## Out of scope

- Public datasets.
- Nav2 bags.
- TensorRT inputs.
