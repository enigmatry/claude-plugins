# Capturing created records and tearing them down

The failure this guards against: **the server commits the record but the test never gets a usable id.** A lost or slow response, a schema variation, a predicate that didn't match, a step that threw after the create — any of these leave the capture variable undefined, a teardown guarded only on `if (createdRecord)` silently skips, and the row stays in the shared environment forever.

## Find the capture util first

The capture machinery is identical for every entity, so it belongs in the project, not hand-written into each spec. Look for `utils/create-capture.ts` or the project's equivalent; if there isn't one, create the files in the appendix once and use them everywhere after that.

It provides three things:

- `uniqueName(prefix)` — a run-marked value, `e2e-<runId>-<prefix>-<random>`. The marker is what lets teardown prove a row is the test's own before deleting it, and what lets a sweep find rows that escaped teardown entirely.
- `armCapture(page, endpoint, field, value)` — returns `{ dispatched, result }`. Neither promise ever rejects.
- `expectCreated(result)` — rethrows a captured failure at the point the test reads it.

The per-entity page-object member is a one-line delegate:

```typescript
readonly armCreateCapture = (uniqueKey: string): CreateCapture =>
  armCapture(this.page, new URL('/api/items', this.baseUrl), 'name', uniqueKey);
```

## In the spec

Order is the whole point: the run-marked key exists before anything is typed, the capture is armed before the click and kept where teardown can reach it, and the result is read after the click so a failure rethrows inside the test.

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
  uniqueKey = uniqueName('item');
  await itemPage.fillName(uniqueKey);

  capture = itemPage.armCreateCapture(uniqueKey);
  await itemPage.clickSave();
  created = expectCreated(await capture.result);

  await expect(itemPage.getRow(uniqueKey)).toBeVisible();
});
```

## Teardown

Both promises resolve whether or not the test reached its own `await`, so teardown awaits them without `.catch` juggling. The fallback runs only on dispatch proof: no observed create request means nothing to clean up, and a lookup would risk matching another row.

```typescript
test.afterEach(async ({ request }) => {
  const settled = await capture?.result;
  const record = created ?? (settled && 'record' in settled ? settled.record : undefined);

  if (record) {
    await deleteItem(request, record, { ignoreMissing: true });
    return;
  }

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
- A periodic job sweeps the `e2e-` prefix for runs killed before `globalTeardown` ran — deleting only rows older than the suite's enforced maximum run lifetime (Playwright's `globalTimeout`), or whose run id is absent from an active-run registry. An age threshold with no enforced lifetime behind it can't distinguish a dead run from a long one.

## The cleanup-helper contract

Per entity, alongside the page object's `armCreateCapture`:

- `async function deleteX(request: APIRequestContext, x: CreatedRecord, options: { ignoreMissing?: boolean } = {}): Promise<void>`.
- `async function deleteXByName(request: APIRequestContext, uniqueKey: string, dispatch: DispatchedCreate): Promise<void>` — the fallback, following the rules above.
- **Replay, don't re-authenticate.** Reuse the auth/tenant headers captured from the app's own create request, stripping HTTP/2 pseudo-headers (`:authority`, …) and client-managed headers (`content-length`, `host`). Reuse the project's header-replay helper if one exists.
- Derive the delete URL from the captured create URL's origin + pathname, so host and tenant context are preserved.
- Throw a descriptive error on non-OK; tolerate 404 only when `ignoreMissing`.
- Some entities can't be hard-deleted (soft-delete, state machines, cascades). Check how existing helpers handle the entity's lifecycle before assuming `DELETE` works.

## Appendix — creating the capture util

Only when the project has none. Four files: one exported declaration each, per `typescript` → *Files and declarations*, with the contract types in a theme-named file because specs, page objects and cleanup helpers all import them. Write them once, then the rest of this file is all a spec needs.

The code follows `frontend-foundations` and `typescript` unchanged — no casts (response bodies are narrowed through a type guard), braces on every clause, arrow functions throughout, named durations. The reasons behind its shape live here rather than in comments:

- **Both listeners are armed synchronously** inside `armCapture`, so the caller's click can't outrun them.
- **Origin + pathname match exactly.** `endsWith` also matches unrelated endpoints.
- **The correlation field is compared for exact equality, per declared media type.** The media type is compared as its essence — parameters stripped, case folded — because `includes` also matches a type smuggled into a parameter and misses valid uppercase. Substring matching on the body would pick up a concurrent worker's create against the same endpoint. A repeated form field is ambiguous because servers differ on which occurrence they bind. Multipart, a missing or unknown content type, or an unparseable body fails closed: the create goes uncaptured, and its run-marked key lets the sweep reclaim the row.
- **Neither promise rejects.** A rejection would land during the awaited click, before the test attaches a handler — an unhandled rejection. `dispatched` resolves to `undefined` when no request was observed or its headers were unavailable (page already closed), which keeps the fallback off. `result` carries the failure as a value for `expectCreated` to rethrow.
- **`timeout` is always bounded.** Teardown awaits both promises and must not hang the run.
- **`uniqueName` fails fast without `E2E_RUN_ID`.** Stamp it once in `globalSetup` (`process.env.E2E_RUN_ID ??= randomUUID().slice(0, runIdLength)`); minting `e2e-undefined-…` keys would leave rows no sweep can tie back to a run.

```typescript
// utils/create-capture-contracts.ts
export interface CreatedRecord { id: string; url: string; headers: Record<string, string> }
export interface DispatchedCreate { url: string; headers: Record<string, string> }
export type CaptureResult = { record: CreatedRecord } | { error: Error };

export interface CreateCapture {
  dispatched: Promise<DispatchedCreate | undefined>;
  result: Promise<CaptureResult>;
}
```

```typescript
// utils/unique-name.ts
import { randomUUID } from 'node:crypto';

const randomSuffixLength = 8;

export const uniqueName = (prefix: string): string => {
  const runId = process.env.E2E_RUN_ID;
  if (!runId) {
    throw new Error('E2E_RUN_ID is not set. Stamp it in globalSetup before any test runs.');
  }
  return `e2e-${runId}-${prefix}-${randomUUID().slice(0, randomSuffixLength)}`;
};
```

```typescript
// utils/expect-created.ts
import type { CaptureResult, CreatedRecord } from './create-capture-contracts';

export const expectCreated = (result: CaptureResult): CreatedRecord => {
  if ('error' in result) {
    throw result.error;
  }
  return result.record;
};
```

```typescript
// utils/create-capture.ts
import type { Page, Request, Response } from '@playwright/test';
import type { CaptureResult, CreateCapture, DispatchedCreate } from './create-capture-contracts';

const defaultCaptureTimeoutMilliseconds = 15_000;

export const armCapture = (
  page: Page, endpoint: URL, field: string, value: string, timeout = defaultCaptureTimeoutMilliseconds,
): CreateCapture => {
  const isOurCreate = (request: Request): boolean => {
    if (request.method() !== 'POST') {
      return false;
    }
    const url = new URL(request.url());
    if (url.origin !== endpoint.origin || url.pathname !== endpoint.pathname) {
      return false;
    }
    return postFieldEquals(request, field, value);
  };

  const requestPromise = page.waitForRequest(isOurCreate, { timeout });
  const responsePromise = page.waitForResponse((response) => isOurCreate(response.request()), { timeout });

  return {
    dispatched: observeDispatch(requestPromise),
    result: observeResult(responsePromise),
  };
};

const observeDispatch = async (requestPromise: Promise<Request>): Promise<DispatchedCreate | undefined> => {
  try {
    const request = await requestPromise;
    return { url: request.url(), headers: await request.allHeaders() };
  } catch {
    // Not observed, or the page closed first: no dispatch proof, so the fallback stays off.
    return undefined;
  }
};

const observeResult = async (responsePromise: Promise<Response>): Promise<CaptureResult> => {
  try {
    const response = await responsePromise;
    if (!response.ok()) {
      return { error: new Error(`Create failed: ${response.status()} ${response.statusText()}`) };
    }
    const id = createdId(await response.json());
    if (!id) {
      return { error: new Error('Create response did not include an id.') };
    }
    return { record: { id, url: response.url(), headers: await response.request().allHeaders() } };
  } catch (thrown) {
    return { error: toError(thrown) };
  }
};

const createdId = (body: unknown): string | undefined => {
  const id = isRecord(body) ? body['id'] : undefined;
  return typeof id === 'string' ? id : undefined;
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null;

const toError = (thrown: unknown): Error =>
  thrown instanceof Error ? thrown : new Error(String(thrown));

const postFieldEquals = (request: Request, field: string, value: string): boolean => {
  const postData = request.postData();
  if (!postData) {
    return false;
  }
  const [mediaTypeEssence = ''] = (request.headers()['content-type'] ?? '').split(';', 1);
  const mediaType = mediaTypeEssence.trim().toLowerCase();

  if (mediaType === 'application/json') {
    return jsonFieldEquals(postData, field, value);
  }
  if (mediaType === 'application/x-www-form-urlencoded') {
    const values = new URLSearchParams(postData).getAll(field);
    return values.length === 1 && values[0] === value;
  }
  return false;
};

const jsonFieldEquals = (postData: string, field: string, value: string): boolean => {
  try {
    const parsed: unknown = JSON.parse(postData);
    return isRecord(parsed) && parsed[field] === value;
  } catch {
    // Unparseable body: not provably ours, so it fails closed.
    return false;
  }
};
```
