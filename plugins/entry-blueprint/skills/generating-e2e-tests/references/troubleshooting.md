# Mistakes that actually bit us

| Mistake | Reality |
|---|---|
| `import { test } from '@playwright/test'` in a spec | Skips the project's auth and page-object fixtures — the test lands on the login page. Import from the project's fixtures module. |
| Raw `page.getByTestId(…)` calls in a spec | Spec files never touch locators. Add a method to the page object first. |
| `page.waitForTimeout()` to "stabilize" a step | Forbidden. Use `waitForResponse`, `waitForLoadState`, `locator.waitFor`, or a web-first assertion. |
| `page.$()` / `page.$$()` | Deprecated ElementHandle APIs. Use `page.locator()` / `getBy*()`. |
| `getByText` / `getByLabel` on a translated string | Breaks the moment the run uses another language. Use a test id. |
| No per-test timeout on a dialog-heavy flow | Global timeouts are often tight (20–30s) — multi-dialog flows then time out intermittently. Set `60_000`/`90_000` at the top of the describe. |
| Created a record and left it behind | Shared environment. Arm the capture before the click, retain the promise, await it in teardown even on failure, and fall back to a lookup by unique key. See `data-teardown.md`. |
| Hand-rolled the capture inside the page object | The machinery is identical for every entity and easy to get subtly wrong. Delegate to the project's capture util; `armXCapture` is one line. |
| Assigned the capture in a fire-and-forget `.then` | Nothing guarantees it settled before teardown reads the variable. Retain the capture and await it. |
| Retained a capture promise that can reject | Retaining isn't handling. It can reject during the awaited click, before anything is listening, and Node reports an unhandled rejection. Resolve to a `{ record } \| { error }` result and rethrow where the test reads it. |
| Matched the create response with `pathname.endsWith(…)` | Also matches unrelated endpoints, and can pick up a concurrent worker's create. Match exact origin + pathname *and* correlate on your unique request value. |
| Correlated the create with `postData().includes(key)` | Substring matching. It also matches a key that merely contains yours, or one that landed in an unrelated field. Parse the body and compare the intended field for equality. |
| Teardown guarded only on `if (created)` | A committed create whose response was lost or unparseable skips cleanup silently. Add the fail-closed lookup-by-unique-key fallback. |
| Fallback deletes whatever the lookup returned | It can remove another run's row or a seed record. Require dispatch proof, exact key equality, this run's marker, and exactly one match — throw on anything else. |
| Fallback given only the unique key | The captured headers live on the response path, which is precisely what failed. Observe the request separately and hand the fallback its URL and auth headers. |
| Capture promise with no timeout | Teardown awaits it and the run hangs. Always bound it. |
| Deleted or renamed the shared seed records | They're the records almost every spec navigates to. Only touch records your test created. |
| Anchored assertions on a shared title/name | A leftover record from a failed or parallel run with the same title can match instead. Anchor on a unique generated value. |
| Pinned to `chromium` to protect shared state | Browser selection is a compatibility choice, not isolation. It does nothing about concurrent workers, shards, retries, other CI jobs, or another developer. Give the test its own records instead. |
| Added `mode: 'serial'` to protect shared state | It orders tests within one worker and nothing else. |
| Invented a `@smoke` / `@regression` tag | Use only tags that already exist in the suite. |
| Added retries or bumped config timeouts to fix flakiness | Investigate the root cause. Config changes and new npm dependencies require asking first. |
| New page object but tests can't see it | Registration isn't automatic — wire it into the fixtures module (type *and* fixture body). |
| Teardown re-authenticates, or replays raw captured headers | Replay the captured auth headers minus pseudo-headers (`:authority`), `content-length`, and `host` — use the project's header-replay helper. |
| One `item.spec.ts` growing past 200 lines | Split by flow: `add-item.spec.ts`, `edit-item.spec.ts`, `delete-item.spec.ts`. |
| Exhaustive negative cases in an e2e spec | E2e covers happy paths plus business-critical negatives. Validation detail and edge cases belong in unit or component tests. |
