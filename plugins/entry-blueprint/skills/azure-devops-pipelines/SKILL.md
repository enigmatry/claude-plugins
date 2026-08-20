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

- **Never merge a real ticket ID into a branch-gated deploy condition.** Where a `Deploy_*` stage is gated on a ticket-ID placeholder, that placeholder is a temporary manual switch: on your feature branch, substitute your ticket ID to deploy that branch, queue the build, then restore the placeholder before merging. Because the pipeline triggers on every branch, a real ID reaching the default branch makes every push to any branch containing that ID deploy to that environment until someone reverts it. Read the placeholder token, the condition, and the target branch from the repository's own YAML and `CLAUDE.md` — never assume a project's Jira key or default branch name. **Reviewers: reject any PR that merges a real ticket ID into such a condition.**
- When adding a new EF Core `DbContext`, add its name to the `dbContextNames` list passed to the build template. Read the current list from the YAML — don't assume which contexts are already there.
- Environment-specific config goes in `Pipelines/variables/variables.<env>.yml` — never inline environment values in stages.
- Never hardcode secrets or connection strings in YAML — use variable groups or Azure Key Vault references.
- Keep `nodeVersion` in sync with `package.json` engines.
- Keep `batch: true` on triggers to avoid redundant builds for rapid pushes.
