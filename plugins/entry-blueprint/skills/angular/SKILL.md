---
name: angular
description: Angular authoring conventions, written modern-first for Angular 20+ (signals, standalone, inject(); NgModule-era notes cover repos mid-migration) — member visibility, artifact file suffixes, lifecycle hooks and their replacements, control-flow blocks and @for track selection, async work via resource() and toSignal(), the RxJS boundary, forms, selectors, i18n and error surfacing. Use this when writing or reviewing Angular components, services, directives, pipes, interceptors, guards, resolvers or the TypeScript side of templates, including generators that emit them. Spec files are covered by angular-testing; markup structure and SCSS by frontend-styling.
---

# Angular

> Read `frontend-foundations` first (cross-cutting rules) and `typescript`
> (language delta — casing, types, class method style, `async/await`). This file
> owns everything that is true *because of Angular*: the component model, member
> visibility, artifact suffixes, lifecycle hooks, templates, RxJS and forms.

Written modern-first for **Angular 20+**: signals, standalone, `inject()`,
control-flow blocks. Notes marked *(NgModule projects)* apply only when the repo
is genuinely still on that pattern.

## Component structure

- **Standalone is the default from Angular 19** — do **not** write
  `standalone: true`; it is redundant metadata the style guide tells you to omit.
  List Angular Material modules and `ReactiveFormsModule` explicitly in `imports`.
- **`ChangeDetectionStrategy.OnPush` on every new component.** Never `Default`.
- **`inject()` for all DI** — never constructor injection. A decorator that
  cannot be avoided (`@Inject(SOME_TOKEN)` demanded by a framework base class) is
  the only exception; treat any new case as worth questioning.
- **`inject()` goes in a field initializer** (or the constructor). The
  constructor holds nothing else except `effect()` registrations.
- Keep components thin — business logic belongs in injected services.
- **Do not introduce lifecycle hooks in new code.** A signal-based alternative
  exists for every common case (table below).
- **Selectors carry the project's prefix** — `app-*` for an application,
  the library's own prefix for library code, and `[prefix-*]` for attribute
  directives. A selector without it is a finding.
- *(NgModule projects)* Match the existing feature-module structure and do not
  convert modules wholesale as a side effect of another change. When you do
  convert a component, **remove it from its NgModule's `declarations` and move
  its dependencies into the component's own `imports`** in the same change. A
  component with a hard Formly dependency stays `standalone: false` until Formly
  is gone.

## Member visibility

Pick the narrowest that works. The compiler enforces the top and bottom of this
scale, so it is not merely stylistic.

- **`private`** — the default. Anything the template does not reference.
- **`protected`** — a member used **only by this component's own template**.
  Angular's template type-checker can read protected members, so this keeps
  template-only state and handlers out of the class's public surface and marks
  them at a glance. Applies to signals, `computed()`, and handler methods alike.
- **`public`** — only the component's actual contract: `input()` / `output()` /
  `model()`, and anything a parent, a directive or a test genuinely calls.

```ts
readonly productId = input.required<number>();                 // contract → public
protected readonly isExpanded = signal(false);                 // template only
protected readonly toggle = (): void => this.isExpanded.update(v => !v);
private readonly service = inject(ProductService);             // internal
```

A `private` member referenced from the template is a template type-check error —
that is the mechanical backstop. There is no equivalent check pushing `public`
down to `protected`, so that one is on you and on review.

## Artifact file suffixes

`typescript` names the file after the identifier inside it, suffix and all. The
Angular suffix set is `.component.ts`, `.service.ts`, `.pipe.ts`,
`.directive.ts`, `.interceptor.ts`, `.guard.ts`, `.resolver.ts`, plus
`.model.ts` for a class that is none of those, `.interface.ts` and `.enum.ts`.

**Take the answer from `angular.json`, not from upstream docs.** Angular changed
its schematic defaults in v20 — suffix-less components and services,
hyphenated guards — and a repo that configured the older dotted suffixes did so
on purpose, so `ng generate` will agree with the config and the docs will not.

A lazy feature's route table is a bare `routes.ts`; the folder carries the
identity.

## Signals

Prefer signals over a component-level `BehaviorSubject` for local reactive state.

Visibility follows the section above: the contract is public, everything the
template reads is `protected`, the rest is `private`.

```ts
readonly productId = input.required<number>();          // replaces @Input
readonly label = input('default label');
readonly selected = output<Product>();                  // replaces @Output + EventEmitter
readonly value = model<string>('');                     // two-way binding

protected readonly count = signal(0);
protected readonly increment = (): void => this.count.update(v => v + 1);
protected readonly doubled = computed(() => this.count() * 2);        // lazy, memoized
protected readonly pageSize = linkedSignal(() => this.defaultPageSize());  // writable, resets with its source

private readonly table = viewChild.required(MatTable);  // replaces @ViewChild
private readonly rows = viewChildren(RowComponent);
```

- **Never `@Input()` / `@Output()` decorators in new code.**
- **`computed()` over a getter** for anything derived from signals: a getter
  re-runs on every access — and from a template, on every change-detection cycle
  — whereas `computed()` is lazy and memoized. Converting a getter means
  updating every reference to call it (`value` → `value()`).
- **`linkedSignal()`** when the value must be locally writable *and* reset when
  its source changes. `computed()` when it is read-only.
- **`effect()` is for side effects leaving Angular** — `localStorage`, imperative
  DOM, a third-party chart. Never use it to derive state; that is `computed()`.
- **`toSignal()`** converts an Observable; subscription and cleanup are
  automatic. Use `{ initialValue: … }` for async sources, `{ requireSync: true }`
  for synchronous ones.
- **Query a directive/component by type, not by template-reference string.**
  `viewChild.required(MatTable)` returns the directive; `viewChild('table')`
  returns the `ElementRef` unless you pass `{ read: MatTable }` — a type argument
  alone makes it compile while handing you the wrong object at runtime.

**The one getter worth keeping** reads from *classic* reactive forms
(`FormControl`/`FormGroup`/`FormArray`), whose `.value` is a plain snapshot with
changes flowing through `valueChanges` — a `computed()` over it would cache and
go stale. **Signal Forms** (`@angular/forms/signals`) remove even that: value and
state are signals (`form.email().value()`, `.errors()`, `.pending()`). They
landed as *experimental* in Angular 21 — **check your Angular version and the
release notes before migrating a form onto them.**

## Replacing lifecycle hooks

| Old pattern | Modern replacement |
|---|---|
| `ngOnInit` — fetch data, initialize state | field initializer + `toSignal()` / `resource()` |
| `ngOnChanges` — react to input changes | `input()` signal + `computed()` or `effect()` |
| `ngOnDestroy` — clean up subscriptions | `takeUntilDestroyed()` or `DestroyRef.onDestroy()` |
| `ngAfterViewInit` — access child elements | `viewChild()` / `viewChildren()` |
| `ngAfterContentInit` — projected content | `contentChild()` / `contentChildren()` |

```ts
// ✅ modern
export class ProductListComponent {
  private readonly service = inject(ProductService);
  readonly categoryId = input.required<number>();
  protected readonly products = toSignal(
    toObservable(this.categoryId).pipe(switchMap(id => this.service.getProducts(id))),
    { initialValue: [] }
  );
}
```

If a hook is genuinely unavoidable (a third-party library needing imperative
init), declare it as a **plain method** — the framework calls it by name.

## Async work in components

**Never make a lifecycle hook `async`** — Angular ignores the returned Promise.
**Never fire-and-forget a Promise**, in a hook or the constructor; a bare
`someAsync().catch(...)` is error-swallowing racing against rendering.

Prefer, in this order:

1. **`resource({ params, loader })`** for *data loading* tied to the component
   lifecycle. It owns the Promise and exposes `value()` / `status()` / `error()`
   / `isLoading()`. The loader must be **side-effect free** — it re-runs whenever
   `params` change and on `reload()`. (Still developer preview in recent
   versions, and the option names changed in v20 — check yours.)
2. **`computed()` driven by `toSignal()`** for reactive derived data.
3. **A route resolver (`ResolveFn`)** so data is ready before activation.
4. **An app-level initializer** for app-wide async startup, or an explicit
   user-triggered handler for a one-shot side effect.

```ts
protected readonly employees = resource({
  loader: async () => await firstValueFrom(this.employeeService.getEmployees())
});
```

## RxJS boundary

`typescript` makes `async/await` the standard async style. This is where that
meets Angular's Observables — and RxJS lives here, not in the language skill,
because deciding when an Observable is the right shape is an Angular question.

- **An Observable that emits once and completes is a Promise wearing a
  costume** — an HTTP call, `TranslateService.get()`, anything
  `firstValueFrom`-compatible. `await firstValueFrom(...)` it.
- **`.subscribe()` is for true streams only**: Subjects, event buses, router
  events, WebSockets — something that emits repeatedly over time. Always pair
  with `takeUntilDestroyed()`.
- Prefer `toSignal()` over `takeUntilDestroyed()` when the value is consumed by a
  template or a `computed()`.
- Never store a subscription solely to `.unsubscribe()` it when `firstValueFrom`
  would do.
- Reaching for an Observable to model a single value is the anti-pattern this
  section exists to stop. A repo that pipes everything through RxJS is **debt,
  not a local convention**: leave existing code unless you are already in it, and
  write new code the standard way.

## Control flow in templates

Use the built-in blocks. `*ngIf`, `*ngFor` and `*ngSwitch` — and their
de-sugared `[ngIf]` / `[ngForOf]` / `[ngSwitch]` forms — are banned in new code.
`*ngTemplateOutlet` becomes the attribute form `[ngTemplateOutlet]`. Use
`ng-container` only as a non-rendering grouping wrapper, not where `@if`/`@for`
would do.

```html
@if (isLoading()) { <mat-spinner /> } @else { <app-product-list [products]="products()" /> }

@for (item of items(); track item.id) { <app-item [item]="item" /> }
@empty { <p i18n>No items found.</p> }

@defer (on viewport) { <app-heavy-chart [data]="chartData()" /> }
```

### Choosing a `@for` track expression

`track` is required. Pick in this order, and **never track the object itself**:

1. **A stable domain id** — `track item.id`. Reading it through a form control is
   fine: `track group.controls['productId'].value`.
2. **A unique primitive from the item** — only if genuinely unique; duplicate
   keys throw `NG0955`.
3. **`track $index`** — when items are repeatable primitives or no stable key
   exists.

**Never `track item`.** Object identity is unique but not *stable*: it dies
whenever the array is rebuilt — an HTTP refresh, a `.map()`, a `computed()`
re-derive, a `FormArray` reset — so every row is destroyed and recreated, losing
focus, scroll position and in-flight animations.

**Tier 3 is not free.** `$index` makes keys positional, so a reused row receives
a *different item*. Any component inside that row must reset its per-item state
(timers, buffers, rendered output) when its input changes — an `effect()` on the
input, not only cleanup on destroy.

## Forms

Working on a form — typed controls, `patchValue` casts, validation display,
server-side errors, Signal Forms? **Read `references/forms.md`** before writing;
it carries the rules.

## Error handling

- Wrap an awaited API call in `try/catch` **when the failure is something the
  user caused and can act on** — deleting a record that cannot be deleted right
  now. That is the boundary that can recover, because it can tell the user.
- **Do not wrap calls whose failure only a broken client could produce** (an
  undefined enum value, a malformed id) — nothing on screen would change; let
  those reach the global error handler.
- HTTP failures are handled once by the global error interceptor. **Do not add a
  duplicate notification** for them; handle a specific status per feature only
  when the feature genuinely does something different.
- Surface user-facing errors through the project's notification service
  (snackbar/toast/dialog). Reserve `console.error` for background/infrastructure
  failures with no UI.

## i18n

- Every user-facing string is translated. **Never ship a bare literal.**
- **Reuse before adding.** Search for an existing key first; generic labels (OK,
  Yes, No, Cancel, Save) always come from the shared namespace.
- **One key per concept**, no duplication, **no abbreviations**, 4–5 words
  maximum — nest for longer concepts.
- **Always give an explicit `@@` id.** Angular will generate a hash id from the
  source text if you omit one, but that id changes the moment anyone edits the
  wording and cannot be shared between two call sites — so the translation is
  silently orphaned or duplicated.

```ts
$localize`:@@shared.ok:OK`
$localize`:@@employees.employee-list.title:Employees`   // ✅ scoped, kebab-case
$localize`OK`                                            // ❌ auto-id: fragile, unshareable
```

In a template the equivalent is `i18n="@@shared.ok"`. Run the project's
extraction script after adding strings.

## Generated API clients

Import generated types and services through the project's path alias
(`@api`, …), and regenerate rather than editing — see `frontend-foundations` →
*Generated code* for the rule and the project delta below for the command.

## Project delta

Confirm these against the repo before writing:

- Angular version, and whether Signal Forms and `resource()` are past preview.
- Standalone vs NgModule, and whether a Formly migration is still in flight.
- The selector prefix.
- i18n mechanism — `$localize` vs `ngx-translate` — and the extraction script.
- The notification service and the global error interceptor's exact behaviour.
- The codegen tool, its path alias, and its regenerate command.
