---
name: typescript
description: Framework-agnostic TypeScript conventions for codebases on TypeScript 5.x+ compiling to ES2022+ as pure ES modules (a required baseline). Use this when writing or reviewing any .ts file in a project on that baseline, with or without a UI framework. Angular-specific patterns live in angular; unit and component specs in angular-testing; Playwright e2e specs in generating-e2e-tests.
---

# TypeScript

> Read `frontend-foundations` first — it owns comments, naming policy, code
> shape, file organization, failure handling, never-silence-a-signal, security
> and generated code. This file carries the TypeScript delta.

**Scope: the language, nothing above it.** Everything here holds in a Node
service, a build script or a plain browser bundle as much as in an Angular app.
A rule that only makes sense because of a framework — how a component is
declared, when an Observable is right, which file suffixes the schematics emit —
belongs to that framework's skill, not this one.

Targets **TypeScript 5.x or later** compiling to an **ES2022** baseline. Use
native features; never add polyfills. Pure ES modules only — never emit
`require`, `module.exports`, or CommonJS helpers.

## Casing and sigils

- **PascalCase** for classes, interfaces, enums and type aliases;
  **camelCase** for everything else — **including module-level constants**
  (`defaultPageSize`, not `DEFAULT_PAGE_SIZE`).
- **No `I` prefix on interfaces.** Rely on descriptive names.
- **No leading underscore on member names.** Two exceptions, both forced:
  a private backing field for a same-named accessor that carries logic, and an
  unused parameter you are required to declare by an interface or callback
  signature. Never `_` on a name you invent in a method body.

## Files and declarations

`frontend-foundations` already requires kebab-case and one primary declaration
per file. The TypeScript delta:

- **The file is named for the identifier inside it, suffix and all**:
  `TimeProvider` → `time-provider.ts`; `ProductListComponent` →
  `product-list.component.ts`. An identifier with no suffix takes a file with no
  suffix, which is why `routes.ts` is right rather than sloppy.
- **One class per file, one enum per file** — exported or not. A file may also
  declare that class's own input and result types (a request shape and its
  result beside the function that maps between them). **The bound is imports:**
  anything a second file imports gets its own file.
- **Which suffixes exist is a framework/tooling question**, not a language one.
  Take the list from the generator's configuration; for Angular, see `angular`.
- Unit tests are `<subject>.spec.ts` beside `<subject>.ts`. Playwright e2e
  specs are the named exception: they test flows, not source files, so they
  follow the e2e suite's own layout — see `generating-e2e-tests`.

## Type system

- **No `any`, implicit or explicit.** Use `unknown` plus narrowing.
- **Allowed casts — the complete list.** These are the only two named exceptions
  to `frontend-foundations` → *no unchecked `as`*; any other `as` is a finding,
  stated reason or not. Downstream skills reference these — they never broaden
  them.
  1. **The `unknown` double-cast at a library boundary.** When a third-party API
     forces a genuine structural mismatch that no narrowing can bridge:
     `value as unknown as Target`. It is loud, greppable, and confined to that
     boundary.
  2. **The private-member cast in a unit or component spec.** A cast to a
     declared type to reach a private member of the class under test —
     permitted only when the logic is complex enough to warrant direct access
     (`angular-testing` owns the conditions). A Playwright spec — as defined in
     `generating-e2e-tests` → *What counts as a Playwright spec* — has no class
     under test and gets nothing from this rule; `generating-e2e-tests` adds no
     casts of its own.

  **Never `as any`** in either form, and never reach for a cast to paper over a
  type you could narrow.
- Discriminated unions for state machines and event types.
- Centralize shared contracts; do not duplicate shapes.
- Express intent with utility types — `Readonly`, `Partial`, `Record`,
  `NonNullable`.
- Mark class fields `readonly` when never reassigned after construction —
  injected dependencies, subjects, constants.

## Class method style

Declare every class method as a **`readonly` arrow-function property**:

```ts
readonly save = (): void => { ... };
private readonly buildFormModel = (employee: Employee): EmployeeFormModel => { ... };
```

This keeps `this` bound when the member is passed as a callback.

**Stay with method syntax only for:**

- **Members a framework calls by name through an interface** — it looks them up
  on the prototype, so an arrow property is never invoked. (Angular's lifecycle
  hooks are the case you will meet most; `angular` lists them.)
- `constructor` (an ES requirement).
- Getters/setters, `abstract` or overridable members relying on `super`, and
  functions needing an explicit `this` parameter (e.g. chart formatters).

Two consequences worth knowing:

- An arrow-property member is only assigned when its field initializer runs, so
  **declare it before any field initializer that calls it**.
- Arrow properties are **own instance properties, not on the prototype** — so a
  prototype spy (`spyOn(SomeClass.prototype, 'method')`) will not intercept them.
  Spy on the instance instead; see `angular-testing`.

## Async and error handling

**`async/await` is the standard here** — the default for every asynchronous
call, in every project, not a per-repo preference.

- Use `async/await`, never `.then` chains.
- **Never `void` a Promise** to silence `no-floating-promises` — that discards
  the failure rather than handling it. Always `await` at the call site.
- **Never an empty catch** — not `catch (_) {}`, not `catch (e) { }`. Catch at
  the boundary that can recover or tell the user; see `frontend-foundations`.
- Guard edge cases early to avoid deep nesting.
- Route errors through the project's logging/telemetry utility, not bare
  `console.log`.

Where a framework brings its own async primitives — Observables, signals, a
resource loader — the framework skill owns the boundary between them and
`await`. For Angular that is `angular` → *RxJS boundary*.

## Constants and magic numbers

- Name a value whenever the name adds clarity or the value is reused. `0` and
  `1` are the usual carve-out.
- **Time durations go through the project's time abstraction**, never raw
  numeric literals.
- Where a project encapsulates constants as `private static readonly` fields
  rather than module-level `const`, follow it — that split is real between
  repos, so check a neighbour file.

## Module and public-API boundaries

- **Import across a library or feature boundary through its public entry point**,
  never a deep relative path into another module's internals:

```ts
import { createInjectionToken } from '@enigmatry/entry-components/common';   // ✅
import { createInjectionToken } from '../common/utils/provide-config';        // ❌
```

- **Every symbol a consumer needs is re-exported from the entry point's public
  API file.** A data-contract interface is exported type-only:
  `export type { ProductSummary };`
- In a published package, **removing or renaming an export is a breaking change**
  even if nothing internal uses it.
- Keep transport, domain and presentation layers decoupled behind clear
  interfaces; keep modules single-purpose.

## Project delta

Check these before writing — they legitimately differ between repos:

- **Constant placement** — module-level `const` vs `private static readonly`.
- **File suffixes** — from the framework's generator configuration.
- **Whether the repo publishes packages**, and where its public API files live.
- Which lint rules are CI gates vs warning severity.
