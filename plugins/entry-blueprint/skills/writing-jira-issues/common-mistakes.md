# Common mistakes

Quick reference for `writing-jira-issues`. Where a row and `SKILL.md` disagree, `SKILL.md` wins.

Grouped by the same three stages as the Verify list in `SKILL.md`. Add a new row to the stage it belongs to, not to the end.

## Before you write

| Mistake | Reality |
|---|---|
| Took the requester's premise at face value | Check the premise, not just the vocabulary. It may already exist, or not exist at all. |
| Filed an issue for a report you could not evidence | No issue. The negative finding and what rules the report out go to the user in the chat. |
| Wrote "I searched and this doesn't exist" into an issue | There is no section for it, and every required Bug section would be unfillable. It belongs in the chat. |
| Wrote up a duplicate check that found nothing | A clean search is not content. Found one → tell the user in the chat; found none → say nothing. |
| Stayed silent about a precedent because the duplicate scan was clean | A precedent is not a duplicate. Cite it in Background/context. |
| Ignored the Step 2 table and guessed the issue type | The table decides. Precedent in the tracker is a cross-check, not the rule. |
| Guessed an answer so the Open questions section could go | Keep the question, and say in the chat that it is unanswered. |
| Created the issue with Open questions the requester had already answered | Resolve while drafting, then drop the section. |

## The draft

**Shape and sizing**

| Mistake | Reality |
|---|---|
| Invented a section the contract doesn't list | The lists are closed. Use an existing section, a comment, or the chat. |
| Invented a separate template for a UI story, a backend story or a perf fix | One Story contract. UI stories just append Mockup and Copy & i18n. |
| Copied an older issue's layout as the format | Older issues predate this contract. Precedent decides type only. |
| Followed every rule at maximum length | Size the issue to the change. Sixteen acceptance criteria for a one-line change fails the reader the contract serves. |
| Wrote a branch per cause where the causes share an outcome | One rule covers them. Every branch is behaviour to build, translate and test. |
| Wrote acceptance criteria for a case that cannot occur in operation | Reachable in code is not reachable in practice. Report it and let the expert place it. |
| Dropped an unreachable edge case without mentioning it | Never silently, even to keep the issue small. It lands somewhere — a criterion, Out of scope, a tester comment, or its own Bug. |
| Left an empty Mockup / i18n / Dependencies heading | Drop the heading. Empty reads as unfinished, not as "none". |

**Story**

| Mistake | Reality |
|---|---|
| Put the behaviour in Solution instead of Current/Intended | Current/Intended carry the behaviour; Solution carries the implementation trap. |
| Wrote an acceptance criterion off a Solution bullet | ACs test Intended behaviour. Solution is advice the implementer may ignore. |
| Dropped a trap bullet to keep Solution to three | Every trap gets a bullet. The count is a guide for the structural ones. |
| Worked examples listed only the rows that change | The unchanged rows are the regression set. Include them. |
| Wrote a first Background paragraph that only makes sense with the second | The body carries paragraph one alone. It has to stand up by itself. |
| Added Data-equivalence verification for a `COUNT(*)` | Only for queries whose rows reach a consumer. An acceptance criterion covers a number. |

**Bug**

| Mistake | Reality |
|---|---|
| Wrote a cause into a Bug's Expected ("should join on…") | Expected is functional. The mechanism goes in Solution or Technical pointers, per the routing table. |
| Added Technical pointers to a bug whose cause is already clear | Gated on cause-unknown. Known cause with a chosen approach → Solution instead. |
| Summarised a stack trace to keep Actual "functional" | Lead functional, then paste it verbatim. The ban is on causes, not observations. |
| Grew a Bug's Summary into three paragraphs of mechanism and precedent | Summary is an abstract for triage. History goes in Background/context. |
| Listed a negative in Notes you didn't test | Drop it. An assumed negative reads as tested and stops investigation on no evidence. |

**Scope and references**

| Mistake | Reality |
|---|---|
| Logged the requester's answers as Out of scope bullets | Only exclusions a cold reader would assume were included. The rest is conversation. |
| Added a Reference file list the implementer could have grepped for | If the body names the error, rule, entity or field, drop the section. It only ages. |

**Writing style**

| Mistake | Reality |
|---|---|
| Packed actor, event, mechanism and limitation into one sentence | Four steps, four sentences. |
| Chained value, problem and workaround through a colon and commas | Separate sentences. |
| Put a second actor or the mechanism in the `User story` line | One role, one capability, one outcome. The mechanism goes in the body sections. |
| Shortened a sentence by dropping a fact | Repackage, don't trim. Same facts, more sentences. |
| Reached for the impressive word | Plain English. Many readers are scanning, and not all are native speakers. |

## Before you create

| Mistake | Reality |
|---|---|
| Wrote the body first, then padded it into a draft | Draft first, then cut. Padding invents facts nobody analysed. |
| Put the whole draft in the issue body | The body is the lean subset. The full draft goes in the attached markdown. |
| Created the issue without attaching the draft | Both artefacts, every time. |
| Named the draft file after an issue key you don't have yet | Name it for the subject, rename it on creation. |
| Set Labels or Components without checking | Most projects leave them empty. Check recent issues first. |
| Picked a parent Epic yourself, from precedent or memory | Only the user names the Epic. Empty is a correct outcome; ask if you think one applies. |
| Hand-edited a translation file from an issue | Draft it, mark it *(to review)*, let a native speaker confirm. |
| Referenced a sub-task key | Always the parent Story/Bug. |
| Created `Implementation` / `Code review` / `Test` sub-tasks | Jira automation creates them; you get duplicates. |
| Created the issue straight after your own checklist pass | Three fresh reviewers first: contract, claims, errors. You cannot see what your own draft assumes. |
| Forked yourself as a reviewer, or told a reviewer what you believe | A fresh subagent, handed sources, not conclusions. A reviewer handed your hypothesis confirms it. |
| Applied every reviewer finding as given | Check each one against the source. Fix it, or reject it with a reason. |
| Kept a claim the claims reviewer could not source | Find the source, delete the claim, or move it to Open questions with its options. |
| Wrote the review outcome into the issue | It is process. Report it in the chat. |
