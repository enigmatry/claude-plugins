# Global styles folder hierarchy

Load this when adding, moving or reorganizing anything under the global
`styles/` folder. Component styles live beside their component and do not need
this file.

Everything global lives under a single `styles/` folder, and **only `main.scss`
compiles** — every other file is a partial prefixed with `_`.

| Folder | Holds |
|---|---|
| `modules/` | **utilities only** — mixins, functions, variables. No styles. |
| `partials/` | **styles only**, invoking the utilities from `modules/` |
| `partials/core/` | app-wide classes: `layouts/`, `states/`, grid, global padding |
| `partials/core/elements/` | base HTML-element styles — the **only** files with element selectors, and no class selectors in them |
| `partials/polyfills/` | browser/device-specific styles — every `-moz-*` / `-webkit-*` rule belongs here |
| `partials/vendors/libraries/` | vendor SCSS utilities used to generate global styles |
| `partials/vendors/overrides/` | global vendor overrides — see the main skill → *Overriding vendor and framework styles* |

**Every subfolder in `partials/` has an `_index.scss` containing only
`@use`/`@forward`** for the files beside it — same as `main.scss`. That is what
makes a block of styling easy to switch off and then delete cleanly, which
happens often over a project's life.
