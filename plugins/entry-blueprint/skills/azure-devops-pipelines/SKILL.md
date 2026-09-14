---
name: azure-devops-pipelines
description: Best practices for Azure DevOps Pipeline YAML files in the project. Use this when creating, editing, or reviewing Azure DevOps CI/CD pipeline YAML.
---

# Azure DevOps Pipelines

All pipeline YAML lives in `Pipelines/`. Read the actual YAML you're editing; this skill only records rules and rationale you can't derive from the files.

## Shared templates

Reusable pipeline templates are consumed from the **`enigmatry-azure-pipelines-templates`** repository — do not inline template logic that already exists there:

```yaml
resources:
  repositories:
    - repository: templates
      type: git
      name: Enigmatry - Azure Pipelines Templates/enigmatry-azure-pipelines-templates
```

## File layout

Keep the entry pipeline a thin orchestrator. As it grows, split it into local templates by concern — `build-*.yml`, `deploy-*.yml` — and when any of those passes roughly **200 lines**, split it again along the next natural seam: per stage, per job, or per environment. A file long enough that you have to scroll to find a stage is already too long.

## Rules

- **Never merge a manual deploy override in its "on" state.** Pipelines often carry a temporary switch that lets a *feature* branch reach an environment the deploy conditions would otherwise exclude. It takes different shapes — a ticket-ID placeholder inside a branch-gated `Deploy_*` condition (substitute your ticket ID to deploy that branch), or a boolean variable such as `manualPublishOverride: false` folded into an `isDeployBranch` expression (flip it to `true`). The workflow is the same: change it on your branch only, queue the build manually, and restore the default before merging. Because the switch is global, an "on" value landing on the default branch deploys every matching build — every push containing that ID, or every PR-validation build running as `refs/pull/N/merge` — to that environment until someone reverts it. Read the switch's name, its default, the condition it feeds, and the target  branch from the repository's own YAML and `CLAUDE.md`; never assume a Jira key, a variable name, or a default branch. **Reviewers: reject any PR that merges the override in its "on" state, whether that is a real ticket ID or a
  `true`.**
- When adding a new EF Core `DbContext`, add its name to the `dbContextNames` list passed to the build template. Read the current list from the YAML — don't assume which contexts are already there.
- Environment-specific config goes in `Pipelines/variables/variables.<env>.yml` — never inline environment values in stages.
- Never hardcode secrets or connection strings in YAML — use variable groups or Azure Key Vault references.
- Keep nodeVersion aligned with the Node version the repo documents (engines, .nvmrc, or CLAUDE.md).
- Keep `batch: true` on triggers to avoid redundant builds for rapid pushes.
