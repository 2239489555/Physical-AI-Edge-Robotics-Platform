# M7 Edge Runtime Scripts

## Goal

Create company-server-friendly project-local runtime scripts for start, stop, health check, log collection, and cleanup.

## Context

The project must behave like an edge runtime without polluting a company-owned Jetson server. systemd and Docker are allowed later as templates, but P0 should first prove controlled scripts.

## Progress Notes

- P0-015 project-local start/stop runtime scripts are completed and Jetson verified on 2026-06-12.
- The verified lifecycle starts `fake_sensor_adapter`, `sensor_processor`, `system_metrics_node`, and `health_monitor`, writes logs under `runtime/logs/runtime/`, stores PID state under `runtime/run/p0_runtime/`, and stops only manifest-recorded process trees.

## Inputs

- P0 ROS 2 pipeline.
- Metrics and health topics.
- Jetson monitor logs.
- Runtime governance rules.

## Expected Outputs

- Start script.
- Stop script.
- Health check script.
- Collect logs script.
- Cleanup artifacts script with dry-run default.
- Redaction or exclusion support for diagnostic bundles.
- Cleanup and rollback documentation.

## Technical Constraints

- Scripts must not delete or write outside the project workspace by default.
- No default long-lived global service.
- No default public web service.
- Diagnostic bundles must not be committed to git.

## Acceptance Criteria

- Start script launches the P0 pipeline.
- Stop script stops project-started processes.
- Health check reports node, topic, frequency, latency, system metrics, disk space, and health state where available.
- Collect logs bundles logs, configs, system info, and sample results under project-local runtime artifacts.
- Cleanup script defaults to dry-run and only targets project-local runtime artifacts.
- Documentation explains rollback and any global changes.

## Verification Commands

- `scripts/start.sh` or platform equivalent.
- `scripts/stop.sh` or platform equivalent.
- `scripts/health_check.sh` or platform equivalent.
- `scripts/collect_logs.sh` or platform equivalent.
- `scripts/cleanup_artifacts.sh --dry-run` or platform equivalent.

## Runtime Artifact Location

Use project-local runtime directories only.

## Cleanup and Rollback

Document every global change. If no global change is made, state that explicitly.

## Interview Artifact Questions

- What makes this company-server-friendly?
- How would a remote engineer use the diagnostic bundle?
- What is safe to delete at the end of the project?

## Out of Scope

- Installing permanent systemd services by default.
- Creating Docker images as a P0 gate.
- Public network exposure.
