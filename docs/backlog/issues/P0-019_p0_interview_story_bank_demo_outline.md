# P0-019 P0 Interview Story Bank And Demo Outline

Type: HITL

User stories covered: 14, 20, 22, 25

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Convert the P0 engineering evidence into interview-ready explanations and a short demo outline without overstating the project's hardware scope.

## Acceptance criteria

- [ ] Story bank explains the company-style problem simulated by P0.
- [ ] Story bank explains architecture, topic contracts, QoS choices, metrics, health rules, and runtime governance.
- [ ] Story bank includes at least three failure stories: dropped frames, subscriber delay, and QoS mismatch.
- [ ] Story bank explains how the fake sensor path maps to future real hardware adapters.
- [ ] Three-minute demo outline references real commands and evidence.
- [ ] Resume bullets are marked draft until reviewed for accuracy.
- [ ] Text does not imply real robot hardware was used.

## Blocked by

- P0-018

## Verification commands

- Manually rehearse the three-minute demo.
- Cross-check every claim against P0 gate evidence.

## Runtime artifact location

`runtime/artifacts/demo/` for optional local demo evidence.

## Cleanup and rollback

Keep durable story docs in the repository. Keep bulky demo artifacts under runtime.

## Out of scope

- Recording final capstone video.
- Claiming TensorRT or Nav2 experience before those tasks are complete.
