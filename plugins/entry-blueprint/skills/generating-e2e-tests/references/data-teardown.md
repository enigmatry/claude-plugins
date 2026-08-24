# Capturing created records and tearing them down

The failure this guards against: **the server commits the record but the test never gets a usable id.** A lost or slow response, a schema variation, a predicate that didn't match, a step that threw after the create — any of these leave the capture variable undefined, a teardown guarded only on `if (createdRecord)` silently skips, and the row stays in the shared environment forever.

## Find the capture util first

The capture machinery is identical for every entity, so it belongs in the project, not hand-written into each spec. Look for `utils/create-capture.ts` or the project's equivalent; if there isn't one, create it once from the appendix and use it everywhere after that.

It provides three things:

- `uniqueName(prefix)` — a run-marked value, `e2e-<runId>-<prefix>-<random>`. The marker is what lets teardown prove a row is the test's own before deleting it, and what lets a sweep find rows that escaped teardown entirely.
- `armCapture(page, endpoint, field, value)` — returns `{ dispatched, result }`. Neither promise ever rejects.
- `expectCreated(result)` — rethrows a captured failure at the point the test reads it.

The per-entity page-object method is then a one-liner:

```typescript
armCreateCapture(uniqueKey: string): CreateCapture {
  return armCapture(this.page, new URL('/api/items', this.baseUrl), 'name', uniqueKey);
}
```

## In the spec

```typescript
let uniqueKey: string | undefined;
let capture: CreateCapture | undefined;
let created: CreatedRecord | undefined;

test.beforeEach(() => {
  uniqueKey = undefined;
  capture = undefined;
  created = undefined;
});

test('adds an item', async ({ itemPage }) => {
  uniqueKey = uniqueName('item');                  // 1. run-marked value exists first
  await itemPage.fillName(uniqueKey);

  capture = itemPage.armCreateCapture(uniqueKey);  // 2. armed before the click, retained
  await itemPage.clickSave();                      // 3. act
  created = expectCreated(await capture.result);   // 4. resolve, rethrowing here

  await expect(itemPage.getRow(uniqueKey)).toBeVisible();
});
```

## Teardown

```typescript
test.afterEach(async ({ request }) => {
  // The test may have failed before it awaited the capture. Awaiting the
  // result is safe — it resolves either way, so no `.catch` juggling.
  const settled = await capture?.result;
  const record = created ?? (settled && 'record' in settled ? settled.record : undefined);

  if (record) {
    await deleteItem(request, record, { ignoreMissing: true });
    return;
  }

  // No id. Fall back only when the create was actually dispatched — otherwise
  // there is nothing to clean up, and a lookup risks matching another row.
  const dispatch = await capture?.dispatched;
  if (dispatch && uniqueKey) {
    await deleteItemByName(request, uniqueKey, dispatch);
  }
});
```

- `ignoreMissing` because the record may already be gone — a delete-flow test, or a partial earlier cleanup.
- Teardown must never mask a test failure. Let it surface its own error; never swallow the test's.
- Multiple records: independent nested `try`/`finally` deletions in dependency order, so a failure deleting the first still attempts the rest.

## The fallback must fail closed

A lookup-and-delete that guesses is worse than no cleanup: it can remove another run's row or a seed record. `deleteXByName` deletes only what it can prove the test owns.

| Matches found | Behaviour |
|---|---|
| None | No-op. Return without throwing. |
| Exactly one, carrying this run's marker | Delete it. |
| More than one | Throw. Never delete "the first one". |
| Any match without this run's marker | Throw. |

- **Never call it without dispatch proof.** No observed create request means no record to clean up.
- **Compare keys with exact equality inside the helper**, even when the API only offers a partial-match search — filter the results client-side rather than trusting the query.
- **Scope the query the way the app scopes its own reads.** Derive origin + pathname from `dispatch.url` and replay `dispatch.headers`, so auth and tenant context match the create.

## What this pattern still doesn't cover

A bounded timeout doesn't cancel the POST. If the server commits *after* the capture timed out and after the fallback lookup ran, the row survives the run and nothing inside `afterEach` can observe it. That race isn't closeable at test scope, so don't document the suite as if it were — mitigate outside:

- `globalTeardown` sweeps records matching the run prefix once all workers are done, catching anything that committed late.
- A periodic job sweeps the `e2e-` prefix for runs killed before `globalTeardown` ran.

## The cleanup-helper contract

Per entity, alongside the page object's `armCreateCapture`:

- `async function deleteX(request: APIRequestContext, x: CreatedRecord, options: { ignoreMissing?: boolean } = {}): Promise<void>`.
- `async function deleteXByName(request: APIRequestContext, uniqueKey: string, dispatch: DispatchedCreate): Promise<void>` — the fallback, following the rules above.
- **Replay, don't re-authenticate.** Reuse the auth/tenant headers captured from the app's own create request, stripping HTTP/2 pseudo-headers (`:authority`, …) and client-managed headers (`content-length`, `host`). Reuse the project's header-replay helper if one exists.
- Derive the delete URL from the captured create URL's origin + pathname, so host and tenant context are preserved.
- Throw a descriptive error on non-OK; tolerate 404 only when `ignoreMissing`.
- Some entities can't be hard-deleted (soft-delete, state machines, cascades). Check how existing helpers handle the entity's lifecycle before assuming `DELETE` works.

## Appendix — creating the capture util

Only when the project has none. Write it once, then the rest of this file is all a spec needs.

```typescript
// utils/create-capture.ts
import type { Page, Request } from '@playwright/test';
import { randomUUID } from 'node:crypto';

export interface CreatedRecord { id: string; url: string; headers: Record<string, string> }
export interface DispatchedCreate { url: string; headers: Record<string, string> }
export type CaptureResult = { record: CreatedRecord } | { error: Error };

export interface CreateCapture {   // neither promise ever rejects
  dispatched: Promise<DispatchedCreate | undefined>;
  result: Promise<CaptureResult>;
}

// runId is stamped once in globalSetup and read from env.
export const uniqueName = (prefix: string) =>
  `e2e-${process.env.E2E_RUN_ID}-${prefix}-${randomUUID().slice(0, 8)}`;

export const expectCreated = (result: CaptureResult): CreatedRecord => {
  if ('error' in result) throw result.error;
  return result.record;
};

// `timeout` is always bounded — teardown resolves these promises and must not hang the run.
export function armCapture(
  page: Page, endpoint: URL, field: string, value: string, timeout = 15_000,
): CreateCapture {
  const isOurCreate = (request: Request) => {
    if (request.method() !== 'POST') return false;

    const url = new URL(request.url());
    // Exact origin + pathname. `endsWith` also matches unrelated endpoints.
    if (url.origin !== endpoint.origin || url.pathname !== endpoint.pathname) return false;

    // Exact field equality, so a concurrent worker's create against the same
    // endpoint can't be picked up as ours.
    return postFieldEquals(request.postData(), field, value);
  };

  // Called synchronously, so both listeners are armed before the caller clicks.
  const requestPromise = page.waitForRequest(isOurCreate, { timeout });
  const responsePromise = page.waitForResponse(r => isOurCreate(r.request()), { timeout });

  return {
    // Proof the create went out, plus the auth/tenant context the fallback needs
    // — the response path is exactly what failed when the fallback runs.
    dispatched: (async () => {
      const request = await requestPromise.catch(() => undefined);
      return request && { url: request.url(), headers: await request.allHeaders() };
    })(),

    // Failures travel as a value. A rejection would land during the awaited
    // click, before the test attaches a handler — an unhandled rejection.
    result: (async (): Promise<CaptureResult> => {
      try {
        const response = await responsePromise;
        if (!response.ok()) {
          throw new Error(`Create failed: ${response.status()} ${response.statusText()}`);
        }
        const body = (await response.json()) as { id?: string };
        if (!body.id) {
          throw new Error('Create response did not include an id.');
        }
        const headers = await response.request().allHeaders();
        return { record: { id: body.id, url: response.url(), headers } };
      } catch (error) {
        return { error: error as Error };
      }
    })(),
  };
}

const postFieldEquals = (postData: string | null, field: string, value: string) => {
  if (!postData) return false;
  try {
    return (JSON.parse(postData) as Record<string, unknown>)[field] === value;
  } catch {
    return postData.includes(value); // last resort: form-encoded or multipart body
  }
};
```
