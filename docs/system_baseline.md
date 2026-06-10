# System Baseline

Status: reviewed from sanitized summary

This document is the durable, sanitized summary of the Jetson system baseline. Raw command output belongs under `runtime/artifacts/preflight/` and must not be committed.

## Snapshot Metadata

| Field | Value |
| --- | --- |
| Baseline date | 2026-06-10 |
| Collected by | User on Jetson |
| Host label | Redacted or local-only |
| Raw artifact directory | `runtime/artifacts/preflight/20260610T042153Z/` |
| Summary reviewed | Yes |

## Hardware And OS

| Field | Value |
| --- | --- |
| Device | Jetson Orin series server |
| Architecture | arm64 |
| OS | Ubuntu 22.04.5 LTS |
| Kernel | Recorded in local raw artifact `00_uname.txt` |
| L4T | R36.4.3 |
| JetPack | JetPack 6.2 family, inferred from L4T R36.4.3 and project baseline |
| CPU | 12-core CPU, per project baseline |
| RAM | 61Gi total, 45Gi available |
| Disk free | 770G free on `/` |

## NVIDIA Stack

| Component | Version / Status |
| --- | --- |
| CUDA | 12.6 |
| TensorRT | 10.3.0.30-1+cuda12.5 |
| cuDNN | Not detected by summary helper |
| VPI | Not detected by summary helper |
| NVIDIA container toolkit | 1.16.2-1 |
| NVIDIA container runtime | Not detected by summary helper |
| nvpmodel | MAXN |
| tegrastats | Command failed or unavailable in collector run |

## ROS And Build Tooling

| Tool | Version / Status |
| --- | --- |
| ROS 2 | Missing or command failed |
| Python | Python 3.10.12 |
| pip | pip 25.1.1 from user-local Python site packages |
| CMake | 3.22.1 |
| GCC/G++ | 11.4.0 |
| colcon | Missing or command failed |

## Package Sources

Raw apt sources are intentionally not committed. Review local `15_apt_sources.txt` on the Jetson before adding ROS 2 sources. Redact internal mirrors, tokens, hostnames, or company-specific network details before committing any summary.

## Relevant Environment Variables

Raw environment output is intentionally not committed. Summary indicates no usable ROS 2 command was available during collection.

## Baseline Decision

Before installing dependencies, record the decision here:

- Proceed with ROS 2 Humble install: Yes, after logging the planned global change.
- Required precautions: Install only minimal ROS 2 Humble packages, run apt simulation first, do not upgrade Ubuntu, do not install ROS 2 Jazzy, and do not write to `.bashrc` yet.
- Known risks: Adding ROS apt source and installing deb packages changes host package state; tegrastats was not detected by the collector and needs follow-up after ROS baseline.
- Rollback or cleanup notes: Record installed packages in `docs/system_change_log.md`; remove packages only after explicit rollback review.

## Raw Artifact Handling

Raw outputs are local-only. Do not commit:

- hostnames
- IPs
- usernames
- internal apt mirrors
- raw logs
- diagnostic bundles
- tokens or keys
