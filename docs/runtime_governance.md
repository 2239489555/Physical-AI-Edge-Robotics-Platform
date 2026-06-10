# Runtime Governance

This project is developed locally and debugged on a company-owned Jetson server. Runtime artifacts must stay inside the repository workspace so the project can be audited and cleaned up without touching unrelated system files.

## Commit To Git

Commit long-lived, reviewable project assets:

- Source code.
- ROS 2 package manifests, launch files, and config files.
- Scripts and tools.
- PRD, backlog, ADRs, interface contracts, test reports, debug guides, and interview artifacts.
- Small sanitized CSV, JSON, or Markdown examples when they are useful for documentation.

## Keep Local Only

Do not commit bulky or sensitive runtime artifacts:

- `runtime/`
- rosbag files.
- Raw logs.
- downloaded datasets.
- diagnostic bundles.
- video files.
- TensorRT engines and model cache files.
- Docker build cache or generated images.

## Runtime Directory Layout

Create runtime directories with:

- `bash scripts/setup_runtime_dirs.sh` on Jetson/Linux.
- `powershell -ExecutionPolicy Bypass -File scripts/setup_runtime_dirs.ps1` on Windows.

```text
runtime/
|-- datasets/
|-- bags/
|-- logs/
|-- results/
|-- artifacts/
|-- cache/
`-- tmp/
```

## Company Server Rules

- Do not write project outputs to `/tmp`, `/var/log`, global downloads, or other untracked locations by default.
- Do not create systemd services or long-running global background processes during P0-001.
- Do not expose local dashboards or web services publicly by default.
- Do not commit hostnames, IPs, usernames, tokens, keys, or raw company logs.
- Cleanup scripts must default to project-local paths and must not delete outside the repository workspace.

## Phase P0-001 Scope

This phase creates only repository skeleton and governance files. It does not install ROS 2, create C++ packages, run Jetson commands, or modify system-level configuration.
