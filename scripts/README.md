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
