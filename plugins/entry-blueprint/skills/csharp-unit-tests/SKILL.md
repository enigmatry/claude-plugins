---
name: csharp-unit-tests
description: Best practices for C# unit and integration testing in Enigmatry Entry projects — NUnit 4, Shouldly, FakeItEasy, Verify.NUnit, builders and code books, the Enigmatry.Entry test packages, and WebApplicationFactory + Testcontainers.MsSql + Respawn. Use this when writing or reviewing C# tests.
---

# C# Unit and Integration Testing (Enigmatry Entry)

**This file is the shared Enigmatry standard, distributed through the `entry-blueprint` plugin — don't copy it into a repo or edit it per project.** Everything project-specific — base-class names, helper APIs, seeded test users, builder and code-book locations, clock seams, known legacy — lives in the host repo's **project notes** at `.claude/project-notes/csharp-unit-tests.md`. Read that file before writing tests. If the repo has none yet, create it from `${CLAUDE_PLUGIN_ROOT}/skills/csharp-unit-tests/references/project-notes.template.md` and fill in only what you can verify in the repo. When a project needs a different rule, change its project notes, not this file; that is what keeps the standard from drifting.

## Stack

| Purpose | Library | Notes |
|---|---|---|
| Test runner | **NUnit 4** + **NUnit.Analyzers** | `[Test]`, `[TestCase]`, `[TestCaseSource]`. The org baseline — don't bump the test-framework major as part of ordinary test work. |
| Assertions | **Shouldly** | `x.ShouldBe(y)`, `ShouldBeTrue`, `ShouldNotBeNull`, `ShouldBeOfType`, `ShouldBeEmpty` |
| Mocking | **FakeItEasy** | `A.Fake<T>()`, `A.CallTo(...)`, `.MustHaveHappened...()` |
| Mocking `IQueryable` | **MockQueryable.FakeItEasy** | `.BuildMock()` to back a repository's `QueryAll()` |
| Snapshots | **Verify.NUnit** | complex objects, DTOs/responses, documents, integration responses |
| Test data generation | **AutoFixture** / **Bogus** | only where the values genuinely don't matter — see [Determinism](#determinism) |
| Integration host | **`Microsoft.AspNetCore.Mvc.Testing`** (`WebApplicationFactory<Program>`) | real API pipeline, real DI container |
| Integration database | **Testcontainers.MsSql** + **Respawn** | a real SQL Server; **never** the EF Core in-memory provider |

**Never introduce** (all present in some older Enigmatry suites — legacy, don't copy, convert on touch):

- `FluentAssertions` (`.Should().Be(...)`) — Shouldly only
- `NSubstitute` (`Substitute.For<T>()`) and `Moq` (`new Mock<T>()`, `.Setup`, `It.IsAny`, `.Object`, `.Verify(..., Times.X)`) — FakeItEasy only
- Classic NUnit asserts (`Assert.AreEqual`, `Assert.IsTrue`, `ClassicAssert`) and the constraint model (`Assert.That(x, Is.EqualTo(y))`) — Shouldly only
- The EF Core in-memory / SQLite provider as a stand-in for SQL Server — it silently accepts queries and constraints SQL Server rejects
- MSTest or xUnit (`[Fact]`, `[Theory]`, `[MemberData]`) — some repos still contain an isolated xUnit project; the project notes list them if so

A single test file must never import two mocking libraries or two assertion libraries. If you touch a legacy fixture, finish the conversion in that file.

## Coverage expectations

Every new or materially changed handler, validator, domain rule, or mapping needs focused tests — the happy path plus the validation, boundary and error paths that actually carry risk. "It's covered by an existing integration test" is only true if that test would fail when the new behaviour breaks.

Every test must be able to fail when the behaviour it protects breaks. Assert an observed outcome or interaction — never a tautology or a value copied straight from the arrange. When adding a test, observe it failing for the intended reason (before or while implementing the production change) before considering it complete — fail against the pre-fix behaviour or a temporary mutation of the protected production code, with a failure message naming the broken contract; flipping the expected value, or Verify failing only because no `.verified.txt` exists yet, proves nothing.

## Project and file layout

- One test project per production project: `<Project>.Tests`. Mirror the production folder structure inside it.
- Name test files and classes with the `Fixture` suffix: `Section.cs` → `SectionFixture.cs`. The name must carry the subject type or concept — never a bare `Fixture` (unsearchable).
- **Never add `[TestFixture]`** — NUnit discovers any non-abstract class that has `[Test]` methods, whatever it's called, and an abstract base with `[TestFixture]` on it changes nothing. The `Fixture` suffix is a naming convention, not a discovery mechanism. (The attribute is only needed when it carries construction data — `[TestFixture(arg)]`, a generic fixture's type arguments, or `[TestFixtureSource]`.)
- **Every fixture carries `[Category("unit")]` or `[Category("integration")]`** so CI can filter (`dotnet test --filter "TestCategory=unit"`).
- Prefer `internal sealed` for new unit fixtures. NUnit discovers `internal` fixtures perfectly well — `public` is **not** required for discovery. Integration fixtures inheriting a public base follow the base's accessibility; match the surrounding project rather than mass-changing.
- **Name the subject after its type, never `_sut`/`sut`**: `private EmployeeService _employeeService;`, not `private EmployeeService _sut;`. Same for dependencies — `_contractRepository`, not `_repo2`.
- Declare the subject and its dependencies as private `_camelCase` fields — never PascalCase `{ get; set; }` auto-properties (legacy style). Add `= null!` to `[SetUp]`-assigned fields **only when the test project has `Nullable` enabled**; projects with nullable disabled declare them plainly.

## Naming — descriptive PascalCase, no underscores, no repeated context

The fixture name already identifies the subject, so the method name describes only scenario and outcome, in PascalCase. Given-When-Then is expressed in the words (`WhenXThenY`), not with separators:

```csharp
// ✅ correct
WhenEndExceedsMaxLengthThrows
ToStringReturnsEndValue
InactiveEmployeeIsNotReturned

// ❌ avoid — underscores
Constructor_WhenEndExceedsMaxLength_ThrowsArgumentOutOfRangeException

// ❌ avoid — repeating the fixture's subject
EmployeeServiceCreateReturnsId   // "EmployeeService" is already the class name
```

Older suites contain many `Method_Scenario_Expectation` names. Treat them as legacy: don't add new ones, don't mass-rename.

## Test structure — AAA without comments

Separate Arrange / Act / Assert with a **blank line only** — never write `// Arrange`, `// Act` or `// Assert`.

```csharp
[Test]
public void ToStringReturnsEndValue()
{
    var section = new Section(0, 2500);

    var result = section.ToString();

    result.ShouldBe("2500");
}
```

**Prefer a single logical assertion per test.** Asserting two tightly-related properties of the same result is one concept and fine — though once a result object needs several assertions, `await Verify(...)` on the projected contract is usually the better trade — one assertion line, the whole contract pinned. Assertion count is the smell signal, not a licence to snapshot a larger object than the contract (see [Verify](#snapshot-testing-with-verifynunit)). Asserting unrelated outcomes is never fine — split the test, or collapse it with `[TestCase]`. Run one arrange→act→assert cycle per test; never re-mutate state and assert a second scenario in the same body.

**Do not use `ShouldSatisfyAllConditions`** (or a stack of `ShouldContain`/`ShouldBe` calls) to bundle unrelated outcomes into one test — that is the multi-assertion smell, not an exception to it. Reach for [Verify](#snapshot-testing-with-verifynunit) when the whole result is a contract worth snapshotting; a growing stack of `ShouldBe`s on one DTO's fields is the signal, not a hard threshold.

## No branching on the scenario

Test bodies must not branch on **which scenario they are testing** — no `if`/`else`, ternary, `switch` or null-coalescing that selects a different expectation or a different act. A branch like that means one test silently covers several behaviours, so a failure no longer says which path broke.

Remove it one of two ways:

- **Split the divergent case into its own test** — the norm for "found vs not found", "valid vs invalid".
- **Push the variation into the test data** — carry the expected value on the `*Data` object and assert it directly instead of computing it with `? :`.

```csharp
// ❌ avoid — a ternary picking the expected value
result.ShouldBe(expectedVisible ? targetUser : null);

// ✅ correct — the null case is its own test; the expected value is carried in the data
result.ShouldBe(data.Expected);
```

Straightforward iteration in *arrange* (seeding several entities, building a list) or a cohesive collection assertion is fine — the rule targets control flow that changes the scenario or the expectation, not every loop.

## Parameterized tests — [TestCase] and [TestCaseSource]

**Scan for duplication before writing a new `[Test]` method.** Two or more tests that share body structure and differ only in literal values (strings, numbers, enum members) MUST be collapsed into one `[TestCase]`-parameterized method, even when their names differ.

```csharp
// ❌ avoid — identical structure, only the expected value differs
[Test] public void ActiveStatusHasCorrectName()   { ... status.Name.ShouldBe("Active"); }
[Test] public void InactiveStatusHasCorrectName() { ... status.Name.ShouldBe("Inactive"); }

// ✅ correct
[TestCase(UserStatusId.Active,   "Active")]
[TestCase(UserStatusId.Inactive, "Inactive")]
public void StatusHasCorrectName(UserStatusId id, string expected)
{
    var status = UserStatus.FromValue(id.Value);

    status.Name.ShouldBe(expected);
}
```

Use `[TestCaseSource]` when the data is objects rather than literals, or is reused across fixtures:

```csharp
[TestCaseSource(typeof(FindVisibleByIdSource), nameof(FindVisibleByIdSource.Get))]
public void FindVisibleByIdReturnsExpectedUser(FindVisibleByIdData data) { ... }
```

Sources run at test **discovery**, before any `[SetUp]` — keep them static and self-contained (no fixture state, DI, database, or clock), and don't cache a source's output in a `static readonly` field.

For readable case names in the runner, rely on a positional `record`'s generated `ToString` for primitive data, or compose several real fields (`ToString() => $"{Type} {Threshold}"`). For opaque domain objects pass a label as a **constructor parameter that only `ToString` reads** — never `ToString() => SomeProperty;` on an already-public property.

## Reducing duplication

Before adding a test, look for structure to share instead of copy — in this order:

1. **Collapse identical bodies into one parameterized test** (`[TestCase]` for literals, `[TestCaseSource]` + `*Source`/`*Data` for objects). Never leave two near-identical `[Test]` methods that differ only by input — a reviewer will send it back.
2. **Extract a shared arrange/act/assert helper**: repeated arrange lines → a private `Arrange(...)` helper; a repeated invocation → `Act(...)`; a repeated verification → a named helper (`VerifyNoSave()`). The subject and its fakes are `[SetUp]` fields the helpers read and write.
3. **Lift shared construction of a non-trivial dependency out of the fixtures** into one internal factory/builder called from each `[SetUp]` — don't paste the wiring into every fixture.
4. **Move repeated object graphs into a Builder, repeated named objects and values into a code book, and repeated case sets into a `*Source`.**

Duplication that varies only by data is a smell, not a style choice.

## Test data

Reusable mutable test objects are created fresh per use. Never hold an entity, DTO, collection, or other mutable object graph in a `static readonly` field or a fixture-lifetime field initializer — NUnit reuses one fixture instance for all its tests, so one test mutating the graph silently changes what a later test arranges. Return it from a builder, factory method, or expression-bodied property instead. Constants and immutable values are unaffected.

### Builders — the default

Reusable entity/DTO construction goes into a fluent `*Builder`: `With*` methods returning `this`, a `Build()`, and an `implicit operator` to the built type so a builder can be passed straight where the entity is expected. Default every field to something valid so a test only sets what it cares about.

```csharp
var user = new UserBuilder()
    .WithEmailAddress("john_doe@john.doe")
    .WithFullName("John Doe")
    .WithStatusId(UserStatusId.Active);
```

Build through the domain factory (`User.Create(command)`) rather than setting properties, so the entity's own invariants run. Prefer inline construction when an object is used by exactly one test; move it to a builder from the second use. **Builders are frequently shared across test projects — and in some repos live in a production assembly. Search for an existing one before writing a new one** (the project notes say where they live).

### Code books — named test data

A **code book** gives a recurring test object or value one name in one place, instead of the same literal or private `Build*` helper re-declared across fixtures. A book is a per-domain-type `internal static` class of expression-bodied entries, named by the *meaning* the entry carries in a test — `Some…`, `Another…`, `Expired…`, `NotFound…` — never by the test that first needed it. Because entries are `=>` members, every access yields a fresh object, so a shared entry can never leak one test's mutations into the next (the rule at the top of this section). Meaning-named value constants — a valid BSN, a valid IBAN, a max-length string — belong in the same book as the objects that use them.

```csharp
internal static class Users
{
    public static UserBuilder Some => new UserBuilder()
        .WithEmailAddress("some.user@example.com")
        .WithStatusId(UserStatusId.Active);

    public static UserBuilder Deactivated => Some.WithStatusId(UserStatusId.Deactivated);
}

var user = Users.Deactivated.WithFullName("Jane Doe");
```

The default shape in Entry projects is the one above: **entries return a pre-configured builder, not a finished entity**, so the domain factory still runs and callers keep chaining `With*`. Entries may compose entries from other books. A project may choose another shape — entries returning finished immutable objects, or C# 14 `extension(User)` static members so that `User.Some` reads like a member of the type — as long as entries stay fresh per access and named by meaning. The project notes say which shape the project uses and where its books live.

Promotion follows the duplication ladder: construct inline while one test needs it → lift to a fixture-local expression-bodied member when the fixture reuses it → promote to a book entry the moment a second fixture needs the same shape or value. Adopt on touch: promote when you edit a fixture that duplicates a shape, don't sweep the suite.

### `*Source` classes — `[TestCaseSource]` data sets

- Name the class `*Source` and the method `Get()` (or `GetData(...)` when it needs runtime arguments); `yield return` one case per line, each optionally delegating to a named private helper.
- **Prefer a dedicated `*Source` file per data set** — one class, one set. Don't collect many unrelated `[TestCaseSource]` sets as sibling methods on one class; it hides which set feeds which test. A small source owned by exactly one fixture may stay next to it — that permission is about *placement*, not embedding: non-trivial case construction still belongs in a named `*Source` class, not in an inline `IEnumerable<TestCaseData>` method or collection initializer on the fixture itself.
- Keep sources free of assertion logic — data only. Sources may compose builders.

| Situation | Use |
|---|---|
| Object used once, in one test | inline construction |
| Same object shape needed by ≥2 tests | `*Builder` |
| Same named object or value (a role, a state, a canonical valid value) needed by ≥2 fixtures | code book entry |
| Same test body run with multiple data variants | `*Source` + `[TestCaseSource]` |

## Mocks — FakeItEasy

Create fakes **inside the test** by default. When a fixture has more than one test exercising the same subject, hold it and its dependencies as private fields, build them once in `[SetUp]`, and give each test a small `Arrange` helper that configures the fakes. Never write a static factory that rebuilds the subject inside every test — it is built in one place.

```csharp
private IRepository<User> _userRepository = null!;
private ICurrentUserProvider _currentUserProvider = null!;
private UserService _userService = null!;

[SetUp]
public void SetUp()
{
    _userRepository = A.Fake<IRepository<User>>();
    _currentUserProvider = A.Fake<ICurrentUserProvider>();
    _userService = new UserService(_userRepository, _currentUserProvider, A.Fake<ITimeProvider>());
}

private void Arrange(params User[] users) =>
    A.CallTo(() => _userRepository.QueryAll()).Returns(users.ToList().BuildMock());
```

- Back an `IQueryable`-returning repository method with `MockQueryable.FakeItEasy`'s `.BuildMock()` — it supports async EF operators (`ToListAsync`, `FirstOrDefaultAsync`), a plain `AsQueryable()` does not. It evaluates in memory: it proves the orchestration around the query, not that the expression translates to SQL or behaves like SQL Server (collation, null semantics, provider functions) — query correctness belongs in the real-database integration tests.
- Verify interactions with `A.CallTo(() => _service.DoAsync(A<int>._)).MustHaveHappenedOnceExactly()` / `.MustNotHaveHappened()`.
- Never share mutable fake state across tests; per-test `A.CallTo` configuration stays in the test (or its `Arrange` helper).
- NUnit runs all of a fixture's tests on **one instance**, sequentially by default — that is what makes `[SetUp]`-assigned fields safe. Don't mark such a fixture `[Parallelizable]` at method scope; if per-test parallelism is ever genuinely needed, switch to `[FixtureLifeCycle(LifeCycle.InstancePerTestCase)]` first.
- **An unconfigured member returns a Dummy when FakeItEasy can create one — otherwise `default(T)`, which may be `null`.** For typical fakeable reference types that means a non-null dummy (including things like `Expression` or `Type`), so a production `if (x == null)` branch is never reached unless you say so: `A.CallTo(() => _repository.FindById(id)).Returns(null)`. Never rely on either default when the scenario depends on a sentinel result — a test whose scenario *is* "not found" or "not set" must configure the null explicitly. This is the main trap when porting Moq tests, which returned `null` by default — a ported test can keep compiling and silently start exercising a different path.

### Don't fake `ILogger` — use `NullLogger`

Logging is almost never the behaviour under test, and a constructor that demands an `ILogger<T>` is not a reason to reach for a fake. Pass the null implementation:

```csharp
_service = new PoolAppService(_client, NullLogger<PoolAppService>.Instance, mapper);
```

`NullLogger<T>.Instance` (or `NullLoggerFactory.Instance` / `NullLoggerProvider.Instance` where a factory or provider is required) is a shared singleton — prefer it over `new NullLogger<T>()`. The Entry libraries themselves do this.

Fake `ILogger<T>` **only when a log call is the asserted requirement** — e.g. a handler that must record an error on a swallowed failure. Because `LogError`/`LogInformation` are extension methods and can't be intercepted, assert against the underlying generic `ILogger.Log<TState>` member they all call:

```csharp
A.CallTo(_logger)
    .Where(call => call.Method.Name == "Log" && call.GetArgument<LogLevel>(0) == LogLevel.Error)
    .MustHaveHappenedOnceExactly();
```

That assertion is brittle (it string-matches a method name and positional arguments) — match enough to identify the required event (the level, plus the exception or message content where relevant), and pair it with a behavioural assertion unless the log entry is itself the entire observable contract.

## Exception assertions

Shouldly owns exception assertions — `Should.Throw<T>(...)` / `Should.ThrowAsync<T>(...)` is the standard form (the `act.ShouldThrow<T>()` extension is equivalent; don't mix both in one file).

```csharp
Should.Throw<ArgumentException>(() => new Section(500, 100));
```

Async assertions must be **awaited or returned**:

```csharp
[Test]
public Task NullArgumentThrows() =>
    Should.ThrowAsync<ArgumentNullException>(() => _handler.Handle(null!, CancellationToken.None));
```

**Never call an async throw-assertion from a `void` test** — the Task is discarded, the assertion never runs, and the test can never fail (false green). This applies to both `Should.ThrowAsync<T>(...)` and `act.ShouldThrowAsync<T>()`. Tooling only partly covers this — NUnit.Analyzers flags `async void` tests and the compiler flags unawaited calls inside `async` methods, but a discarded assertion in a synchronous `void` test compiles silently unless the project adds an analyzer for it (the project notes say if it does). The rule holds regardless. Pass a deliberate token explicitly to token-taking methods — usually `CancellationToken.None`, or a created/cancelled token when cancellation propagation is itself the contract. `Assert.Throws`/`Assert.ThrowsAsync`/`Assert.That(..., Throws.X)` are legacy — refactor on touch.

## Snapshot testing with Verify.NUnit

Use Verify for integration responses, documents, and any result whose whole shape is the contract. The snapshot also pins fields you didn't explicitly assert, so an added or removed DTO member is caught — exactly what you want when a contract changes.

```csharp
var response = await Client.GetAsync<GetUserDetails.Response>($"api/users/{_user.Id}");

await Verify(response);
```

- Verify the whole result (including the `CommandResult`/`Result<T>` wrapper when there is one), not just `.Value`, unless you specifically need the value alone. The snapshot is the **smallest complete contract under test** — the full wrapper when the wrapper is part of the contract, never an entire aggregate, service, or incidental object graph dragged in for convenience. An anonymous projection is appropriate when the test protects a result together with a related state change or call count.
- **Never let secrets or personal data reach Verify at all** — no credentials, tokens, connection strings, or personal data beyond what the scenario needs. Project them away or configure scrubbers **before calling `Verify`**: the `.received.txt` is written before any approval step, so scrub-on-approve is already too late. Don't rely on a reviewer spotting them in the diff.
- With default settings a non-parameterized snapshot is `<Fixture>.<Method>.verified.txt` — name the test method meaningfully; parameters and Verify settings extend the name, so trust the `Received:`/`Verified:` paths Verify reports. On first run Verify writes `.received.txt`: review it, then approve it as `.verified.txt` and **commit the `.verified.txt` file** (`*.received.*` stays git-ignored).
- **Centralize shared Verify settings** (scrubbers, converters, ignored members) using the project's documented mechanism — a `[ModuleInitializer]` initializer or a shared settings factory; the project notes say which. Reuse it instead of duplicating scrubbers per test, and use per-test settings only for genuine exceptions.
- When a test asserts on fixed GUIDs or dates, keep them **unscrubbed** or the snapshot proves nothing.
- Do **not** use Verify for simple scalar outcomes — Shouldly there.
- A changed snapshot is a contract change: read the diff, don't bulk-accept `.received.txt` files.

## Determinism

Tests must produce the same result on every machine and every run.

- **Time**: production reads the clock through an injected abstraction — in Entry projects `Enigmatry.Entry.Core.ITimeProvider` (`UtcNow` / `FixedUtcNow`), **not** the BCL `System.TimeProvider`, and never `DateTime.Now`/`UtcNow` directly. Some projects add a second seam for the *local* date (a date provider returning "today" in the app's timezone) — the project notes list every clock seam. **Freeze every relevant seam** when an assertion depends on time; faking a clock to return the current time is pointless, and a fake that is created but never registered in the container silences nothing.
- **No real sleeps or wall-clock waits**: no `Thread.Sleep`, no `Task.Delay`, no polling loops on the wall clock to make a test pass. Control the clock or synchronize on the task/event that represents completion; a bounded wall-clock timeout guarding that deterministic wait against hanging is fine. An eventually-style poll is acceptable only when eventual consistency is itself the behaviour under test and no deterministic completion signal exists.
- **No uncontrolled randomness** in code under test: no `Guid.NewGuid()`, `Random.Shared`, or unseeded generator where the value affects the outcome. AutoFixture/Bogus are fine for values that genuinely don't matter — but an unseeded random string can accidentally satisfy or violate a rule (e.g. an alphanumeric generator producing an all-digit value), which is how flaky tests are born. Seed the generator or pin the value. When production code genuinely needs randomness, route it through an injectable seam — Entry ships `Enigmatry.Entry.Randomness` (`IGenerateRandomness` + typed `Random*Generator`s) — so a test can fake the value, the same way `ITimeProvider` seams the clock.
- **No dependency on culture defaults** when the app sets a non-invariant default culture — parse and format explicitly, or set the culture in the fixture.
- **No dependency on ambient state**: network, file system, wall clock, or a shared database, unless explicitly controlled as below.

## Validators (FluentValidation)

- One `<Command>ValidatorFixture` per validator, `[Category("unit")]`, using `FluentValidation.TestHelper`: `await validator.TestValidateAsync(command)` then `ShouldHaveValidationErrorFor(c => c.Field)` / `ShouldNotHaveValidationErrorFor(...)`.
- **Unit-test validation rules exhaustively here, not through the API.** Add an integration test only when its subject is something the unit test can't see: that the validator is *registered* in the pipeline, its message localization, or the HTTP error contract.
- Build a fresh command per case that satisfies the *other* rules, so only the rule under test can fail.
- Sweep boundaries with `[TestCase]` (null / empty / whitespace / max+1 / each enum member), not one `[Test]` per value.
- Fake repository lookups used by async rules with `A.Fake<IRepository<T>>()` + `.BuildMock()`. A validator containing any `MustAsync`/`CustomAsync` must be exercised with the async helpers — the sync ones throw.
- If a project ships a validator-test base class with field/enum/id helpers, use it instead of hand-writing sweeps (see the project notes).

## Use the Entry test building blocks — don't re-copy them

Test infrastructure that used to be copied from the blueprint into every project is now shipped as NuGet packages. **Before writing any test plumbing, check whether Entry already provides it** — a local copy means a bug fixed upstream never reaches this repo.

| Package | Provides |
|---|---|
| `Enigmatry.Entry.AspNetCore.Tests.Utilities` | `Database.TestDatabase` (Testcontainers.MsSql with a shared ref-counted container, env-var override, and multi-database support via `ConnectionStringEnvironmentVariables` + `OnAfterContainerInitialized`), `DatabaseInitializerOptions` (`TablesToIgnore`, before/after-delete custom SQL, identity reseeding, container image) and the migrate-or-Respawn initializer behind it; `DatabaseHelpers.DropAllSql` + the `SplitStatements()` string extension; `ServiceScopeExtensions.Resolve<T>()`; `Http.UriExtensions.AppendParameters(...)` |
| `Enigmatry.Entry.AspNetCore.Tests.SystemTextJson` / `…NewtonsoftJson` | typed HTTP helpers (`Client.GetAsync<T>`, `PostAsync<T>`, `PostAsync<T, TResponse>`, `PutAsync…`), `DeserializeWithStatusCodeCheckAsync`, the `HttpSerializationOptions`/`Settings` seam for custom converters, and Shouldly-backed response assertions — `BeBadRequest()`, `BeNotFound()`, `ContainValidationError(field, message)` |

Those three are `IsPackable` and on the feed. **`Enigmatry.Entry.AspNetCore.Tests` is not** — despite its `PackageId`, it sets `IsTestProject` without `IsPackable`, so it is Entry's own test suite and ships nothing. Its test-authentication scheme (`TestUserAuthenticationHandler` + `TestAuthenticationOptions` + `TestUserData`, driven by a `TestPrincipalFactory`) is therefore a **pattern to copy, not a dependency to add** — a local copy of it in a project is correct, not duplication. Read it in the building-blocks repo when you need to wire up test impersonation.

`ContainValidationError` is the right tool for the narrow integration test that checks the HTTP error contract (see [Validators](#validators-fluentvalidation)) — don't parse `ValidationProblemDetails` by hand.

Two caveats:

- **Available doesn't mean recommended.** The same Utilities package also ships `Database.InMemory.InMemoryDbModule`/`InMemoryDatabase`/`TestRunner` and `TestServer.ApiEnvironment<T>` — an older harness style built on the EF in-memory provider. Prefer `TestDatabase` on real SQL Server with `WebApplicationFactory`; use the in-memory path only in a project that already standardised on it.
- **Check the version the project actually references** before using an API you found in the building-blocks source — a local checkout of that repo is often ahead of the `EntryVersion` the project consumes.

Project-specific plumbing (a factory base that injects configuration, bearer-token helpers, tenant/user seeding) legitimately stays in the repo. the project notes list what this project keeps locally and which local copies are now redundant.

## Integration tests

The standard Enigmatry setup: `WebApplicationFactory<Program>` against a real SQL Server from **Testcontainers.MsSql**, reset between tests with **Respawn**. Some projects run the API tests and the database tests in one fixture hierarchy, others split them across `Api.Tests` and `Infrastructure.Tests`, and side processes (worker, scheduler, importer, CLI) sometimes build their own host instead of using `WebApplicationFactory`. **Use the harness, authentication setup, HTTP helpers, seeding helpers and route conventions documented in the project notes — never invent a parallel harness**, and don't assume a helper exists on every fixture base.

The database lifecycle behind the standard harness — whether from the Entry package or a local copy of it — is: migrate only when the schema changed (missing DB or pending migrations), otherwise **Respawn-delete the data**. That's what makes per-test isolation cheap, and it has consequences:

- **Lookup/seed tables must be listed in the reset configuration's ignore list.** Add every new enum/lookup table there or its seeded rows get wiped and unrelated tests start failing. Only immutable reference data belongs on that list — ignored tables are never reset, so a test that mutates one leaks state into every later test.
- A local SQL Server can replace the container through connection-string environment variables (`IntegrationTestsConnectionString` by convention, often supplied via `.runsettings`). Projects needing more than one database require **all** of them to be set before local mode kicks in.
- **Test projects that share a database must not run concurrently.** Running them together races on Respawn and migrations and produces phantom failures (deadlocks, `'X' is not a constraint`, HTTP 500s). Run one project at a time when the project notes say they share state; `TestCategory=unit` is normally safe solution-wide.

Writing the tests:

- Seed data in `[SetUp]` with builders plus the harness's add-and-save helper.
- Call the API through the typed helpers from `Enigmatry.Entry.AspNetCore.Tests.*Json.Http` — `Client.GetAsync<T>(url)`, `Client.PostAsync<TRequest, TResponse>(url, command)` — not hand-rolled serialization. Check the route prefix your API actually uses.
- Assert the response with `await Verify(response)`; assert persisted state through the harness's query helper.
- **Integration tests earn their cost on routing, authorization, middleware, persistence, mapping and the external error contract** — happy flows plus the failure flows whose value is in that plumbing. Keep exhaustive business-rule, validation and edge-case matrices in unit tests.
- **Don't add a dedicated test for a simple, logic-free property** (a value just carried command → entity → DTO). Extend an existing create/update round-trip: set it in the command, assert it on the response. Reserve new tests for actual logic.
- Replace out-of-process dependencies (mail, blob storage, message bus, external HTTP) with the fakes already registered in the test container — check what the project replaces before adding your own.

## Running tests

```pwsh
dotnet test <Solution>.sln
dotnet test <Project>.Tests
dotnet test --filter "TestCategory=unit"
dotnet test --filter "FullyQualifiedName~MyFixture.MyTest"
```

Integration tests additionally need Docker (or the local connection-string environment variables) plus any per-project settings/secrets listed in the project notes. Note that a `TestCategory` filter silently skips fixtures that carry no category and any non-NUnit project — the project notes list those if the repo has them.

## What NOT to do

- Don't use underscores in test method names, don't repeat the fixture's subject in them, and don't add `[TestFixture]` to a `*Fixture` class.
- Don't name the subject `_sut`/`sut`.
- Don't write `// Arrange`, `// Act`, `// Assert` comments.
- Don't use `Assert.*` / `Assert.That`, FluentAssertions, NSubstitute or Moq — Shouldly and FakeItEasy only.
- Don't write separate `[Test]` methods for cases that differ only in input values. **Check for this before writing any new `[Test]`.**
- Don't branch on the scenario inside a test body.
- Don't bundle unrelated assertions with `ShouldSatisfyAllConditions`.
- Don't call an async throw-assertion without awaiting or returning it.
- Don't write a test that can't fail — no tautologies, no asserting a value the test itself arranged; observe a new test failing for the intended reason before you're done.
- Don't leave a fixture importing two mocking or two assertion libraries.
- Don't fake `ILogger`/`ILogger<T>` just to satisfy a constructor — pass `NullLogger<T>.Instance`.
- Don't test validation rules through an integration test, or add a unit test that only asserts a property assignment.
- Don't hand-roll test plumbing the Entry test packages already provide — typed HTTP helpers, response assertions, the Testcontainers/Respawn database lifecycle.
- Don't use the EF in-memory provider as a stand-in for SQL Server (a narrow, provider-independent exception documented in the project notes is the only pass), and don't let tests depend on the real clock, real network, or leftover database state.
- Don't `Thread.Sleep`/`Task.Delay`/poll the wall clock to make a test pass — control the clock or synchronize on completion.
- Don't keep a mutable test object graph in a `static readonly` or fixture-lifetime field — build it fresh per use.
- Don't re-declare the same named test object or value — a private `Build*` helper, a magic BSN — in a second fixture; promote it to a code book entry.
- Don't bulk-approve `.received.txt` snapshots.
- Don't ship a fixture without a `[Category]`, or a time-dependent test whose clock seams aren't all frozen.
