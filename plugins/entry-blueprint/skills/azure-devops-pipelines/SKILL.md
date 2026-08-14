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

## Rules

- **The `BP-XYZ` placeholder in the `Deploy_Test` condition must stay a placeholder on `master`.** It's a temporary manual switch for deploying a *feature* branch to Test: replace it with your branch's ticket ID on that branch, queue the build, then restore `BP-XYZ` before merging. **Reviewers: reject any PR that merges a real ticket ID in that condition.** Because the pipeline triggers on every branch, a real ID landing on `master` makes every push to any branch containing that ID deploy to Test until someone reverts it.
- When adding a new EF Core `DbContext`, add its name to the `dbContextNames` list passed to the build template (currently one: `AppDbContext`).
- Environment-specific config goes in `Pipelines/variables/variables.<env>.yml` — never inline environment values in stages.
- Never hardcode secrets or connection strings in YAML — use variable groups or Azure Key Vault references.
- Keep `nodeVersion` in sync with `package.json` engines.
- Keep `batch: true` on triggers to avoid redundant builds for rapid pushes.
