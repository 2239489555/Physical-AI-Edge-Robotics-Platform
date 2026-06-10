# M8 P0 Phase Gate

## Goal

Review all P0 evidence and decide whether the project is ready for P1 TensorRT work.

## Context

The roadmap is milestone-gated. P1 should not start until the reliability loop is real, documented, reproducible, and explainable.

## Inputs

- M0 through M7 deliverables.
- Test reports.
- Interface contracts.
- Runtime artifacts.
- Cleanup and rollback notes.
- Interview artifacts.

## Expected Outputs

- P0 gate report.
- Evidence checklist.
- Known gaps and follow-up tasks.
- Decision: pass, conditional pass, or fail.

## Technical Constraints

- Do not hide failed checks.
- Do not treat visual demos as substitutes for logs, bags, CSV, and health evidence.
- Do not move to TensorRT, Nav2, or Isaac ROS if core P0 claims are unverified.

## Acceptance Criteria

- 100Hz 10-minute normal run evidence exists.
- receive_rate, drop_rate, p95 latency, p99 latency, and health state are recorded.
- Fault injection evidence exists for dropped frames, subscriber sleep, and QoS mismatch.
- rosbag record and replay evidence exists.
- tegrastats system monitor evidence exists.
- collect logs and cleanup evidence exists.
- Company asset safety checks pass.
- The user can explain the system without reading generated text verbatim.

## Verification Commands

Use the verification commands recorded by M0 through M7. The gate report should cite exact commands and artifact locations.

## Runtime Artifact Location

Store the gate report in long-term docs. Store bulky supporting artifacts under project-local runtime artifacts and keep them out of git.

## Cleanup and Rollback

Confirm cleanup commands and rollback notes are complete before declaring P0 complete.

## Interview Artifact Questions

- What is the P0 story in three minutes?
- What broke, how was it detected, and how was it reproduced?
- What changes when a real camera, LiDAR, or robot base is added later?

## Out of Scope

- Starting P1 implementation.
- Retrofitting unverified claims into the resume.
