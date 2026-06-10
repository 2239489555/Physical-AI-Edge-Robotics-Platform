# Jetson Phase 1 Test Guide

Use this guide after pulling the repository on the Jetson server to verify P0-001.

## Goal

Verify repository skeleton and runtime governance only.

This phase does not install ROS 2, build ROS packages, run tegrastats, or change system configuration.

## Commands

From the repository root on the Jetson:

```bash
git status --short
find docs -maxdepth 3 -type f | sort
find ros2_ws -maxdepth 3 -type f | sort
find scripts -maxdepth 2 -type f | sort
find tools -maxdepth 2 -type f | sort
bash scripts/setup_runtime_dirs.sh
find runtime -maxdepth 2 -type d | sort
git status --short --ignored
```

For local Windows verification before copying or pulling on the Jetson:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_runtime_dirs.ps1
Get-ChildItem -Directory runtime
git status --short --ignored
```

## Expected Results

- `docs/prd/Jetson_Physical_AI_PRD.md` exists.
- `docs/backlog/issues/INDEX.md` exists.
- `docs/runtime_governance.md` exists.
- `docs/adr/README.md` exists.
- `ros2_ws/src/README.md` exists.
- `scripts/setup_runtime_dirs.sh` exists.
- `scripts/setup_runtime_dirs.ps1` exists for local Windows verification.
- `tools/README.md` exists.
- `runtime/` is created by the script.
- `runtime/` contains `datasets`, `bags`, `logs`, `results`, `artifacts`, `cache`, and `tmp`.
- `runtime/` appears as ignored output in git status, not as a file to commit.

## Cleanup

To remove only phase-one runtime outputs:

```bash
rm -rf runtime
```

Do not run cleanup commands outside the repository root.
