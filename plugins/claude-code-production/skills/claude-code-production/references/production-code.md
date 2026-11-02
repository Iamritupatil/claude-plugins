# Production Code & Scalability Reference

## Contents
1. Minimal code: decision rules
2. Structure
3. Error handling
4. Configuration
5. Data access & performance
6. Scalability patterns
7. Observability
8. Testing
9. API design & compatibility
10. Definition of done

---

## 1. Minimal code: decision rules

- **Reuse before writing.** Search the codebase for an existing helper first (grep for the verb/noun).
- **Rule of three.** Don't abstract until the third real duplicate. Two similar blocks are cheaper than a wrong abstraction.
- **Delete as a feature.** If a change makes code obsolete, remove it in the same PR.
- **No speculative generality.** No options, flags, hooks or interfaces without a current caller.
- **Small diffs.** Prefer several reviewable PRs over one large one. A diff a reviewer can't hold in their head is a diff that hides bugs.
- **But never cut:** validation, authz, error handling at boundaries, timeouts, tests for behaviour that matters.

## 2. Structure

- Layers: **transport** (routes/handlers: parse, validate, authz, map errors) → **service** (business rules, no HTTP types) → **data access** (queries only).
- Pure functions for business logic where possible: easiest to test and reason about.
- Dependencies passed in (constructor/params), not imported singletons — enables testing and swapping.
- One module, one responsibility. Name things for what they do in the domain.

## 3. Error handling

- Distinguish **expected** errors (validation, not-found, conflict — return typed results/4xx) from **unexpected** ones (bugs, outages — log with context, return generic 5xx).
- Never swallow: `catch {}` with nothing in it is a bug.
- Don't leak internals: no stack traces, SQL, or file paths in client responses.
- Every outbound call has a **timeout**. Retries only for idempotent operations, with exponential backoff + jitter and a max attempts cap. Consider circuit breakers for flaky dependencies.
- Clean up resources (`finally`, `defer`, `using`, context managers).

## 4. Configuration

- Parse and validate all config at startup into a typed object; crash fast on missing/invalid values.
```ts
const Env = z.object({
  DATABASE_URL: z.string().url(),
  PORT: z.coerce.number().int().default(3000),
  NODE_ENV: z.enum(["development", "test", "production"]),
});
export const env = Env.parse(process.env);
```
- No environment-specific `if` branches scattered in code; drive behaviour from config.

## 5. Data access & performance

- Every list endpoint is **paginated** (cursor-based preferred for large/changing sets) with a max page size.
- Add an **index** for every new query's filter/sort columns; check the query plan for hot paths.
- Avoid **N+1**: batch-load (`IN (...)`, dataloaders, ORM `include`/`select_related`).
- Use **transactions** for multi-write invariants; keep them short; no network calls inside.
- **Migrations**: backward-compatible (expand → migrate → contract); never drop/rename a column in the same deploy that stops using it; large backfills batched.
- Select only needed columns for large tables.

## 6. Scalability patterns

- **Stateless handlers**: sessions/state in DB or cache, so instances scale horizontally.
- **Idempotency keys** on create/payment endpoints that clients may retry.
- **Background jobs** for slow work (emails, exports, image processing); jobs are idempotent and retry-safe.
- **Bounded everything**: request body size, batch size, queue length, concurrency (worker pools/semaphores), result sets.
- **Caching** with explicit TTLs and invalidation strategy; never cache per-user data under a shared key.
- **Rate limiting** per user/IP on auth and expensive endpoints.
- **Graceful shutdown**: stop accepting, drain in-flight, close pools.
- **Health checks**: liveness (process alive) separate from readiness (dependencies reachable).

## 7. Observability

- Structured (JSON) logs with level, timestamp, request ID, user ID (not email), operation.
- Log at boundaries and on errors; not inside tight loops.
- Redact secrets/tokens/PII by default in the logger config.
- Metrics for rate, errors, duration (RED) on each endpoint/job; traces across service calls where available.

## 8. Testing

- Bug fix → failing test first, then fix.
- For each endpoint: success, validation error (400), unauthenticated (401), unauthorized/other user's resource (403/404), not found (404).
- Unit-test business logic; integration-test data access against a real DB (container) rather than mocks where feasible.
- Deterministic: no real time, randomness, or network without control. No sleeping in tests.
- Test names describe behaviour: `rejects order when quantity exceeds stock`.

## 9. API design & compatibility

- Consistent response shape (e.g. `{ data, error }`) and error codes.
- Additive changes only on published APIs; version or deprecate otherwise.
- Validate and document request/response schemas (OpenAPI generated from the schema where possible).
- Use correct HTTP semantics (GET safe, PUT/DELETE idempotent).

## 10. Definition of done

- [ ] Smallest change that fully meets the requirement
- [ ] Tests added/updated; full suite, typecheck, lint pass (actually run)
- [ ] Security checklist applied where relevant
- [ ] No unbounded queries/loops/payloads; indexes added
- [ ] Logs/metrics adequate to debug in production
- [ ] Docs/CLAUDE.md updated if commands, conventions or gotchas changed
- [ ] Commit message explains *why*
