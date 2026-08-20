---
name: pull-request
description: Create an Azure DevOps pull request titled after its Jira ticket, using the Squash merge strategy with auto-complete off. Use when the user asks to open, create, publish, or raise a PR, or to send the current branch for review.
---

# Pull Request

Read the project identifiers (Jira project key, Atlassian cloud ID, Azure DevOps org/repo/project, default branch) from the **"Known identifiers"** section of the host project's `CLAUDE.md`. If that section is missing, ask the user for them rather than guessing.

## Create

Create the PR in Azure DevOps from the current branch, targeting the default branch:

- **Title:** `<TICKET-ID> - <Jira ticket title>` (uppercase ticket ID, space-dash-space separator). Fetch the ticket title if it isn't in context — never invent it.
- **Description:** the direct Jira link, then a short summary — one paragraph of a few sentences on what changed and why, for a reviewer who hasn't read the ticket. Not a changelog, not a bullet list, no section headings.
- **Draft:** no, unless the user asks for one.

## Verify the completion options — do not skip this

Creating a PR does not set these, and the defaults are wrong for this workflow: Azure DevOps treats an unset merge strategy as no-fast-forward, and an org or project setting can enable auto-complete at creation time without being asked. So after creating the PR, explicitly update it and then **read it back** and confirm:

- `completionOptions.mergeStrategy` is `Squash`.
- `autoCompleteSetBy` is `null` — this workflow completes PRs manually after review. If it came back non-null because a project setting queued it, cancel auto-complete and read back again.

If the read-back doesn't show both, report that plainly instead of claiming success.

Confirm the PR URL to the user.
