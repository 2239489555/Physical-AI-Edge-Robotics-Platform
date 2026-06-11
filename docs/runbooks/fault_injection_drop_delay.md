# Fault Injection Drop And Delay

P0-009 adds two controlled fault scenarios for the fake sensor pipeline:

- drop injection in `fake_sensor_adapter`;
- subscriber processing delay in `sensor_processor`.

The goal is to compare normal vs fault behavior with project-local evidence. This runbook is intentionally scoped to simulation because the project has no physical sensors or robots yet.

## Fault Controls

Fake sensor drop injection:

- `drop_enabled`: enables synthetic sample drops.
- `drop_probability`: probability from `0.0` to `1.0` that a generated sample is skipped.
- `drop_seed`: deterministic random seed for repeatable runs.
- `fake_sensor_drop.yaml`: default P0-009 drop scenario with `drop_probability: 0.2`.

Subscriber delay injection:

- `processing_delay_enabled`: enables a sleep before the processor timestamps receipt.
- `processing_delay_ms`: processing delay added per received sample.
- `processor_delay.yaml`: default P0-009 delay scenario with `processing_delay_ms: 8.0`.

## Evidence To Collect

Run the smoke script on Jetson:

```bash
cd ~/chengwei
bash scripts/run_p0_009_fault_injection_smoke.sh
```

Expected report:

```text
runtime/results/p0_009_smoke_report.txt
```

Expected bag root:

```text
runtime/bags/p0-009
```

The report must include normal vs fault metrics:

- normal `drop_rate`;
- drop fault `drop_rate`;
- drop-rate increase;
- normal `p95_latency_ms`;
- delay fault `p95_latency_ms`;
- p95 latency increase;
- rosbag message counts for drop and delay scenarios.

## Expected Behavior

The normal scenario should show near-zero drops and approximately 100Hz receive rate.

The drop fault scenario should introduce sequence gaps. The processor should convert those gaps into increased `dropped_count` and `drop_rate`.

The subscriber delay scenario should keep samples flowing but increase `p95_latency_ms` and `p99_latency_ms`.

Both fault scenarios must be recorded under `runtime/bags/p0-009` so they can be replayed later without touching global system locations.

## Local Report Verification

After the Jetson agent returns `runtime/results/p0_009_smoke_report.txt`, verify it from Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_009_smoke_report.ps1 -ReportPath runtime\results\p0_009_smoke_report.txt
```

Use the completion gate when both implementation and returned Jetson evidence are present:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_009_completion_gate.ps1 -ReportPath runtime\results\p0_009_smoke_report.txt
```

## Cleanup

Delete only project-local artifacts for this scenario:

```bash
rm -rf runtime/bags/p0-009
rm -f runtime/results/p0_009_*
rm -f runtime/logs/p0_009_*
```

Do not delete shared ROS logs, apt caches, or system files for this task.
