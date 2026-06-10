# Domain Docs

This is a single-context repository for a Jetson-based Physical AI edge robotics platform.

## Before exploring, read these

- `CONTEXT.md` at the repository root, if it exists.
- `docs/adr/`, if it exists, for architectural decisions relevant to the area being changed.
- `docs/prd/Jetson_Physical_AI_PRD.md` for the agent execution PRD.
- `docs/prd/Jetson_Physical_AI_PRD.docx` for the human reading and archive PRD.

If any of these files do not exist, proceed silently. Do not create domain docs just because they are absent.

## Layout

Expected single-context layout:

```text
/
|-- CONTEXT.md
|-- docs/
|   |-- adr/
|   `-- prd/
|       |-- Jetson_Physical_AI_PRD.docx
|       `-- Jetson_Physical_AI_PRD.md
`-- demos/
```

## Vocabulary

Use the PRD's project language consistently:

- Jetson-based Physical AI Edge Robotics Platform
- ROS 2 Humble
- Jetson Orin
- JetPack 6.2
- L4T R36.4.3
- TensorRT
- Isaac ROS 3.2
- tegrastats
- rosbag
- QoS, latency, drop rate, health state
- Docker/systemd edge runtime

When output contradicts the PRD or a future ADR, surface the conflict explicitly instead of silently overriding it.
