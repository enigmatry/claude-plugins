---
name: frontend-code-review
description: Review harness for a front-end change — which skill to load for which file type, severity tiers, a scan order, the comment format, and an explicit list of what not to flag. Use this when reviewing an Angular, TypeScript or SCSS pull request or diff. It provides the process only; the rules being checked live in frontend-foundations, typescript, angular, frontend-styling, angular-testing, generating-e2e-tests and a11y.
---

# Front-End Code Review

You are an expert front-end engineer reviewing a change. **Flag only what
matters**: bugs, security problems, broken conventions, wrong architecture.

This file is the *harness*. The rules you check against live elsewhere — load
the ones the diff touches rather than working from memory.

| Diff touches | Load |
|---|---|
| anything | `frontend-foundations` |
| `.ts` | `typescript` |
| components, services, directives, pipes, interceptors, guards, resolvers, templates | `angular` |
| `.html`, `.scss` | `frontend-styling` |
| user-facing UI | `a11y` |
| unit/component specs (colocated beside their source) | `angular-testing` |
| Playwright e2e specs (a `playwright.config.*` in the suite) | `generating-e2e-tests` |

Review comments are written in **English**.

## Severity tiers

Rank every finding and report the most severe first.

**🔴 CRITICAL — blocks merge**

- Security: vulnerability, exposed secret or PII, missing authorization check
- Correctness: logic error, data corruption, race condition
- Breaking change: a published package's public API changed without a version
  bump (what counts as breaking: `typescript` → *Module and public-API
  boundaries*)
- Data loss

**🟡 IMPORTANT — requires discussion**

- Code quality: severe SOLID violation, excessive duplication
- Test coverage: new behaviour or a new public API with no test
- Performance: obvious bottleneck, memory leak, undisposed subscription
- Architecture: significant deviation from the established pattern, or a
  dependency pointing the wrong way
- Accessibility: a WCAG AA failure in changed UI

**🟢 SUGGESTION — non-blocking**

- Readability, naming, logic that could be simplified
- Optimization with no functional impact
- Minor convention deviations
- An `a11y` rule tagged *(house rule)* violated in a project that has not
  adopted it as its own standard — unmarked `a11y` rules are WCAG failures and
  stay IMPORTANT
- A missing doc comment where `frontend-foundations` → *Comments* requires one
  (generated reference docs only — never on public members generally)

## Scan order

Work outside-in and stop at the first tier that makes the change unmergeable.
Check each step against the loaded skill, not from memory.

1. **Scope** — does it do what the description says, and only that? An unrelated
   drive-by change is its own finding.
2. **Correctness** — off-by-one, null paths, race conditions, missing `await`.
3. **Security** — secrets, PII in logs, unvalidated input, unsanitized HTML.
4. **Failure handling** — empty catch, `void` on a promise, log-and-continue, a
   duplicate notification for an error already handled globally.
5. **Suppressions** — `any`, `!` and `@ts-*` are banned outright
   (`frontend-foundations`, `typescript`): any new one is a finding, reason or
   not. A new `as` must be one of the casts `typescript` allows — anything else
   is a finding. A new lint disable needs a named rule and a stated reason.
6. **Framework conventions** — `angular`'s bans and requirements: structural
   directives, `@for` track stability, DI style, decorators, `async` hooks,
   `OnPush`, selector prefix.
7. **Accessibility** — for any changed template.
8. **Styling judgement calls** — the ones Stylelint cannot make: foundation
   reuse, tokens, vendor overrides, encapsulation, combinators, class naming.
   Check the diff against `frontend-styling` → *Before you finish* — that list
   is the authority; do not re-derive it from memory here.
9. **Tests** — is the new behaviour covered, do the tests branch, can they fail,
   are they deterministic? Judge an e2e spec by `generating-e2e-tests`, not
   `angular-testing` — its run-unique randomized keys, suite layout and timeout
   literals are required there, not findings.
10. **Leftovers** — commented-out code, `TODO` with no ticket, debug logging,
    unused imports, hand-edits to generated files.

## Review principles

1. **Be specific** — exact file and line, with a concrete example.
2. **Provide context** — explain *why* it is an issue and what the impact is.
3. **Suggest a solution** — show the corrected code, not just the problem.
4. **Be constructive and pragmatic** — improve the code rather than criticize the
   author, acknowledge a smart solution, and group related comments into one
   instead of filing five about the same thing.
5. **Say what you did not check** — an untested runtime path, a design decision
   you lack context for.

## Comment format

````markdown
**[TIER] Category: Brief title**

What is wrong, in one or two sentences.

**Why this matters:**
The impact, or the reason for the suggestion.

**Suggested fix:**
```ts
// corrected code
```

**Reference:** the convention it violates, or a link.
````

## What NOT to flag

- **Anything a tool already reports.** Formatting, indentation, quote style,
  trailing commas, and every rule ESLint or Stylelint enforces at error severity
  — CI will say it, and saying it again buries the findings that matter. If a
  rule *should* exist and does not, the config is the finding, not the line.
- **Pre-existing violations the diff merely moved.** Debt is not this author's
  finding unless they are already editing that code.
- **Generated files** — `*.generated.*`, codegen or NSwag output. Review the
  generator or its template instead.
- **A documented in-flight migration** — a component still on the old pattern
  because the migration is deliberately staged. Check the repo's own notes before
  calling it a bug.
- **Stylistic preferences with no defensible reason.** "I'd have written it
  differently" is not a review comment.
- **Speculative performance concerns** without a measurement or a clear
  mechanism.

## Project delta

Before reviewing, read the repo's `CLAUDE.md`/`AGENTS.md` and any
project-specific review skill for:

- Architecture patterns unique to the repo (configuration/provider patterns,
  entry-point boundaries, permission services, filter models).
- Which migrations are in flight and therefore not findings.
- Which lint rules are CI gates and which are warning severity.
- Whether the repo publishes packages — that raises API changes to CRITICAL.
