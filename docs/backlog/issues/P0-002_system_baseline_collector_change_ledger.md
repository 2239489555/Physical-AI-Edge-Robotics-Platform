# P0-002 System Baseline Collector And Change Ledger

Status: ready for Jetson collection

Type: AFK

User stories covered: 3, 5, 11, 12, 21

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create a repeatable system inventory workflow that records the Jetson baseline and starts a change ledger before global changes are made.

## Acceptance criteria

- [x] A system baseline template exists for OS, kernel, architecture, L4T, JetPack, CUDA, TensorRT, cuDNN, VPI, Python, CMake, GCC, Docker, NVIDIA container runtime, nvpmodel, disk, memory, apt sources, and relevant environment variables.
- [x] A change ledger template exists with fields for date, command, reason, affected files or packages, verification, rollback, and risk.
- [x] A collector script or command list writes raw command outputs under `runtime/artifacts/preflight/`.
- [x] The collector avoids uploading or committing raw system output.
- [x] Documentation explains why Ubuntu 24.04, ROS 2 Jazzy, untracked dist-upgrade, and global pip changes are out of scope.
- [x] Running the collector is optional in non-Jetson environments and fails with a clear message if required commands are missing.

## Completion evidence

- Added sanitized baseline summary template: `docs/system_baseline.md`.
- Added global change ledger template: `docs/system_change_log.md`.
- Added read-only Jetson collector: `scripts/collect_system_baseline.sh`.
- Added sanitized summary helper: `scripts/summarize_system_baseline.sh`.
- Added Jetson phase 2 test guide: `docs/testing_jetson_phase2.md`.
- Collector supports `--help` and `--dry-run`.
- Collector writes raw outputs only under `runtime/artifacts/preflight/<timestamp>/`.
- Summary helper writes `SUMMARY.sanitized.md` under the selected preflight directory.
- Collector does not install packages, modify apt sources, change shell rc files, or write system directories.
- Jetson execution is still required before dependency installation decisions.

## Blocked by

- P0-001

## Verification commands

- `rg "System Baseline" docs`
- `rg "Change Ledger" docs`
- Run the collector in dry-run or help mode if implemented.

## Runtime artifact location

`runtime/artifacts/preflight/`

## Cleanup and rollback

Cleanup must delete only project-local preflight artifacts. It must not touch apt sources, shell rc files, or system packages.

## Out of scope

- Installing packages.
- Changing apt sources.
- Running dist-upgrade.
