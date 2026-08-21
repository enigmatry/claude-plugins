# @enigmatry/scss-foundation — what it provides

Load this before writing any new mixin, function, utility class or breakpoint,
to check whether the foundation already has it. Source:
<https://github.com/enigmatry/entry-angular-building-blocks/tree/master/libs/scss-foundation>.

## Modules (`src/modules/`)

| Module | Provides |
|---|---|
| `borders/border-radius` | `partial-border-radius()` |
| `display/items` | display/flex item helpers |
| `layout/grid`, `layout/grid-core` | `generate()`, `generate-reverse-row()` — the grid system |
| `lists/row-coloring` | `row-coloring()`, `odd-row-coloring()`, `even-row-coloring()` |
| `position/absolute`, `fixed`, `set-position` | `position()`, `set-position()`, `position-unset()` |
| `responsiveness/breakpoints` | `apply-on()`, `show-on-mobile()`, `show-on-tablet()` — **the** breakpoint API |
| `sizes/set-size` | `box-definition()`, `box-dimensions()` |
| `states/hover`, `states/visibility` | `background-hover()`, visibility toggles |
| `text/hover`, `text/modification` | `font-hover()`, `ellipsis()`, `capitalize()` |
| `typography/fonts` | `define-font()` |

## Utility classes (`src/partials/core/`)

`.align-center`, `.align-right`, `.align-vertical`, `.space-between`,
`.stack-vertical`, `.capitalized`, `.first-letter-capitalized`, `.clickable`,
`.draggable`, `.forbidden`, `.no-resize`, `.hidden`.

## When it is almost right

If something is *almost* right, extend it in `scss-foundation` (with a test —
see `references/scss-unit-tests.md`) — do not fork it into a component.
