---
name: generating-e2e-tests
description: Use when adding, generating, or modifying a Playwright end-to-end test — triggers include "write an e2e test", "add a Playwright test", "cover X with an e2e test", a new *.spec.ts, a new page object, or a new test cleanup/teardown helper.
---

# Generating a Playwright e2e test

## Overview

E2e tests are Playwright + TypeScript specs that usually run against a **shared environment** with real seeded data. Two principles drive everything:

**Core principle 1: specs read like user stories.** Every element interaction goes through a page-object method; a spec file never contains a raw locator call.

**Core principle 2: every test removes or reverts the data it creates.** On a shared environment, any test that creates, edits, or pays for a record captures the app's own API request and tears the record down via API in `afterEach`. Data left behind breaks other people's runs.

**The test project's own documentation is authoritative.** Before writing anything, find and read the e2e project's instructions (its `CLAUDE.md` / `AGENTS.md` / `README.md` and any per-folder READMEs). Where those documents conflict with this skill, they win — this skill supplies the workflow and the defaults for anything they leave unspecified.

## When to use

- Adding a new e2e spec, page object, fixture, or cleanup helper to a Playwright test project.
- Extending an existing spec with a new scenario.

Not for: unit tests, component tests, API-only test suites, or interactive browser exploration via MCP tools.

## Before writing (discover, then reuse)

1. **Locate the e2e project** and read its docs: project instructions, `playwright.config.ts` (global timeout, projects, `webServer`, env loading), `package.json` scripts, and any per-folder READMEs.
2. **Name the file by the project's convention.** If none is documented, default to kebab-case `<verb>-<entity>[-<subentity>].spec.ts`, verb **always first**, one canonical verb per action (`add` — never new/create, `edit` — never update, `delete`, `merge` — never combine, plus specific verbs like `search`, `filter`, `upload`, `toggle`, `navigate`); standalone flows may use a plain name (`login`, `checkout`).
3. **Find the closest archetype spec** in the existing suite and mirror its shape. Look for one of each: a create + verify + API-cleanup spec, a delete-flow spec, an edit spec, a long multi-record flow, and a read-only spec (no cleanup, no timeout override) — the one closest to your scenario is your template.
4. **Inventory what exists**: page objects, cleanup/teardown helpers, data generators, fixtures, and static test data. Identify the project's shared seed records (the customer/user/entity most specs navigate to) — reuse them for navigation, **never delete or permanently mutate them**.

## Recipe

### The spec

1. **Imports** — import `test` and `expect` from the project's extended fixtures module (e.g. `../fixtures`), **never** directly from `@playwright/test` when a fixtures module exists — it wires up authentication and page-object fixtures. Static data from the project's test-data files; cleanup helper plus its record type via a type-only import.
2. **Describe + timeout** — `test.describe('<Title Case Name>', …)`. Check the global timeout in `playwright.config.ts`; multi-dialog flows usually need a per-test override at the top of the describe (`test.setTimeout(60_000)` or `90_000` for long flows). Never bump the global config instead.
3. **Authentication** — use the project's mechanism (auto-fixture, storage state, or explicit fixture); write no hand-rolled login code in a spec. If the project has an opt-out tag for unauthenticated tests, use it only for login/public-page tests. **Use only tags that already exist in the suite** — do not invent `@smoke`/`@regression` schemes.
4. **`beforeEach`** — reset the capture variable(s) (`createdRecord = undefined;`), then navigate using the existing navigation helper/page-object method the sibling specs use. Prefer navigating by a unique key (email, code) over a name search that may paginate.
5. **Unique data** — from the project's generators, or timestamps/UUIDs, so parallel workers don't collide. If a generated value must later be found through the app's own search, check how that search tokenizes (hyphens, spaces) and pick the generator accordingly.
6. **Body** — one `test.step('Sentence case description', …)` per logical action; web-first assertions on `Locator`s returned by page-object getters: `await expect(itemPage.getRow(name)).toBeVisible();`, `toContainText`, `toHaveText`, `toHaveURL`. Long linear flows may use `// Arrange / // Act / // Assert` comments instead.
7. **`afterEach` teardown** — describe-scoped `let createdRecord: CreatedRecord | undefined;`, guarded teardown with the built-in `request` fixture:

```typescript
test.afterEach(async ({ request }) => {
  if (createdRecord) {
    await deleteRecord(request, createdRecord);
  }
});
```

Delete-flow tests pass `{ ignoreMissing: true }` (the happy path already deleted the record via the UI). Edit tests come in two shapes: editing a **pre-existing shared record** → read the original value before saving and revert it in teardown; editing a record **the test created itself** → create via UI, edit, and simply delete the created record in teardown (no revert, no `ignoreMissing`). Multiple records → independent nested `try/finally` deletions in dependency order; teardown must never mask a test failure.

### Capturing the created record

The save goes through a page-object `…AndCapture…` method that arms `page.waitForResponse` **before** clicking, matches on method + pathname (add a body match if a page-load request hits the same endpoint), and returns `{ id, url, headers }`:

```typescript
async clickSaveAndCapture(): Promise<CreatedRecord> {
  const responsePromise = this.page.waitForResponse(
    response =>
      response.request().method() === 'POST' &&
      new URL(response.url()).pathname.endsWith('/Items')
  );
  await this.saveButton.click();
  const response = await responsePromise;
  if (!response.ok()) {
    throw new Error(`Save failed: ${response.status()} ${response.statusText()}`);
  }
  const { id } = (await response.json()) as { id?: string };
  if (!id) {
    throw new Error('Save response did not include an id.');
  }
  return { id, url: response.url(), headers: await response.request().allHeaders() };
}
```

For flows where later steps can fail after the create, arm the promise early and assign the capture variable in a `.then` so teardown still has the id.

### New page object (only if no existing one fits)

- Follow the project's base-class convention; absent one, a standalone `export class XPage` with `constructor(public readonly page: Page)` and type-only imports (`import type { Page, Locator } from '@playwright/test';`).
- **All static locators are `private readonly` fields assigned in the constructor** — never inline in a method body. The only inline exception: dynamic locators needing a runtime parameter, returned as `Locator` (e.g. `getRow(text): Locator { return this.rows.filter({ hasText: text }).first(); }`).
- Scope dialog-only controls via `page.getByRole('dialog').getByTestId(…)`.
- Method style: `clickX()`, `fillX(value)`, `selectX(value)`, `getX(): Locator` for assertions, `…AndCapture…(): Promise<CreatedX>` for creates. Synchronize with `waitForResponse`/`waitFor` — never `waitForTimeout`.
- **Register it wherever the project wires page objects to tests** (typically the fixtures module: add the property to the fixtures type and the fixture body) — a page object that isn't registered is invisible to specs.

### New cleanup helper (only if no existing one fits)

- Export `interface CreatedX { id: string; url: string; headers: Record<string, string> }` and `async function deleteX(request: APIRequestContext, x: CreatedX, options: { ignoreMissing?: boolean } = {}): Promise<void>`.
- **Replay, don't re-auth**: reuse the auth/tenant headers captured from the app's own create request, stripping HTTP/2 pseudo-headers (`:authority`, …) and client-managed headers (`content-length`, `host`) — reuse the project's header-replay helper if one exists. Derive the delete URL from the captured create URL's origin + pathname so host/tenant context is preserved.
- Throw a descriptive error on non-OK; tolerate 404 only when `ignoreMissing`.
- Some records can't be hard-deleted (soft-delete, state machines, cascades) — check how existing helpers handle the entity's lifecycle before assuming `DELETE` works.

### Selectors

`page.getByTestId()` first. If the element has no test id, **prefer adding one to the application code** (kebab-case value) over a CSS/XPath selector — ask before falling back. Role-based (`getByRole`) is fine for standard widgets (options, dialogs). If the app is localized, **never** use text-based selectors (`getByText`/`getByLabel`/`getByPlaceholder`) on translated strings.

### Parallelism

Assume files run fully parallel; design tests to be independently runnable with no shared mutable state. Don't add `test.describe.configure({ mode: 'serial' })` — each browser project is a separate worker, so serial mode doesn't protect shared state anyway. A test touching shared state that can't tolerate multiple browsers at once gets pinned instead: `test.skip(({ browserName }) => browserName !== 'chromium', '<reason>');` at describe level. Optional features skip inside the test: `test.skip(!featureAvailable, 'Feature is not enabled in this environment');`.

### Keep the project's docs in sync

If the test project maintains inventory tables (covered scenarios, page objects, helpers, test data), update them for everything you add — check its READMEs for such tables before finishing.

## Verify (don't skip)

From the e2e project directory:

- Run the project's lint script → 0 errors (run the auto-fix variant first if there is one).
- Run the new spec on one browser: `npx playwright test tests/<file> --project=chromium` → green. Check the project docs for prerequisites (app running locally? credentials in the process environment?). If credentials are injected by a runner/IDE and a raw terminal run fails on missing env vars, that is usually **expected, not a bug** — never "fix" it by editing config or hardcoding credentials; ask the user to run it or supply credentials.
- Check the passing test against current Playwright best practices via Context7 (`mcp__Context7__resolve-library-id` → `query-docs`) and fix what it flags.

## Common mistakes (these actually bit us)

| Mistake | Reality |
|---|---|
| `import { test } from '@playwright/test'` in a spec | Skips the project's auth and page-object fixtures — the test lands on the login page. Import from the project's fixtures module. |
| Raw `page.getByTestId(…)` calls in a spec | Spec files never touch locators. Add a method to the page object first. |
| `page.waitForTimeout()` to "stabilize" a step | Forbidden. Use `waitForResponse`, `waitForLoadState`, `locator.waitFor`, or a web-first assertion. |
| `page.$()` / `page.$$()` | Deprecated ElementHandle APIs. Use `page.locator()` / `getBy*()`. |
| `getByText`/`getByLabel` on a translated string | Breaks the moment the run uses another language. Use a test id. |
| No per-test timeout on a dialog-heavy flow | Global timeouts are often tight (20–30s) — multi-dialog flows time out intermittently. Set 60_000/90_000 at the describe top. |
| Created a record and left it behind | Shared environment. Capture `{ id, url, headers }` on save and delete/revert in `afterEach` — or the next run (and colleagues) inherit your data. |
| Deleted or renamed the shared seed records | They're the records almost every spec navigates to. Only touch records your test created. |
| Anchored assertions on a shared title/name | A leftover record from a failed or parallel run with the same title can match instead. Anchor on a unique generated value. |
| Invented a `@smoke`/`@regression` tag | Use only tags that already exist in the suite. |
| Added `mode: 'serial'`, retries, or bumped config timeouts to fix flakiness | Investigate the root cause. Config changes and new npm dependencies require asking first. |
| New page object but tests can't see it | Registration isn't automatic — wire it into the fixtures module (type + fixture body). |
| Teardown re-authenticates or replays raw captured headers | Replay the captured auth headers minus pseudo-headers (`:authority`), `content-length`, and `host` — use the project's header-replay helper. |

## File layout (typical Playwright project — verify against the actual one)

- Specs: `tests/<verb>-<entity>[-<subentity>].spec.ts`
- Page objects: `pages/<name>-page.ts` (class `<Name>Page`), registered in `fixtures/index.ts`
- Cleanup helpers + generators: `utils/<entity>-cleanup.ts`, `utils/generators.ts`, a header-replay helper
- Static data: `test-data/<entities>.json`
- Test-id additions: the application's frontend source
- Docs to update: the project README's coverage table and any per-folder READMEs
