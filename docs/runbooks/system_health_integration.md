# System Health Integration

P0-012 connects Jetson system metrics to the existing health monitor.

## What Runs

- `system_metrics_node` publishes `/edge/metrics/system` as `edge_reliability_msgs/msg/SystemMetrics`.
- `health_monitor` subscribes to `/edge/metrics/pipeline` and `/edge/metrics/system`.
- `health_monitor` publishes `/edge/health/state` as `edge_reliability_msgs/msg/HealthState`.

## Rule Families

Pipeline rules keep their P0-010 names:

- `receive_rate_warning`, `receive_rate_unhealthy`
- `drop_rate_warning`, `drop_rate_unhealthy`
- `p95_latency_warning`, `p95_latency_unhealthy`
- `p99_latency_warning`, `p99_latency_unhealthy`
- `out_of_order_unhealthy`

System rules use `system_*` names:

- `system_cpu_warning`, `system_cpu_unhealthy`
- `system_memory_warning`, `system_memory_unhealthy`
- `system_disk_warning`, `system_disk_unhealthy`
- `system_gpu_warning`, `system_gpu_unhealthy`
- `system_temperature_warning`, `system_temperature_unhealthy`
- `system_power_warning`, `system_power_unhealthy`

## Units

- CPU, memory, disk, and GPU thresholds are percentages.
- Temperature thresholds use Celsius.
- Power thresholds use watts.
- Memory percent is calculated from `memory_used_mb / memory_total_mb`.
- Disk percent comes from `SystemMetrics.disk_used_percent`, sampled from `disk_path`.

## Smoke Test

Run the P0-012 smoke on Jetson:

```bash
cd ~/chengwei
bash scripts/run_p0_012_system_health_smoke.sh
```

The smoke runs two scenarios:

- `health_monitor_system_nominal.yaml`, expected `HEALTHY`;
- `health_monitor_system_pressure.yaml`, expected `UNHEALTHY` with `system_temperature_unhealthy` or `system_power_unhealthy`.

The P0-012 smoke configs intentionally relax pipeline receive-rate and latency thresholds so this test isolates system-health behavior. P0-010 remains the strict pipeline health verification path.

Outputs stay under `runtime/results/`, `runtime/logs/`, and `runtime/artifacts/preflight/`.
