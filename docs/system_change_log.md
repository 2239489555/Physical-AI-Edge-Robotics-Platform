# System Change Log

Record every global system change made on the company-owned Jetson server.

Do not use this log for project-local runtime artifacts under `runtime/`; those can be cleaned separately. Use this log for actions that affect the host outside the repository workspace.

## Change Entry Template

```text
Date:
Operator:
Task:
Command:
Reason:
Files changed:
Packages installed:
Packages removed:
Services changed:
Environment changed:
Verification:
Rollback:
Risk:
Notes:
```

## Entries

No global system changes have been recorded yet.

## Rules

- Record the change before or immediately after running it.
- Do not run `dist-upgrade` for this project.
- Do not upgrade Ubuntu to 24.04.
- Do not switch the main ROS target to ROS 2 Jazzy.
- Do not modify apt sources without recording why and how to roll back.
- Do not run global `pip install` into system Python without recording why and how to roll back.
- Prefer project-local outputs under `runtime/`.
- Prefer documented apt packages or NVIDIA-supported packages over random install scripts.
