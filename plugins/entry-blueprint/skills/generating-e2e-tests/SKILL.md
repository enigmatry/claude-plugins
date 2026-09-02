---
name: generating-e2e-tests
description: Write or modify Playwright end-to-end tests. Use only for a Playwright spec — one that imports test/expect from @playwright/test or from a fixtures module extending it, AND lives under the testDir of a playwright.config.* rather than beside a source file (the one definition, in this skill's "What counts as a Playwright spec") — or when the user explicitly asks for a Playwright/e2e test. Covers coverage scope, spec structure, page objects, and API teardown of created data on shared environments. Layers on frontend-foundations and typescript, and supersedes angular-testing for e2e specs. Not for unit tests, component tests, API-only test suites, or interactive browser automation.
---

# Generating a Playwright e2e test

Three rules drive everything:

1. **Specs read like user stories.** Every element interaction goes through a page-object method; a spec file never contains a raw locator call.
2. **Every test cleans up the data it creates** — including when it fails mid-flow. On a shared environment, a test that creates or mutates a record tears it down via API in `afterEach`. See `references/data-teardown.md`.
3. **The test project's own documentation wins.** Where the e2e project's `CLAUDE.md` / `AGENTS.md` / `README.md` conflicts with this skill, follow the project. This skill supplies defaults for what they leave unspecified.

## How this skill layers

> Read the `frontend-foundations` skill first — it is the base layer here as
> everywhere — and follow the `typescript` skill for every `.ts` file in the
> suite. Do **not** load `angular-testing`: it owns unit and component specs
> only.

### What counts as a Playwright spec

This is the only definition; `angular-testing`, `typescript` and
`frontend-code-review` point here rather than restating it. A spec is a
Playwright spec when **both** hold:

1. It imports `test`/`expect` from `@playwright/test`, or from a fixtures module
   that extends Playwright's `test`.
2. It lives under the `testDir` of a `playwright.config.*` (typically `tests/`),
   not beside a source file.

Every other spec is a unit or component spec and belongs to `angular-testing` —
including a colocated Vitest spec that imports only a type such as `Page` from
`@playwright/test`, and every colocated spec in a package that also happens to
contain a `playwright.config.*`. Config presence proves an e2e suite exists, not
that a given spec belongs to it.

### Deliberate exceptions

This is the complete list. Everything not named here — comments, braces, the
two allowed casts, arrow-property class members, one declaration per file —
applies unchanged, and the reference code in `references/` follows it.

- **Run-unique randomized keys (UUID/timestamp) are required** — fixed values
  collide across parallel workers and concurrent runs. Randomness stays in
  identity keys; assertions remain deterministic. (`angular-testing` forbids
  randomness; it doesn't apply here, but a reviewer reaching for it should know
  why.)
- **Suite layout (`tests/<verb>-<entity>.spec.ts`) replaces colocation** —
  e2e specs test flows, not source files.
- **Raw duration literals handed to Playwright** — `test.setTimeout(60_000)` on
  a describe, a `{ timeout }` on a `waitFor*`, the named default in the capture
  util. No injected time provider exists in a Playwright suite; these are
  budgets the runner enforces, not logic under test. Name any duration that
  isn't a one-off per-describe budget.
- **Playwright's `test`, not `it`**, with sentence-case `test.step` titles.
  Steps are the structure — they execute and appear in the report — so
  `// Arrange / Act / Assert` comments are never written, the same as everywhere
  else in this plugin.

## Coverage scope

E2e tests are slow to run and expensive to keep green, so this is not where coverage goes to be exhaustive.

- Cover the **happy path of each user-facing flow**.
- Add an unhappy path only when the failure is **business-critical** — a declined payment, a validation that must block a save, a permission denial.
- Everything else belongs a layer down. Field-level validation, message wording, boundary values, and error branches are unit- or component-test work.

Rule of thumb: one happy path per flow, plus at most one or two crucial negatives. If you're writing a third negative case for the same flow, move it down a layer instead.

## Discover only what the change needs

Always read:

- The nearest project instructions (`CLAUDE.md` / `AGENTS.md` / `README.md` in the e2e project, plus the target folder's README if it has one).
- The target spec and its closest sibling spec — that sibling is your template for shape, imports, and naming.

Read these **only when the change depends on them**:

| Read | When |
|---|---|
| `playwright.config.*` | Timeouts, projects, `webServer`, or env loading matter to your change |
| Cleanup helpers, fixtures | The test creates, edits, or deletes data |
| Data generators, static test data | You need a unique value or a shared seed record |
| `package.json` scripts | You're about to run lint or tests |

Don't inventory the whole suite. One close sibling spec beats five archetypes.

## Write the spec

1. **Name it** by the project's convention. Absent one: kebab-case `<verb>-<entity>[-<subentity>].spec.ts`, verb first, one canonical verb per action (`add` — never new/create, `edit` — never update, `delete`, `merge` — never combine, plus specific verbs like `search`, `filter`, `upload`, `toggle`, `navigate`). Standalone flows may use a plain name (`login`, `checkout`).
2. **Import `test` and `expect` from the project's fixtures module** (e.g. `../fixtures`) — never from `@playwright/test` directly when a fixtures module exists, since the fixtures wire up authentication and page objects.
3. **`test.describe('<Title Case Name>', …)`**, one flow per describe. Multi-dialog flows usually need `test.setTimeout(60_000)` (or `90_000`) at the top of the describe — never raise the global config instead.
4. **Authentication** through the project's mechanism (auto-fixture, storage state, explicit fixture). No hand-rolled login in a spec. Use only tags that already exist in the suite — don't invent `@smoke`/`@regression`.
5. **`beforeEach`** — reset the capture variables, then navigate with the existing navigation helper. Prefer navigating by a unique key (email, code) over a name search that may paginate.
6. **Unique data** from the project's generators, or a timestamp/UUID, so parallel workers can't collide. If the value must later be found through the app's own search, check how that search tokenizes before picking the generator.
7. **Body** — one `test.step('Sentence case description', …)` per logical action; web-first assertions on `Locator`s returned by page-object getters (`await expect(itemPage.getRow(name)).toBeVisible()`). Structure comes from steps, never from `// Arrange / Act / Assert` comments.
8. **Teardown** for anything the test created or mutated — follow `references/data-teardown.md`.

### Split before the file gets long

One flow per spec file. Split when any of these is true:

- The file passes **~200 lines**.
- It covers more than one user-facing flow — prefer `add-item.spec.ts` / `edit-item.spec.ts` / `delete-item.spec.ts` over one `item.spec.ts`.
- A single describe holds more than ~5 tests.
- It needs more than one teardown shape.
- Helper functions are accumulating in the spec — those belong in a page object or `utils/`.

A 500-line spec isn't a spec, it's a suite. Split it when you touch it.

## Isolation on a shared environment

Every test must be independently runnable, in any order, concurrently with other runs.

- **Default: each test creates its own records** with unique generated keys and deletes them in teardown. No test depends on data another test made. Keys carry a run marker (`e2e-<runId>-…`) so teardown can prove ownership before deleting and a sweep can find what escaped — see `references/data-teardown.md`.
- **Reuse shared seed records for navigation only** — never delete them, never leave them mutated.
- **Teardown for an edit depends on who owns the record.** Edited one the test created? Delete it — no revert, no `ignoreMissing` juggling. Edited a pre-existing one? Read the original value before saving and revert in teardown, knowing a concurrent run can observe or overwrite the intermediate value and that a revert can restore stale data. Prefer creating your own record.
- **Browser selection is a compatibility choice, not isolation.** `--project=chromium`, or a `browserName` skip, does nothing about concurrent Chromium workers, shards, retries, other CI jobs, or another developer on the same environment. Never use it to protect shared state.
- **Don't reach for `test.describe.configure({ mode: 'serial' })` to protect shared state** — it orders tests within one worker and nothing else.
- **If mutating a record the test didn't create is genuinely unavoidable**, that needs a real cross-process lock, not a Playwright construct: an ownership token, a version/ETag check on the read-modify-write, guaranteed release in `finally`, and a lease timeout so a crashed run can't wedge the environment. A lock only binds writers that take it — a suite, a job, or a developer that doesn't can still read or overwrite the intermediate state, so it lowers the odds rather than removing them. Prefer a per-run tenant or an isolated environment. **Ask before introducing any of the three.**
- Optional features skip inside the test: `test.skip(!featureAvailable, 'Feature is not enabled in this environment');`.

## Verify (don't skip)

From the e2e project directory:

- Project lint script → 0 errors (run the auto-fix variant first if there is one).
- The new spec on one browser: `npx playwright test tests/<file> --project=chromium` → green. Check the project docs for prerequisites (app running locally? credentials in the process environment?). If credentials are injected by a runner or IDE and a raw terminal run fails on missing env vars, that's **expected, not a bug** — never "fix" it by editing config or hardcoding credentials; ask the user to run it.
- Check the passing spec against current Playwright guidance via Context7 (`mcp__Context7__resolve-library-id` → `query-docs`) and fix what it flags.
- Update any inventory tables the project maintains (covered scenarios, page objects, helpers, test data).

## References

Load these when the task reaches them, not upfront:

- `references/data-teardown.md` — failure-safe capture of created records, `afterEach` shapes, cleanup-helper contract.
- `references/page-objects-and-selectors.md` — page-object conventions, registration, selector policy.
- `references/troubleshooting.md` — mistakes that have actually bitten us, and the reality behind each.

## File layout (typical Playwright project — verify against the actual one)

- Specs: `tests/<verb>-<entity>[-<subentity>].spec.ts`
- Page objects: `pages/<name>-page.ts` (class `<Name>Page`), registered in `fixtures/index.ts`
- Cleanup helpers and generators: `utils/<entity>-cleanup.ts`, `utils/generators.ts`, a header-replay helper, the capture util (`utils/arm-capture.ts` and its siblings — see `references/data-teardown.md`)
- Static data: `test-data/<entities>.json`
- Test-id additions: the application's frontend source
