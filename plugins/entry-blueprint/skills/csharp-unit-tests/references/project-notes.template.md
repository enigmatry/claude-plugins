# Project notes — <project name>

Project-specific companion to the shared `entry-blueprint:csharp-unit-tests` skill. The skill is the org standard; everything here is specific to this repo. Fill in only what you can verify in the code — leave a heading as an open question rather than guessing, and delete headings that don't apply.

## Test projects

| Project | Covers | Categories | Integration profile |
|---|---|---|---|
| `<Solution>.Model.Tests` | domain entities, commands, validators — shared builders and code books live here | `unit` | — |
| `<Solution>.Api.Tests` | API, in-process via `WebApplicationFactory` | mixed | SQL Server (Testcontainers + Respawn) / in-process without database / EF in-memory |

Fixture layout notes (where fixtures don't mirror production folders; where fixture helper types live).

## Integration test harness

Base fixture classes, what each seeds (tenant, user, roles), and the helpers they expose (`Client`, `Resolve<T>()`, `AddAndSaveChangesAsync`, `QueryDb<T>()`, …). Factory and client lifetime (shared per fixture or created per test) and who disposes them. How registrations are replaced (`ConfigureTestServices`, Autofac module, …). Authentication scheme for test requests. Route conventions (`api/` prefix or not). Culture forced in setup, if any. Parallelization settings at assembly and fixture level.

## Entry test packages vs local copies

Which `Enigmatry.Entry.*.Tests.*` packages are referenced and at which `EntryVersion`; local helpers the packages supersede (migration candidates); helpers that are legitimately local.

## Test databases

- **SQL Server profile**: how the database is provisioned (Testcontainers / local connection string / both) and how the mode is selected. Where the Respawn configuration lives and which tables must be ignored. Whether test projects share a database — if so, run them one project at a time. Secrets or environment variables individual fixtures need.
- **EF in-memory profile**: how the store is named and isolated per test or fixture, who owns and resets it.
- **Coverage boundary** (any profile other than SQL Server, for an application that has a database): where SQL Server query and constraint coverage lives, or that it is a known gap. An application without a database records "not applicable".

## Test data, builders and code books

- Where reusable builders live (test project and/or production assembly).
- Code-book shape used here (builder-returning entries are the default; finished objects or `extension` members are the alternatives), how books are named, and where they live.
- Reusable valid values (BSN, IBAN, max-length strings) and where they are defined.
- Known duplication to promote into books on touch.

## Shared doubles and host replacements

Which external dependencies are already replaced by test doubles, and where each host registers them.

## Verify

Which test projects reference `Verify.NUnit` and at which version. Where shared `VerifySettings` come from (`[ModuleInitializer]` or a settings factory), what they scrub or ignore, and consequences (e.g. members that can never be asserted through a snapshot). Rough snapshot count and what typically churns them.

## Time seams

Every clock seam (`ITimeProvider`, a local-date provider, …), its concrete type, and how each fixture base freezes them — or doesn't.

## Validators

Validator-fixture base class and helpers, if the project ships them (field/enum/id sweeps, child-validator canaries), and their file location.

## Known legacy and dormant tests

Conventions the suite still violates in places (underscored names, `*Tests` suffix, branching bodies, inline `TestCaseData`, legacy assertion or mocking libraries, missing categories, ignored or `[Explicit]` fixtures). Convert on touch, don't mass-refactor.

## Accepted deviations

Deliberate departures from the skill on its project-selectable points, each with its reason.

## Other gotchas

Analyzer setup (which rules fail the build), `TestCategory` filter syntax, multitenancy behaviour in tests, and anything else a newcomer trips over.
