# P0-008 rosbag Record And Replay Workflow

Type: AFK

Status: completed, Jetson verified on 2026-06-11

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

- [x] Record command or script stores bags under `runtime/bags/`.
- [x] Replay command or script replays a recorded bag into the processor.
- [x] README explains which topics to record for normal and fault cases.
- [x] Bag naming convention includes scenario name and timestamp.
- [x] Test report records at least one normal replay and whether metrics match within explainable tolerance.
- [x] Large bags are excluded from git.

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

## Implementation evidence

- Runbook: `docs/runbooks/rosbag_record_replay_workflow.md`.
- Jetson smoke script: `scripts/run_p0_008_rosbag_replay_smoke.sh`.
- Returned-report verifier: `scripts/verify_p0_008_smoke_report.ps1`.
- Completion gate: `scripts/verify_p0_008_completion_gate.ps1`.
- Normal replay bag path convention: `runtime/bags/p0-008/normal_replay_<UTC timestamp>`.
- Replay evidence compares `received_count`, `receive_rate_hz`, `drop_rate`, and `out_of_order_count`.

## Jetson verification evidence

Verified on Jetson on 2026-06-11 with `SMOKE_EXIT_STATUS=0`; `timeout 180s` did not trigger.

- Build: `colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor --symlink-install` completed with `Summary: 3 packages finished [1.63s]`.
- Unit tests: `colcon test --packages-select edge_reliability_processor` completed with `Summary: 3 tests, 0 errors, 0 failures, 0 skipped`.
- Record: `runtime/bags/p0-008/normal_replay_20260611T023316Z` captured `/edge/sensors/fake_primary` only.
- Bag contents: 764 `edge_reliability_msgs/msg/SensorSample` messages over 7.630289390s.
- Replay: `ros2 bag play` drove `sensor_processor`, which published 12 `PipelineMetrics` samples.
- Metrics match: replay `received_count` was 763 of 764 recorded samples, `replay receive ratio: 0.999`, `receive_rate_hz: 99.989`, `drop_rate: 0.000000`, and `out_of_order_count: 0`.
- Replay latency note: replay latency fields were about 16.9s because `SensorSample.header.stamp` keeps the original record-time wall clock; P0-008 intentionally validates count/rate/drop/order, not live publish-to-receive latency.
- Runtime hygiene: only ignored `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/` outputs were produced, with no residual fake sensor, processor, or rosbag processes.

## Runtime artifact location

`runtime/bags/`, `runtime/results/`

## Cleanup and rollback

Use project-local cleanup only. Do not delete source or docs.

## Out of scope

- Public datasets.
- Nav2 bags.
- TensorRT inputs.
