---
name: writing-jira-issues
description: Functional analysis and Jira issue authoring — the section contract, formatting and field conventions for stories and bugs. Use this when acting as business/functional analyst: turning a request, test finding, incident or performance investigation into a Story or Bug, writing acceptance criteria, refining or splitting an existing issue, or when asked to "create a ticket", "write a story", "log a bug" or "prepare refinement".
---

# Writing Jira issues

## Overview

**The analysis is the work; this skill is about its shape.** Reading the code, finding the precedent and naming the open questions happens reliably without guidance. What drifts is *structure*: which sections, in which order, under which names, with which fields set. A well-analysed issue in the wrong shape still forces every reader to re-orient.

So this skill is a **section contract**, not a set of warnings. Assemble the parts listed for your work type, in order.

**Every Story uses one contract.** Capability work, backend work, tooling, a measured performance fix: same spine, different optional sections appended. Do not invent a variant template because the work "feels different" — if a section seems missing, it is an optional one you should be appending, not a new shape.

Bugs use a different register, because a defect report answers different questions.

## When to use

- Turning a request, test finding, production incident or performance investigation into a Story or Bug.
- Refining, restructuring or splitting an existing issue.
- Not for: sub-tasks (see *Never create these*), or PR descriptions (see the repository's `CLAUDE.md`).

## Step 1 — Investigate before writing

Every claim in the issue must trace to something you read. In order:

1. **Related issues, including comments.** Comments routinely amend acceptance criteria. Search for prior art on the same screen or query — prior art on the same area tells you which **type** to file. It never tells you the format: that is fixed by the contract in Step 3, never copied from an older issue.
   **Always scan for a duplicate, and keep the result out of the issue.** If you find one, stop and tell the user in the chat — give the key and the distinguishing symptom, and let them decide whether to file, amend the existing issue, or drop it. If you find none, say nothing: a clean search is not a finding, and it never becomes a section, a note or a line in the description.
   **A precedent is not a duplicate, and it does belong in the issue.** An earlier issue that established the convention at stake, fixed the same mechanism elsewhere, or set the pattern this work follows goes in Background/context by key. The "say nothing" rule above covers the *search*, not what the search turns up.
2. **`git log` on the area.** Recurring defects usually have a prior fix that names the mechanism.
3. **The code itself.** The handler, the entity, the query, the configuration, the generated output.
4. **Attachments and inline images.** Jira media is auth-gated and cannot be fetched with `WebFetch`. If you cannot open one, **say so and ask for it to be pasted into the chat** — never infer what a mockup shows.

**Correct the requester's vocabulary against the code.** The word a stakeholder uses for a filter, a status or a field is often none of: the label on screen, the key behind it, or the entity property it maps to. Write what exists, and say so when you have substituted a term.

## Step 2 — Decide whether to file, then choose the type

**First ask whether there is an issue at all.** Not every report becomes one. Three outcomes end the work here:

| What you found | What to do |
|---|---|
| The reported thing does not exist — wrong build, wrong screen, wrong word for it | **Do not file.** Report the negative finding to the user in the chat, with the evidence that rules it out and the questions that would settle it |
| It already works, or already exists in the form asked for | **Do not file.** Say so in the chat, and show where |
| A duplicate covers it | **Do not file.** Give the key and the distinguishing symptom, and let the user decide |

**A negative finding is a real deliverable, and it never becomes an issue.** "I searched every branch and this does not exist" is often the most valuable thing an analyst produces, but there is no section for it in either contract — every required Bug section is unfillable when the reported behaviour is not real. Write it up in the chat: what you checked, what rules the report out, and the two or three questions that would resolve it. Never soften a report you cannot evidence into an issue that looks fileable.

**The requester's premise can be wrong, not just their vocabulary.** They may ask for something that exists, describe a screen that has no such control, or report against a branch build. Check the premise before you check the wording. Where the premise is partly wrong — the capability exists but is broken, or exists in a weaker form — say so in the chat, then let reality shape Current behaviour rather than writing the issue the requester imagined.

Once you are filing, choose the type:

| Situation | Type |
|---|---|
| New or changed user-facing capability | **Story** |
| The capability exists but is defective, and the requester is asking for it to work properly | **Story** — the defects go in Current behaviour and Solution |
| Product behaves incorrectly against intended behaviour, nobody asked for a change | **Bug** |
| Internal change, no user-visible behaviour change | **Story** |
| Performance: symptom reported, **cause not yet measured** | **Bug**, plus *What we know / don't* and *Technical pointers* |
| Performance: **cause measured**, specific fix named | **Story**, plus *Investigation findings* and *Data-equivalence verification* |

**The performance discriminator is "has the cause been measured yet?", not "did a user complain?".** A complaint with no measurement is an investigation: the deliverable is a baseline and a diagnosis, which is Bug-shaped. A measured cause with a named reshape is planned work, which is Story-shaped.

**Do not route on "it breaches the performance norm".** Such norms are usually percentile-based — for example 90% within 1s, 99% within 5s, 99.9% within 10s — so a single anecdote of "about eight seconds" cannot establish a breach at all. Which tier is violated depends on frequency, which is exactly what has not been measured. Cite the norm as the target; never as the trigger.

**Do not determine the parent Epic yourself.** Set a parent only when the user names one; otherwise leave it empty. Never work from a remembered list of Epics, and never infer a parent from what neighbouring issues are parented to — an Epic that looks like a fit routinely isn't, and a wrong parent quietly misfiles the work where the wrong people own it. Many stories have no parent at all, so empty is a correct outcome, not an omission. If you believe the work belongs under an Epic, say so and let the user decide.

## Step 3 — Assemble the sections

**The section lists below are closed. Never invent a section.** If something you want to say has no section, it belongs in an existing one, in a comment, or in the chat — not under a heading you made up. A reader scanning a tracker learns where each kind of information lives; a one-off heading breaks that for everyone, and headings invented to record your own process ("Analysis", "Findings so far", "Duplicates checked", "Assumptions") record work nobody asked to read.

Work you did that produced no finding is not content. Say it in the chat if it matters.

**Match the weight of the issue to the weight of the change.** The contract says which sections exist, not how long they run. A small change gets a short issue: three or four numbered points per behaviour section, a worked-examples table with a handful of rows, acceptance criteria in single figures. Reserve the long form for work that genuinely branches. Following every rule at maximum length produces an issue nobody finishes reading, which fails the same reader the contract is written for. If Current behaviour runs past about eight points, or acceptance criteria past about ten, you are probably describing the subsystem rather than the change.

### Two artefacts: the issue body and the attached draft

Every issue you create produces two things.

1. **The issue body.** A lean subset of the contract. Listed per template below.
2. **The full draft, as a markdown file, attached to the issue.** Every section the contract calls for, including the ones the body leaves out.

The body is what people read in Jira. Keep it short enough to read in one pass. The attachment carries the complete analysis for whoever picks the work up.

| Template | Sections in the issue body |
|---|---|
| **Story** | User story · Background/context (first paragraph only) · Current behaviour · Intended behaviour · Worked examples · Acceptance criteria — drop Worked examples when the rule does not branch |
| **Bug** | Summary · Steps to reproduce · Expected · Actual (short prose, evidence verbatim) · Impact · Acceptance criteria |

Everything else the contract produces goes to the attachment only:

- **Story** — the rest of Background/context, Solution, Out of scope, and any optional section that applies.
- **Bug** — Background/context, Notes, What we know / don't, Solution or Technical pointers, Out of scope, and any optional section that applies.
- **Bug, Actual** — "short" governs the prose, not the evidence. The functional statement is a sentence or two, and the verbatim evidence (stack trace, log excerpt, generated SQL) stays in the body beneath it. A reader triaging a bug recognises it from the trace faster than from any description, so the evidence belongs where they will see it.

Write the markdown file first, then cut the body down from it. Never write the body first and pad it out afterwards. Cutting keeps the two consistent; padding invents facts that were never analysed.

Name the draft for its subject while you write it — `migration-run-summary.md` — then rename it to the issue key once the issue exists. If no attachment tool is available, say so and hand the file to the user to attach, telling them what to rename it to.

Write the description as **Markdown**, not wiki markup — `## Heading` and `-` bullets, never `h2.`.

**Required and in-the-body are independent axes.** The full picture:

**Story** — ● always · ○ optional · — not in this template

| Section | In the draft | In the body |
|---|---|---|
| User story | ● | ● |
| Background/context | ● | first paragraph only |
| Current behaviour | ● | ● |
| Intended behaviour | ● | ● |
| ↳ Worked examples | ● (drop when the rule does not branch) | ● |
| Acceptance criteria | ● | ● |
| Solution | ● | — |
| Out of scope | ● | — |
| Open questions | ○ | — |
| Mockup · Copy & i18n | ○ UI change | — |
| Investigation findings (measured) | ○ you have measurements | — |
| Data-equivalence verification | ○ the change reshapes a query | — |
| Dependencies | ○ | — |
| Reference | ○ gated | — |

**Bug**

| Section | In the draft | In the body |
|---|---|---|
| Summary | ● | ● |
| Background/context | ○ history only | — |
| Steps to reproduce | ● | ● |
| Expected | ● | ● |
| Actual | ● | ● short prose, evidence verbatim |
| Impact | ● | ● |
| Acceptance criteria | ● | ● |
| Notes | ● (drop when you tested no negatives) | — |
| What we know / don't | ○ cause not yet measured | — |
| Solution | ○ cause known | — |
| Technical pointers | ○ cause unknown | — |
| Out of scope | ○ | — |
| Open questions · Dependencies | ○ | — |
| Reference | ○ gated | — |

A complete worked Bug and Story, draft and body, are in `examples.md`.

**Changing this contract means changing `examples.md` in the same edit.** A stale example beats the rule it contradicts, because people copy what they can see. The same goes for `common-mistakes.md`.

### Story — one contract for every Story

What varies between stories is which *optional* sections get appended, plus one spine section: Worked examples.

```
User story          As a <role that exists in this product>, I want <capability>, so that <outcome>.
Background/context  What today's behaviour is and why it is wrong, then where the rest of the
                    product already does it correctly, then any precedent by key. Two or three
                    paragraphs, no code. The first paragraph must stand alone — it is the only
                    one the issue body carries, so it has to work as the whole justification.
Current behaviour   Numbered. What happens now — error messages verbatim — and what the user or
                    system is left with as a result.
Intended behaviour  Numbered. What must happen instead, including everything that stays the same,
                    said explicitly ("nothing changes for these cases"). Bold every UI label and
                    key term. The unchanged neighbours are the half a reader cannot infer.
  Worked examples   A `###` sub-heading under Intended behaviour holding a decision table.
Acceptance criteria Numbered flat list. One per worked-examples branch, plus what gets stored, plus
                    the test expectation. Each independently verifiable by someone who read nothing
                    else.
                    ─── the issue body ends here; everything below is attachment-only ───
Solution            Implementation-shaping notes: what changes, what drives the condition, and
                    every trap the change leaves behind. Two or three structural bullets, plus one
                    bullet per trap — never drop a trap to keep the section short.
Out of scope        Decided exclusions a reader would otherwise assume are included — with the
                    issue key if it lives elsewhere.
```

**The Current/Intended split is what makes the shape work.** A reader who knows neither can diff the two and see exactly what changes. Never collapse them into a single "Solution as rules" section — that forces every reader to reconstruct the delta themselves.

**Intended behaviour is the contract; Solution is advice.** Intended behaviour states what the system must do, is verifiable by someone who never opens the code, and would still be true if the feature were rebuilt in a different stack. Solution describes *this* codebase as it stands: what to touch and what will bite. Acceptance criteria are written off Intended behaviour and the worked examples, never off Solution.

**Solution must name the trap.** Its highest-value bullet is usually the one identifying code downstream that assumes a guarantee the change removes — a value that can now be absent, an ordering that no longer holds, a branch that becomes reachable. That bullet is invisible to every user and untestable as behaviour; omitting it means the implementer discovers it via a crash.

**Worked examples are a decision table, not prose.** One column per input that steers the rule, plus an Outcome column. Mark the rows whose result changes. Include the unchanged rows — they are the regression set, and the acceptance criteria are written straight off the rows:

| Input A | Input B | Input C | Outcome |
|---|---|---|---|
| no | – | empty | Rejected — "<the exact error message>" |
| yes | Type 1 | empty | **Accepted (new)** |
| yes | Type 1 | filled | Accepted — value retained alongside the flag |
| yes | – | empty | Rejected — "<the exact error message>" |

Cover, at minimum: each branch of the new rule, each branch that must stay unchanged, and the boundary where the two meet.

**Omit Worked examples when the rule does not branch on inputs.** A query reshape, a performance fix, a change with one outcome for every case — there is nothing to tabulate, and a one-row table is noise.

### Story — optional sections

Append only the ones that apply, in this order, after **Out of scope**. All of them are attachment-only. Drop the heading entirely when it does not apply — an empty heading reads as unfinished work, not as a considered "none". A backend or tooling story typically uses none of them.

```
Open questions      Undecided things, each with its options. Never decide one silently.
Mockup              UI change. Screenshots, one per state, captioned. If none exists yet, keep the
                    heading and use it to name the states you need — never infer an unseen mockup.
Copy & i18n         UI change. Table of new keys. Translations drafted and marked (to review).
Investigation findings (measured)   Where you have measurements. Environment, method and run count,
                    then a before/after table.
Data-equivalence verification       Where the change reshapes a query whose rows reach a consumer —
                    a screen, an export, an API response. How output was proven unchanged. Not for
                    a count, an existence check or any query whose rows nobody sees.
Dependencies        Only when something genuinely follows or feeds this, by key.
Reference           Only when the implementer could not find the code from the issue's own terms.
                    Cap it at where to start; a twenty-file list is a reading assignment.
```

**A measured performance fix:** Current behaviour carries the real query in a fenced block, Intended behaviour the proposed one plus any alternative already rejected, with the reason. Acceptance criteria turn technical — execution plan, snapshots passing unmodified, before/after timings in the PR.

**Add Reference only when the implementer has nothing to search on without it.** A well-written body already hands over the identifiers: the verbatim error message, the rule being changed, the entity, the field, the endpoint. Anyone can grep those, so a file list adds nothing and starts going stale the moment the code moves. Include the section only when the relevant code is genuinely unfindable from the issue's own terms — no distinctive string to search for, a generated or configuration-driven path, behaviour spread across a layer a reasonable search would not reach, or a surprising mechanism that needs pointing at. Then give the starting point, not the reading list. If you find yourself adding Reference to compensate for a vague Current behaviour, fix Current behaviour instead.

**A user-facing story** is the base contract plus Mockup and Copy & i18n. The mockup illustrates the states; it does not replace the rules.

**Put every open question to the requester while drafting, and drop the ones they answer.** The section carries only what is still genuinely undecided when the issue is created — a product call nobody has made yet, or a decision waiting on someone who is not in the conversation. Creating an issue that still asks something the requester already told you is a drafting failure, not diligence. Most issues end up with no Open questions at all.

**When you cannot reach the requester, keep the questions and hand them over.** Drafting without anyone to ask is normal. Write the section, and list the same questions in the chat so the user can answer them before the issue is created — say plainly that they are unanswered rather than guessing. Never silently pick an answer to empty the section.

**Out of scope vs Open questions** — they collide constantly, so the rule is:

| The item is… | Goes in |
|---|---|
| Undecided, and someone must decide it | Open questions, with the options |
| Decided, and excluded | Out of scope, with the key if it lives elsewhere |
| A separate defect you found while analysing | Out of scope, named as its own Bug — never silently folded into this story |
| The same weakness on a path that has a supported preferred alternative | Nothing. Don't mention it, don't file it |
| Something the requester ruled out that nobody would have expected anyway | Nothing. It's a transcript of the conversation, not a boundary |

**Out of scope is not a log of the requester's decisions.** Apply one test to every bullet: *would a reader who was never in the conversation assume this was included?* If not, drop it. Answering "no logging" or "not that endpoint" when asked settles the scope; it does not earn a line. A section full of exclusions nobody would have expected reads as a considered product boundary while actually being drafting process — the same failure the closed-list rule names, applied to a section instead of a heading. Keep the bullets a reader would otherwise have to ask about, and say the rest in the chat.

**Before spinning a related weakness out into its own issue, ask whether the affected path is one the product wants used at all.** A route that exists as a deliberate low-ceremony escape hatch — a CRUD endpoint that applies only basic business logic, an admin-only bypass, a legacy import — is not held to the same standard as the supported route. When a correct alternative exists and is the preferred way to do the job, a weakness on the lesser path is not a backlog item, and mentioning it in Out of scope reads as an invitation to file it.

**The test is whether an alternative exists, not how rough the path looks.** A one-off operator CLI with no polish is still the only way that data gets in; a weakness there has no preferred alternative to fall back on, so it is a real backlog item. Rough and optional are different things.

### Defect — Bug

```
Summary             What goes wrong, in which screen, under which combination of settings. An
                    abstract: one or two sentences someone can triage from a list view. It
                    deliberately compresses Actual — that duplication is the point.
Background/context  Optional. Only when the defect has history a reader needs: the change it
                    regressed from, a precedent issue that established the pattern, a prior fix
                    that did not cover this path. Omit it for a defect that stands on its own —
                    most do.
Steps to reproduce  Role/permission needed, then numbered steps. Split into labelled cases when several inputs trigger it.
Expected            The correct behaviour as a rule. Functional — what the user should see or get.
Actual              The incorrect behaviour, precisely enough to become a test. Leads functional in
                    a sentence or two; verbatim evidence (stack trace, generated SQL, log excerpt)
                    goes beneath it, in the body as well as the draft.
Impact              Who is affected and what they can no longer trust. This drives priority.
Acceptance criteria Numbered flat list, each independently verifiable. Include the negative cases —
                    what must stay untouched — and a criterion covering the reproduction from
                    Steps to reproduce. Where the cause is unmeasured, the first criterion records
                    a baseline — row count, environment, method, run count. A reported figure is
                    never the baseline.
                    ─── the issue body ends here; everything below is attachment-only ───
Notes               Which inputs trigger it and — importantly — which do not. Tested only, so drop
                    the heading when you tested no neighbouring cases. This is the one required
                    section that disappears when it would be empty.
```

Optional, appended in this order after **Notes**. All of them are attachment-only:

```
What we know / don't Any bug whose cause is unknown, not only a performance one. A table:
                    reported (not measured) · verified by reading code · not known · missing
                    instrumentation. Pairs with Technical pointers — that lists the candidates,
                    this bounds what is established.
Solution            Where the cause is known and an approach has been chosen. Same meaning as in a
                    Story: what to change and the trap it leaves behind. Numbered when there are
                    alternatives, priority order, core change separated from optional follow-ups.
Technical pointers  Where the cause is unknown. Candidate causes in priority order, each with the
                    real code and file:line, prefixed "starting points from static reading, not a
                    verified diagnosis." Never alongside Solution — see the routing table below.
                    On an unmeasured performance bug this is the bulk of the issue.
Out of scope        Decided exclusions a reader would otherwise assume are included — with the
                    issue key if the work lives elsewhere. Not a log of the requester's decisions.
Open questions / Dependencies / Reference   As for a Story, Reference gated the same way.
```

**Every negative in Notes must be one you tried.** A tested negative bounds the defect: it points at the mechanism, sizes the fix, and stops the implementer bouncing the ticket after a neighbouring case works. An assumed one ("probably doesn't affect exports") reads identically and closes off investigation on no evidence — drop it rather than hedge it.

**Summary is an abstract, Background/context is history — they are not the same job.** Summary exists so someone can triage from a list view, so it stays at one or two sentences and compresses what Actual says at length. Background/context adds what Actual cannot: where this defect came from. A three-paragraph Summary carrying mechanism, row counts and precedent has stopped being skimmable — split the history out. Note the asymmetry with a Story: a Story's abstract is its `User story` line, and a Story always needs Background/context because a change needs justifying, whereas a defect justifies itself.

**Expected and Actual are the Bug's functional description.** They hold behaviour, never a cause — the same standard Intended behaviour meets in a Story. "Expected: the query joins on the active agreement" is a cause masquerading as a requirement; write what the user should see or get.

**The prohibition is on causes, not on observations.** A stack trace, a log excerpt or the generated SQL is what actually happened, so it belongs in Actual: lead with the functional failure in a sentence or two, then paste the evidence verbatim beneath it. Never summarise it away to keep the section "functional".

**Technical pointers is gated on the cause being unknown**, not on the quality of the functional description. Where the cause *is* known, its content belongs in **Solution** instead:

| Situation | Section |
|---|---|
| Cause known, approach chosen | **Solution** — what to change, and the trap it leaves behind |
| Cause unknown, finding it is the deliverable | **Technical pointers** — candidate causes in priority order |
| Cause obvious from the behaviour, no approach decided yet | Neither. Expected/Actual is enough |

Never both. A technical guess alongside a chosen approach only anchors the developer on the guess. For an ordinary defect the cause is usually implied by the behaviour, so Technical pointers rarely applies here; when it does, see *Label hypotheses as hypotheses*.

**An unmeasured performance bug:** Summary names the endpoint, the reported figure, and that it is unverified. Expected quotes the tier being targeted. Actual states the report as reported, naming the assumption it rests on. Technical pointers carries the weight.

**Never promote a reported figure to an acceptance criterion.** A second-hand "about eight seconds" is not a baseline. The first criterion records one; until then the figure stays labelled as reported wherever it appears.

## Formatting

| | Convention |
|---|---|
| Issue title (the Jira summary field) | Sentence case. No bracketed area tag (`[MigrationTool]: …`) — but name the subsystem in the sentence when the title is meaningless without it. Not to be confused with a Bug's **Summary** section |
| Headings | `##` per section, no repeat of the issue title |
| Acceptance criteria | Numbered flat list |
| Open questions | Prose bullets, each with its options |
| Data-heavy content | Tables, not prose — import models (Field \| Type \| Max Length \| Notes), default values, lookup mappings |

Where a project you are writing into visibly uses something else, follow the project. Check recent issues before assuming.

## Field conventions

| Field | Convention |
|---|---|
| Labels | Leave empty unless the project actively uses them — check recent issues before setting one |
| Components | Same |
| Priority | Projects use the full range. Read recent issues to learn what earns each level, and default to the middle one unless data loss, production impact or a blocked release says otherwise |
| Parent | Only the Epic the user names. Never choose one yourself; empty is a correct outcome |

Where the report came from belongs in a **comment**, not the description. If you are drafting rather than creating the issue, hand the comment over as text alongside the description — don't fold it into the body to avoid the extra step.

## Writing style

Write short sentences. One idea per sentence.

**Explain things in a fixed order.** Four steps, always this sequence:

1. Who acts, and why the thing at stake matters to them.
2. What happens in the flow.
3. What that means for the affected party.
4. Why the current workaround does not solve it.

Give each step its own sentence, or its own small group of sentences. Do not merge them. Skip a step only when it does not apply.

**Two things never go in one sentence:**

- Actor, event, mechanism and limitation together. Split them across the four steps.
- Value, problem and workaround chained through a colon and commas. Use separate sentences.

**A `User story` line holds one role, one capability, one outcome.** No second or third actor. Identifiers and field names are fine when they make the capability concrete — what the line must not carry is a second actor, the mechanism, or a chain of outcomes.

Before:

> As a scheduler user, I want the nightly job to stop failing with an out-of-memory error caused by an unscoped include on the product's standards collection, so that agreements expire and the downstream exports, which currently show stale data, become correct again.

After:

> As a scheduler user, I want expired agreements to be closed automatically, so that reports show current data.

The error, the cause and the stale exports did not disappear. They moved to Current behaviour, Solution and Impact, where each one gets its own sentence.

**Repackage, do not trim.** Splitting a sentence must never drop a fact. If a long sentence carried five facts, the short sentences that replace it carry the same five. Length is not the goal. One idea per sentence is the goal.

**Use plain English.** Pick the ordinary word over the impressive one. Readers scan at speed, and many are not native speakers.

## Content rules

- **One rule beats exhaustive cases.** Where several different causes lead to the same outcome, write one rule that says so instead of a branch per cause. Every extra branch is behaviour to build, translate and test. "A line that does not commit is counted as failed" carries five causes; five criteria naming them separately carry the same meaning at five times the cost, and go stale the moment a sixth cause appears.
- **Worked examples for any rule with arithmetic, boundary or combination semantics.** A notice-period or eligibility rule needs its edges spelled out in prose: *"if today is 31 May, the end date must be 30 June or later."* A rule driven by a combination of inputs — a validation rule, a permission matrix, a status transition — needs the decision-table form instead (see *Story*). Either way, three examples per branch beats a paragraph.
- **Evidence verbatim, not paraphrased.** Paste the stack trace, the generated SQL, the measurement table, the error message. Summarising evidence removes the part the developer needs.
- **Label hypotheses as hypotheses.** When you traced a cause statically but could not reproduce it, say so and frame the section as diagnostic steps in priority order — *"starting points, not a verified diagnosis"*. An asserted wrong cause is worse than an honest list.
- **Distinguish measured from reported.** State environment, method and run count for real numbers; mark estimates as estimates and say where they came from.
- **Screenshots inline** at the criterion they illustrate, not collected at the end — except in a dedicated Mockup section.
- **Descoped items struck through**, not deleted, so the decision history survives.
- **Cross-references**: bold keys inline (**ABC-1234**). Always the parent Story/Bug, never a sub-task number.
- **Code**: identifiers, keys and paths in backticks; multi-line in fenced blocks with a language tag.
- **Tense**: present/future. The issue describes what should happen, never what was done.
- **i18n keys follow the convention that dominates the existing keys** in the codebase, not the one proposed in an older issue. Check before inventing a key.
- **Translations are drafted and marked *(to review)***. A native speaker confirms before anything lands in a translation file; never hand-edit one from an issue.
- **Roles come from the code that defines them**, never from Jira prose. Issues routinely use role names that do not exist in the product. Write the user story against a role that exists, and flag the mismatch to the requester rather than silently substituting.
- **Don't decide product questions.** A change to *which rows a user sees* is a product decision. Put it in Open questions with the trade-off, not in an acceptance criterion.
- **No acceptance criteria for scenarios that cannot happen in operation — but always report the edge case in the chat first.** Reachable in code is not the same as reachable in practice. The code shows what is possible; the domain expert knows what occurs, and that is their call to make with the finding in front of them. What is being decided is only where it lands: an acceptance criterion, one `Out of scope` bullet, a remark for the tester in a comment, or a Bug of its own. Never drop a finding silently to keep the issue small.

## Never create these

**Where the project's Jira automation generates `Implementation`, `Code review` and `Test` sub-tasks** on creation of a Story or Bug, creating them by hand produces duplicates. Write the parent issue and stop. Check how the project behaves before creating any sub-task.

Create a sub-task by hand only for genuine one-off work outside that triad (e.g. *"Delete test environment databases after merge"*), with a specific summary.

## Verify

### Before you write

- [ ] Every claim traces to code, a comment, `git log`, or an attachment you read.
- [ ] The reported thing exists, and the requester's premise holds. Where it does not → no issue; the negative finding and its evidence go to the user in the chat.
- [ ] Duplicate scan done. One found → raised with the user in the chat. None found → nothing written anywhere. A precedent, as opposed to a duplicate, is cited in Background/context.
- [ ] Issue type chosen from the Step 2 table.
- [ ] Open questions put to the requester where one is reachable, and the answered ones dropped. Where nobody is reachable, they stay in the section and are listed in the chat as unanswered.
- [ ] Vocabulary and role names taken from the code, not from the request.
- [ ] Any attachment you could not open was raised, never guessed at.

### The draft

- [ ] Sections match the contract for this work type; no invented headings.
- [ ] The issue is sized to the change: behaviour sections in single figures, acceptance criteria around ten or fewer, unless the change genuinely branches that much.
- [ ] Story: Current **and** Intended behaviour both present; what stays the same stated explicitly; the worked-examples table covers the unchanged rows as well as the new ones.
- [ ] Bug: Summary is one or two skimmable sentences, history in Background/context; Expected and Actual functional with evidence verbatim under the lead; cause known → Solution, cause unknown → Technical pointers, never both.
- [ ] Acceptance criteria individually testable, no item bundling rules with "and", traced to Intended behaviour and the worked examples (or to Expected) — never to Solution.
- [ ] Reachable negative and edge cases covered (empty, none eligible, no permission). Cases that cannot occur in operation were reported in the chat, and the expert's call on where they land was followed.
- [ ] Causes sharing an outcome stated as one rule, not a branch each.
- [ ] Reported figures not promoted to acceptance criteria; measured numbers carry method and environment; unverified causes framed as hypotheses.
- [ ] Optional sections appended only where they apply and dropped rather than left empty; every Out of scope bullet passes the cold-reader test; Reference omitted unless the code is unfindable from identifiers the body already gives.
- [ ] Present/future tense, one idea per sentence, explanations in the fixed order, `User story` holding one role, one capability, one outcome. Sentences repackaged, not trimmed.

### Before you create

- [ ] Full draft written to a markdown file, then attached or handed to the user to attach.
- [ ] Body carries only the body subset for this template, cut down from the draft. Nothing in the body is absent from the attachment.
- [ ] Description written as Markdown, not wiki markup.
- [ ] UI change → i18n table present, translations marked as draft.
- [ ] Labels/Components per the project; Priority set; Parent only an Epic the user named, otherwise empty.
- [ ] Referenced keys are Stories/Bugs, not sub-tasks.
- [ ] No `Implementation` / `Code review` / `Test` sub-tasks created.

## Common mistakes

`common-mistakes.md` holds the quick-reference table, grouped by the same three stages as the Verify list above. Read it when reviewing a draft, or when something feels off. The contract above is the authority, and a new row goes in the stage it belongs to rather than at the end.
