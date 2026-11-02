---
name: plan-feature
description: Interview the user, read the relevant code, and write a minimal, secure implementation plan to docs/plans/<feature>.md, then stop for approval. Use when starting any feature or change touching more than two files.
argument-hint: [feature-name]
disable-model-invocation: true
---
Plan the feature "$ARGUMENTS". Do not write implementation code.

1. Ask up to 5 sharp questions about requirements, edge cases, scale expectations and who may access what. Wait for answers.
2. Read the relevant code (delegate wide searches to the Explore subagent). Find existing helpers to reuse.
3. Write `docs/plans/$ARGUMENTS.md` with:
   - Goal and non-goals
   - Smallest viable design; files to change (fewer is better); what existing code is reused
   - Data model / migration (backward compatible), indexes, pagination
   - Security: trust boundaries, validation, authz rule, secrets, abuse/rate limits
   - Failure modes: timeouts, retries, idempotency
   - Test plan: success, 400, 401, 403/404, not-found, edge cases
   - Rollout / rollback
4. Stop and ask for approval. Do not start coding.
