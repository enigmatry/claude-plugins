# Integration tests — host, profiles and harness

Companion to the `csharp-unit-tests` skill; read it when a task touches an integration fixture or harness. The skill's [Coverage expectations](../SKILL.md#coverage-expectations) say *what* an integration test is for; this file says how the host, the database profile and the Entry test packages fit together. The project notes name the concrete base classes, helpers, seeded users and route conventions — **use the harness documented there, never invent a parallel one**, and don't assume a helper exists on every fixture base.

## Host ownership and lifetime

Every project settles two things, recorded in its notes: whether the `WebApplicationFactory` (and its `HttpClient`) is **shared across a fixture** or **created per test**, and **who disposes** it.

- Shared factory (the common shape with a database): the fixture base owns it, creates the client in `[SetUp]` or `[OneTimeSetUp]`, and disposes it in the matching teardown. Tests never dispose what the base owns.
- Per-test factory (common in database-free hosts): the fixture creates factory and client in `[SetUp]` and disposes both in `[TearDown]` (or implements `IDisposable` and lets NUnit dispose the fixture instance per test with `[FixtureLifeCycle(LifeCycle.InstancePerTestCase)]`). An undisposed factory leaks sockets, hosted services and static state into later tests.
- Cleanup has to run **after a failed test too** — teardown, not the tail of the test body.
- Resolve services through a **scope** (`Services.CreateScope()`, or the harness's `Resolve<T>()`) and read persisted state through a fresh scope or context, not through entities the test itself tracked.

## Replacing registrations

Out-of-process dependencies — mail, blob storage, message bus, external HTTP, clocks — are replaced by fakes or stubs **registered through the host's existing customization hook**, before the host is built: `WithWebHostBuilder(b => b.ConfigureTestServices(...))` for Microsoft DI, the project's `ConfigureContainer`/Autofac module hook where the app uses Autofac. Check what the project already replaces (project notes: *Shared doubles and host replacements*) before adding your own, and confirm the resolved service *is* the replacement — same lifetime, and for collection registrations the whole collection. Reset mutable fake state and shared singletons between tests.

The clock is replaced the same way: a frozen clock seam registered in the container. A fake that is created but never registered silences nothing.

## The three profiles

### SQL Server — Testcontainers.MsSql + Respawn

The default for a new project whose integration tests must prove persistence. `WebApplicationFactory<Program>` runs against a real SQL Server in a container, reset between tests with Respawn. The database lifecycle — whether from the Entry package or a local copy of it — is: **migrate only when the schema changed** (missing DB or pending migrations), otherwise **Respawn-delete the data**. That is what makes per-test isolation cheap, and it has consequences:

- **Lookup/seed tables must be listed in the reset configuration's ignore list.** Add every new enum/lookup table there or its seeded rows get wiped and unrelated tests start failing. Only immutable reference data belongs on that list — ignored tables are never reset, so a test that mutates one leaks state into every later test.
- A local SQL Server can replace the container through connection-string environment variables (`IntegrationTestsConnectionString` by convention, often supplied via `.runsettings`). Projects needing more than one database require **all** of them to be set before local mode kicks in.
- **Everything that shares a database must not run concurrently** — test projects sharing one database, and fixtures inside one project when assembly- or fixture-level `[Parallelizable]` is on. Racing Respawn and migrations produces phantom failures (deadlocks, `'X' is not a constraint`, HTTP 500s). Check the parallel settings, run one project at a time when the notes say they share state, and treat `dotnet test <Solution>.sln` without a filter as safe only once that is settled.
- Needs Docker (or the connection-string variables) on every machine that runs the suite, including CI.

### In-process host without a database

The right profile for an application that has no database, and a legitimate choice for a project whose persistence is covered elsewhere. The host runs the real pipeline — routing, DI, middleware, authorization, serialization, error translation — with repositories and gateways replaced by fakes or stubs. Assert writes against the stub's state or with `A.CallTo(...).MustHaveHappened...()`. Such a suite proves nothing about SQL Server; the project notes say where query and constraint coverage lives, or record that it is a known gap.

### In-process host with EF in-memory

A project may run application-level integration tests on the EF in-memory provider (Entry ships `InMemoryDbModule`/`InMemoryDatabase` for it). It exercises orchestration over an EF-backed store without a database service, and it does **not** prove SQL translation, relational constraints, transactions or raw SQL — the provider accepts queries and constraints SQL Server rejects. Keep it for the tests whose contract is orchestration, record its purpose and limits in the project notes, and put any test that must prove SQL Server behaviour on the production provider.

## Entry test building blocks — don't re-copy them

Test infrastructure shared by Entry projects ships as NuGet packages. **Before writing any test plumbing, check whether Entry already provides it** — a local copy means a bug fixed upstream never reaches this repo.

| Package | Provides |
|---|---|
| `Enigmatry.Entry.AspNetCore.Tests.Utilities` | `Database.TestDatabase` (Testcontainers.MsSql with a shared ref-counted container, env-var override, and multi-database support via `ConnectionStringEnvironmentVariables` + `OnAfterContainerInitialized`), `DatabaseInitializerOptions` (`TablesToIgnore`, before/after-delete custom SQL, identity reseeding, container image) and the migrate-or-Respawn initializer behind it; `DatabaseHelpers.DropAllSql` + the `SplitStatements()` string extension; `ServiceScopeExtensions.Resolve<T>()`; `Http.UriExtensions.AppendParameters(...)`; and the EF in-memory harness `Database.InMemory.InMemoryDbModule`/`InMemoryDatabase`/`TestRunner` + `TestServer.ApiEnvironment<T>` |
| `Enigmatry.Entry.AspNetCore.Tests.SystemTextJson` / `…NewtonsoftJson` | typed HTTP helpers (`Client.GetAsync<T>`, `PostAsync<T>`, `PostAsync<T, TResponse>`, `PutAsync…`), `DeserializeWithStatusCodeCheckAsync`, the `HttpSerializationOptions`/`Settings` seam for custom converters, and Shouldly-backed response assertions — `BeBadRequest()`, `BeNotFound()`, `ContainValidationError(field, message)` |

Those three are `IsPackable` and on the feed. **`Enigmatry.Entry.AspNetCore.Tests` is not** — despite its `PackageId`, it sets `IsTestProject` without `IsPackable`, so it is Entry's own test suite and ships nothing. Its test-authentication scheme (`TestUserAuthenticationHandler` + `TestAuthenticationOptions` + `TestUserData`, driven by a `TestPrincipalFactory`) is therefore a **pattern to copy, not a dependency to add** — a local copy of it in a project is correct, not duplication. Read it in the building-blocks repo when you need to wire up test impersonation.

`ContainValidationError` is the right tool for the narrow integration test that checks the HTTP error contract — don't parse `ValidationProblemDetails` by hand.

**Check the version the project actually references** before using an API you found in the building-blocks source — a local checkout of that repo is often ahead of the `EntryVersion` the project consumes, and the package contents above describe the current release.

Project-specific plumbing (a factory base that injects configuration, bearer-token helpers, tenant/user seeding) legitimately stays in the repo. The project notes list what the project keeps locally and which local copies the packages supersede.

## Writing the tests

- Seed data in `[SetUp]` with builders plus the harness's add-and-save helper (SQL Server profile), or arrange the stubs the host resolves (database-free profiles).
- Call the API through the typed helpers from `Enigmatry.Entry.AspNetCore.Tests.*Json.Http` — `Client.GetAsync<T>(url)`, `Client.PostAsync<TRequest, TResponse>(url, command)` — not hand-rolled serialization. Check the route prefix the API actually uses (project notes).
- Assert the response with `await Verify(response)` — the typed DTO when the deserialized shape is the contract, the raw response when the wire format, status or headers are. Assert persisted state through the harness's query helper in a fresh scope.
- **Don't add a dedicated test for a simple, logic-free property** (a value just carried command → entity → DTO). Extend an existing create/update round-trip: set it in the command, assert it on the response. Reserve new tests for actual logic.
- Test authentication runs through the project's documented scheme and seeded users; never a real identity provider.

## Running integration tests

Beyond `dotnet test` (see the skill's [Running tests](../SKILL.md#running-tests)): the SQL Server profile needs Docker or the connection-string environment variables; every profile may need per-project settings or secrets listed in the project notes; and projects that share a database run one at a time. `dotnet test --filter "TestCategory=integration"` selects the fixtures that carry the category.
