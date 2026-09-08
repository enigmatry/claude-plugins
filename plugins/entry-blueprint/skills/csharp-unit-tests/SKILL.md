---
name: csharp-unit-tests
description: Best practices for C# unit and integration testing in Enigmatry Entry projects — NUnit 4, Shouldly, FakeItEasy, Verify.NUnit, builders and code books, FluentValidation validator fixtures, and the project's documented integration profile (WebApplicationFactory with Testcontainers.MsSql + Respawn, or an in-process host without a database). Reads repo-specific facts from the host project's notes. Use this when writing or reviewing C# tests.
---

# C# Unit and Integration Testing (Enigmatry Entry)

**This file is the shared Enigmatry standard, distributed through the `entry-blueprint` plugin — don't copy it into a repo or edit it per project.** Everything project-specific — base-class names, helper APIs, seeded test users, builder and code-book locations, clock seams, integration profile, known legacy — lives in the host repo's **project notes** at `<repo-root>/.claude/project-notes/csharp-unit-tests.md`. Resolve the repository root that contains the target test project (in a monorepo, the notes for that project); don't assume the working directory is the root. Read the notes before writing tests.

If the repo has no notes yet: while **writing** tests, create the file from `${CLAUDE_PLUGIN_ROOT}/skills/csharp-unit-tests/references/project-notes.template.md`, fill in only what you can verify in the repo, leave the rest as open questions, and tell the user. While **reviewing** or explaining, read the template as an inspection checklist and don't create files. When a project needs a different rule, change its project notes, not this file; that is what keeps the standard from drifting.

## Scope and precedence

- The task and the host repo's own instructions (`CLAUDE.md`, project notes) decide *which* tests to write. Loading this skill never means adding tests at a level the task doesn't call for — most tasks need unit tests only; the [integration reference](references/integration-tests.md) is read when the task touches an integration fixture or harness.
- **Org standard, not negotiable per project:** NUnit 4, Shouldly, FakeItEasy, Verify.NUnit, and every convention in this file that isn't marked as project-selectable. Libraries in the legacy list below are converted on touch.
- **Project-selectable, recorded in the project notes:** the integration profile (real SQL Server, in-process host without a database, or EF in-memory — see [Integration tests](#integration-tests)), the code-book shape and naming, fixture-helper placement, test-project layout, the clock seam's concrete type. Where the notes are silent, infer the established choice from package references, configuration and the maintained fixtures before applying the default named here.
- **A test-writing task is not a migration.** Convert legacy constructs in the file you touch (see the legacy list), never restructure a project's harness, layout or profile as a side effect. A wider migration is its own task.

## Stack

| Purpose | Library | Notes |
|---|---|---|
| Test runner | **NUnit 4** + **NUnit.Analyzers** | `[Test]`, `[TestCase]`, `[TestCaseSource]`. The org baseline — don't bump the test-framework major as part of ordinary test work. |
| Assertions | **Shouldly** | `x.ShouldBe(y)`, `ShouldBeTrue`, `ShouldNotBeNull`, `ShouldBeOfType`, `ShouldBeEmpty`. Specialised verification APIs (Verify, `FluentValidation.TestHelper`) sit beside it, not instead of it. |
| Mocking | **FakeItEasy** | `A.Fake<T>()`, `A.CallTo(...)`, `.MustHaveHappened...()` |
| Mocking `IQueryable` | **MockQueryable.FakeItEasy** | `.BuildMock()` to back a repository's `QueryAll()` |
| Snapshots | **Verify.NUnit** | complex objects, DTOs/responses, documents, integration responses |
| Test data generation | **AutoFixture** / **Bogus** | only where the values genuinely don't matter — see [Determinism](#determinism) |
| Integration host | **`Microsoft.AspNetCore.Mvc.Testing`** (`WebApplicationFactory<Program>`) | real API pipeline, real DI container, with or without a database — the profile is project-selectable |
| Integration database (SQL Server profile) | **Testcontainers.MsSql** + **Respawn** | the default for a new project whose tests must prove SQL Server persistence |

**Legacy — never introduce, convert on touch** (all present in some older Enigmatry suites):

- `FluentAssertions` (`.Should().Be(...)`) — Shouldly only
- `NSubstitute` (`Substitute.For<T>()`), `Moq` (`new Mock<T>()`, `.Setup`, `It.IsAny`, `.Object`, `.Verify(..., Times.X)`) and any other mocking library — FakeItEasy only
- Classic NUnit asserts (`Assert.AreEqual`, `Assert.IsTrue`, `ClassicAssert`) and the constraint model (`Assert.That(x, Is.EqualTo(y))`) for state assertions — Shouldly only
- MSTest or xUnit (`[Fact]`, `[Theory]`, `[MemberData]`) — some repos still contain an isolated xUnit project; the project notes list them if so

A single test file never imports two general-purpose assertion libraries or two mocking libraries. "Convert on touch" means: when you edit a fixture that still uses a legacy library, convert that fixture's remaining legacy calls in the same change; don't sweep the suite.

## Coverage expectations

- **Unit tests** aim at every meaningful branch of new or materially changed business logic — handlers, validators, domain rules, mappings — including the boundary, invalid, empty and null inputs each rule actually distinguishes, and both sides of every boundary. Trivial pass-through behaviour (a value carried command → entity → DTO) and generated code get no dedicated test unless they carry a specific risk.
- **Integration tests** cover representative happy paths plus the failures whose value is in the plumbing — routing, authorization, validator registration, serialization, persistence, error translation — and every distinct error contract a client reacts to (a `4xx` the frontend handles specifically, an error surfacing from a deep layer). Exhaustive business-rule and input matrices stay in unit tests. "It's covered by an existing integration test" is only true if that test would fail when the new behaviour breaks.

**Every test must be able to fail when the behaviour it protects breaks.** Assert an independently observed outcome or interaction against an explicit expectation — never a tautology, and never only that the setup produced the value you assigned. For a bug fix, watch the test fail against the original defect before fixing. For a test added to existing correct behaviour, be able to say which regression it detects; a focused temporary mutation of the production code is a good way to check when in doubt. Flipping the expected value, or Verify failing only because no `.verified.txt` exists yet, proves nothing.

**Match assertion precision to the contract.** When exact content, identity, order or count matters, assert it exactly: `ShouldContain("color")` also passes on `colored`, and `items.Any(i => i.Text.Contains(...)).ShouldBeTrue()` passes when the right text sits on the wrong element. Assert the whole value with `ShouldBe`, or project the relevant elements and compare the sequence. Use containment or existence assertions only when containment or existence *is* the requirement.

## Project and file layout

- One test project per production project: `<Project>.Tests`, mirroring the production folder structure. A project with an established different layout keeps it (project notes); don't restructure during test work.
- **One fixture per production type**, named after it with the `Fixture` suffix: `Section.cs` → `SectionFixture.cs`. The name must carry the subject type or concept — never a bare `Fixture` (unsearchable). Integration fixtures follow the endpoint or workflow they exercise instead.
- **A fixture growing past roughly 250 lines is a prompt to inspect, not a limit.** First apply the [duplication ladder](#reducing-duplication) — parameterize, extract `Arrange` helpers, move data into builders, books and `*Source` classes. Only when distinct behaviour groups still make the fixture hard to navigate, split it into fixtures named by group (`EmployeeServiceAuthorizationFixture`, `EmployeeServiceUpdatesFixture`). Never split just to satisfy a line count, and a long test fixture is not by itself evidence that the production class needs refactoring.
- **`[TestFixture]`:** omit the parameterless attribute — NUnit discovers any class with `[Test]` methods, whatever its name, and an abstract base carrying `[TestFixture]` changes nothing. Keep it when it carries data: `[TestFixture(arg)]`, a generic fixture's type arguments, or `[TestFixtureSource]`. The `Fixture` suffix is a naming convention, not a discovery mechanism.
- **Every fixture carries `[Category("unit")]` or `[Category("integration")]`** so CI can filter (`dotnet test --filter "TestCategory=unit"`). Adopt on touch in suites that don't have it yet.
- New unit fixtures are `internal sealed`; NUnit discovers `internal` fixtures, `public` is a convention where a suite uses it. Match the surrounding project rather than mass-changing.
- **Name the subject after its type, never `_sut`/`sut`**: `private EmployeeService _employeeService;`. Same for dependencies — `_contractRepository`, not `_repo2`.
- Declare the subject and its dependencies as private `_camelCase` fields when the fixture shares them across tests — never PascalCase `{ get; set; }` auto-properties. Add `= null!` to `[SetUp]`-assigned fields **only when the test project has `Nullable` enabled**.
- A helper type a fixture needs (a `Testable*` subclass, a stub, a builder) lives where the project notes say; the default is its own `internal sealed` file in the same mirrored folder.

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

- **Keep the scenario-defining inputs visible in the test.** Arrange may take several lines; move setup into a builder, a code-book entry or an `Arrange` helper when it is incidental or repeated, and only when the helper's name and arguments still tell the reader what the scenario is. A one-line arrange is the happy outcome of good builders, not a rule to satisfy by hiding data.
- **Act is one statement.** One arrange→act→assert cycle per test; never re-mutate state and assert a second scenario in the same body.
- **Assert one logical outcome.** Two or three tightly-related properties of the same result are one concept and fine. Once one result needs more than about two property assertions, `await Verify(...)` on the projected contract is the better trade — one assertion line, the whole contract pinned (see [Verify](#snapshot-testing-with-verifynunit)). Asserting unrelated outcomes is never fine — split the test, or collapse it with `[TestCase]`.
- **Do not use `ShouldSatisfyAllConditions`** (or a stack of `ShouldContain`/`ShouldBe` calls) to bundle unrelated outcomes into one test — that is the multi-assertion smell, not an exception to it.

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

**Scan for duplication before writing a new `[Test]` method.** Tests that share body structure and differ only in literal values (strings, numbers, enum members) are one `[TestCase]`-parameterized method, even when their names differ. Scenarios that differ in *behaviour* stay separate tests.

```csharp
// ❌ avoid — identical structure, only the expected value differs
[Test] public void ActiveStatusHasCorrectName()   { ... name.ShouldBe("Active"); }
[Test] public void InactiveStatusHasCorrectName() { ... name.ShouldBe("Inactive"); }

// ✅ correct
[TestCase(UserStatus.Active,   "Active")]
[TestCase(UserStatus.Inactive, "Inactive")]
public void StatusHasCorrectName(UserStatus status, string expected)
{
    var name = status.ToDisplayName();

    name.ShouldBe(expected);
}
```

Use `[TestCaseSource]` when the data is objects rather than attribute-compatible literals, or is reused across fixtures:

```csharp
[TestCaseSource(typeof(FindVisibleByIdSource), nameof(FindVisibleByIdSource.Get))]
public void FindVisibleByIdReturnsExpectedUser(FindVisibleByIdData data) { ... }
```

Sources run at test **discovery**, before any `[SetUp]` — keep them static and self-contained (no fixture state, DI, database, or clock), and don't cache a source's output in a `static readonly` field.

For readable case names in the runner, rely on a positional `record`'s generated `ToString` for primitive data, or compose several real fields (`ToString() => $"{Type} {Threshold}"`). For opaque domain objects pass a label as a **constructor parameter that only `ToString` reads** — never `ToString() => SomeProperty;` on an already-public property.

## Reducing duplication

Before adding a test, look for structure to share instead of copy — in this order:

1. **Collapse identical bodies into one parameterized test** (`[TestCase]` for literals, `[TestCaseSource]` + `*Source`/`*Data` for objects). Never leave two near-identical `[Test]` methods that differ only by input — a reviewer will send it back.
2. **Extract a shared arrange/act/assert helper**: repeated arrange lines → a private `Arrange(...)` helper; a repeated invocation → `Act(...)`; a repeated verification → a named assertion helper (`ShouldHaveNoSavedChanges()`) that expresses one reusable contract and keeps a useful failure message. The subject and its fakes are `[SetUp]` fields the helpers read and write.
3. **Lift shared construction of a non-trivial dependency out of the fixtures** into one internal factory/builder called from each `[SetUp]` — don't paste the wiring into every fixture.
4. **Move repeated object graphs into a Builder, repeated named objects and values into a code book, and repeated case sets into a `*Source`.**

Duplication that varies only by data is a smell, not a style choice.

**Arrange and act helpers return values; they don't assert the outcome.** A `ShouldNotBeNull()` inside a capture helper reports the failure at the wrong place and hides the behaviour check from the test body. Return the captured value and let the test assert; throw (`?? throw new InvalidOperationException("The provider was never called.")`) only for a genuinely broken arrangement.

**Name repeated literals by role.** `"a"`/`"b"` values scattered through a fixture become `const string FirstItem`/`SecondItem` when the reader would otherwise have to infer which literal plays which part. Obvious boundary values (`0`, `-1`, `""`) stay visible inline.

## Test data

Reusable mutable test objects are created fresh per use. Never hold an entity, DTO, collection, or other mutable object graph in a `static readonly` field or a fixture-lifetime field initializer — NUnit reuses one fixture instance for all its tests, so one test mutating the graph silently changes what a later test arranges. Return it from a builder, factory method, or expression-bodied member that **constructs a new graph on every access**; `=>` syntax alone guarantees nothing if the body returns a cached instance. Constants and immutable values are unaffected.

Two separate decisions govern test data: **how an object is constructed** (inline vs builder) and **where it is shared** (inline → fixture-local member → code book).

### Construction — inline or builder

Use a constructor or object initializer for simple data. Reusable entity/DTO construction with defaults goes into a fluent `*Builder`: `With*` methods returning `this`, a `Build()`, and an `implicit operator` to the built type so a builder can be passed straight where the entity is expected. Default every field to something valid so a test only sets what it cares about.

```csharp
var user = new UserBuilder()
    .WithEmailAddress("john_doe@john.doe")
    .WithFullName("John Doe")
    .WithStatusId(UserStatusId.Active)
    .Build();
```

Build valid objects through the domain factory (`User.Create(command)`) so the entity's own invariants run; a test of an *invalid* input constructs that input directly, without the factory refusing it in arrange. Call `.Build()` when the variable is used as the entity; rely on the implicit conversion only when passing the builder straight into a parameter. **Builders are frequently shared across test projects — and in some repos live in a production assembly. Search for an existing one before writing a new one** (the project notes say where they live).

### Sharing — fixture-local member or code book

A **code book** gives a recurring test object or value one name in one place, instead of the same literal or private `Build*` helper re-declared across fixtures. A book is a per-domain-type `internal static` class of expression-bodied entries, named by the *meaning* the entry carries in a test — `Some…`, `Another…`, `Expired…`, `NotFound…` — never by the test that first needed it. Meaning-named value constants — a valid BSN, a valid IBAN, a max-length string — belong in the same book as the objects that use them.

```csharp
internal static class Users
{
    public static UserBuilder Some => new UserBuilder()
        .WithEmailAddress("some.user@example.com")
        .WithStatusId(UserStatusId.Active);

    public static UserBuilder Deactivated => Some.WithStatusId(UserStatusId.Deactivated);
}

var user = Users.Deactivated.WithFullName("Jane Doe").Build();
```

The default shape in Entry projects is the one above: **entries return a pre-configured builder**, so the domain factory still runs and callers derive variants by chaining `With*`. A project may choose another shape — entries returning finished objects (with the book named exactly after the domain type and the type aliased, `using DomainUser = ...;`), or C# 14 `extension(User)` static members — as long as every access yields a fresh graph and entries are named by meaning. The project notes say which shape and naming the project uses and where its books live.

Rules that hold for every shape:

- **One book per domain type.** A sub-object that needs its own graph gets its own book; books compose by reference (`Orders.Some` uses `Customers.Some`), never by inlining a second type's graph.
- **Variants are new entries or `With*` chains, never mutation of a finished entry** — `Users.Some.Build()` followed by property assignments in the test hides what the scenario changed.
- **Changing a widely used entry changes every test that uses it.** Inspect the consumers; when a close-but-different shape is needed, add a new entry.
- **Role and outcome vocabulary goes to the book on first use** (`Some`, `Another`, `NotFound`, `Forbidden`): its value is a uniform vocabulary across fixtures, not reuse. Conversely, if the only honest name is the test that wanted it (`NewOrganizationWithoutUniqueName`), it is fixture data, not a book entry.

Promotion follows the reuse: construct inline while one test needs it → lift to a fixture-local expression-bodied member when the fixture reuses it → promote to a book entry the moment a second fixture needs the same shape or value. Adopt on touch: promote when you edit a fixture that duplicates a shape, don't sweep the suite.

### `*Source` classes — `[TestCaseSource]` data sets

- Name the class `*Source` and the method `Get()` (or `GetData(...)` when it needs runtime arguments); `yield return` one case per line, each optionally delegating to a named private helper.
- **Prefer a dedicated `*Source` file per data set** — one class, one set. Don't collect many unrelated `[TestCaseSource]` sets as sibling methods on one class; it hides which set feeds which test. A small source owned by exactly one fixture may stay next to it as a top-level class — that permission is about *placement*, not embedding: non-trivial case construction belongs in a named `*Source` class, not in an inline `IEnumerable<TestCaseData>` method or collection initializer on the fixture itself.
- Keep sources free of assertion logic — data only. Sources may compose builders and book entries.

| Situation | Use |
|---|---|
| Object used once, in one test | inline construction (through the type's builder when one exists) |
| Same object graph needed by ≥2 tests in one fixture | fixture-local `private static T Name => ...;` member |
| Same named object or value needed by ≥2 fixtures, or a role/outcome entry of the type | code book entry |
| Non-trivial construction with sensible defaults, wherever it happens | `*Builder` |
| Same test body run with multiple data variants | `*Source` + `[TestCaseSource]` |

## Mocks — FakeItEasy

Create fakes **inside the test** by default. When a fixture has more than one test exercising the same subject, hold it and its dependencies as private fields, build them once in `[SetUp]`, and give each test a small `Arrange` helper that configures the fakes. Build the subject in one place — `[SetUp]`, or a single factory when a test needs a differently wired subject — not in every test.

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
- NUnit runs all of a fixture's tests on **one instance**, sequentially by default — that is what makes `[SetUp]`-assigned fields safe. Check the assembly- and fixture-level `[Parallelizable]` settings before relying on it; if per-test parallelism is ever genuinely needed, switch to `[FixtureLifeCycle(LifeCycle.InstancePerTestCase)]` first, and remember that a fresh instance does not isolate static state or shared services.
- **An unconfigured member returns a Dummy when FakeItEasy can create one — otherwise `default(T)`, which may be `null`.** For typical fakeable reference types that means a non-null dummy (including things like `Expression` or `Type`), so a production `if (x == null)` branch is never reached unless you say so: `A.CallTo(() => _repository.FindById(id)).Returns(null)`. A test whose scenario *is* "not found" or "not set" must configure the null explicitly. This is the main trap when porting Moq or NSubstitute tests, which returned `null` by default — a ported test can keep compiling and silently start exercising a different path.

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

**Never call an async throw-assertion from a `void` test** — the Task is discarded, NUnit never observes its result, and the test passes whether or not the exception was thrown (false green). This applies to both `Should.ThrowAsync<T>(...)` and `act.ShouldThrowAsync<T>()`. Tooling only partly covers this — NUnit.Analyzers flags `async void` tests and the compiler flags unawaited calls inside `async` methods, but a discarded assertion in a synchronous `void` test compiles silently unless the project adds an analyzer for it (the project notes say if it does). The rule holds regardless. Pass a deliberate token explicitly to token-taking methods — usually `CancellationToken.None`, or a created/cancelled token when cancellation propagation is itself the contract. `Assert.Throws`/`Assert.ThrowsAsync`/`Assert.That(..., Throws.X)` are legacy — refactor on touch.

## Snapshot testing with Verify.NUnit

Use Verify for integration responses, documents, and any result whose whole shape is the contract. The snapshot also pins fields you didn't explicitly assert, so an added or removed member of the *verified representation* is caught — exactly what you want when a contract changes.

```csharp
var response = await Client.GetAsync<GetUserDetails.Response>($"api/users/{_user.Id}");

await Verify(response);
```

- **Check the test project first**: that it references `Verify.NUnit`, which version, how it imports the verifier (`ImplicitUsings`/`using static VerifyNUnit.Verifier;`), and where shared settings come from (project notes). Verify is part of the org stack, so adding the reference to a test project that lacks it is in scope for a test-writing task — say so in the change.
- Verify the whole result (including the `CommandResult`/`Result<T>` wrapper when there is one), not just `.Value`, unless you specifically need the value alone. The snapshot is the **smallest complete contract under test** — the full wrapper when the wrapper is part of the contract, never an entire aggregate, service, or incidental object graph dragged in for convenience. An anonymous projection is appropriate when the test protects a result together with a related state change or call count.
- A snapshot sees only what reaches the verified object and survives serialization and settings. A typed-DTO snapshot protects the deserialized shape; a wire-contract test that must catch an extra or renamed JSON field, a status code or a header snapshots the raw response instead.
- **Test data is synthetic. No secrets or real personal data reach Verify at all** — no credentials, tokens or connection strings. Project them away or configure scrubbers **before calling `Verify`**: the `.received.txt` is written before any approval step, so scrub-on-approve is already too late.
- With default settings a non-parameterized snapshot is `<Fixture>.<Method>.verified.txt`; NUnit test parameters extend the name automatically. **Every parameterized case must resolve to a distinct, stable snapshot name** — for opaque objects, colliding `ToString` values or unstable representations, use the installed version's parameter-naming settings (`UseParameters`, `UseTextForParameters`) with a semantic case key. A readable runner name is not proof of a unique snapshot path; trust the `Received:`/`Verified:` paths Verify reports. On first run Verify writes `.received.txt`: review it, then approve it as `.verified.txt` and **commit the `.verified.txt` file** (`*.received.*` stays git-ignored).
- **Centralize shared Verify settings** (scrubbers, converters, ignored members) using the project's documented mechanism — a `[ModuleInitializer]` initializer or a shared settings factory; the project notes say which. Reuse it instead of duplicating scrubbers per test, and use per-test settings only for genuine exceptions.
- When a test asserts on fixed GUIDs or dates, keep them **unscrubbed** or the snapshot proves nothing.
- Do **not** use Verify for simple scalar outcomes — Shouldly there.
- A changed snapshot is a contract change: read the diff, don't bulk-accept `.received.txt` files.

## Determinism

Tests must produce the same result on every machine and every run.

- **Time**: production reads the clock through the project's injected clock seam — in Entry projects `Enigmatry.Entry.Core.ITimeProvider` (`UtcNow` / `FixedUtcNow`); other codebases have their own abstraction — **not** the BCL `System.TimeProvider`, and never `DateTime.Now`/`UtcNow` directly. Some projects add a second seam for the *local* date (a date provider returning "today" in the app's timezone) — the project notes list every clock seam. **Freeze every relevant seam** when an assertion depends on time; faking a clock to return the current time is pointless, and a fake that is created but never registered in the container silences nothing.
- **No real sleeps or wall-clock waits**: no `Thread.Sleep`, no `Task.Delay`, no polling loops on the wall clock to make a test pass. Control the clock or synchronize on the task/event that represents completion; a bounded wall-clock timeout guarding that deterministic wait against hanging is fine. An eventually-style poll is acceptable only when eventual consistency is itself the behaviour under test and no deterministic completion signal exists.
- **No uncontrolled randomness** in code under test: no `Guid.NewGuid()`, `Random.Shared`, or unseeded generator where the value affects the outcome. AutoFixture/Bogus are fine for values that genuinely don't matter — but an unseeded random string can accidentally satisfy or violate a rule (e.g. an alphanumeric generator producing an all-digit value), which is how flaky tests are born. Seed the generator or pin the value. When production code genuinely needs randomness, route it through an injectable seam — Entry ships `Enigmatry.Entry.Randomness` (`IGenerateRandomness` + typed `Random*Generator`s) — so a test can fake the value, the same way the clock seam does.
- **No dependency on culture defaults** when the app sets a non-invariant default culture — parse and format explicitly, or set the culture in the fixture.
- **No dependency on ambient state**: network, file system, wall clock, or a shared database, unless explicitly controlled as in the [integration reference](references/integration-tests.md).

## Validators (FluentValidation)

- One `<Command>ValidatorFixture` per validator, `[Category("unit")]`, using `FluentValidation.TestHelper`: `await validator.TestValidateAsync(command)` then `ShouldHaveValidationErrorFor(c => c.Field)` / `ShouldNotHaveValidationErrorFor(...)`.
- **Unit-test validation rules exhaustively here, not through the API.** Add an integration test only when its subject is something the unit test can't see: that the validator is *registered* in the pipeline, its message localization, or the HTTP error contract.
- Build a fresh command per case that satisfies the *other* rules, so only the rule under test can fail.
- Sweep boundaries with `[TestCase]` (null / empty / whitespace / max and max+1 / each enum member), not one `[Test]` per value. Cover the valid side of every boundary, not just the failing one.
- **Enum rules** cover every defined member as valid and representative undefined values as invalid — out-of-range on both sides and gaps in sparse enums. For `[Flags]` distinguish permitted combinations from unsupported bits according to the rule actually written; FluentValidation's `IsInEnum` accepts any combination of defined bits.
- **A child validator gets its own fixture.** The parent fixture adds one canary proving the child is wired (`ShouldHaveChildValidator(c => c.Child, typeof(ChildValidator))`, or one representative invalid child producing the nested failure path) and, for a `.When(...)`-gated child, that the condition applies. Don't re-test the child's rules from the parent.
- **Whole-object rules** (`RuleFor(x => x).Must(...)`) and rules over nested paths are tested by validating the complete input and asserting the relevant failure (and its property path or error code where it matters); a direct-member setup helper doesn't reach them.
- **Throw-safety is a distinct assertion.** A `Must`/`When` predicate that dereferences a sibling, or a child-validated reference without `NotNull`, can throw on a null or empty input instead of failing validation cleanly. When an edge input is meant to be *invalid*, the failing validation assertion already covers it; when the input is meant to be *valid*, assert the validator survives it.
- Fake repository lookups used by async rules with `A.Fake<IRepository<T>>()` + `.BuildMock()`. A validator containing any `MustAsync`/`CustomAsync` must be exercised with the async helpers — the sync ones throw.
- If a project ships a validator-test base class with field/enum/id helpers, use it instead of hand-writing sweeps (see the project notes).

## Integration tests

An integration test runs the real API pipeline and DI container through `WebApplicationFactory<Program>` (side processes — worker, scheduler, importer — build their own host). What sits behind the host is the project's **integration profile**, one of:

| Profile | Proves | Doesn't prove |
|---|---|---|
| **SQL Server** — Testcontainers.MsSql + Respawn (default for a new project with a database) | routing, DI, middleware, authorization, serialization, error translation, **and** SQL translation, constraints, transactions, migrations, persistence wiring | — |
| **In-process host, no database** — dependencies replaced by fakes/stubs | the same application-pipeline behaviour; the only choice for an application without a database | anything about a database |
| **In-process host with EF in-memory** — where a project chose it | application-level orchestration over an EF-backed substitute | SQL translation, relational constraints, transactions, raw SQL |

The project notes say which profile(s) the project uses; a suite may use more than one for different contracts. **Preserve the project's profile during ordinary test work, and never add an alternate database provider to prove SQL Server behaviour** — a test that must prove a query, constraint or migration runs against the production provider, or the notes record where that coverage lives (or that it is a known gap).

Everything else — host and client lifetime and disposal, replacing registrations, the Entry test packages, the SQL Server lifecycle (migrate-or-Respawn, ignore lists, local connection strings, shared-database concurrency), typed HTTP helpers and Verify on responses — is in [`references/integration-tests.md`](references/integration-tests.md). Read it when the task touches an integration fixture or harness; skip it for unit-only work.

## Running tests

```pwsh
dotnet test <Solution>.sln
dotnet test <Project>.Tests
dotnet test --filter "TestCategory=unit"
dotnet test --filter "FullyQualifiedName~MyFixture.MyTest"
```

`TestCategory=unit` is normally safe solution-wide. A category filter silently skips fixtures that carry no category, and adapters other than NUnit's map the filter differently — the project notes list such projects if the repo has them. Integration prerequisites (Docker or connection strings, secrets, which projects must not run concurrently) are in the integration reference and the project notes.

## What NOT to do

The highest-risk mistakes; each rule above carries its own exceptions.

- Don't introduce a legacy library — FluentAssertions, NSubstitute, Moq, classic or constraint-model `Assert` for state — and don't leave a fixture you touched still using one.
- Don't write a test that can't fail: no tautologies, no asserting only what the test itself assigned, no substring or `Any(...)` match where the exact value is the contract.
- Don't call an async throw-assertion without awaiting or returning it.
- Don't write separate `[Test]` methods for cases that differ only in input values. **Check for this before writing any new `[Test]`.**
- Don't branch on the scenario inside a test body, and don't bundle unrelated assertions with `ShouldSatisfyAllConditions`.
- Don't keep a mutable test object graph in a `static readonly` or fixture-lifetime field, and don't re-declare a named test object or value that a code book (or a second fixture) already has.
- Don't fake `ILogger`/`ILogger<T>` just to satisfy a constructor — pass `NullLogger<T>.Instance`.
- Don't test validation rules through an integration test, or add a unit test that only asserts a property assignment.
- Don't let tests depend on the real clock, real network, `Thread.Sleep`/`Task.Delay`, or leftover database state, and don't add an alternate database provider to prove SQL Server behaviour.
- Don't change a project's integration profile, harness, layout, or test-project structure as a side effect of writing a test.
- Don't bulk-approve `.received.txt` snapshots, and don't let secrets or real personal data reach a snapshot.
- Don't use underscores in test method names, don't repeat the fixture's subject in them, don't name the subject `_sut`, and don't write `// Arrange` / `// Act` / `// Assert` comments.
