# Issue Tracker

PRDs and backlog tasks for this repository live first in repository Markdown.

Primary sources:

- `docs/prd/Jetson_Physical_AI_PRD.md`
- `docs/backlog/`
- `docs/competency_matrix.md`

GitHub Issues are an optional execution queue after a task has been reviewed and sanitized for public sharing.

Repository remote:

```text
https://github.com/2239489555/Physical-AI-Edge-Robotics-Platform.git
```

Use the `gh` CLI only when a task is ready to be published to GitHub Issues.

## Conventions

- Create an issue: `gh issue create --title "..." --body "..."`
- Read an issue: `gh issue view <number> --comments`
- List issues: `gh issue list --state open --json number,title,body,labels,comments`
- Comment on an issue: `gh issue comment <number> --body "..."`
- Apply a label: `gh issue edit <number> --add-label "..."`
- Remove a label: `gh issue edit <number> --remove-label "..."`
- Close an issue: `gh issue close <number> --comment "..."`

When a skill says "publish to the issue tracker", first update or create a Markdown task under `docs/backlog/`. Create a GitHub issue only if the task is sanitized and ready for remote execution.

When a skill says "fetch the relevant ticket", first read the relevant Markdown task. If the task was already published to GitHub, run `gh issue view <number> --comments`.
