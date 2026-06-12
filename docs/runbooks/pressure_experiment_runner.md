# Pressure Experiment Runner

P0-014 runs bounded 500Hz and 1000Hz pressure scenarios for the fake sensor pipeline.

The goal is evidence, not a hard real-time guarantee. A pressure run can show receive-rate shortfall, nonzero drops, or latency spikes and still be a successful P0-014 run if the runner completes and writes the CSV/report artifacts.

## Jetson Command

```bash
cd ~/chengwei
bash scripts/run_p0_014_pressure_smoke.sh
```

## Outputs

- Smoke report: `runtime/results/p0_014_smoke_report.txt`
- CSV: `runtime/results/qos/p0_014_pressure_results.csv`
- Markdown report: `runtime/results/qos/p0_014_pressure_report.md`
- Per-scenario logs: `runtime/logs/qos/`
- Per-scenario generated YAML: `runtime/tmp/p0-014/configs/`
- Reserved bag directory: `runtime/bags/qos/`

The smoke runner does not record high-rate bags by default. This keeps artifacts small on the company Jetson. Use `runtime/bags/qos/` only for targeted manual captures.

## Scenario Shape

Pressure scenarios:

- 500Hz and 1000Hz
- BestEffort and Reliable matched publisher/subscriber QoS
- KeepLast depth 10 and 50

QoS mismatch scenarios:

- BestEffort publisher
- Reliable subscriber
- 500Hz and 1000Hz

The mismatch rows should show `received_count` equal to 0 while metrics still publish. That is expected because a Reliable subscriber is not compatible with a BestEffort publisher.

## Reading The CSV

Start with:

- `target_ratio`: `receive_rate_hz / frequency_hz`
- `rate_gap_hz`: requested rate minus measured receive rate
- `drop_rate` and `dropped_count`
- `p95_latency_ms` and `p99_latency_ms`

Then read system context:

- `cpu_percent`
- `memory_used_mb`
- `temperature_c`

System metrics are supporting evidence. They should not be treated as proof of a single bottleneck without matching communication symptoms.

## P0 Gate Separation

P0-014 passes when:

- the pressure matrix runs,
- CSV and Markdown outputs are produced,
- QoS mismatch is reproduced,
- runtime artifacts stay under project-local `runtime/` paths.

P0-014 does not require 500Hz or 1000Hz to be stable.
