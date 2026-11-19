# Worked examples

Two complete issues for `writing-jira-issues` — one Bug, one Story. Each shows the **full draft** (the attached markdown) and then the **issue body** cut down from it.

The domain is invented. Copy the shape, not the content.

---

## Example 1 — Bug

Cause is known and an approach is chosen, so the draft carries **Solution** and no Technical pointers. Notes has tested negatives. Background/context is omitted: the defect stands on its own.

### Full draft (attached as `ABC-1234.md`)

```markdown
## Summary

Exporting a filtered order list produces a file containing every order, ignoring the filter.

## Steps to reproduce

Requires the **Orders read** permission.

1. Open **Orders**.
2. Set the **Status** filter to `Cancelled`.
3. Click **Export to CSV**.
4. Open the downloaded file.

## Expected

The file contains only the orders shown on screen — the cancelled ones.

## Actual

The file contains every order in the account, cancelled or not. The on-screen list is correct;
only the export ignores the filter. No error is shown, so the user has no signal that the file is
wrong.

Generated SQL for the export, captured from the query log:

    SELECT o.Id, o.Reference, o.PlacedOn, o.StatusId
    FROM   [Order] o
    WHERE  o.AccountId = @accountId
    ORDER BY o.PlacedOn DESC

The `StatusId` predicate present in the list query is absent here.

## Impact

Anyone exporting a filtered list gets a file that silently contradicts the screen they exported
it from. Finance uses these exports for month-end reconciliation, so a wrong file is copied into
downstream spreadsheets before anyone notices. Affects every filter on the screen, not just
status.

## Acceptance criteria

1. Exporting a filtered order list produces a file whose rows match the rows on screen.
2. Criterion 1 holds for the **Status**, **Customer** and **Placed between** filters, and for any
   combination of them.
3. The search box keeps working as it does today.
4. Exporting with no filter set still produces every order in the account.
5. Exporting a filter that matches nothing produces a file with headers and no rows.
6. Reproducing the steps above no longer produces the defect.

## Notes

Tested:

* Reproduces with the **Status**, **Customer** and **Placed between** filters.
* Reproduces with several filters combined.
* Does **not** reproduce for the search box — search is applied to the export correctly.
* Does **not** depend on result size; a two-row filtered list still exports everything.

## Solution

* The export builds its own query instead of reusing the list query's filter object. Pass the
  same filter into both so they cannot drift again.
* The export runs outside the request's paging, so it has no `Skip`/`Take` to strip — only the
  `WHERE` needs adding.
* Trap: the export streams rows, so applying the filter changes the row count the progress
  indicator was written against. Check it still reports sensibly for a small result set.

## Out of scope

* Adding a column chooser to the export. Requested separately.
```

### Issue body

Summary · Steps to reproduce · Expected · Actual · Impact · Acceptance criteria — verbatim from the draft. **Notes**, **Solution** and **Out of scope** stay in the attachment. The generated SQL stays in the body: it is what makes the defect recognisable at a glance.

---

## Example 2 — Story

A backend rule change. No UI, so no Mockup and no Copy & i18n. All open questions were answered while drafting, so there is no Open questions section.

### Full draft (attached as `ABC-2345.md`)

```markdown
## User story

As an account administrator, I want to invite a colleague who already has an account elsewhere,
so that they can join my account without creating a second login.

## Background/context

Invitations are rejected when the email address already exists in the system. The rule was written
when an address could belong to only one account. Accounts can now share people, so the rule
blocks a case the product is meant to support.

The rest of the product already treats an address as reusable. A person can be added to a second
account through the admin import, and the login page resolves one address to several accounts.
Only the invitation path still refuses.

## Current behaviour

1. Sending an invitation to an address that already exists is rejected with
   "This email address is already in use."
2. The rejection happens whether the existing account is the one inviting or a different one.
3. The administrator has no way to complete the invitation. They ask the person to sign up with a
   second address.

## Intended behaviour

1. An invitation to an address that does not exist yet is created as it is today. Nothing changes.
2. An invitation to an address that exists on a **different** account is accepted. The person is
   invited to this account and keeps their existing login.
3. An invitation to an address that is already a member of **this** account is still rejected,
   with the same message. Inviting someone twice remains an error.
4. A pending invitation to the same address on this account is still rejected. Nothing changes for
   duplicate invitations.
5. Accepting an invitation never merges profiles. The person gains membership of a second account
   and nothing else.

### Worked examples

| Address exists? | Member of this account? | Pending invite here? | Outcome |
|---|---|---|---|
| no | – | no | Invitation created — unchanged |
| yes | no | no | **Invitation created (new)** — existing login reused |
| yes | yes | no | Rejected — "This email address is already in use." |
| yes | no | yes | Rejected — duplicate invitation, unchanged |

## Acceptance criteria

1. Inviting an address held on a different account creates the invitation.
2. Accepting that invitation grants membership of the inviting account and leaves the existing
   login unchanged.
3. Inviting an address that is already a member of the inviting account is rejected with
   "This email address is already in use."
4. Inviting an address with a pending invitation on the inviting account is rejected.
5. Inviting an address that does not exist behaves exactly as it does today.
6. Accepting an invitation does not alter the person's name, password or settings.

## Solution

* The uniqueness check runs against the whole address table. Scope it to memberships and pending
  invitations of the inviting account.
* The invitation record stores an address, not a person. It resolves the person on acceptance, so
  no schema change is needed.
* Trap: the acceptance path assumes it is creating a login and generates a password-set link
  unconditionally. It must skip that when the person already has one, or it will reset a working
  password.

## Out of scope

* Letting a person switch between accounts once they belong to several. That is the account
  switcher, tracked separately.
```

### Issue body

User story · the **first paragraph** of Background/context · Current behaviour · Intended behaviour · Worked examples · Acceptance criteria. The second background paragraph, **Solution** and **Out of scope** stay in the attachment.
