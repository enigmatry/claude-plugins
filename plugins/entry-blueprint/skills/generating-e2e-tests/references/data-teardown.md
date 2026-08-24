# Capturing created records and tearing them down

The failure this guards against: **the server commits the record but the test never gets a usable id.** A lost or slow response, a schema variation, a predicate that didn't match, a step that threw after the create — any of these leave the capture variable undefined, a teardown guarded only on `if (createdRecord)` silently skips, and the row stays in the shared environment forever.

So the pattern is: establish a run-marked unique key **before** the click, arm the capture **before** the click, observe the request separately from the response, retain both, resolve them in teardown even when the test failed, and fall back to a fail-closed lookup by unique key.

## Unique keys carry a run marker

Generated keys are not just unique — they identify the run that owns them:

```typescript
// e2e-<runId>-<random>, with runId stamped once in globalSetup and read from env.
export const generateItemName = () => `e2e-${process.env.E2E_RUN_ID}-${randomUUID().slice(0, 8)}`;
```

The marker is what lets teardown prove a row is the test's own before deleting it, and what lets a sweep find rows that escaped teardown entirely.

## The page-object capture method

Arm both watchers synchronously and return their promises. Do **not** `await` either inside the method — the listeners would attach after the click and miss a fast response.

Observe the **request** independently of the response. The auth/tenant headers and the create URL come from the request, so the fallback path still has them when the response never arrives or fails to parse — the exact situation the fallback exists to handle.

```typescript
interface DispatchedCreate { url: string; headers: Record<string, string> }
interface CreateCapture {
  dispatched: Promise<DispatchedCreate | undefined>;  // never rejects
  response: Promise<CreatedRecord>;
}

armCreateCapture(uniqueKey: string, timeout = 15_000): CreateCapture {
  const endpoint = new URL('/api/items', this.baseUrl);

  const isOurCreate = (request: Request) => {
    if (request.method() !== 'POST') return false;

    const url = new URL(request.url());
    // Exact origin + pathname. `endsWith` also matches unrelated endpoints.
    if (url.origin !== endpoint.origin || url.pathname !== endpoint.pathname) return false;

    // Exact field equality, so a concurrent worker's create against the same
    // endpoint can't be picked up as ours.
    return postFieldEquals(request.postData(), 'name', uniqueKey);
  };

  // Called synchronously, so both listeners are armed before the caller clicks.
  const requestPromise = this.page.waitForRequest(isOurCreate, { timeout });
  const responsePromise = this.page.waitForResponse(r => isOurCreate(r.request()), { timeout });

  return {
    // Proof the create actually went out, plus the context the fallback needs.
    dispatched: (async () => {
      const request = await requestPromise.catch(() => undefined);
      return request && { url: request.url(), headers: await request.allHeaders() };
    })(),

    response: (async () => {
      const response = await responsePromise;
      if (!response.ok()) {
        throw new Error(`Create failed: ${response.status()} ${response.statusText()}`);
      }
      const body = (await response.json()) as { id?: string };
      if (!body.id) {
        throw new Error('Create response did not include an id.');
      }
      return { id: body.id, url: response.url(), headers: await response.request().allHeaders() };
    })(),
  };
}
```

Correlate on an exact field, not a substring — `postData()?.includes(uniqueKey)` also matches a key that merely contains ours, or one that landed in an unrelated field:

```typescript
const postFieldEquals = (postData: string | null, field: string, value: string): boolean => {
  if (!postData) return false;
  try {
    return (JSON.parse(postData) as Record<string, unknown>)[field] === value;
  } catch {
    return postData.includes(value); // last resort: form-encoded or multipart body
  }
};
```

Always give both watchers a bounded `timeout` — teardown resolves these promises, and they must not hang the run.

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
  uniqueKey = generateItemName();                  // 1. run-marked value exists first
  await itemPage.fillName(uniqueKey);

  capture = itemPage.armCreateCapture(uniqueKey);  // 2. armed and retained
  await itemPage.clickSave();                      // 3. act
  created = await capture.response;                // 4. resolve for assertions

  await expect(itemPage.getRow(uniqueKey)).toBeVisible();
});
```

Never assign the capture inside an untracked `.then`. A rejection there is an unhandled rejection, and nothing guarantees the callback ran before teardown reads the variable.

## Teardown

```typescript
test.afterEach(async ({ request }) => {
  // The test may have failed before it awaited the capture.
  const record = created ?? (await capture?.response.catch(() => undefined));

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

Multiple records: independent nested `try`/`finally` deletions in dependency order, so a failure deleting the first still attempts the rest.

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

A bounded timeout doesn't cancel the POST. If the server commits *after* the capture timed out and after the fallback lookup ran, the row survives the run and nothing inside `afterEach` can observe it. That race isn't closeable at test scope — mitigate it outside:

- Every generated key carries the run marker, so escaped rows stay identifiable.
- `globalTeardown` sweeps records matching the run prefix once all workers are done, catching anything that committed late.
- A periodic job sweeps the `e2e-` prefix for runs killed before `globalTeardown` ran.

Say so when you write the suite. A pattern documented as airtight when it isn't is worse than one with a stated limit and a sweep behind it.

## Editing an existing record

Two shapes, and they aren't interchangeable:

| What you edited | Teardown |
|---|---|
| A record the test created itself | Delete the created record. No revert, no `ignoreMissing` juggling. |
| A pre-existing record | Read the original value before saving, revert it in teardown — but read the isolation rules in `SKILL.md` first: concurrent runs can observe or overwrite the intermediate value, and a revert can restore stale data. Prefer creating your own record. |

## The cleanup-helper contract

- Export `interface CreatedX { id: string; url: string; headers: Record<string, string> }` and `async function deleteX(request: APIRequestContext, x: CreatedX, options: { ignoreMissing?: boolean } = {}): Promise<void>`.
- Also export the fail-closed fallback deleter `async function deleteXByName(request: APIRequestContext, uniqueKey: string, dispatch: DispatchedCreate): Promise<void>`, following the table above.
- **Replay, don't re-authenticate.** Reuse the auth/tenant headers captured from the app's own create request, stripping HTTP/2 pseudo-headers (`:authority`, …) and client-managed headers (`content-length`, `host`). Reuse the project's header-replay helper if one exists.
- Derive the delete URL from the captured create URL's origin + pathname, so host and tenant context are preserved.
- Throw a descriptive error on non-OK; tolerate 404 only when `ignoreMissing`.
- Some entities can't be hard-deleted (soft-delete, state machines, cascades). Check how existing helpers handle the entity's lifecycle before assuming `DELETE` works.
