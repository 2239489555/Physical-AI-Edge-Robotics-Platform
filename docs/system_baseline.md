# System Baseline

Status: template

This document is the durable, sanitized summary of the Jetson system baseline. Raw command output belongs under `runtime/artifacts/preflight/` and must not be committed.

## Snapshot Metadata

| Field | Value |
| --- | --- |
| Baseline date | TBD |
| Collected by | TBD |
| Host label | Redacted or local-only |
| Raw artifact directory | `runtime/artifacts/preflight/<timestamp>/` |
| Summary reviewed | No |

## Hardware And OS

| Field | Value |
| --- | --- |
| Device | TBD |
| Architecture | TBD |
| OS | TBD |
| Kernel | TBD |
| L4T | TBD |
| JetPack | TBD |
| CPU | TBD |
| RAM | TBD |
| Disk free | TBD |

## NVIDIA Stack

| Component | Version / Status |
| --- | --- |
| CUDA | TBD |
| TensorRT | TBD |
| cuDNN | TBD |
| VPI | TBD |
| NVIDIA container runtime | TBD |
| nvpmodel | TBD |
| tegrastats | TBD |

## ROS And Build Tooling

| Tool | Version / Status |
| --- | --- |
| ROS 2 | TBD |
| Python | TBD |
| pip | TBD |
| CMake | TBD |
| GCC/G++ | TBD |
| colcon | TBD |

## Package Sources

Summarize apt sources here after reviewing raw artifacts. Redact internal mirrors, tokens, hostnames, or company-specific network details before committing.

## Relevant Environment Variables

Summarize only relevant ROS/CUDA/build environment variables. Do not commit secrets.

## Baseline Decision

Before installing dependencies, record the decision here:

- Proceed with ROS 2 Humble install: TBD
- Required precautions: TBD
- Known risks: TBD
- Rollback or cleanup notes: TBD

## Raw Artifact Handling

Raw outputs are local-only. Do not commit:

- hostnames
- IPs
- usernames
- internal apt mirrors
- raw logs
- diagnostic bundles
- tokens or keys
