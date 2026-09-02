# Project notes — <project name>

Project-specific companion to the shared `entry-blueprint:csharp-unit-tests` skill. The skill is the org standard; everything here is specific to this repo. Fill in only what you can verify in the code — delete headings that don't apply.

## Test projects

| Project | Covers | Categories |
|---|---|---|
| `<Solution>.Model.Tests` | domain entities, commands, validators — shared builders and code books live here | `unit` |
| `<Solution>.Api.Tests` | API, in-process via `WebApplicationFactory` | mixed |

Fixture layout notes (where fixtures don't mirror production folders).

## Integration test harness

Base fixture classes, what each seeds (tenant, user, roles), and the helpers they expose (`Client`, `Resolve<T>()`, `AddAndSaveChangesAsync`, `QueryDb<T>()`, …). Authentication scheme for test requests. Route conventions (`api/` prefix or not). Culture forced in setup, if any.

## Entry test packages vs local copies

Which `Enigmatry.Entry.*.Tests.*` packages are referenced; local helpers the packages now supersede (migration candidates); helpers that are legitimately local.

## Test databases

How the database is provisioned (Testcontainers / local connection string / both) and how the mode is selected. Where the Respawn configuration lives and which tables must be ignored. Whether test projects share a database — if so, run them one project at a time. Secrets or environment variables individual fixtures need.

## Test data, builders and code books

- Where reusable builders live (test project and/or production assembly).
- Code-book shape used here (builder-returning entries are the default) and where the books live.
- Reusable valid values (BSN, IBAN, max-length strings) and where they are defined.
- Known duplication to promote into books on touch.

## Shared doubles and host replacements

Which external dependencies are already replaced by test doubles, and where each host registers them.

## Verify

Where shared `VerifySettings` come from (`[ModuleInitializer]` or a settings factory), what they scrub or ignore, and consequences (e.g. members that can never be asserted through a snapshot). Rough snapshot count and what typically churns them.

## Time seams

Every clock seam (`ITimeProvider`, a local-date provider, …) and how each fixture base freezes them — or doesn't.

## Known legacy and dormant tests

Conventions the suite still violates in places (underscored names, `*Tests` suffix, branching bodies, inline `TestCaseData`, ignored or `[Explicit]` fixtures). Convert on touch, don't mass-refactor.

## Accepted deviations

Deliberate departures from the skill, each with its reason.

## Other gotchas

Analyzer setup (which rules fail the build), `TestCategory` filter syntax, validator-fixture conventions, multitenancy behaviour in tests, and anything else a newcomer trips over.
