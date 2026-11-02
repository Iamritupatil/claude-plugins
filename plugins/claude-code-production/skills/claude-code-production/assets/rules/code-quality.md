---
paths: ["src/**", "app/**", "lib/**", "server/**", "api/**"]
---
# Production code rules
- Smallest diff that fully solves the task; delete code made obsolete; no unrelated refactors.
- Layers: route (parse, validate, authz, map errors) -> service (business logic) -> data access.
- Typed errors for expected failures; never swallow exceptions; no internals in client errors.
- Every list is paginated with a max page size; add indexes for new query patterns; no N+1.
- Nothing unbounded: loops, batches, payloads, retries, concurrency.
- Idempotency for retryable writes; slow work goes to background jobs.
- Structured logs with request IDs; redact sensitive fields.
- Tests cover success, 400, 401, 403/404 and not-found; deterministic.
