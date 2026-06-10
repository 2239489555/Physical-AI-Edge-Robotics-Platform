# P1-001 Public Dataset Or rosbag Selection Manifest

Type: HITL

User stories covered: 8, 13, 20, 24

## Parent

`docs/prd/Jetson_Physical_AI_PRD.md`

## What to build

Select and document at least one public dataset or public rosbag sample that can run on the single Jetson server and makes the project more credible than self-generated fake data alone.

## Acceptance criteria

- [ ] Candidate data source is publicly accessible.
- [ ] License is documented.
- [ ] Single sample target size is preferably under 5GB.
- [ ] Data is not committed to git.
- [ ] Manifest records source URL, license, expected size, checksum if available, download command, conversion command if needed, and intended topics.
- [ ] Sample includes at least one useful robotics input category such as camera/video, IMU, LiDAR, odom, scan, or existing bag topics.
- [ ] If no suitable data is selected, the task records why and proposes next candidates.

## Blocked by

- P0-018

## Verification commands

- Review manifest.
- If downloaded, verify file location under `runtime/datasets/`.
- `git status --short` to confirm data files are ignored.

## Runtime artifact location

`runtime/datasets/`

## Cleanup and rollback

Delete downloaded samples only from `runtime/datasets/`.

## Out of scope

- Training models.
- Downloading large full datasets.
- Committing dataset files.
