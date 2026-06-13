# Emonotate

Draw and collect emotional arcs.

This repository is a monorepo containing the frontend and backend for Emonotate.

| Directory | Description |
|---|---|
| [emonotate-app/](emonotate-app/) | React.js frontend |
| [emonotate-backend/](emonotate-backend/) | Python (Django) backend |

## Getting Started

Run the following command once after cloning:

```bash
make setup
```

This configures git to use the project's shared hooks in [.githooks/](.githooks/).

### Environment variables (required for `pre-push`)

The `pre-push` hook posts a comment to the task management API on every push.
Set the following variables in your shell profile (e.g. `~/.zshenv`):

```bash
export TOOL_API_URL="<comment endpoint URL>"
export TOOL_API_KEY="<API key>"
export TOOL_USER_ID=<user id>
```

## Git Commit Message Format

All commits must follow this format:

```
<kind>: <summary>

[<detail>]

Task: <task_id>
```

**Rules:**

| Field | Rule |
|---|---|
| `kind` | `Ftr` (feature) / `Fix` (bug fix) / `Eta` (estimate) |
| First line | ASCII only, 50 chars max, summary starts with uppercase |
| Detail lines | ASCII only, 50 chars max each (optional) |
| Blank lines | Required after first line, and before `Task:` |
| `task_id` | Integer |

**Examples:**

```
Ftr: Add user authentication

Task: 12
```

```
Fix: Correct off-by-one error in arc renderer

The end index was exclusive but treated as inclusive,
causing the last data point to be dropped.

Task: 34
```

The `commit-msg` hook enforces this format automatically after `make setup`.

## Git Hooks

| Hook | Trigger | Behavior |
|---|---|---|
| `commit-msg` | `git commit` | Validates commit message format |
| `pre-push` | `git push` | Posts a comment to the task management API for each pushed commit |

## GitHub Actions

| Workflow | Trigger | Behavior |
|---|---|---|
| [update-task-status-on-merge](.github/workflows/update-task-status-on-merge.yml) | push to `develop` | Updates the status of each commit's task to merged |
| [validate-releases-pr](.github/workflows/validate-releases-pr.yml) | PR opened/edited to `releases` | Checks that the PR body contains `Event: <event_id>` |
| [update-event-status-on-merge-to-releases](.github/workflows/update-event-status-on-merge-to-releases.yml) | PR merged to `releases` | Updates the event status to released |

### Required GitHub Secrets

Set the following in **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `TOOL_API_KEY` | API key for the task management tool |
| `TOOL_TASK_API_URL` | Task update endpoint base URL (e.g. `https://<host>/api/task_app/tasks/`) |
| `TASK_STATUS_MERGE_ID` | Status ID that represents "merged" in the task tool |
| `TOOL_EVENT_API_URL` | Event update endpoint base URL (e.g. `https://<host>/api/task_app/events/`) |
| `EVENT_STATUS_RELEASE_ID` | Status ID that represents "released" in the task tool |

### PR format for `releases` branch

PRs targeting `releases` must include the following in the PR body:

```
Event: <event_id>
```
