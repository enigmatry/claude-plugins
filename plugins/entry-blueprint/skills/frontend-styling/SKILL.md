---
name: frontend-styling
description: How HTML markup and SCSS are built at Enigmatry — SMACSS naming, scss-foundation reuse, vendor-override rules, design tokens and mobile-first breakpoints under the shared Stylelint contract. Use this when writing or reviewing any .html template, .scss or .css file. What that markup must achieve for users — contrast, keyboard, labels, reflow — belongs to a11y.
---

# Front-End Styling — HTML & SCSS

> Read `frontend-foundations` first. This file owns **how** markup and
> stylesheets are built; `a11y` owns **what they must achieve**. Where they meet,
> `a11y` is the stricter authority.

Distilled from Enigmatry's internal **Sass Coding Standard** (sections: SMACSS,
General Conventions, File/Folder Hierarchy, Stylelint, Accessibility). For
Enigmatry developers that standard is the source of truth; when it and this
file disagree, the standard wins.

## Reuse before you write

**Before writing any mixin, function, utility class or breakpoint, enumerate
what the installed `@enigmatry/scss-foundation` actually exports**
(`node_modules/@enigmatry/scss-foundation/src`). Adding a near-duplicate
locally is the most common styling mistake in these repos.
`references/scss-foundation-catalog.md` is a non-normative orientation
snapshot of the catalogue — the installed package is the authority.

If something is *almost* right, extend it in `scss-foundation` (with a test) —
do not fork it into a component.

## Markup

- **A native element beats a styled `div`.** `<button>` for actions, `<a href>`
  for navigation, `<ul>/<li>` for lists, `<table>` for tabular data,
  `<label for>` for labels, the CDK or `<dialog>` for modals.
- Landmarks, heading order, and preferring the component library's components:
  see `a11y`.
- **No computation in a template.** A property read, a signal call or a form-state
  query is fine; an operator, a chain, or a call into your own component code
  belongs in a `computed()` — a template-invoked function re-runs on every
  change-detection cycle.
- **No inline `style="…"`**, and no `[ngStyle]` where a class would do. Bind a
  class: `[class.active]="isActive()"`.
- Keep templates flat — extract a child component when nesting makes the file
  hard to scan. Control-flow blocks and `track`: see `angular`.

## Class naming — SMACSS, not BEM

SMACSS was chosen deliberately: most Enigmatry developers write SCSS only
occasionally and come from a C# background, so kebab-case reads better than
`underscore__case`, and BEM's conventions push toward fixed HTML structure and
long names.

**The hard naming rules:**

- **Up to three words.** One or two is the target. Needing more means the
  component should be split.
- **`a-z` and hyphens only** — no numbers, no special characters, no
  underscores, no PascalCase.
- **Class selectors only.** No id selectors, no attribute selectors. The single
  exception is base HTML-element styling in the general styles (see
  `references/global-styles-hierarchy.md`), and those files contain *no* class
  selectors — never mix the two.

**No category prefixes.** SMACSS conventionally tags categories with `l-`,
`is-` and `theme-`; we do not — they are abbreviations and filler, which the
rules above rule out. SMACSS still organises the *thinking* — base, layout,
module, state, theme — but every class is named the same way: full words,
kebab-case, two or three of them.

| Category | How it is named | Example |
|---|---|---|
| Base | bare element selector, general styles only | `button { … }` |
| Layout | the region itself | `.sidebar`, `.page-content` |
| Module | the component | `.product-card` |
| Sub-module / variant | module name plus a word | `.product-card-title`, `.product-card-compact` |
| State | the state, as a plain adjective | `.selected`, `.loading`, `.expanded` |
| Theme | the theme | `.dark`, `.compact` |

```scss
.product-card { … }
.product-card-title { … }     // ✅ sub-module
.product-card__title { … }    // ❌ BEM — not our convention
.product-card.selected { … }  // ✅ state as its own class
.product-card.is-selected     // ❌ `is-` is not a word
```

Name for the module and its role, never its appearance. Class names must be
greppable in full — **never assemble one with `&`** (`&-title`).

Declarations *inside* a rule are SMACSS-ordered too (box → border → background →
text → other); `stylelint-config-property-sort-order-smacss` autofixes this.

## Selectors and nesting

- **Nesting: three levels maximum, two is the target.**
- **Avoid the `+`, `>`, `~` and `*` combinators.** They force assumptions about
  the HTML and couple the stylesheet to it. A plain descendant selector —
  `.my-class .my-other-class` — is right in the large majority of cases.
  (Stylelint permits up to 2 combinators, so this one is on review, not the
  linter.)
- `@extend` only onto a `%placeholder`, never onto a class.
- **`!important` is disallowed.** If you need it, the selector above it is wrong.

The shared `@enigmatry/stylelint-config` enforces **independent caps** — on
selector specificity, nesting depth, compound selectors, classes, type
selectors and pseudo-classes per selector (IDs, attribute selectors and the
universal selector at zero), plus a file-length cap. A selector must satisfy
every one; **the config is the authority for the numbers** — do not restate
them in prose or assert them from memory in review.

**Every rule in the shared config is error severity.** A `stylelint-disable` is
hiding a real failure — the two legitimate uses are a global utility needing an
extra pseudo-class (the `.sr-only` pattern in `a11y`) and a sass-true assertion
block.

## Overriding vendor and framework styles

**Never `::ng-deep`**, `/deep/` or `>>>`. It is deprecated, it leaks out of the
component, and its cascade is unpredictable. The shared Stylelint config
*tolerates* it for legacy code — that is not permission; this ban is enforced by
review.

**Never mix vendor styles with custom ones.** There are exactly two sanctioned
ways to override a third-party style, and the choice is about scope:

1. **Globally** — put a file in `styles/partials/vendors/overrides/` that repeats
   **the same selectors in the same order** as the vendor library, loaded after
   it. This is the only place a framework-generated class may be targeted, and it
   is why the override lives beside the library rather than inside a component.
2. **Locally** — introduce **your own class** and override with a deeper
   selector under it. In Angular, put that class on the component's own host:

```ts
@Component({
  selector: 'app-order-panel',
  host: { class: 'order-panel' },
  // …
})
```

  The host class is a stable, greppable hook that belongs to you — the local
  override is then scoped under `.order-panel` instead of piercing encapsulation.

**Prefer the library's theming API over either.** For Angular Material that is
the `mat.*` theming mixins and design tokens; reaching for a selector usually
means theming was not tried.

`:host` for the component's own box and `:host-context()` for ancestor-driven
variants stay correct. **`ViewEncapsulation.None` leaks styles globally** and
needs a written reason.

## Styles folder hierarchy

Component styles live beside their component. Everything global lives under a
single `styles/` folder — adding or reorganizing anything there? **Read
`references/global-styles-hierarchy.md`** for the folder layout, the
only-`main.scss`-compiles rule and the `_index.scss` convention.

## SCSS module system

- **`@use` and `@forward` only.** `@import` is deprecated.
- **Always namespace.** `@use 'sass:math';`, `@use '../variables' as vars;` —
  never `@use … as *`.
- **Omit the extension and the leading underscore** in a load path:
  `@use 'modules/typography/fonts'`.
- **A mixin not meant for use outside its own file is prefixed with `-`**
  (`@mixin -toggle-state`). Sass has no private mixins; the dash is the
  convention that says so.
- **Don't repeat yourself:** repeated mixin logic becomes a private mixin;
  styles repeated across components become a shared mixin in `modules/`.
- **Keep files small** — a file holds one component's styles, or a handful of
  related mixins, and should rarely exceed ~100 lines. The shared config
  enforces a hard cap via `stylelint-file-max-lines`.

## Tokens, values and units

- **Never hard-code a colour, spacing step, radius, font size, z-index or
  breakpoint.** Use the token layer and the `scss-foundation` API. A one-off
  literal is a design-system gap, not a shortcut.
- `currentColor` for icon fills and strokes.
- Allowed units: `px`, `%`, `em`, `rem`, `vw`, `deg`, `ms`, `s`. **`fr`,
  `vh`/`dvh` and `ch` are not on the list** — if a layout needs one, extend the
  shared config rather than disabling the rule at the call site.
- `rem` for type and spacing that must scale with user font size; `px` only for
  hairlines and things that must not scale.
- **Zero *length* takes no unit** (`margin: 0`) — a `<time>` always needs one
  (`transition-duration: 0s`). Precision to 2 decimals.
- **Modern colour syntax**: `rgb(0 0 0 / 50%)`, short hex, no named colours.
  Numeric `font-weight` (`600`, not `semibold`).
- Transitions ≥ 100ms, and honour `@media (prefers-reduced-motion: reduce)`.
- **No hand-written vendor prefixes** — the build adds them; browser-specific
  rules that genuinely must be authored go in `partials/polyfills/`.
- Contrast thresholds and why alpha on text fails: see `a11y`.

## Responsive

- **Mobile-first with `min-width`.** `max-width` queries are disallowed in the
  shared config precisely because they invert this.
- **An application defines 3–6 breakpoints in a single file and sticks to them.**
  Use `scss-foundation`'s `responsiveness` module (`apply-on()`,
  `show-on-mobile()`, `show-on-tablet()`) — never a literal `768px`, never a
  hand-rolled media query.
- Prefer intrinsic layout (`flex`, `grid`, `clamp()`, `minmax()`, `auto-fit`)
  over a breakpoint whenever the layout can adapt on its own.
- The 320px reflow requirements are in `a11y` → *Reflow*.

## SCSS unit tests

A new **public** mixin or function in a library with a sass-true suite needs a
test — see `references/scss-unit-tests.md`. Application component styles are not
unit tested.

## Before you finish

Stylelint clean, plus what it cannot check: it came from `scss-foundation` or a
token rather than a literal; no `::ng-deep`, no `ViewEncapsulation.None`, no
vendor class targeted outside `vendors/overrides/`; names are two or three full
kebab-case words, no category prefixes, greppable in full; nesting ≤2 where possible and no `>`/`+`/`~`; and
the `a11y` checks still pass.

## Project delta

- Stylelint setup: `@enigmatry/stylelint-config` in devDependencies, a
  `.stylelintrc.json` that only extends it, and a `sass-lint` script
  (`stylelint --fix src/**/*.scss`). Vendor libraries are excluded via
  `ignoreFiles`, not by disabling rules.
- Where this project's tokens and its breakpoint file live.
- Whether the repo has a sass-true suite.
- Which of ESLint/Stylelint are CI gates.
