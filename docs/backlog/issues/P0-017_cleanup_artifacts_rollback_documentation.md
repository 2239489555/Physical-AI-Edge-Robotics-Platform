# P0-017 cleanup_artifacts And Rollback Documentation

Type: AFK

User stories covered: 3, 11, 12, 13, 21

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Create cleanup tooling and rollback documentation that make the project safe to remove from a company-owned Jetson server.

## Acceptance criteria

- [ ] cleanup script defaults to dry-run.
- [ ] cleanup script targets only project-local runtime directories by default.
- [ ] cleanup script refuses to delete paths outside the repository workspace.
- [ ] Rollback documentation distinguishes project-local artifacts from global system changes.
- [ ] Documentation lists all expected directories and what is safe to delete.
- [ ] Known system changes are recorded or explicitly marked as none.

## Blocked by

- P0-016

## Verification commands

- `scripts/cleanup_artifacts.sh --dry-run` or platform equivalent.
- Inspect cleanup output for paths.
- Manual review that no outside-workspace paths are targeted.

## Runtime artifact location

`runtime/`

## Cleanup and rollback

This issue creates the cleanup mechanism. It must be reviewed before using destructive cleanup mode.

## Out of scope

- Deleting system packages.
- Removing ROS 2 installation.
- Removing Docker or system services.
