---
name: code-comments
description: When a comment may be written and what it may say, in every file that can hold one — C#, TypeScript, HTML, SCSS, SQL, scripts, and build, config and pipeline files (`.csproj`, `.props`, `.targets`, pipeline YAML, `tsconfig`, ESLint config, `.editorconfig`, Dockerfile, Bicep). Use this whenever writing, editing or reviewing any such file, together with the language or tool skill.
---

# Code Comments

The one source of truth for comments in every file a project keeps in source
control. Other skills point here and may only narrow a rule, naming the
exception and its reason.

These rules bind new and changed lines. An existing comment that breaks them is
debt: fix it when you are already editing that code, never copy its style.

## The rule

Code explains itself through **names, types, and small units** — in a config
file, through property names, target names, step `displayName`s and the
structure of the file. A comment is not that mechanism.

- **Comment only when it is critical.** Critical means the fact cannot be
  recovered from the code and a careful reader would get it wrong without it: a
  non-obvious *why*, a security rationale, a subtle ordering constraint, or a
  link to the ticket tracking a workaround.
- **One short line** — not a paragraph, not a header block.
- **Never narrate what the code does.** No line-by-line commentary, no comment
  restating a name, no structural labels (`// Arrange`, `# Build stage`,
  `<!-- Properties -->`).
- **Prefer intent that executes.** A precise name, a type, or a test that fails
  when the invariant breaks outlives prose. If a comment exists to explain why a
  check is written a certain way, write the test and drop the comment.
- **A comment that is no longer true is a defect** — correct or delete it in the
  same change that outdates it.
- **No new commented-out code.** Delete it; git remembers. A bare `TODO` with no
  ticket is not an exception.
- **No doc-comment mandate.** Do not add XML doc or JSDoc merely because a member
  is public; write one when a caller cannot use the API correctly without it.
  `frontend-foundations` names the one exception (published packages with
  generated reference docs).

## Explanation belongs in documentation, not in comments

How something works, why it is set up this way, what it is for, how to run or
change it — that is documentation. Put it where people look for it:

| What it explains | Where it goes |
|---|---|
| How a project, tool or folder works, how to run or extend it | the `README.md` beside it, or the project's docs |
| A design decision or a pattern other code should follow | the architecture or design docs |
| Why this change was made, what was tried, what a reviewer should check | the PR description and the commit message |
| A rule for agents working in the repo | `CLAUDE.md` / `AGENTS.md`, or a skill |

If the README already says it, a comment repeating it is noise; if it does not,
the README is what is missing. **Never write a comment because it would help an
AI agent** understand the code: agents read the docs too, and people have to
read past it.

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
- **What is allowed** is the same as in code: one short line where a value would
  otherwise look wrong and someone would "fix" it — a pinned version with the
  ticket that unpins it, an ordering the tool depends on, a setting that must
  match another file.
- **A suppression says why in one line** beside it (`NoWarn`, `#pragma`,
  `eslint-disable`, `Justification` on `[SuppressMessage]`). That line is a
  permitted comment, not an exception to this rule.

## Comments about the change itself

A comment describes the code as it is, to someone reading it later. History
belongs in git.

- No comments recording what changed or what was removed (`// was X`,
  `// new:`, `# moved from build.yml`, `// fixed bug`).
- No comments addressed to the reviewer or the user (`// as requested`,
  `// see PR discussion`). That conversation goes in the PR.
