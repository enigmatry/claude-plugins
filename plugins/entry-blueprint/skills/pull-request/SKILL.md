---
name: pull-request
description: Use when the user asks to create a pull request (PR).
---

# Pull Request

Read the project identifiers (Jira project key, Atlassian cloud ID, Azure DevOps org/repo/project, default branch) from the **"Known identifiers"** section of the host project's `CLAUDE.md`. If that section is missing, ask the user for them rather than guessing.

Create the PR in Azure DevOps from the current branch, targeting the default branch:

- Title: `<TICKET-ID> - <Jira ticket title>` (uppercase ticket ID, space-dash-space separator). Fetch the ticket title if it isn't in context — never invent it.
- Description: the direct Jira link to the ticket, nothing else.
- Not a draft unless the user asks for one.

Always use the **Squash** merge strategy. Do **not** enable auto-complete — the PR is completed manually after review. Confirm the PR URL to the user.
