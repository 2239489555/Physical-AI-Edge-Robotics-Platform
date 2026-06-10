# Jetson Phase 2 Test Guide

Use this guide to verify P0-002: system baseline collector and change ledger.

## Dependency Policy

Do not install ROS 2 or other dependencies yet. First collect and review the system baseline.

This phase is read-only:

- No apt install.
- No apt upgrade or dist-upgrade.
- No apt source changes.
- No global pip install.
- No systemd or Docker configuration changes.

## Commands On Jetson

From the repository root:

```bash
git pull origin main
bash scripts/setup_runtime_dirs.sh
bash scripts/collect_system_baseline.sh --dry-run
bash scripts/collect_system_baseline.sh
bash scripts/summarize_system_baseline.sh
find runtime/artifacts/preflight -maxdepth 2 -type f | sort
git status --short --ignored
```

## Expected Results

- Dry-run prints commands and does not write system files.
- Real run writes raw outputs under `runtime/artifacts/preflight/<timestamp>/`.
- Summary script writes `SUMMARY.sanitized.md` under the newest preflight directory.
- `runtime/artifacts/preflight/` is ignored by git.
- `docs/system_baseline.md` exists as the sanitized summary template.
- `docs/system_change_log.md` exists as the global-change ledger.
- No dependencies are installed by this phase.

## What To Send Back

Do not paste raw logs if they contain company-sensitive details.

Send the contents of `SUMMARY.sanitized.md`, or this short summary:

```text
OS:
L4T:
JetPack:
CUDA:
TensorRT:
Python:
Docker:
NVIDIA container runtime:
nvpmodel:
Disk free:
RAM:
ROS 2 already installed? yes/no
Collector errors:
```

## Cleanup

To remove only local preflight artifacts:

```bash
rm -rf runtime/artifacts/preflight
```

Do not remove system packages or apt sources as part of this phase.
