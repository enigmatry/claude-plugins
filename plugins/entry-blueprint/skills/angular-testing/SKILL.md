---
name: angular-testing
description: Angular and TypeScript unit testing on Vitest — the standard runner. Covers test structure and naming, TestBed setup, mocking strategy, coverage expectations, parameterized tests, async handling and fake timers, and test data. Use this when writing or reviewing a unit or component spec (*.spec.ts, *.test.ts colocated with its source), when deciding what to cover for a new component, service, pipe or interceptor, or when a project is still on Jest, Jasmine or Karma and needs migrating to Vitest. Not for Playwright e2e specs — those belong to generating-e2e-tests.
---

# Angular Unit Testing

> Read `frontend-foundations` first — it owns naming, code shape and
> never-silencing-a-signal, all of which bind spec files too.

**Scope: unit and component specs only.** A spec in a confirmed Playwright e2e
project (a `playwright.config.*` exists) is not bound by this file —
`generating-e2e-tests` owns it, including its deliberate departures from the
rules below.

**Vitest is the runner.** New suites are written on it, and a project still on
Jest, Jasmine or Karma is migrated rather than extended — see *Legacy runners*
at the end.

## Universal rules

- **Test bodies are straight-line.** No `if`/`else`, no ternary, no `switch`, no
  loop, no null-coalescing to choose an outcome — a test that branches is two
  tests. Use `it.each` instead. (The one exception is a corpus-sweeping fitness
  test that must visit every file: collect offenders into a list and make a
  single assertion on that list, so one failure names them all.)
- **Collapse duplicates.** Tests differing only in literal values become one
  parameterized case. Scan for this *before* writing a new `it()`.
- **Every test must be able to fail.** Assert the real outcome, never a
  tautology, and confirm a new test fails before making it pass.
- **No structural narration.** Separate arrange / act / assert with a blank line,
  not a comment.
- **Determinism.** No wall clock, no randomness, no real sleeps. Take time
  through the project's injected time provider and control it from the test.
- **Specs are production code** — same lint gates, same naming rules, no `any`.
  The one blessed carve-out is an inline `no-magic-numbers` disable for a
  genuinely incidental literal in a test; never in production code.

## What to cover

- Every public method, and for each: the **happy path and the primary error
  path**. If a code path has an error callback, assert it, not just `next`.
- Private helpers through the public API. Reach in directly only when the logic
  is complex enough to warrant it.
- **No coverage padding.** A test that asserts nothing meaningful is worse than
  no test: it makes the report lie. Coverage is a floor, not the goal.

## File and structure conventions

- One spec per source file, beside it: `foo.service.spec.ts` next to
  `foo.service.ts`.
- Nest `describe` by class, then by method or behaviour group.
- Name tests **"does X when Y"** — the behaviour and its condition. Not
  `should…`, not the method name repeated.

```ts
describe('ProductService', () => {
  describe('search', () => {
    it('returns an empty page when the query matches nothing', () => { … });
  });
});
```

- Use `it` consistently, including `it.each`. `test` is an alias; do not mix both
  in one file.

## Setup

- Angular 20+ runs Vitest through the first-party `@angular/build:unit-test`
  builder — prefer it over a hand-rolled config. (It was introduced as
  experimental; check what your version supports.) `@analogjs/vitest-angular`
  is the alternative on older Angular.
- **Globals are ambient only when the config sets `globals: true`** — Vitest's
  default is `false`. Check the builder options or `vitest.config.ts`; when they
  are ambient, `tsconfig.spec.json` needs `"types": ["vitest/globals"]`. Type-only
  imports are still needed either way: `import type { Mock } from 'vitest'`.
- The editor may red-underline `describe`/`it`/`expect` in a spec — a false
  positive from type-checking against the app `tsconfig`. The runner uses
  `tsconfig.spec.json`. Ignore the squiggle; do not "fix" it with a disable.

## TestBed

- Call `TestBed.configureTestingModule` in `beforeEach`; Angular resets the
  TestBed between tests automatically.
- Inject mocks with `useValue` providers; retrieve the subject with
  `TestBed.inject(ServiceUnderTest)`.
- HTTP: `provideHttpClient()` + `provideHttpClientTesting()` in `providers`, then
  `TestBed.inject(HttpTestingController)` and `httpMock.verify()` in `afterEach`.
- **Skip TestBed entirely for pure functions and Angular-free utilities** —
  import and call them directly.

```ts
let mocks: ReturnType<typeof buildMocks>;

beforeEach(() => {
  mocks = buildMocks();
  TestBed.configureTestingModule({
    providers: [
      ServiceUnderTest,
      { provide: SomeDependency, useValue: mocks.someDependency },
    ],
  });
  service = TestBed.inject(ServiceUnderTest);
});
```

## Mocking

- **Rebuild mocks in `beforeEach`** via a `const buildMocks = () => ({ … })`
  factory. Never share mutable mock state across tests; a global "reset all"
  hides stale-state bugs.
- **`vi.mock` is not usable for first-party code** under the Angular unit-test
  builder, and mocking an npm package with it is flaky — **inject through the
  TestBed instead**. The failure modes and the Jest comparison are in
  `references/migrate-to-vitest.md` (trap 2).
- If a class constructs a non-injectable dependency itself, **give it a factory
  parameter** and pass a stub from the spec, rather than mocking the package.
- Use a **partial spy** (`vi.spyOn`) when you need a real instance with one
  method replaced. Restore it if it was set outside `beforeEach`. **Spy on the
  instance, not the prototype** — arrow-property methods never live on the
  prototype (`typescript` → *Class method style*).
- For Observable-returning dependencies return `of(value)` or
  `throwError(() => new Error(…))`; for Promise APIs use `mockResolvedValue` /
  `mockRejectedValue`.
- `vi.clearAllMocks()` only when the mock reference must stay stable across tests
  (e.g. a `describe`-scope spy) and you need to clear call history only. Rebuild
  via the factory otherwise. (`mockReset` semantics differ from Jest's — see
  `references/migrate-to-vitest.md`, trap 3.)
- **Prefer testing behaviour through the public API.** Reach into a private
  member only when the logic is complex enough to warrant it, and do it with the
  spec-only cast `typescript` allows — a cast to a declared type, never `any`.

## Test data — bind connected values

When the same value appears in several places **because they refer to the same
thing**, bind it to a named `const` and reuse it. That makes the relationship
explicit and keeps the test correct when the value changes.

```ts
// ❌ the reader cannot tell which 1s are linked
const repair  = { id: 42, productId: 1 };
const product = { id: 1, repairs: [repair] };
expect(open).toHaveBeenCalledWith(expect.objectContaining({ productId: 1, repairId: 42 }));

// ✅ connected ids named once
const productId = 1;
const repairId = 42;
const repair  = { id: repairId, productId };
const product = { id: productId, repairs: [repair] };
expect(open).toHaveBeenCalledWith(expect.objectContaining({ productId, repairId }));
```

- Give each distinct concept its own constant even when the values coincide.
- Derive dependent forms from the constant — `String(productId)`, not `'1'`.

## Parameterized tests

```ts
it.each<[number, string]>([
  [0, 'Unknown'],
  [1, 'Active'],
  [2, 'Inactive'],
])('formats status %i as %s', (status, expected) => {
  expect(formatStatus(status)).toBe(expected);
});
```

- Give an explicit tuple type so arguments do not infer as `(string | number)[]`.
- Use an object-per-case form (`describe.each([{ description, … }])`) when the
  cases need labels.

## Async and timers

- **Always `await` async calls** in tests; never `void`, never fire-and-forget.
  **Vitest has no `done` callback** — a test either is synchronous or returns a
  promise.
- `await expect(promise).resolves.toBe(…)` / `.rejects.toThrow(…)` reads better
  than a try/catch.
- For Observables use `await firstValueFrom(...)` or pass `of(value)` directly —
  **never `.subscribe()` in a test**.
- **Do not reach for `fakeAsync`/`tick()`** — they need `zone.js/testing`, which
  a Vitest/zoneless setup typically does not load. Use Vitest's own timers:

```ts
vi.useFakeTimers();
service.startPolling();
vi.advanceTimersByTime(5000);          // await vi.advanceTimersByTimeAsync(…) if the work is async
expect(mocks.client.fetch).toHaveBeenCalledTimes(2);
vi.useRealTimers();
```

  `vi.useFakeTimers()` fakes `Date` by default. To flush microtasks only,
  `await Promise.resolve()`.
- **Do not snapshot-test services.** Snapshots are for component templates.
- If a code path logs an error, assert the logger spy was called — do not leave
  it unchecked.

## Legacy runners — migrate, do not extend

A repo on **Jest**, **Jasmine** or **Karma** is on the old standard. When you are
asked to add tests there, or the suite comes up in planning, **propose migrating
it to Vitest** rather than adding to it in the old style; if the migration is out
of scope for the change in hand, say so explicitly and match the surrounding
style for that one change.

Read `references/migrate-to-vitest.md` for the API mapping, the config swap, the
traps that bite (the `done` callback, prototype spies, `fakeAsync`, module
mocks) and a recommended order. Migrate the runner in **one dedicated change** —
config, setup file, globals and mock style together. A half-migrated suite where
two runners share a repo is worse than either.

## Project delta

- The runner config and the test scripts (`test`, `test:watch`, `test:ci`,
  `test:coverage`).
- Whether globals are ambient or imported.
- Existing test builders, mock factories and the injected time provider.
- Which paths coverage is collected from, and whether it is a CI gate.
