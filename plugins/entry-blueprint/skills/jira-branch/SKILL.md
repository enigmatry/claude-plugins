---
name: jira-branch
description: Create a git feature branch from a Jira ticket, assigning the ticket to yourself and transitioning it to In Progress. Use this when the user asks to create a new branch and provides (or implies) a Jira ticket ID.
---

# Git Branch from Jira Ticket

## Project configuration

First, read the **"Known identifiers"** section of the host project's `CLAUDE.md`
for:

- **Jira project key** (e.g. `BP`) — used to validate/complete ticket IDs
- **Atlassian cloud ID** (e.g. `yourcompany.atlassian.net`)
- **Default branch** — the branch to start from

If that section is missing, ask the user for the Jira project key before
proceeding, and suggest adding a "Known identifiers" section to `CLAUDE.md`.

## Workflow

1. **Fetch the Jira ticket** by its ID to retrieve its **summary/title** and current status.
2. **Assign the ticket to yourself**: call `atlassian-atlassianUserInfo` to get your account ID, then `atlassian-editJiraIssue` to set `assignee.accountId`.
3. **Transition to In Progress** (if not already): call `atlassian-getTransitionsForJiraIssue` to find the "In Progress" transition ID, then `atlassian-transitionJiraIssue` to apply it.
4. Convert the title to **kebab-case** (lowercase, spaces → hyphens, strip special characters).
5. Create and switch to the branch: `features/<TICKET-ID>-<kebab-case-title>`
   - Example: ticket `BP-42` with title "Add product search endpoint" → `features/BP-42-add-product-search-endpoint`
6. Run `git checkout -b <branch-name>` (or `git switch -c <branch-name>`) to create and immediately switch to it.
7. Confirm the active branch, assignment, and ticket status to the user.

## Rules

- Ticket ID is uppercase as-is (e.g. `BP-42`, not `bp-42`).
- Kebab-case segment: lowercase only, hyphens instead of spaces/underscores, remove any characters that are not alphanumeric or hyphens.
- Always assign the ticket and transition it before creating the branch.
- Skip the transition step (but still assign) if the ticket is already "In Progress".
