# P0-016 health_check And collect_logs Diagnostic Bundle

Type: AFK

User stories covered: 3, 5, 11, 13, 20, 21

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Add operational scripts that check P0 runtime health and create a sanitized diagnostic bundle for remote debugging.

## Acceptance criteria

- [ ] Health check reports ROS node presence, topic presence, topic frequency, latest health state, latency metrics, disk space, and system metrics where available.
- [ ] Health check has a nonzero exit code when critical checks fail.
- [ ] collect_logs writes bundles under `runtime/artifacts/`.
- [ ] Bundle includes logs, configs, system baseline summary, recent results, and optional small samples.
- [ ] Bundle excludes or redacts hostnames, IPs, usernames, tokens, keys, raw company data, and bulky runtime artifacts by default.
- [ ] Documentation explains what is safe to share publicly and what is not.

## Blocked by

- P0-015

## Verification commands

- `scripts/health_check.sh` or platform equivalent.
- `scripts/collect_logs.sh` or platform equivalent.
- Inspect generated bundle contents.
- `git status --short` to confirm bundles are ignored.

## Runtime artifact location

`runtime/artifacts/diagnostics/`

## Cleanup and rollback

Delete diagnostic bundles only under project-local runtime artifacts.

## Out of scope

- Uploading diagnostic bundles.
- Public web dashboard.
