# P1-005 TensorRT Performance Report And Interview Artifacts

Type: AFK

User stories covered: 5, 14, 20, 25

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Turn TensorRT inference results into a performance report and interview story that compares CPU baseline, TensorRT FP32, and TensorRT FP16 where available.

## Acceptance criteria

- [ ] Report includes FPS, preprocess latency, inference latency, postprocess latency, end-to-end latency, CPU, RAM, temperature, and GPU indicator.
- [ ] Report compares CPU baseline with TensorRT modes where available.
- [ ] Report states what could not be tested and why.
- [ ] Story explains why Jetson GPU inference matters for Physical AI edge systems.
- [ ] Story avoids claiming model training or real hardware deployment if not performed.
- [ ] CSV and charts, if generated, are stored under runtime or committed only if small and sanitized.

## Blocked by

- P1-004

## Verification commands

- Run benchmark command or launch file for each mode.
- Inspect generated CSV/report.
- Cross-check claims against tegrastats logs.

## Runtime artifact location

`runtime/results/tensorrt/`, `runtime/artifacts/tensorrt_report/`

## Cleanup and rollback

Keep durable sanitized report in docs. Keep bulky raw logs under runtime.

## Out of scope

- Optimizing model accuracy.
- Building a full perception product.
