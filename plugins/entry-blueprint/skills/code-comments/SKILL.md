---
name: code-comments
description: When a comment may be written and what it may say, in every file that can hold one — C#, TypeScript, HTML, SCSS, SQL, PowerShell and shell scripts, and build, config and pipeline files (`.csproj`, `.props`, `.targets`, pipeline YAML, `tsconfig`, ESLint config, `.editorconfig`, Dockerfile, Bicep). Use this whenever writing, editing or reviewing any such file, together with the language or tool skill.
---

# Code Comments

The one source of truth for comments in every file a project keeps in source
control. Other skills point here and may only narrow a rule, naming the
exception and its reason.

These rules bind new and changed lines. An existing comment that breaks them is
debt: fix it when you are already editing that code, never copy its style.

## The rule

Code must be self-explanatory through **names, types, and small methods** — in a
config file, through property names, target names, step `displayName`s and the
structure of the file. A comment is not that mechanism.

Everything below governs **human-authored explanatory and documentation
comments**. Generated headers, tool directives, suppression justifications,
ticketed TODOs and versioned SQL migration blocks follow
[Exceptions](#exceptions) instead.

### An inline comment is admissible in exactly two cases

**The comment itself must identify which** — by naming the external behaviour or
constraint, or by naming both the plausible edit and the resulting defect. Where
both cases fit, classify it as (1).

1. **Observed or documented behaviour, or a binding constraint, of a system,
   tool or contract outside the edited code** — something the code cannot express
   and a reader cannot deduce. *"The vendor API sends these as numbers or quoted
   strings, sometimes both in one payload."* A licence or contractual limit
   counts, and belongs next to the code it constrains rather than only in the PR:
   *"plotted as published: the provider's terms forbid altering the data."*
2. **A specific edit a reader would plausibly make, and the specific defect it
   would cause.** Name both halves; "this is subtle" or "this is deliberate" is
   neither. **A defect means violating an external contract or standard, a safety
   or correctness property, or a previously established repository invariant** —
   a test may evidence such an invariant but never establishes one by itself. A
   cost, a performance tradeoff, an outcome the author preferred, or a decision
   recorded only in a ticket is **not** a defect, so "don't replace this with
   per-item lookups, that is an N+1" stays out. *"After `switchMap` on purpose:
   before it, teardown leaves the in-flight request running."* When a test can
   enforce the property, write it; keep the comment only if the harmful edit
   still looks valid locally.

**Prefer intent that executes.** A precise name, a type, or a test that fails
when the invariant breaks outlives prose. If a comment exists to explain why a
check is written a certain way, a test asserting that case is strictly better —
write the test and drop the comment.

### Documentation comments

XML doc and JSDoc have one separate allowance: **an API fact a caller needs that
the signature cannot carry** — a thrown exception, a precondition, a documented
range. *"Throws ArgumentOutOfRangeException when the interval exceeds 31 days."*
Do not document a member by restating its name, or merely because it is public.
`frontend-foundations` names the one front-end exception (a published package
whose reference docs are generated from JSDoc).

### Length

**Each admissible comment is one line and at most 120 characters** — consecutive
comment lines count as one comment, so two adjacent one-liners are still one
comment and still capped. If it will not fit, the name is wrong or the fact
belongs in the PR.

### Never

- **Narrate what the code does** — no line-by-line commentary, no comment
  restating the identifier, the signature or the next line, no structural labels
  (`// Arrange`, `# Build stage`, `<!-- Properties -->`).
- **Leave a comment that is no longer true** — that is a defect; correct or delete
  it in the same change that outdates it.
- **Record the change itself** — what changed or was removed (`// was X`,
  `// new:`, `# moved from build.yml`), or a note to the reviewer or user
  (`// as requested`, `// see PR discussion`). History belongs in git, the
  conversation in the PR.
- **Write a comment to help an AI agent** understand the code. Agents read the
  docs too, and people have to read past it.

## Explanation belongs in documentation, not in comments

Rationale, rejected alternatives, why a type exists, and what a decision cost go
in the **PR description**; a sentence restating the identifier, the signature or
the next line goes nowhere. Longer-lived explanation goes where people look for
it:

| What it explains | Where it goes |
|---|---|
| Why this change was made, what was tried, what it cost, what a reviewer should check | the PR description and the commit message |
| How a project, tool or folder works, how to run or extend it | the `README.md` beside it, or the project's docs |
| A design decision or a pattern other code should follow | the architecture or design docs |
| A rule for agents working in the repo | `CLAUDE.md` / `AGENTS.md`, or a skill |

If the README already says it, a comment repeating it is noise; if it does not,
the README is what is missing.

## Build, config and pipeline files get no exemption

The rule applies unchanged to `.csproj`, `.props`, `.targets`,
`Directory.Packages.props`, pipeline YAML, `tsconfig*.json`, ESLint and
Stylelint configs, `.editorconfig`, Dockerfiles and Bicep. These files are read
by a tool, and the person opening one is looking for a setting; prose around
every element hides it.

- **No explanatory blocks.** A multi-line XML comment above an MSBuild target
  saying what it does and why, or a YAML comment above each step or variable, is
  the case this rule exists for. A well-named target, property or `displayName`
  says what; the README or PR says why.
- **No section banners** grouping properties or steps; the file's own structure
  groups them.
- The two admissible cases and the 120-character line apply as in code — for
  example a setting that must match a value in another system, or an ordering the
  tool depends on that a tidy-up would break.

## Exceptions

- **Tool directives and generated headers** — `#pragma`, `eslint-disable`,
  `prettier-ignore`, a generator's `<auto-generated>` header — are not
  explanatory comments. Leave generated ones alone.
- **A suppression says why in one line** beside it (`NoWarn`, `#pragma`,
  `eslint-disable`, `Justification` on `[SuppressMessage]`).
- **A TODO carries its ticket.** A bare `TODO` with no ticket is deleted.
- **No new commented-out code.** Delete it; git remembers. An existing block
  earns its place only if the line above it says which case it is: a
  dev-iteration helper that cannot ship enabled, a revisit trigger naming the
  condition that would flip it back, or a generator's own scaffold. A superseded
  expression sitting beside its replacement, an unreferenced method, and a bare
  `//TODO` with no ticket are none of those — delete them on sight.
- **Versioned SQL migrations are the standing exception.** A reverse/revert
  block, a re-run helper that makes a non-idempotent seed script locally
  repeatable, and a destructive step deliberately deferred for rollback safety
  are all legitimate, and none of them will ever have a ticket. Label the block —
  `-- reverse script`, `-- re-run helper`, `-- deferred: <why>`.

## Reviewing comments

- **Deleting a human-authored comment that fails these tests is always correct**
  and needs no discussion.
- **A stale or misleading comment is a finding. Absence of comments is not** —
  self-explanatory code is the standard.
