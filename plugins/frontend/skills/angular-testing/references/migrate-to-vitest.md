# Migrating an Angular suite to Vitest

Load this only when a repo is still on Jest, Jasmine or Karma. The target style
is the parent `angular-testing` skill; this file is the mechanical mapping and
the traps.

**Do it in one dedicated change.** Config, setup file, globals policy and mock
style move together. A repo where half the specs are Jest and half are Vitest
runs two toolchains, two sets of types and two mock APIs — worse than either
alone.

---

## 1. Toolchain

**Remove:** `jest`, `jest-preset-angular`, `@types/jest`, `ts-jest`,
`jest.config.{js,ts}`, `setup-jest.ts` — or, on the Jasmine side, `karma`,
`karma-*`, `jasmine-core`, `@types/jasmine`, `karma.conf.js`, `test.ts`.

**Add:** `vitest`, `jsdom`, and a coverage provider (`@vitest/coverage-v8`).

**Wire it up.** On Angular 20+ prefer the first-party builder — no separate
Vitest config file:

```jsonc
// angular.json → projects.<app>.architect.test
{
  "builder": "@angular/build:unit-test",
  "options": {
    "buildTarget": "::development",
    "tsConfig": "tsconfig.spec.json",
    "runner": "vitest",
    "setupFiles": ["src/testing/setup.ts"]
  }
}
```

On older Angular, `@analogjs/vitest-angular` plus a `vitest.config.ts` is the
fallback. Either way, decide the globals policy once:

```jsonc
// tsconfig.spec.json — only if the config sets globals: true
{ "compilerOptions": { "types": ["vitest/globals"] } }
```

Scripts: `test`, `test:watch`, `test:ci` (`vitest run`), `test:coverage`.

---

## 2. From Jest

Most of the surface is a rename. Do it with a careful find-and-replace, then
read the diff — the traps below are what a blind replace gets wrong.

| Jest | Vitest |
|---|---|
| `jest.fn()` | `vi.fn()` |
| `jest.spyOn(o, 'm')` | `vi.spyOn(o, 'm')` |
| `jest.clearAllMocks()` | `vi.clearAllMocks()` |
| `jest.useFakeTimers()` / `advanceTimersByTime` | `vi.useFakeTimers()` / `vi.advanceTimersByTime` |
| `jest.requireActual('x')` | `await vi.importActual('x')` |
| `jest.mock('./x')` | delete — see trap 2 |
| `@types/jest`, `jest.DoneCallback` | gone — see trap 1 |

Matchers, `expect.objectContaining`, `expect.any`, `toMatchSnapshot` and the
`describe`/`it`/`beforeEach` shapes are unchanged. `jest-preset-angular`'s
snapshot serializers have no equivalent — regenerate affected snapshots and
inspect the first diff rather than trusting `-u`.

### Traps

1. **`done` does not exist.** Vitest has no done callback; a test is synchronous
   or returns a promise. Every `it('…', (done: jest.DoneCallback) => { … })`
   becomes `async`. For an `HttpTestingController` assertion that used `done`,
   the flush is synchronous anyway — drop the callback and assert inline.

   ```ts
   // Jest
   it('adds the header', (done: jest.DoneCallback) => {
     tester.requestSuccess(done, r => expect(r.request.headers.get('X-Custom')).toBe('value'));
   });

   // Vitest
   it('adds the header to API requests', () => {
     http.get('/api/thing').subscribe();
     const request = httpMock.expectOne('/api/thing');
     expect(request.request.headers.get('X-Custom')).toBe('value');
     request.flush({});
   });
   ```

2. **`jest.mock` has no working replacement for first-party code.** `vi.mock`
   throws on relative imports under the Angular builder and silently no-ops on
   path aliases. Every `jest.mock('./auth.service')` must become a TestBed
   provider, and any `mockClass`-style helper the repo built on top of it goes
   with it:

   ```ts
   // before
   jest.mock('./auth.service');
   mockClass(AuthService, () => Object({ isAuthenticated: () => true }));

   // after
   TestBed.configureTestingModule({
     providers: [{ provide: AuthService, useValue: { isAuthenticated: () => true } }]
   });
   ```

   This is the part of a Jest migration that takes real time. Budget for it.

3. **`mockReset` semantics differ.** Vitest restores the implementation passed to
   `vi.fn(impl)`; Jest left an `undefined`-returning stub. A test that relied on
   the Jest behaviour will now see the original implementation.

4. **Prototype spies stop working** once methods are `readonly` arrow properties
   (see `typescript`). If the old suite spied on `SomeClass.prototype`, spy on
   the instance instead.

---

## 3. From Jasmine / Karma

A bigger jump: the spy API, the matchers and the async model all change.

| Jasmine | Vitest |
|---|---|
| `jasmine.createSpy('close')` | `vi.fn()` |
| `jasmine.createSpyObj('S', ['a','b'])` | `{ a: vi.fn(), b: vi.fn() }` |
| `spy.and.returnValue(x)` | `spy.mockReturnValue(x)` |
| `spy.and.callFake(fn)` | `spy.mockImplementation(fn)` |
| `spy.and.returnValues(a, b)` | `spy.mockReturnValueOnce(a).mockReturnValueOnce(b)` |
| `jasmine.objectContaining` / `jasmine.any` | `expect.objectContaining` / `expect.any` |
| `toBeTrue()` / `toBeFalse()` | `toBe(true)` / `toBe(false)` |
| `jasmine.clock()` | `vi.useFakeTimers()` |
| `fakeAsync(() => { …; tick(n); })` | `async () => { …; await vi.advanceTimersByTimeAsync(n); }` |
| `flushMicrotasks()` | `await Promise.resolve()` |
| `waitForAsync` + `fixture.whenStable()` | `async` + `await fixture.whenStable()` |
| `HttpClientTestingModule` | `provideHttpClient()` + `provideHttpClientTesting()` |

### Traps

1. **`fakeAsync`/`tick` are Zone constructs.** They need `zone.js/testing`, which
   a Vitest setup typically does not load. Convert to Vitest timers; where the
   work under test is asynchronous, use the `…Async` variants so the microtask
   queue drains.

2. **NgModule test setup.** A Karma-era spec declares its component in
   `declarations` and imports its feature module. Once the component is
   standalone (see `angular`), that becomes a single `imports: [TheComponent]`.
   Migrating the runner and converting components to standalone are two separate
   changes — do the runner first.

3. **`httpMock.verify()` in `afterEach` still applies.** Keep it.

4. **Test names.** Jasmine suites are usually `should …`; the house style is
   *"does X when Y"*. Rename as you touch each file rather than in a separate
   pass.

---

## 4. Order of work

1. Swap the toolchain and get **one** trivial spec green — that proves the
   builder, setup file and globals policy.
2. Convert pure-function and service specs next. They are the bulk and the
   easiest.
3. Convert specs with HTTP or timers — the `done` and `fakeAsync` traps live
   here.
4. Convert component specs last.
5. Delete the old config, setup files, types and scripts **in the same change**.
   A leftover `jest.config.js` will mislead the next person and the next agent.
6. Re-check the coverage gate: the provider changed, so the number will move
   slightly even though the tests did not.
