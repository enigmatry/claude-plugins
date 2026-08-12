---
name: pull-request
description: Create an Azure DevOps pull request titled after the Jira ticket, with Squash merge strategy and auto-complete enabled. Use this when the user asks to create a PR (pull request).
---

# Pull Request Workflow

## Project configuration

First, read the **"Known identifiers"** section of the host project's `CLAUDE.md`
for:

- **Jira project key** (e.g. `BP`) and **Atlassian cloud ID** (e.g. `yourcompany.atlassian.net`)
- **Azure DevOps org/repo** (e.g. `yourorg/your-repo`) and **Azure DevOps project**
- **Default branch** — the PR target (e.g. `master`)

If that section is missing, ask the user for these values before proceeding,
and suggest adding a "Known identifiers" section to `CLAUDE.md`.

## Workflow

1. **Fetch the Jira ticket** (if not already known) to get the title.
2. **Get current branch name**: `git branch --show-current`
3. **Create the PR** via Azure DevOps using:
   - `sourceRefName`: current branch (`refs/heads/<branch-name>`)
   - `targetRefName`: `refs/heads/<default-branch>`
   - `title`: `<TICKET-ID> - <Jira ticket title>`
   - `description`: `https://<atlassian-cloud-id>/browse/<TICKET-ID>`
   - `isDraft`: false (unless user requests a draft)
4. Set **Squash** merge strategy and enable **auto-complete**: call `azure-devops-repo_update_pull_request` with `mergeStrategy: Squash` and `autoComplete: true`.
5. Confirm the PR URL to the user.

## Rules

- PR title format: `<TICKET-ID> - <ticket title>` (uppercase ticket ID, space-dash-space separator).
- PR description must be the direct Jira link.
- Always use Squash merge strategy.
- Always enable Auto-complete — verify `autoCompleteSetBy` is non-null in the response.
- Never create the PR without the Jira ticket title (fetch it if not in context).
