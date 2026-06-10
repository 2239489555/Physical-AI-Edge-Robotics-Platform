# Jetson-based Physical AI Edge Robotics Platform PRD

Agent execution version. The DOCX in this directory remains the human reading and archive version.

## Problem Statement

The user has six years of software development experience, including Java, C++, multi-language development, and recent work with Codex, Claude Code, Cursor, and similar AI coding agents. The user wants to prepare for a future Physical AI and Robotics Software Engineer job market, where value shifts from writing ordinary software to making AI-controlled physical systems run reliably.

The user is starting from zero robotics experience. They have not previously worked with ROS 2, Nav2, Gazebo, Isaac ROS, robot sensors, robot coordinate frames, or robotics debugging workflows. They are learning outside regular work hours, but can usually invest more than 10 hours per week when work allows.

The current available resource envelope is intentionally narrow:

- One company-owned Jetson Orin series server.
- 64GB RAM and 12-core CPU.
- Ubuntu 22.04.5, L4T R36.4.3, JetPack 6.2, CUDA 12.6.
- No real robot, camera, LiDAR, IMU, chassis, manipulator, or dedicated x86 RTX workstation.
- Visual output is possible through an external display, browser, Cursor, or SSH port forwarding, but must not be required for core validation.

The core product problem is: how can the user build job-relevant Physical AI and edge robotics system engineering ability with only one Jetson server and no robotics hardware, while keeping company asset safety, cleanup, reproducibility, and interview readiness as first-class requirements?

## Solution

Build an Edge Robotics Reliability Lab on the Jetson server.

The main demo is not a toy robot and not a general ROS tutorial. It is a reliability-centered edge robotics lab that proves the user can design, run, observe, break, reproduce, diagnose, package, and explain a robotics-style edge system.

Core P0 loop:

1. Fake or replayed sensor input.
2. ROS 2 Humble C++ data pipeline.
3. Metrics for publish rate, receive rate, drop rate, avg latency, p95 latency, and p99 latency.
4. Jetson system monitoring through tegrastats.
5. Fault injection for dropped frames, subscriber delay, QoS mismatch, and system pressure.
6. rosbag record and replay for reproduction.
7. Health state reporting.
8. Project-local logs, results, bags, and diagnostic bundles.
9. Company-server-friendly start, stop, health check, cleanup, and collect logs scripts.
10. Interview artifacts that explain the engineering story in human terms.

North Star Acceptance:

At the end of the project, the user can start a Jetson-hosted ROS 2 edge runtime, demonstrate sensor or video input, metrics, tegrastats monitoring, fault injection, rosbag reproduction, health checks, log collection, cleanup, and at least one P1 enhancement. The user can explain the architecture, tradeoffs, failure diagnosis, performance evidence, and path from simulation to real hardware in a three-minute demo and interview narrative.

P0 success is not "all modules completed". P0 success is a complete, verifiable reliability loop. TensorRT, Nav2, and Isaac ROS are enhancements after the P0 gate.

## User Stories

1. As a robotics beginner, I want a zero-baseline onboarding path, so that I can understand ROS 2 concepts before building a larger system.
2. As a learner with only one Jetson server, I want the project to avoid extra hardware assumptions, so that I can complete meaningful work without buying a robot or sensors.
3. As a company-server user, I want all generated artifacts kept under the project workspace, so that the server can be audited and cleaned later.
4. As a future Robotics Software Engineer candidate, I want to build ROS 2 nodes in C++17, so that the project trains skills expected in robotics runtime work.
5. As a future Edge AI Engineer candidate, I want Jetson metrics connected to ROS 2, so that I can reason about CPU, GPU, RAM, temperature, power, and runtime bottlenecks.
6. As a future Physical AI engineer, I want a fake sensor pipeline with timestamps and sequence IDs, so that I can learn data continuity, latency, drop detection, and health monitoring.
7. As a reliability engineer, I want fault injection, so that normal and abnormal behavior can both be tested and explained.
8. As a user without real sensors, I want video files, public bags, and simulation data to stand in for hardware, so that I can build toward real hardware boundaries without pretending fake data is enough.
9. As a system integrator, I want stable adapter boundaries, so that fake inputs can later be replaced by USB camera, CSI camera, LiDAR, IMU, or base driver adapters.
10. As a developer, I want every ROS 2 package to document node contracts, so that topics, QoS, parameters, metrics, logs, health rules, and bag requirements are explicit.
11. As a maintainer, I want every phase to include cleanup and rollback notes, so that system changes are not forgotten.
12. As a company-server user, I want system baseline and change ledger files, so that every global change can be justified and reversed.
13. As a project owner, I want runtime artifacts excluded from git, so that bags, logs, videos, and datasets do not pollute the repository.
14. As a learner, I want each milestone to produce interview artifacts, so that engineering work becomes explainable job-readiness material.
15. As an agent user, I want a Markdown PRD, so that Codex, Claude Code, Cursor, and future agents can read a diffable source of truth.
16. As an agent user, I want AFK-ready backlog items, so that a coding agent can implement a bounded task without guessing scope.
17. As a tester, I want automatic tests for pure logic and scripted smoke tests for runtime behavior, so that the project is not only manually verified.
18. As a Jetson operator, I want hardware-specific acceptance kept separate from generic CI, so that GPU and tegrastats behavior is verified on the real server.
19. As a demo presenter, I want optional visual output through browser, dashboard, display, or forwarded ports, so that the project is easier to show without making visuals a pass/fail dependency.
20. As a future interviewer, I want clear evidence for each claim, so that "I built this" means the user can show commands, logs, CSV, bags, reports, and tradeoff explanations.
21. As a security-conscious user, I want logs and screenshots redacted before public sharing, so that company information is not exposed.
22. As a project maintainer, I want a phase gate before P1 work, so that TensorRT, Nav2, or Isaac ROS cannot distract from the P0 reliability loop.
23. As a learner with variable time, I want task-based progress rather than week-based pressure, so that progress pauses and resumes cleanly.
24. As a future hardware integrator, I want the core pipeline independent of concrete hardware drivers, so that real sensors can be connected through adapters later.
25. As a portfolio builder, I want a final demo video and story bank, so that the project can become a credible GitHub and interview asset.

## Implementation Decisions

- The primary product is the Edge Robotics Reliability Lab.
- The roadmap is milestone-gated, not week-gated. The original 20-week plan is only a reference cadence.
- P0 is mandatory and must complete before TensorRT, Nav2, or Isaac ROS receives serious implementation time.
- P0 includes robotics onboarding, Jetson system inventory, ROS 2 Humble baseline, 100Hz fake sensor pipeline, metrics, health monitor, tegrastats monitor, QoS and latency lab, project-local runtime scripts, and a P0 phase gate.
- P0 does not require real cameras, real robots, LiDAR, IMU, manipulator hardware, x86 RTX workstation, Isaac Sim, or any additional purchased hardware.
- P0 must be headless-verifiable through CLI, logs, CSV, rosbag, Markdown reports, health checks, and diagnostic bundles.
- Visual output is allowed as an enhancement through external display, HTML dashboard, Cursor, browser, or SSH port forwarding.
- A lightweight HTML dashboard is P0.5, not a P0 pass condition.
- P1 priority is TensorRT perception on Jetson. Nav2 is secondary. Isaac ROS is P2 and must not block the main path.
- Public datasets or public rosbag samples are P1 required to avoid relying only on self-generated fake data.
- Core ROS 2 runtime nodes use C++17 and rclcpp.
- Python is allowed for orchestration, data conversion, report generation, analysis scripts, dashboard prototypes, and one-off validation.
- All generated runtime data should live under a project-local runtime area and be ignored by git.
- Large experimental files should not be committed. This includes large bags, videos, datasets, long raw logs, TensorRT engines, and diagnostic bundles.
- Each phase must include cleanup and rollback guidance.
- Company-server-friendly operation is mandatory. P0 and P1 should avoid global services and long-lived background processes by default.
- systemd and Docker are introduced as templates and controlled runtime options later, not as early global requirements.
- systemd install scripts must be explicit and reversible.
- Dashboard or web services must not default to public exposure.
- SSH tunneling or localhost binding is preferred for visual access.
- collect logs tooling must support redaction or exclusion patterns.
- Every ROS 2 package must include an interface contract covering nodes, topics, QoS, parameters, logs, metrics, health rules, rosbag topics, and failure modes.
- The core pipeline must be separated from hardware adapters. Fake sensor, video file, public bag, and simulated input adapters stand in for future real sensors.
- Stable topic contracts allow future adapters for USB camera, CSI camera, LiDAR, IMU, odometry, and base control.
- Markdown PRD is the main agent-readable source. The DOCX remains a human-readable archive.
- Markdown backlog is the source of truth for tasks. GitHub Issues are the optional execution queue after tasks are reviewed and sanitized.

## P0 Acceptance Criteria

Normal scenario:

- 100Hz fake sensor pipeline runs continuously for 10 minutes without crashing.
- Receive rate is at least 99Hz during the normal run.
- Normal-run drop rate is 0.
- p95 latency is at most 20ms during the normal run.
- p99 latency is at most 50ms during the normal run.
- System health remains healthy during the normal run.
- rosbag replay reproduces metrics within an explainable tolerance.
- Runtime artifacts are stored in project-local runtime directories.

Fault scenarios:

- Random dropped frames increase drop count.
- Subscriber sleep increases p95 and p99 latency.
- QoS mismatch produces the expected communication failure and can be explained.
- CPU, memory, disk, or temperature threshold crossings move health to warning or unhealthy.
- Log collection bundles logs, configs, system info, and result samples without including secrets.

Pressure scenarios:

- 500Hz and 1000Hz tests must generate CSV output and a bottleneck explanation.
- 500Hz and 1000Hz are not P0 pass/fail stability thresholds.

## Testing Decisions

- Test external behavior and observable contracts, not implementation details.
- Pure logic should be unit tested where possible, including sequence continuity, latency window statistics, drop-rate calculation, and health-state transitions.
- Build verification should include colcon build once ROS 2 packages exist.
- Launch smoke tests should verify that nodes start and parameters load.
- Bag replay regression should verify that a known sample bag produces expected metrics.
- Script checks should verify that start, stop, health check, collect logs, and cleanup scripts are executable and bounded to the project workspace.
- Jetson-specific verification must run on the Jetson server and be recorded in test reports.
- Generic CI is not required to emulate Jetson GPU, TensorRT, or tegrastats behavior.
- P0 phase gate requires both normal and fault scenario evidence.
- Every phase must produce test reports and interview artifacts before being considered done.

## Out of Scope

The following are explicitly deferred until P0 is complete:

- Buying real robots, LiDAR, IMU, cameras, chassis, or manipulators.
- Connecting a real robot base or arm.
- Training foundation models, large models, or reinforcement learning systems.
- Treating Isaac ROS or Isaac Sim as the main path.
- Running Isaac Sim on the Jetson.
- Optimizing for RViz, Gazebo, or visual polish before reliability evidence.
- Building a complex frontend dashboard.
- Introducing Kubernetes, cloud infrastructure, complex MLOps, or distributed multi-machine architecture.
- Creating broad abstractions only to look advanced.
- Making any dependency on an x86 RTX workstation.

## Further Notes

### Resource Envelope

All P0 and P1 work must be possible on the single Jetson server. If a tool requires unavailable hardware or a workstation, it becomes P2 or documentation-only until resources change.

### Runtime Governance

Project-generated data should be stored under project-local runtime directories:

- datasets
- bags
- logs
- results
- artifacts
- cache
- tmp

Cleanup scripts must default to dry-run behavior and must not delete outside the project workspace.

### Company Asset Safety Rules

Do not upload company internal data, hostnames, IPs, usernames, tokens, private keys, logs, network details, or diagnostic bundles to public repositories. Public demos, screenshots, and README examples must be sanitized.

Web services should bind to localhost by default. If a different bind address is used, the reason must be documented.

### System Baseline and Change Ledger

Before global installation or system modification, record OS, kernel, L4T, JetPack, CUDA, TensorRT, cuDNN, VPI, apt sources, NVIDIA packages, ROS packages, Python, pip, CMake, GCC, colcon, disk, memory, nvpmodel, tegrastats baseline, and relevant shell environment entries.

Every global change must record date, command, reason, affected files or packages, validation, and rollback notes.

### Hardware Adapter Boundary

Core processors, metrics, health logic, logging, and runtime scripts should depend on stable ROS 2 topic contracts rather than concrete hardware drivers. Hardware-specific input belongs in adapter nodes.

### Required Per-Phase Artifacts

Each phase should include README, architecture notes, interface contract, test report, debug guide, cleanup or rollback notes, and interview artifacts.
