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
