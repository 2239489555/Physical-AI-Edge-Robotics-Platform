# CAP-001 Capstone Demo, Resume Summary, And Final Story

Type: HITL

User stories covered: 14, 20, 22, 25

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Assemble the final portfolio artifact from P0 plus at least one P1 enhancement: demo outline, sanitized evidence, resume summary, and interview story bank.

## Acceptance criteria

- [ ] Final README or summary explains the Edge Robotics Reliability Lab clearly.
- [ ] Three-minute demo script references real commands, reports, metrics, and artifacts.
- [ ] Resume bullets are accurate and do not imply real hardware use if none occurred.
- [ ] Interview story bank covers architecture, QoS, metrics, tegrastats, fault injection, rosbag replay, cleanup, and the P1 enhancement.
- [ ] Public-facing artifacts are sanitized for company asset safety.
- [ ] Final report states remaining risks, what was not tested, and what real hardware would change.

## Blocked by

- P0-019
- At least one P1 enhancement issue.

## Verification commands

- Cross-check every public claim against source reports.
- Manual demo rehearsal.
- `git status --short` to confirm bulky runtime artifacts are not staged.

## Runtime artifact location

`runtime/artifacts/capstone/`

## Cleanup and rollback

Keep final sanitized docs in git. Keep raw video, logs, and bulky evidence under runtime.

## Out of scope

- Publishing private company data.
- Claiming production robot deployment.
