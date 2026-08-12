# Enigmatry Claude Code Plugins

Claude Code plugin marketplace by [Enigmatry](https://github.com/enigmatry).

## Plugins

### entry-blueprint

Skills, workflows, MCP servers and a code-review Stop hook for .NET 9 + Angular
vertical-slice projects built on the
[Enigmatry Entry Blueprint](https://github.com/enigmatry) starter template.

#### Skills

| Skill | Use for |
|---|---|
| `entry-blueprint:aspnet-rest-apis` | .NET Web API features: MediatR, Autofac, FluentValidation, vertical slices |
| `entry-blueprint:csharp-coding-standards` | Any C# file: naming, formatting, nullability |
| `entry-blueprint:csharp-unit-tests` | C# tests: NUnit, FluentAssertions, NSubstitute, Verify |
| `entry-blueprint:typescript-coding-standards` | Any TypeScript file: naming, type system, async, architecture |
| `entry-blueprint:angular-unit-testing` | Angular Jest spec files |
| `entry-blueprint:a11y` | UI components and templates: WCAG 2.2 Level AA |
| `entry-blueprint:azure-devops-pipelines` | Azure DevOps pipeline YAML |
| `entry-blueprint:code-review-blueprint` | Reviewing changes before declaring work done |
| `entry-blueprint:jira-branch` | Creating a git branch from a Jira ticket (assigns + transitions the ticket) |
| `entry-blueprint:pull-request` | Creating an Azure DevOps PR with Squash merge and auto-complete |

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

- `azure-devops` — [@azure-devops/mcp](https://www.npmjs.com/package/@azure-devops/mcp); the organization name is requested at install time (plugin user config)
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

## Installation

```
/plugin marketplace add enigmatry/claude-plugins
/plugin install entry-blueprint@enigmatry
```

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
