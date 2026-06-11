# Health Monitor Thresholds

P0-010 adds `edge_reliability_health`, a C++ ROS 2 package that turns `/edge/metrics/pipeline` into `/edge/health/state`.

The monitor publishes `edge_reliability_msgs/msg/HealthState` and uses configurable thresholds so normal and injected-fault behavior can be explained in interviews and reproduced on Jetson.

## Topics

Input:

```text
/edge/metrics/pipeline
```

Output:

```text
/edge/health/state
```

## Default Thresholds

The default P0 thresholds are tuned from the P0-009 Jetson evidence:

- normal 100Hz run: `drop_rate: 0.000000`, p95 latency around 0.580ms;
- drop fault: `drop_rate: 0.192000`;
- delay fault: p95 latency around 8.436ms.

Default health thresholds:

- `min_receive_rate_hz_warning: 95.0`
- `min_receive_rate_hz_unhealthy: 80.0`
- `max_drop_rate_warning: 0.001`
- `max_drop_rate_unhealthy: 0.01`
- `max_p95_latency_ms_warning: 5.0`
- `max_p95_latency_ms_unhealthy: 20.0`
- `max_p99_latency_ms_warning: 10.0`
- `max_p99_latency_ms_unhealthy: 50.0`

Expected default outcomes:

- normal HEALTHY;
- drop fault UNHEALTHY;
- delay fault WARNING.

## Rule Names

Active rule names are included in `HealthState.active_rules`:

- `metrics_warmup`
- `receive_rate_warning`
- `receive_rate_unhealthy`
- `drop_rate_warning`
- `drop_rate_unhealthy`
- `p95_latency_warning`
- `p95_latency_unhealthy`
- `p99_latency_warning`
- `p99_latency_unhealthy`
- `out_of_order_unhealthy`

If any unhealthy rule is active, the state is `UNHEALTHY`. Otherwise, if any warning rule is active, the state is `WARNING`. If no rules are active, the state is `HEALTHY`.

## Run

```bash
cd ~/chengwei
bash scripts/run_p0_010_health_monitor_smoke.sh
```

Expected report:

```text
runtime/results/p0_010_smoke_report.txt
```

Local report verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_010_smoke_report.ps1 -ReportPath runtime\results\p0_010_smoke_report.txt
```

Completion gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_010_completion_gate.ps1 -ReportPath runtime\results\p0_010_smoke_report.txt
```

## Cleanup

Delete only P0-010 local runtime evidence:

```bash
rm -f runtime/results/p0_010_*
rm -f runtime/logs/p0_010_*
rm -f runtime/artifacts/preflight/p0_010_*
```

Do not delete bags from previous tasks or global ROS files.
