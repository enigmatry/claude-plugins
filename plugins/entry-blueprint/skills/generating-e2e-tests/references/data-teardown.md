# Capturing created records and tearing them down

The failure this guards against: **the server commits the record but the test never gets a usable id.** A lost or slow response, a schema variation, a predicate that didn't match, a step that threw after the create — any of these leave the capture variable undefined, a teardown guarded only on `if (createdRecord)` silently skips, and the row stays in the shared environment forever.

So the pattern is: establish the unique key **before** the click, arm the capture **before** the click, retain the capture promise, await it in teardown even when the test failed, and fall back to a lookup by unique key.

## The page-object capture method

Arm `waitForResponse` synchronously and return the promise. Do **not** `await` it inside the method — the listener would attach after the click and miss a fast response.

```typescript
armCreateCapture(uniqueKey: string, timeout = 15_000): Promise<CreatedRecord> {
  const endpoint = new URL('/api/items', this.baseUrl);

  // Called synchronously, so the listener is armed before the caller clicks.
  const responsePromise = this.page.waitForResponse(response => {
    const request = response.request();
    if (request.method() !== 'POST') return false;

    const url = new URL(response.url());
    // Exact origin + pathname. `endsWith` also matches unrelated endpoints.
    if (url.origin !== endpoint.origin || url.pathname !== endpoint.pathname) return false;

    // Correlate on the unique value this test sent, so a concurrent worker's
    // create against the same endpoint can't be picked up as ours.
    return request.postData()?.includes(uniqueKey) ?? false;
  }, { timeout });

  return (async () => {
    const response = await responsePromise;
    if (!response.ok()) {
      throw new Error(`Create failed: ${response.status()} ${response.statusText()}`);
    }
    const body = (await response.json()) as { id?: string };
    if (!body.id) {
      throw new Error('Create response did not include an id.');
    }
    return { id: body.id, url: response.url(), headers: await response.request().allHeaders() };
  })();
}
```

Always give the capture a bounded `timeout` — teardown awaits this promise, and it must not hang the run.

## In the spec

```typescript
let uniqueKey: string | undefined;
let capture: Promise<CreatedRecord> | undefined;
let created: CreatedRecord | undefined;

test.beforeEach(() => {
  uniqueKey = undefined;
  capture = undefined;
  created = undefined;
});

test('adds an item', async ({ itemPage }) => {
  uniqueKey = generateItemName();                  // 1. unique value exists first
  await itemPage.fillName(uniqueKey);

  capture = itemPage.armCreateCapture(uniqueKey);  // 2. armed and retained
  await itemPage.clickSave();                      // 3. act
  created = await capture;                         // 4. resolve for assertions

  await expect(itemPage.getRow(uniqueKey)).toBeVisible();
});
```

Never assign the capture inside an untracked `.then`. A rejection there is an unhandled rejection, and nothing guarantees the callback ran before teardown reads the variable.

## Teardown

```typescript
test.afterEach(async ({ request }) => {
  // The test may have failed before it awaited the capture.
  const record = created ?? (await capture?.catch(() => undefined));

  if (record) {
    await deleteItem(request, record, { ignoreMissing: true });
    return;
  }

  // The create may have committed without yielding an id. Idempotent —
  // a no-op when nothing matches.
  if (uniqueKey) {
    await deleteItemByName(request, uniqueKey);
  }
});
```

- `ignoreMissing` because the record may already be gone — a delete-flow test, or a partial earlier cleanup.
- The fallback lookup must be **idempotent** and must not throw when there is nothing to delete.
- Teardown must never mask a test failure. Let it surface its own error; never swallow the test's.

Multiple records: independent nested `try`/`finally` deletions in dependency order, so a failure deleting the first still attempts the rest.

## Editing an existing record

Two shapes, and they aren't interchangeable:

| What you edited | Teardown |
|---|---|
| A record the test created itself | Delete the created record. No revert, no `ignoreMissing` juggling. |
| A pre-existing record | Read the original value before saving, revert it in teardown — but read the isolation rules in `SKILL.md` first: concurrent runs can observe or overwrite the intermediate value, and a revert can restore stale data. Prefer creating your own record. |

## The cleanup-helper contract

- Export `interface CreatedX { id: string; url: string; headers: Record<string, string> }` and `async function deleteX(request: APIRequestContext, x: CreatedX, options: { ignoreMissing?: boolean } = {}): Promise<void>`.
- Also export a lookup-by-unique-key deleter (`deleteXByName`) for the fallback path — idempotent, a no-op when nothing matches.
- **Replay, don't re-authenticate.** Reuse the auth/tenant headers captured from the app's own create request, stripping HTTP/2 pseudo-headers (`:authority`, …) and client-managed headers (`content-length`, `host`). Reuse the project's header-replay helper if one exists.
- Derive the delete URL from the captured create URL's origin + pathname, so host and tenant context are preserved.
- Throw a descriptive error on non-OK; tolerate 404 only when `ignoreMissing`.
- Some entities can't be hard-deleted (soft-delete, state machines, cascades). Check how existing helpers handle the entity's lifecycle before assuming `DELETE` works.
