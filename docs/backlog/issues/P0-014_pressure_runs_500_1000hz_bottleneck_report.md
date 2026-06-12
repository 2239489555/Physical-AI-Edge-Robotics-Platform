# P0-014 500/1000Hz Pressure Runs And Bottleneck Report

Type: AFK

Status: completed, Jetson verified 2026-06-12

User stories covered: 5, 6, 7, 17, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Extend QoS experiments with 500Hz and 1000Hz pressure runs that generate evidence and bottleneck explanations without treating high-frequency stability as a P0 pass gate.

## Acceptance criteria

- [x] Experiment runner includes 500Hz and 1000Hz scenarios.
- [x] CSV output is generated even when the pipeline cannot sustain the requested rate.
- [x] Report separates pass/fail P0 thresholds from pressure observations.
- [x] Report explains bottlenecks using receive rate, drop rate, latency, and Jetson system metrics.
- [x] QoS mismatch scenario is reproduced and explained.
- [x] No claim is made that 500Hz or 1000Hz must be stable for P0 completion.

## Implementation notes

- `scripts/run_p0_014_pressure_smoke.sh` runs 8 matched pressure scenarios: `500Hz/1000Hz x best_effort/reliable x depth 10/50`.
- The runner also runs 2 expected QoS mismatch scenarios: BestEffort publisher plus Reliable subscriber at 500Hz and 1000Hz.
- Pressure CSV output is written to `runtime/results/qos/p0_014_pressure_results.csv`.
- Pressure Markdown output is written to `runtime/results/qos/p0_014_pressure_report.md`.
- Per-scenario generated YAML stays under `runtime/tmp/p0-014/configs/`.
- Per-scenario launch logs stay under `runtime/logs/qos/`.
- `runtime/bags/qos/` is reserved, but the smoke runner intentionally avoids high-rate bag recording to keep company-server artifacts small.

## Jetson verification evidence

Returned P0-014 smoke evidence from Jetson HEAD `ad3144c` completed with `SMOKE_EXIT_STATUS=0`, no timeout after about 363 seconds, and no residual `fake_sensor_adapter`, `sensor_processor`, `system_metrics_node`, or related launch processes.

Summary:

- Build completed for `edge_reliability_msgs`, `edge_reliability_fake_sensor`, `edge_reliability_processor`, and `edge_reliability_system`.
- Unit tests completed with `Summary: 3 tests, 0 errors, 0 failures, 0 skipped`.
- scenario count: 10.
- pressure scenario count: 8.
- qos mismatch scenario count: 2.
- CSV output was written to `runtime/results/qos/p0_014_pressure_results.csv`.
- Markdown report was written to `runtime/results/qos/p0_014_pressure_report.md`.
- Runtime hygiene stayed clean: only ignored `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, and `runtime/` outputs were present.

Observed highlights:

- 500Hz matched QoS scenarios tracked target rate closely; depth 50 BestEffort still showed p99 latency pressure at 28.722ms.
- 1000Hz BestEffort depth 10 tracked the target rate with zero drop rate, while 1000Hz BestEffort depth 50 measured 933.616Hz (`target_ratio=0.934`), giving a concrete receive-rate shortfall example.
- 1000Hz Reliable depth 10 showed nonzero drop-rate evidence (`drop_rate=0.013389`), while Reliable depth 50 reached 1000.018Hz with zero drops in the returned run.
- QoS mismatch scenarios reproduced `RELIABILITY_QOS_POLICY` warnings with `received_count=0` for both 500Hz and 1000Hz, which is the expected compatibility failure.

## Blocked by

- P0-013

## Verification commands

- `bash scripts/run_p0_014_pressure_smoke.sh`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_014_pressure_runs.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_014_smoke_report.ps1 -ReportPath runtime\results\p0_014_smoke_report.txt`
- `ros2 topic hz <topic>`
- Inspect generated CSV and report.

## Runtime artifact location

`runtime/results/qos/`, `runtime/logs/qos/`, `runtime/bags/qos/`

## Cleanup and rollback

Remove only pressure-run outputs under runtime directories.

## Out of scope

- Real-time kernel tuning.
- Hard real-time guarantees.
