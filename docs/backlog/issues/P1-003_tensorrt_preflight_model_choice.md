# P1-003 TensorRT Environment Preflight And Model Choice

Type: HITL

User stories covered: 5, 8, 12, 20

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Verify TensorRT readiness on the Jetson and select a lightweight model path for a P1 inference demo.

## Acceptance criteria

- [ ] TensorRT, trtexec, CUDA, cuDNN, and related JetPack components are inventoried.
- [ ] Model candidate is lightweight enough for the Jetson and documented with license/source.
- [ ] ONNX-to-engine path is documented.
- [ ] Decision records whether to use bare metal or NVIDIA container for this P1 slice.
- [ ] Risks and fallback path are documented if TensorRT conversion fails.
- [ ] No large model or engine files are committed to git.

## Blocked by

- P0-018

## Verification commands

- `trtexec --help`
- `dpkg -l` checks for TensorRT-related packages.
- `tegrastats` during a trivial GPU or TensorRT check if available.

## Runtime artifact location

`runtime/artifacts/tensorrt_preflight/`, `runtime/cache/models/`

## Cleanup and rollback

Delete downloaded model and generated engine files only from runtime directories.

## Out of scope

- Implementing the inference node.
- Benchmarking FP32/FP16.
