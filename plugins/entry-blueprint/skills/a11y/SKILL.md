---
name: a11y
description: Accessibility — WCAG 2.2 Level AA conformance for user-facing UI. Covers semantics and landmarks, accessible name/role/value/state, keyboard operability and focus management, composite widget patterns, contrast and colour tokens, forced-colors/High Contrast mode, reflow at 320px, labels, forms and error messaging, images, navigation and tables. Use this whenever building or reviewing a UI component, form, navigation or user-facing HTML/Angular template, or when asked for an accessibility or screen-reader review. It defines what the UI must achieve for users; how the markup and SCSS are built is frontend-styling.
---

# Accessibility — WCAG 2.2 AA

> Read `frontend-foundations` first. `frontend-styling` owns SCSS architecture
> and the token system; this file owns what those styles must achieve.

## Non-negotiables

- Conform to [WCAG 2.2 Level AA](https://www.w3.org/TR/WCAG22/). Go beyond
  minimum conformance where it meaningfully improves usability.
- **Use the project's component library's patterns.** Do not recreate a component
  it already provides. If unsure, copy an existing usage in the repo. The result
  must still have a correct accessible name/role/value, keyboard behaviour, focus
  management, visible label and sufficient contrast.
- **No library component for the job? Prefer native HTML over ARIA.** Add ARIA
  only when native semantics cannot express it — never onto an element whose
  native semantics already work (`required`, not `aria-required`, on an
  `<input>`; `aria-required` only where the control cannot take the native
  attribute).
- **Every element exposes a correct accessible name, role, value, state and
  properties** (WCAG 4.1.2). State that changes — expanded, selected, checked,
  invalid, busy — must change programmatically too, not only visually.
- Every interactive element is keyboard operable, has clearly visible focus, and
  creates no keyboard trap.
- **Never claim output is "fully accessible."** Generated markup still needs
  manual review and assistive-technology testing.

## Inclusive language and cognitive load

- Respectful, people-first language in user-facing text; no assumptions about
  ability, cognition or experience.
- Plain language, consistent page structure and navigation order, and an
  interface free of unnecessary distraction.

## Structure and semantics

- Landmarks — `header`, `nav`, `main`, `footer` — used for what they mean.
- Headings introduce sections and never skip a level. **One `h1` per page**,
  normally the first heading inside `main`.
- A descriptive `<title>`, formatted "Unique page - section - site".

## Keyboard and focus

- Tab order follows reading order and is predictable. Focus is always visible.
- Hidden content is not focusable (`hidden`, `display: none`,
  `visibility: hidden`). Anything under `aria-hidden="true"` — including its
  descendants — must not be focusable.
- **Static content is never tabbable.** The one exception is `tabindex="-1"` on
  an element that needs programmatic focus.

### Skip link

Provide one as the first focusable element on the page.

```html
<header>
  <a href="#maincontent" class="sr-only">Skip to main content</a>
</header>
<main id="maincontent" tabindex="-1">
  <h1>…</h1>
</main>
```

```css
.sr-only:not(:focus):not(:active) {
  clip-path: inset(50%);
  height: 1px;
  overflow: hidden;
  position: absolute;
  white-space: nowrap;
  width: 1px;
}
```

### Composite widgets

A component with internal arrow-key navigation (tabs, listbox, menu, grid, date
picker) exposes **one tab stop** and manages focus internally:

- **Roving tabindex** — exactly one item has `tabindex="0"`, all others `-1`;
  arrow keys swap the attribute and call `.focus()`.
- **`aria-activedescendant`** — the container is focusable and arrow keys update
  `aria-activedescendant="IDREF"`.

## Contrast and colour

- Text contrast ≥ **4.5:1** (large text ≥ **3:1**; large means ≥ 24px regular or
  ≥ 18.66px bold).
- Focus indicators and key control boundaries ≥ **3:1** against adjacent colours.
- **Never rely on colour alone** for error, success, required or selected state —
  add text and/or an icon with an accessible name.
- **Do not invent colours.** Use the project's design tokens. If no palette
  exists, define a small token set and use only those:
  `--color-bg`, `--color-text`, `--color-muted-text`, `--color-link`,
  `--color-border`, `--color-focus`, `--color-danger`, `--color-success`.
- **Avoid alpha for text and key affordances** — contrast becomes
  background-dependent and usually fails.
- Verify contrast in every interactive state: default, hover, active, focus,
  visited, disabled.
- Unsure? Very dark text on very light backgrounds or the reverse. Never
  mid-grey on white.

## Forced colors / High Contrast

- **Never override or disrupt OS accessibility settings.** The UI must adapt to
  Forced Colors mode automatically; avoid hard-coded colours that fight the
  user's system colours.
- Use `@media (forced-colors: active)` only where system defaults fall short, and
  inside it use **system colour keywords** (`ButtonText`, `ButtonBorder`,
  `CanvasText`, `Canvas`) — never fixed hex or RGB.
- In forced colors, box shadows and decorative gradients disappear — do not rely
  on them to convey state.

```css
@media (forced-colors: active) {
  .button { border: 2px solid ButtonBorder; }
}

/* a shadow-based focus ring disappears in forced colors —
   pair it with a transparent outline, which the mode repaints */
.button:focus-visible {
  box-shadow: 0 0 4px 3px rgb(90 50 200 / 70%);
  outline: 2px solid transparent;
}
```

- **`forced-color-adjust: none` needs an explicit justification** and an
  accessible alternative that still works in the mode.
- Icons follow text colour: `fill: currentColor; stroke: currentColor;` — never
  fixed colours inside an SVG.

## Reflow (SC 1.4.10)

At 320px wide, nothing essential may be removed, obscured or truncated, and the
user must not scroll horizontally to read multi-line text.

- Multi-column layouts stack to a single column; text wraps; controls rearrange
  vertically.
- Content collapsed in the narrow layout must be reachable **within one click**.
- Responsive primitives with fluid sizing; no fixed widths that force
  two-dimensional scrolling.
- `max-width: 100%` on images, video, canvas and iframes.
- `min-width: 0` on flex/grid children so they can shrink;
  `overflow-wrap: anywhere` for long URLs and tokens.
- Avoid absolute positioning and `overflow: hidden` where they cause content
  loss.
- Every interactive element stays visible, reachable and operable.

## Target size, timing and motion

- **Pointer targets are at least 24×24 CSS px** (SC 2.5.8), or spaced so a 24px
  circle centred on each does not overlap a neighbour. Small icon buttons are the
  usual offender — pad the hit area, do not shrink the icon.
- **Give users enough time** (SC 2.2.1). Any time limit is adjustable,
  extendable, or can be turned off. Anything auto-updating, auto-scrolling or
  auto-playing for more than 5 seconds can be paused, stopped or hidden
  (SC 2.2.2).
- **Nothing flashes more than three times per second** (SC 2.3.1), and motion
  respects `@media (prefers-reduced-motion: reduce)`.
- **Time-based media needs alternatives** — captions for video, transcripts for
  audio, audio description where the visual carries meaning of its own.

## Controls and labels

- **Every interactive element has a visible label**, and that label does not
  disappear once the field has focus or a value.
- **The accessible name contains the visible label** — required for voice
  access. If you use `aria-label`, include the visible text inside it.
- Several controls sharing one visible label (many "Remove" buttons) get an
  `aria-label` that keeps the visible text and adds the distinguishing context.

## Forms

- Every control has a programmatic label — prefer `<label for="…">`. The label
  describes the input's purpose.
- Help text is associated with `aria-describedby`.
- Required fields are indicated visually **and** programmatically — the native
  `required` attribute where the control supports it, `aria-required="true"`
  where it does not.
- Error messages explain **how to fix** the problem. Invalid fields carry
  `aria-invalid="true"` (removed when valid) and link their inline error via
  `aria-describedby`.
- **Do not disable the submit button** solely to prevent submission. On submit
  with invalid input, move focus to the first invalid control.

## Graphics, navigation, tables

- Informative images need a meaningful alternative — `alt` on `<img>`,
  `role="img"` plus `aria-label`/`aria-labelledby` on inline `<svg>`. Decorative
  ones are hidden: `alt=""`, or `aria-hidden="true"`.
- Navigation is `<nav>` with lists and links. **Never `role="menu"` /
  `role="menubar"` for site navigation.** Expandable navigation toggles with a
  `<button>` carrying `aria-expanded`; `Escape` may close it.
- Static tabular data uses `<table>` with `<th>` headers. `role="grid"` is only
  for genuinely interactive grids — cells nested in rows, arrow-key navigation.

## Final verification

Before finishing, explicitly check:

- Landmarks, heading order, one `h1`.
- Keyboard: operable, visible focus, predictable order, no traps, skip link
  works.
- Labels visible and contained in accessible names.
- Forms: labels, required indicators, `aria-invalid` + `aria-describedby`, focus
  moves to the first invalid control.
- Contrast 4.5:1 / 3:1, focus boundaries 3:1, colour never the only cue.
- Forced colors: nothing breaks, system colours used inside the media query.
- Reflow at 320px: no content loss, no horizontal scrolling.
- Images: informative ones described, decorative ones hidden; media captioned.
- Targets ≥ 24×24px; time limits adjustable; nothing flashes >3×/second.
- Tables use `<th>`; grids are properly structured.

Then say what was *not* verified. Automated generation catches structure, not
lived experience — recommend manual testing (e.g. Accessibility Insights, a
screen reader pass).

## Project delta

- Which component library is in use, and therefore which patterns are
  off-limits to reimplement.
- Where the colour tokens live and whether a dark or high-contrast theme exists.
- Any a11y linting or automated audit already running in CI.
