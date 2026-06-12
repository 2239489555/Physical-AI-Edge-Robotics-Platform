# QoS Experiment Runner

P0-013 runs the first bounded QoS experiment matrix for the fake sensor pipeline.

## Scope

The runner covers:

- 100Hz and 200Hz fake sensor rates;
- BestEffort and Reliable matched sensor QoS profiles;
- KeepLast depths 10 and 50;
- pipeline metrics plus available Jetson system metrics.

500Hz and 1000Hz pressure runs are intentionally left for P0-014.

## Run

On Jetson:

```bash
cd ~/chengwei
bash scripts/run_p0_013_qos_experiment_smoke.sh
```

The script writes:

- `runtime/results/qos/p0_013_qos_results.csv`
- `runtime/results/qos/p0_013_qos_report.md`
- scenario summaries under `runtime/results/qos/`
- launch logs under `runtime/logs/qos/`
- generated scenario YAML under `runtime/tmp/p0-013/configs/`

## CSV Columns

- `scenario_name`
- `frequency_hz`
- `sensor_qos_reliability`
- `processor_qos_reliability`
- `qos_depth`
- `receive_rate_hz`
- `drop_rate`
- `average_latency_ms`
- `p95_latency_ms`
- `p99_latency_ms`
- `cpu_percent`
- `memory_used_mb`
- `memory_total_mb`
- `temperature_c`
- `notes`

## Reading The Report

BestEffort is the default high-rate sensor profile because fresh data is usually more valuable than old queued data for many robotics streams.
Reliable can be appropriate when every message matters, but it can also create queueing pressure if a subscriber falls behind.
KeepLast depth is recorded because larger queues can absorb bursts while also increasing the amount of stale work a subscriber may process.
