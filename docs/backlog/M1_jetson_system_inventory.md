# M1 Jetson System Inventory

## Goal

Record a reliable Jetson system baseline and start a change ledger before installing or changing global dependencies.

## Context

The Jetson server is a company asset. Jetson software stacks are tightly coupled across L4T, JetPack, CUDA, TensorRT, cuDNN, VPI, ROS, and container runtime versions.

## Inputs

- Current Jetson system state.
- Existing PRD compatibility constraints.

## Expected Outputs

- System baseline document.
- System change log document.
- Preflight artifacts stored under the project workspace.
- Installation risk notes.

## Technical Constraints

- Do not upgrade Ubuntu.
- Do not switch to ROS 2 Jazzy.
- Do not run dist-upgrade.
- Do not perform untracked global pip or apt modifications.

## Acceptance Criteria

- OS, kernel, architecture, L4T, JetPack, CUDA, TensorRT, cuDNN, VPI, Python, CMake, GCC, Docker, NVIDIA container runtime, nvpmodel, disk, memory, and tegrastats baseline are recorded.
- apt sources and relevant NVIDIA/ROS packages are recorded.
- Shell environment changes relevant to CUDA or ROS are recorded.
- Change ledger format exists before further global changes.
- The user can explain why ROS 2 Humble is used and why tegrastats is primary for Jetson metrics.

## Verification Commands

- `uname -a`
- `cat /etc/nv_tegra_release`
- `dpkg-query --show nvidia-l4t-core`
- `nvcc --version`
- `python3 --version`
- `nvpmodel -q`
- `tegrastats`
- `df -h`
- `free -h`
- `apt-cache policy nvidia-jetpack`

## Runtime Artifact Location

Store raw command outputs under project-local runtime artifacts.

## Cleanup and Rollback

No cleanup should be needed for read-only inventory. If any command creates files, document the location and cleanup command.

## Interview Artifact Questions

- What is the relationship between JetPack, L4T, CUDA, and TensorRT?
- Why is Ubuntu 24.04 out of scope?
- Why is nvidia-smi insufficient on Jetson?

## Out of Scope

- Installing ROS 2.
- Building packages.
- Running long experiments.
