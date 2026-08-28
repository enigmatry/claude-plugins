---
name: frontend-foundations
description: Cross-cutting engineering rules for front-end code — comments, naming, code shape, file organization, failure handling, never silencing a compiler or linter signal, security and secrets, generated code, and documentation upkeep. Use this as the base layer on every front-end coding or review task, alongside whichever language, framework, styling, testing or accessibility skill the task calls for.
---

# Front-End Foundations

The base layer every other front-end skill sits on. Each of them carries only
its own delta and points here. Where two overlap, **this file wins**: a skill may
narrow a rule or name an exception with its reason, never contradict one
silently.

## How to read these rules

- **They bind new and changed code.** An existing violation is debt, not licence:
  leave it unless you are already in that code, and never add another.
- **Fix the cause, not the report** — and do not restate a mechanically enforced
  rule in prose that can drift away from it.

## Comments

Code is self-explanatory through **names, types, and small functions**. A comment
is not that mechanism.

- **Comment only when critical** — a fact that cannot be recovered from the code:
  a non-obvious *why*, a security rationale, a subtle ordering constraint, a link
  to the ticket tracking a workaround.
- **One short line.** Not a paragraph, not a header block.
- **Never narrate what the code does.** No line-by-line commentary, no comment
  restating a name, no structural labels.
- **Prefer intent that executes.** A precise name, a type, or a test that fails
  when the invariant breaks outlives prose. If a comment exists to explain why a
  check is written a certain way, write that test and drop the comment.
- **A comment that is no longer true is a defect** — correct or delete it in the
  same change that outdates it.
- **No new commented-out code.** Delete it; git remembers. A bare `//TODO` with
  no ticket is not an exception.
- **No doc-comment mandate.** Do not add JSDoc merely because a member is public;
  write one when a caller cannot use the API correctly without it. **A published
  package whose reference docs are generated from JSDoc is the exception** —
  there, every exported symbol needs one.

## Naming

- **No abbreviations** — `configuration` not `config`, `button` not `btn`,
  `exception` not `ex`, `initialValue` not `initVal`. Common acronyms (`Id`,
  `Url`, `Http`, `Api`, `Dto`) are fine, as are names fixed outside our control
  (a wire format, generated code, an established path alias).
- Name for **behaviour or domain meaning**, never for implementation or type.
- A name that needs a comment to be understood is the wrong name.
- Casing and sigils are per-language — take them from the language skill.

## Shape of code

- Functions under ~20–30 lines; types under ~100–150. Extract a named helper as
  soon as branching grows.
- **One responsibility per type** — one reason to change.
- **Guard edge cases early** so the happy path stays flat. Maximum 3–4 levels of
  nesting.
- **Always use braces** for every control-flow clause, even a single-line body.
- **No magic numbers or bare literals** where a name adds meaning.
- **Dependencies flow inward.** A high-level module must not depend on a
  low-level detail; keep interfaces small and units independently testable.
- Extend an existing abstraction before inventing a parallel one.
- **Prefer the readable, explicit solution over the clever one.** A construct
  that needs a second read is a cost, not a saving.
- Favour immutable data and pure functions where practical.

## File organization

- **Mirror the module path in the folder layout**, so a file's location follows
  from its name.
- **A file is named for the identifier inside it.** A file with no single primary
  identifier is named for the theme its contents share, plural
  (`date-time-extensions.ts`) — never `helpers`, `utils` or `common`.
- **kebab-case filenames**, always. **One primary declaration per file.** How
  strictly, and how suffixes map, is per-language — see `typescript`.
- New code goes where its neighbours are. Do not start a parallel tree.

## Failure handling

- **Never swallow a failure.** Every catch recovers, or wraps and rethrows. An
  empty catch or a log-and-continue is not handling.
- **Catch where you can actually recover or surface the failure** — not at every
  call site. In TypeScript every `catch` is a catch-all, so a per-call-site
  `try/catch` is a boundary-only construct: use it at the boundary that can tell
  the user something, and let everything else reach the global handler.
- **Do not use exceptions for control flow.**
- **Never fire-and-forget async work** — await it, or hand it to a primitive that
  owns its lifetime.

## Never silence a signal

The compiler, the analyzer and the linter are the cheapest tests available.

- **Do not reach for a type-system escape hatch.** No `@ts-ignore`, no
  `@ts-nocheck`, no `any`, no non-null `!`, no unchecked `as` (see `typescript`
  for the short, complete list of allowed casts and why).
- **A new suppression is the narrowest one that works, and it says why.** One
  named rule at one site — never a bare `/* eslint-disable */`, never a whole
  file. Put the reason beside it: `-- why` after the disable. On the TypeScript
  side that means `@ts-expect-error` with a reason over `@ts-ignore`, since it
  fails the build once the underlying problem is fixed.
- **Lowering a rule's baseline severity is a project decision, not an author's.**
  Argue it in the shared config where the whole repo can review it.
- **Run the project's lint before handing work over, and read its output.** A
  green test run is not the same gate: warning-severity rules do not fail CI, so
  a green build is not evidence your change is clean.

## Security and secrets

- **Never hardcode a secret** — no key, token, connection string or password in
  source, tests, or committed config. Load from the platform secret store,
  request least-privilege scopes, and rotate on a schedule.
- **Never log a secret or PII** — not in a log message, an error, or a snapshot.
- Validate and sanitize anything arriving from outside the process, with schema
  validators or type guards.
- **Encode untrusted content before rendering HTML.** Rely on the framework's
  escaping; never bypass its sanitizer.
- Avoid dynamic code execution (`eval`, `new Function`, untrusted templates).
- Prefer immutable flows and defensive copies for sensitive data; use vetted
  crypto libraries only.

## Generated code

**Never hand-edit generated code.** Change the source of truth — model, endpoint,
or template — and regenerate. Manual edits are overwritten and fail CI staleness
gates. Escape hatches inside generated output are the generator's problem, not
precedent for hand-written code.

## Documentation upkeep

- Update the architecture or design docs when introducing a significant new
  pattern; update the README when setup or commands change.
- Document a new configuration key where the others are documented, and cover it
  in tests.
- Call out a breaking change explicitly in the change description.

## Performance and reliability

Defer expensive work until users need it, paginate large result sets, debounce
high-frequency events, and dispose what you allocate — an undisposed
subscription or timer is a leak.

## Project delta

This skill is deliberately project-neutral. Before writing code, find the
project's own answers and follow them where they narrow a rule here:

- Which lint/format tools run, at what severity, and which are CI gates.
- Where generated code lives and the command that regenerates it.
- The notification/logging primitives for user-facing vs background failures.
- The folder layout and any established naming exceptions.

Those belong in the repo's `CLAUDE.md`/`AGENTS.md` or a thin project-specific
skill — not in this file.
