# P0-001 Repository Skeleton And Runtime Governance

Status: completed

Type: AFK

User stories covered: 2, 3, 13, 16, 21

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create the project skeleton that keeps source, docs, tools, ROS 2 packages, and disposable runtime artifacts in clearly separated locations. This slice should make the repository safe to use on a company-owned Jetson before any ROS code is added.

## Acceptance criteria

- [x] Repository contains the expected long-term directories for PRD, backlog, agent docs, future ADRs, ROS workspace, scripts, tools, and runtime outputs.
- [x] `runtime/` and large robotics artifacts are ignored by git.
- [x] `runtime/` contains documented subdirectories for datasets, bags, logs, results, artifacts, cache, and tmp, either through placeholder docs or setup script behavior.
- [x] README links to the PRD, roadmap, issue index, and competency matrix.
- [x] A runtime governance note explains which files are allowed in git and which must stay local.
- [x] No system-level directories are created or modified by this task.

## Completion evidence

- Added repository skeleton docs and tracked placeholder READMEs for `docs/adr/`, `ros2_ws/src/`, `scripts/`, and `tools/`.
- Added `docs/runtime_governance.md`.
- Added Jetson/Linux runtime setup script: `scripts/setup_runtime_dirs.sh`.
- Added Windows local verification runtime setup script: `scripts/setup_runtime_dirs.ps1`.
- Verified `runtime/` creation locally with `powershell -ExecutionPolicy Bypass -File scripts\setup_runtime_dirs.ps1`.
- Verified generated runtime subdirectories: `datasets`, `bags`, `logs`, `results`, `artifacts`, `cache`, and `tmp`.
- Verified `runtime/` appears as ignored output in `git status --short --ignored`.
- No system-level directories or configuration were modified.

## Blocked by

None - can start immediately.

## Verification commands

- `rg --files`
- `git status --short`
- Manual check that `.gitignore` excludes `runtime/`, bags, logs, datasets, artifacts, videos, model engines, and ROS build outputs.

## Runtime artifact location

No bulky runtime artifacts should be created. If placeholder files are needed, keep them small and commit-safe.

## Cleanup and rollback

Remove only directories and placeholder files created by this task. Do not delete existing user files.

## Out of scope

- Installing ROS 2.
- Creating C++ packages.
- Running Jetson commands.
