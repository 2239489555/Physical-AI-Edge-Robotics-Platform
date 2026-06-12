# Runtime Lifecycle Scripts

P0-015 provides project-local start and stop scripts for the P0 runtime pipeline.

These scripts are intentionally not system services. They do not install systemd units, modify shell rc files, or write logs outside the repository runtime directory.

## Start

```bash
cd ~/chengwei
bash scripts/start_runtime.sh
```

The start script launches:

- `fake_sensor_adapter`
- `sensor_processor`
- `system_metrics_node`
- `health_monitor`

It writes process metadata to `runtime/run/p0_runtime/manifest.tsv` and logs to `runtime/logs/runtime/`.

The script waits for these topics before declaring success:

- `/edge/sensors/fake_primary`
- `/edge/metrics/pipeline`
- `/edge/metrics/system`
- `/edge/health/state`

## Stop

```bash
cd ~/chengwei
bash scripts/stop_runtime.sh
```

The stop script reads only `runtime/run/p0_runtime/manifest.tsv` and stops only the recorded process trees. It archives the manifest after stopping so the PID evidence remains available for diagnostics.

## Verification

```bash
bash scripts/run_p0_015_runtime_lifecycle_smoke.sh
```

The smoke script builds the P0 packages, starts the runtime, verifies ROS nodes and topics, receives one health message, stops the runtime, and checks that all manifest PIDs are stopped.

## Known Limitations

- The scripts assume ROS 2 Humble is available at `/opt/ros/humble/setup.bash`.
- The scripts assume the workspace has already been built and `ros2_ws/install/setup.bash` exists.
- They manage only processes they started through the manifest.
- They do not claim to supervise or restart crashed nodes.
- They are not a replacement for production service management.

## Runtime Paths

- PID manifest: `runtime/run/p0_runtime/manifest.tsv`
- Status file: `runtime/run/p0_runtime/status.txt`
- Logs: `runtime/logs/runtime/`
- Smoke report: `runtime/results/p0_015_smoke_report.txt`
