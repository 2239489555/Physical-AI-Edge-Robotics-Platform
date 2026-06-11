# Rosbag Record And Replay Workflow

P0-008 defines the normal replay workflow for the fake sensor pipeline.

The goal is to prove that a captured input stream can reproduce processor metrics without real hardware. The workflow records raw sensor inputs, stops the live publisher, starts the processor, and replays the recorded bag into the processor.

## Bag Naming

Bags are stored under:

```text
runtime/bags/p0-008/<scenario name>_<timestamp>
```

The default scenario name is `normal_replay`. The timestamp is UTC in `YYYYMMDDTHHMMSSZ` form. Scenario names should use letters, numbers, dots, underscores, or dashes.

## Normal Replay

For normal replay, record `/edge/sensors/fake_primary` only.

Rule: record /edge/sensors/fake_primary only for the replay input bag.

```bash
ros2 bag record /edge/sensors/fake_primary -o runtime/bags/p0-008/normal_replay_YYYYMMDDTHHMMSSZ
```

Then stop the live fake sensor before replaying:

```bash
ros2 launch edge_reliability_processor processor.launch.py
ros2 bag play runtime/bags/p0-008/normal_replay_YYYYMMDDTHHMMSSZ
```

Do not replay `/edge/metrics/pipeline` while `sensor_processor` is publishing. Replaying the metrics topic at the same time would create multiple metrics publishers and make the evidence ambiguous.

Rule: do not replay /edge/metrics/pipeline while sensor_processor is publishing.

## Evidence Topics

Use these topic sets:

- Normal reproducibility bag: `/edge/sensors/fake_primary`.
- Live observation bag: `/edge/sensors/fake_primary` and `/edge/metrics/pipeline`.
- Future fault cases: record the raw fault-injected sensor topic first, then optionally record `/edge/metrics/pipeline` and `/edge/health/state` in a separate evidence bag.

## Expected Result

On replay, `sensor_processor` should publish `/edge/metrics/pipeline`.

For the P0-008 smoke check:

- `received_count` should be at least 90% of the recorded sensor message count.
- `received_count` should not exceed recorded sensor messages by more than 5.
- `drop_rate` should be less than or equal to 0.05.
- `out_of_order_count` should be 0 for normal replay.
- `receive_rate_hz` should be close to 100Hz.

The 90% tolerance exists because short ROS graph startup windows and best-effort sensor QoS can lose edge samples without invalidating the replay concept. Larger divergence should be investigated before moving to fault cases.

## One-Command Smoke

From the repository root on Jetson:

```bash
bash scripts/run_p0_008_rosbag_replay_smoke.sh
```

The script writes bags under `runtime/bags/p0-008`, logs under `runtime/logs`, and comparison output under `runtime/results`.

To set a scenario name:

```bash
P0_008_SCENARIO=normal_replay bash scripts/run_p0_008_rosbag_replay_smoke.sh
```

## Git Hygiene

Large bags stay ignored by git. Check with:

```bash
git status --short --ignored
```

Expected runtime outputs are ignored under `runtime/`, `ros2_ws/build/`, `ros2_ws/install/`, and `ros2_ws/log/`.
