# tegrastats System Metrics

P0-011 adds `edge_reliability_system`, a C++ ROS 2 package that parses Jetson `tegrastats` lines and publishes `/edge/metrics/system` as `edge_reliability_msgs/msg/SystemMetrics`.

`tegrastats` is the primary Jetson observability source for this project because it exposes embedded GPU, thermal, memory, and power information that `nvidia-smi` may not provide on Jetson.

## Modes

The `system_metrics_node` supports two input modes:

- `sample_file`: read saved tegrastats lines from `testdata/tegrastats_samples.txt`. This is the default smoke path and works even when live `tegrastats` is unavailable.
- `live_command`: run a bounded command such as `timeout 2s tegrastats --interval 1000` and parse the latest line.

Both modes can append raw input lines to project-local logs under:

```text
runtime/logs/tegrastats
```

## Published Topic

```text
/edge/metrics/system
```

Message type:

```text
edge_reliability_msgs/msg/SystemMetrics
```

Field mapping:

- `cpu_percent`: average of CPU percentages from the `CPU [...]` block.
- `memory_used_mb`: RAM used from `RAM used/totalMB`.
- `memory_total_mb`: RAM total from `RAM used/totalMB`.
- `gpu_percent`: `GR3D_FREQ` percentage when present.
- `temperature_c`: highest nonnegative temperature token.
- `power_w`: sum of current `VDD_*` and `VIN_*` rail values converted from mW to watts.
- `source`: `tegrastats_sample_file` or `tegrastats_live_command`.

## Run

```bash
cd ~/chengwei
bash scripts/run_p0_011_system_metrics_smoke.sh
```

Expected report:

```text
runtime/results/p0_011_smoke_report.txt
```

The smoke verifies:

- parser unit tests;
- `system_metrics_node` launch;
- `/edge/metrics/system` publishes `SystemMetrics`;
- sample-file values are nonzero and internally valid;
- raw tegrastats input is saved under `runtime/logs/tegrastats`;
- live `tegrastats` is probed and reported as `available`, `unavailable`, or `failed`.

Live `tegrastats` availability is useful evidence but not required for the P0-011 sample-file smoke to pass because the baseline previously observed that `tegrastats` might be missing.

## Local Report Verification

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_011_smoke_report.ps1 -ReportPath runtime\results\p0_011_smoke_report.txt
```

Completion gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_011_completion_gate.ps1 -ReportPath runtime\results\p0_011_smoke_report.txt
```

## Cleanup

Delete only P0-011 local runtime evidence:

```bash
rm -f runtime/results/p0_011_*
rm -f runtime/logs/p0_011_*
rm -f runtime/artifacts/preflight/p0_011_*
rm -f runtime/logs/tegrastats/p0_011_*
```

Do not remove global Jetson tooling or package installations.
