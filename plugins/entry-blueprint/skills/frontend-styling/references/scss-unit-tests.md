# SCSS Unit Tests (sass-true)

Load this only when adding or reviewing a **public SCSS mixin or function** in a
library that has a sass-true suite. Application-level component styles are not
unit tested.

`sass-true` compiles the SCSS and asserts on the emitted CSS. A JS runner —
Vitest, per `angular-testing`; some libraries are still on Jest — picks the test
files up through a shim, but the assertions themselves are pure SCSS, so the
runner choice does not change anything below.

## File conventions

| Rule | Detail |
|---|---|
| Naming | `<module-name>.tests.scss` |
| Location | `tests/<category>/` — mirroring `src/modules/<category>/` |
| Granularity | one test file per source module |

```
src/modules/typography/fonts       →  tests/typography/fonts.tests.scss
src/modules/borders/border-radius  →  tests/borders/border-radius.tests.scss
```

## Imports

```scss
@use 'sass-true' as true;                       // preferred alias form
@use '../../src/modules/typography/fonts';      // module under test
@use '../../src/modules/variables' as vars;
```

Be consistent within a file. If the module uses a `$testing` guard to suppress
media queries or side-effecting output, set it **before** any includes:

```scss
vars.$testing: true;
```

## Structure

Strict three-level nesting: `describe` → `it` → `assert`.

```scss
@include true.describe('partial-border-radius($top-left, $top-right, $bottom-right, $bottom-left)') {
  @include true.it('should set only the named corners') {
    @include true.assert() {
      @include true.output() {
        @include border.partial-border-radius($top-right: 10px, $bottom-right: 1.2em);
      }
      @include true.expect() {
        border: {
          top-left-radius: 0;
          top-right-radius: 10px;
          bottom-right-radius: 1.2em;
          bottom-left-radius: 0;
        }
      }
    }
  }
}
```

- `describe` label — the **mixin or function signature**.
- `it` label — plain English describing the scenario.

## Choosing the assertion

- **`expect`** — exact match. Use for happy paths with deterministic output.
- **`contains`** — partial match. Use for error paths and for mixins that emit
  large or unrelated output (e.g. responsive generators).

## Error and guard behaviour

A real Sass `@error` aborts compilation, so sass-true cannot assert on it.
Guarded mixins therefore **emit the failure as a CSS comment** in test mode
(usually behind a `$testing` flag) — assert that with `contains`:

```scss
@include true.output() { @include fonts.define-font('Arial'); }
@include true.contains() {
  /* ERROR [define-font($family, $size, $weight)]: */
  /*   At least two of the font properties must be provided. */
}
```

Follow the existing error-comment format:

```
/* ERROR [mixin-name($params)]: */
/*   Human-readable reason. */
```

## Coverage checklist for a new mixin

1. Happy path with all arguments — exact output.
2. Happy path with defaults only — defaults applied.
3. Named/keyword arguments — partial overrides.
4. Error/guard paths — the error comment is emitted for each invalid input.
5. Edge values — zero, `null`, wrong type, out-of-range.

## Stylelint in test files

Assertion blocks legitimately break rules that are right in production. Disable
**only what the file actually needs**, at the top:

```scss
/* stylelint-disable scss/block-no-redundant-nesting */
/* stylelint-disable shorthand-property-no-redundant-values */
```

A nested `&` selector inside `expect()` needs
`/* stylelint-disable-next-line nesting-selector-no-missing-scoping-root */`
immediately above it.
