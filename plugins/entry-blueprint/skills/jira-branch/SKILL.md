---
name: jira-branch
description: Use when the user asks to create a git branch for a Jira ticket.
---

# Branch from Jira Ticket

Read the project identifiers (Jira project key, Atlassian cloud ID, default branch) from the **"Known identifiers"** section of the host project's `CLAUDE.md`. If that section is missing, ask the user for them rather than guessing.

Branch name: `features/<TICKET-ID>-<kebab-case-ticket-title>`, e.g. `features/BP-42-add-product-search-endpoint`. The ticket ID stays uppercase; the title segment is lowercase alphanumerics and hyphens only.

Before creating the branch, assign the ticket to yourself and transition it to In Progress. If it is already In Progress, skip the transition but still assign it.

Branch off the default branch, switch to the new branch, and confirm the branch name, assignment, and ticket status to the user.
