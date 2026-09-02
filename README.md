# Enigmatry Claude Code Plugins

Claude Code plugin marketplace by [Enigmatry](https://github.com/enigmatry).

> **Private repository** — this marketplace is private to the Enigmatry GitHub
> organization. Installing requires access to `enigmatry/claude-plugins` and
> working git credentials (see [Private repo access](#private-repo-access)).

## Plugins

### entry-blueprint

Skills, workflows, MCP servers and a code-review Stop hook for .NET 10 + Angular
vertical-slice projects built on the
[Enigmatry Entry Blueprint](https://github.com/enigmatry) starter template.

#### Skills

| Skill | Use for |
|---|---|
| `entry-blueprint:aspnet-rest-apis` | .NET Web API features: MediatR, Autofac, FluentValidation, vertical slices |
| `entry-blueprint:csharp-coding-standards` | Any C# file: naming, formatting, nullability |
| `entry-blueprint:csharp-unit-tests` | C# tests: NUnit 4, Shouldly, FakeItEasy, Verify, builders and code books, Testcontainers integration tests |
| `entry-blueprint:frontend-foundations` | Every front-end task: comments, naming, code shape, failure handling, security |
| `entry-blueprint:typescript` | Any TypeScript file: naming, type system, async/await, module boundaries |
| `entry-blueprint:angular` | Angular components, services, directives, templates: signals, standalone, `inject()` |
| `entry-blueprint:angular-testing` | Spec files on Vitest, incl. migrating a repo off Jest/Jasmine/Karma |
| `entry-blueprint:frontend-styling` | `.html`/`.scss`: semantics, SMACSS naming, SCSS modules, tokens, breakpoints |
| `entry-blueprint:a11y` | UI components and templates: WCAG 2.2 Level AA |
| `entry-blueprint:frontend-code-review` | Reviewing a front-end diff: skill per file type, severity tiers, what not to flag |
| `entry-blueprint:azure-devops-pipelines` | Azure DevOps pipeline YAML |
| `entry-blueprint:code-review-blueprint` | Reviewing changes before declaring work done |
| `entry-blueprint:jira-branch` | Creating a git branch from a Jira ticket (assigns + transitions the ticket) |
| `entry-blueprint:pull-request` | Creating an Azure DevOps PR with Squash merge, completed manually after review |

The front-end skills are layered so a rule lives in exactly one file:
`frontend-foundations` is the base every other one points at; `typescript` is
deliberately framework-free; `angular` carries the framework delta and
`angular-testing` the spec delta. The set picks a side in two places —
`async/await` over single-value Observables, and **Vitest as the standard
runner** (a repo on Jest/Jasmine/Karma gets migrated, not extended;
`angular-testing/references/migrate-to-vitest.md` carries the API mapping).
Repo-specific facts belong in the host project's `CLAUDE.md` or a thin
per-project skill, not in these shared skills.

#### Stop hook

A `Stop` hook blocks Claude from finishing while uncommitted `.cs`/`.ts`/`.html`
files exist that haven't been through `entry-blueprint:code-review-blueprint`.
It blocks at most once per batch of changes (loop-guarded via `stop_hook_active`).

> **Windows note:** the hook runs as a POSIX `sh` script and requires Git Bash
> (installed with Git for Windows). Without it the hook falls back to PowerShell
> and the gate fails open — everything else keeps working, the review gate is
> just not enforced.

#### MCP servers

The plugin ships three MCP servers used by the workflow skills:

- `azure-devops` — [@azure-devops/mcp](https://www.npmjs.com/package/@azure-devops/mcp) for the `enigmatry` organization
- `atlassian` — Atlassian remote MCP via `mcp-remote`
- `Context7` — documentation lookup (restricted to `query-docs`, `resolve-library-id`)

#### Project configuration for the workflow skills

`entry-blueprint:jira-branch` and `entry-blueprint:pull-request` read
project-specific identifiers from a **"Known identifiers"** section in the host
project's `CLAUDE.md`. Add one like this:

```markdown
## Known identifiers

- Jira project key: `BP`
- Atlassian cloud ID: `yourcompany.atlassian.net`
- Azure DevOps org/repo: `yourorg/your-repo`
- Azure DevOps project: `Your Project Name`
- Default branch: `master`
```

`entry-blueprint:csharp-unit-tests` reads repo-specific testing facts (fixture
base classes, builder and code-book locations, clock seams, database mode, known
legacy) from **`.claude/project-notes/csharp-unit-tests.md`** in the host
project. Create it from
`skills/csharp-unit-tests/references/project-notes.template.md` — the skill
does this itself when the file is missing. Project rules that differ from the
standard go in that file, never in a copy of the skill.

## Installation

```
/plugin marketplace add enigmatry/claude-plugins
/plugin install entry-blueprint@enigmatry
```

### Private repo access

Claude Code clones this marketplace with your local git credentials. Make sure
they work non-interactively:

```sh
gh auth login          # once, if not already authenticated
gh auth setup-git      # configures git's credential helper to use gh
```

SSH keys or another git credential helper work too. Note that `GH_TOKEN`/
`GITHUB_TOKEN` environment variables alone are **not** picked up by background
marketplace updates — a configured credential helper is required.

Optional hardening: set `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1` so a
failed background update (e.g. after credential rotation) keeps the existing
local marketplace clone instead of discarding it.

### Team auto-install

Add to your project's `.claude/settings.json` so the plugin installs for every
teammate who trusts the repo:

```json
{
  "extraKnownMarketplaces": {
    "enigmatry": {
      "source": { "source": "github", "repo": "enigmatry/claude-plugins" }
    }
  },
  "enabledPlugins": {
    "entry-blueprint@enigmatry": true
  }
}
```

## License

[MIT](LICENSE)
