---
name: jira-branch
description: Create a git feature branch from a Jira ticket, assigning the ticket to yourself and transitioning it to In Progress. Use when the user asks to create a branch, start work on a ticket, or pick up a Jira issue, and provides (or implies) a Jira ticket ID.
---

# Branch from Jira Ticket

Read the project identifiers (Jira project key, Atlassian cloud ID, default branch) from the **"Known identifiers"** section of the host project's `CLAUDE.md`. If that section is missing, ask the user for them rather than guessing.

## Git preflight — before touching Jira

Jira mutations aren't automatically reversible, so establish that the branch can actually be created first. These checks are all read-only:

1. `git fetch` the default branch, then check whether the local base is behind its remote. If it is, stop and ask the user to pull (or offer to fast-forward) — never branch off a stale base.
2. Check that no branch for this ticket already exists locally or on the remote. If one does, stop and ask whether to switch to it rather than creating a duplicate.
3. Check that the working tree is clean enough to switch branches. If uncommitted changes would block the switch, stop and ask how to handle them.

If any check fails, report it and stop — do not assign or transition the ticket.

## Jira, then the branch

Assign the ticket to yourself and transition it to In Progress. If it's already In Progress, skip the transition but still assign it.

Then branch off the default branch and switch to it:

`features/<TICKET-ID>-<kebab-case-keywords>`

The ticket ID stays uppercase. The title segment is **at most 5 keywords** taken from the ticket title — lowercase alphanumerics and hyphens only, filler words dropped. Ticket `BP-42` "Add a product search endpoint to the catalog API" → `features/BP-42-product-search-endpoint`.

Confirm the branch name, assignment, and ticket status to the user.

## If branch creation fails after the Jira update

Say so explicitly and name the inconsistent state you left behind (ticket assigned and In Progress, no branch). Offer to revert the transition. Never let the user discover the mismatch on their own.
