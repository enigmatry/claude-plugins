# Page objects and selectors

## New page object (only if no existing one fits)

- Follow the project's base-class convention. Absent one: a standalone `export class XPage` with `constructor(public readonly page: Page)` and type-only imports (`import type { Page, Locator } from '@playwright/test';`).
- **All static locators are `private readonly` fields assigned in the constructor** — never inline in a method body. The one exception is a dynamic locator that needs a runtime parameter, returned as a `Locator`:

```typescript
getRow(text: string): Locator {
  return this.rows.filter({ hasText: text }).first();
}
```

- Scope dialog-only controls so they can't match the page behind the dialog: `page.getByRole('dialog').getByTestId(…)`.
- Method naming: `clickX()`, `fillX(value)`, `selectX(value)`, `getX(): Locator` for assertions, and `armXCapture(uniqueKey): CreateCapture` for creates — returns the dispatched-request and response promises without awaiting either (see `data-teardown.md`).
- Synchronize with `waitForResponse` or `locator.waitFor` — never `waitForTimeout`.
- **Register it wherever the project wires page objects to tests** — typically the fixtures module: add the property to the fixtures type *and* the fixture body. An unregistered page object is invisible to specs.

## Selectors

In order of preference:

1. `page.getByTestId()`.
2. No test id on the element? **Prefer adding one to the application code** (kebab-case value) over reaching for a CSS or XPath selector — ask before falling back to either.
3. `getByRole` is fine for standard widgets (options, dialogs).
4. If the app is localized, **never** use text-based selectors (`getByText` / `getByLabel` / `getByPlaceholder`) against translated strings — they break the moment a run uses another language.
