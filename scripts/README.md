# Scripts

Project-level scripts live here.

P0 scripts should be company-server-friendly:

- Write outputs under `runtime/`.
- Avoid global system changes by default.
- Refuse unsafe cleanup paths.
- Print clear commands and paths.

Use `setup_runtime_dirs.sh` to create local runtime directories on a Jetson/Linux checkout.

Use `setup_runtime_dirs.ps1` for local Windows verification.

Use `collect_system_baseline.sh` on the Jetson before installing dependencies. It records read-only preflight output under `runtime/artifacts/preflight/`.

Use `summarize_system_baseline.sh` after collection to generate a sanitized summary that can be shared for dependency planning.

Use `summarize_apt_simulation.sh` after an `apt install -s ... | tee ...` dry run to extract removals, upgrades, watched package actions, and the final apt count before approving a host install.

Use `verify_ros2_minimal_slice.ps1` from Windows to statically verify the P0-003 minimal ROS 2 package files before the Jetson `colcon build`.

Use `verify_p0_004_onboarding_docs.ps1` from Windows to check that the P0-004 onboarding guide and interview artifacts cover the required beginner concepts, commands, and evidence.

Use `verify_p0_005_interface_contracts.ps1` from Windows to check that the P0-005 message package and interface contract cover required fields, topics, node roles, QoS, adapter boundaries, rosbag, and failure modes.

Use `verify_p0_006_fake_sensor_slice.ps1` from Windows to check that the P0-006 fake sensor package covers the 100Hz default, `SensorSample` topic contract, YAML parameters, QoS defaults, launch file, README commands, and runtime-artifact hygiene.

Use `run_p0_006_fake_sensor_smoke.sh` on Jetson to run the P0-006 build, launch, topic, frequency, and rosbag smoke check. It writes logs under `runtime/logs/`, command outputs under `runtime/results/`, and bags under `runtime/bags/p0-006/`.

Use `verify_p0_006_smoke_report.ps1` from Windows to check a returned P0-006 `runtime/results/p0_006_smoke_report.txt` before marking the issue complete.

Use `verify_p0_006_completion_gate.ps1` from Windows after a returned P0-006 report exists to run both the static implementation gate and the returned-report gate.

Use `verify_p0_007_processor_metrics_slice.ps1` from Windows to check that the P0-007 processor metrics package covers the `SensorSample` subscription, `PipelineMetrics` publication, QoS defaults, rolling rate/latency windows, unit-testable metric logic, launch/config files, README commands, and runtime-artifact hygiene.

Use `run_p0_007_processor_smoke.sh` on Jetson to run the P0-007 build, unit test, fake sensor launch, processor launch, topic, frequency, metrics echo, and rosbag smoke check. It writes logs under `runtime/logs/`, command outputs under `runtime/results/`, and bags under `runtime/bags/p0-007/`.

Use `verify_p0_007_smoke_report.ps1` from Windows to check a returned P0-007 `runtime/results/p0_007_smoke_report.txt` before marking the issue complete.

Use `verify_p0_007_completion_gate.ps1` from Windows after a returned P0-007 report exists to run both the static implementation gate and the returned-report gate.

Use `verify_p0_008_rosbag_workflow.ps1` from Windows to check that the P0-008 rosbag record/replay workflow covers project-local bag paths, scenario/timestamp naming, raw sensor recording, replay into `sensor_processor`, metrics comparison, report verification, and documentation.

Use `run_p0_008_rosbag_replay_smoke.sh` on Jetson to record a normal raw sensor bag under `runtime/bags/p0-008/`, stop the live fake sensor, replay the bag into `sensor_processor`, and compare replay metrics. It writes logs under `runtime/logs/` and command outputs under `runtime/results/`.

Use `verify_p0_008_smoke_report.ps1` from Windows to check a returned P0-008 `runtime/results/p0_008_smoke_report.txt` before marking the issue complete.

Use `verify_p0_008_completion_gate.ps1` from Windows after a returned P0-008 report exists to run both the static workflow gate and the returned-report gate.

Use `verify_p0_009_fault_injection.ps1` from Windows to check that the P0-009 drop and delay fault-injection slice covers YAML-configurable drop injection, subscriber delay injection, normal vs fault comparisons, rosbag evidence, and documentation.

Use `run_p0_009_fault_injection_smoke.sh` on Jetson to run normal, drop-fault, and subscriber-delay scenarios. It writes logs under `runtime/logs/`, command outputs under `runtime/results/`, and bags under `runtime/bags/p0-009/`.

Use `verify_p0_009_smoke_report.ps1` from Windows to check a returned P0-009 `runtime/results/p0_009_smoke_report.txt` before marking the issue complete.

Use `verify_p0_009_completion_gate.ps1` from Windows after a returned P0-009 report exists to run both the static fault-injection gate and the returned-report gate.
