# Enigmatry Claude Code Plugins

Claude Code plugin marketplace by [Enigmatry](https://github.com/enigmatry).

## Plugins

### entry-blueprint

Skills, workflows, MCP servers, format/build and code-review hooks for .NET 10 + Angular
vertical-slice projects built on the
[Enigmatry Entry Blueprint](https://github.com/enigmatry) starter template.

#### Skills

| Skill | Use for |
|---|---|
| `entry-blueprint:aspnet-rest-apis` | .NET Web API features: MediatR, Autofac, FluentValidation, vertical slices |
| `entry-blueprint:csharp-unit-tests` | C# tests: NUnit 4, Shouldly, FakeItEasy, Verify, builders and code books; integration-test profiles in its references |
| `entry-blueprint:generating-e2e-tests` | Playwright e2e specs: page objects, API teardown, shared-environment safety |
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

#### Hooks

C# style is not described in a skill: the host project's `.editorconfig` is the
standard and the tooling applies it deterministically.

- **PostToolUse** (`Edit`/`Write` of a `.cs` file): runs `dotnet format whitespace`
  on that file in folder mode (no project load, fast). If the file changed,
  Claude is told to re-read it before the next edit.
- **Stop**, `dotnet format` gate: when uncommitted `.cs` files exist, runs
  `dotnet restore`, then `dotnet format --severity info` on them (whitespace,
  style, and analyzer fixes, including `suggestion`-level `.editorconfig` rules)
  and then `dotnet build`. Blocks the stop when any step fails, with the errors
  in the reason. The blueprint builds with `TreatWarningsAsErrors`, so a style
  rule at `warning` that has no code fix also blocks here.
- **Stop**, code-review gate: blocks Claude from finishing while uncommitted
  `.cs`/`.ts`/`.html` files exist that haven't been through
  `entry-blueprint:code-review-blueprint`.

Both Stop gates block at most once per batch of changes (loop-guarded via
`stop_hook_active`). The format hooks are no-ops without the .NET SDK on `PATH`
or without an `.editorconfig` / solution at the project root.

> **Windows note:** the hooks run as POSIX `sh` scripts and require Git Bash
> (installed with Git for Windows). Without it the hooks fall back to PowerShell
> and the gates fail open — everything else keeps working, they are just not
> enforced.

#### MCP servers

The plugin ships two MCP servers used by the workflow skills:

- `azure-devops` — [@azure-devops/mcp](https://www.npmjs.com/package/@azure-devops/mcp) for the `enigmatry` organization
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
base classes, builder and code-book locations, clock seams, integration profile,
known legacy) from **`.claude/project-notes/csharp-unit-tests.md`** at the host
repository root. The skill creates it from its bundled
[project-notes template](plugins/entry-blueprint/skills/csharp-unit-tests/references/project-notes.template.md)
the first time it writes tests in a repo that has none (never during a review),
filling in only what it can verify. A project's choices on the skill's
project-selectable points go in that file, never in a copy of the skill. The skill body carries the common
and unit-test rules; integration-test profiles and harness guidance live in its
`references/integration-tests.md`, loaded only when a task touches them.

## Installation

```
/plugin marketplace add enigmatry/claude-plugins
/plugin install entry-blueprint@enigmatry
```

The repository is public, so no git credentials are needed to add the
marketplace or to receive updates.

### Team setup

Add to your project's `.claude/settings.json`. Once a teammate trusts the repo,
Claude Code registers the marketplace, enables auto-update for it, and reports
the plugin as not installed together with the install command to run — an
externally sourced plugin is never downloaded without that explicit step:

```json
{
  "extraKnownMarketplaces": {
    "enigmatry": {
      "source": { "source": "github", "repo": "enigmatry/claude-plugins" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "entry-blueprint@enigmatry": true
  }
}
```

```sh
claude plugin install entry-blueprint@enigmatry --scope project
```

### Updates

With `autoUpdate` set as above, Claude Code refreshes the marketplace and the
installed plugin in the background after startup whenever the plugin's `version`
is bumped, then asks you to run `/reload-plugins`. To update on demand:

```sh
claude plugin update entry-blueprint@enigmatry
```

## License

[MIT](LICENSE)
