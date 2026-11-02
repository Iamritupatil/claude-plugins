---
name: claude-code-production
description: Production-grade, security-first engineering workflow and Claude Code setup. Use whenever the user asks to write, review, refactor or ship code meant for real use, set up or improve a Claude Code project (CLAUDE.md, .claude/ settings, hooks, skills, subagents, MCP), harden an app against vulnerabilities, or make code scalable and maintainable. Also use when the user says "production ready", "secure this", "clean this up", "set up Claude Code", "configure my repo for Claude", or asks for an API, service, endpoint, auth flow, database layer or deployment. Enforces minimal-but-essential code, defense-in-depth security, and plan → build → verify → ship.
---

# Claude Code: Production & Security Playbook

Two jobs, one standard:

1. **Write code** that is small, correct, secure and ready to scale.
2. **Configure Claude Code** so that standard is enforced every session, not just hoped for.

The guiding idea: *prompts are advice, configuration is enforcement.* Anything that must always hold (no secrets in code, formatting, tests passing, no writes to protected paths) belongs in hooks and permission rules, not in a sentence Claude might skip.

---

## Part 1 — Writing code: the quality bar

### 1.1 Write less code, but the important code

Every line is a liability: it must be read, tested, secured and maintained. Before writing, ask in this order:

1. **Does this need to exist?** Can the requirement be met by configuration, an existing function, the standard library, or a well-maintained dependency already in the project?
2. **What is the smallest change that fully solves it?** Change the fewest files. Don't refactor unrelated code in the same change.
3. **What must not be cut?** Input validation, authorization checks, error handling at boundaries, tests for the behaviour that matters, and logging that helps an on-call engineer. These are the "important code" — never trade them away for brevity.

Avoid: speculative abstractions ("we might need a plugin system"), wrappers that only rename things, duplicate utilities, commented-out code, dead branches, and config options nobody asked for. Prefer one obvious way over three flexible ones.

Adding a dependency is also code. Before adding one, check that it's maintained, widely used, appropriately licensed, and not replaceable by ~20 lines you'd own. Pin versions; commit the lockfile.

### 1.2 Production-grade means

- **Correct at the edges:** empty, null, huge, malformed, duplicate, concurrent and unauthorized inputs are handled deliberately.
- **Fails loudly and safely:** typed/structured errors, no swallowed exceptions, no leaking stack traces or internals to clients, timeouts on every network call, retries only for idempotent operations (with backoff + jitter).
- **Observable:** structured logs with request/correlation IDs; never log secrets, tokens, passwords or full PII.
- **Configurable without code changes:** config and secrets from environment / secret manager, validated at startup, fail fast if missing.
- **Tested:** a failing test before a bug fix; tests cover the success path, validation failures, authz failures and not-found. Tests are deterministic.
- **Typed and linted:** strict mode on; no `any`/untyped escape hatches without a comment explaining why.

### 1.3 Built to scale

Design so the next 10× doesn't require a rewrite: stateless request handlers (state in DB/cache), pagination on every list endpoint, indexes for every query pattern you ship, no N+1 queries, bounded queues and batch sizes, idempotency keys for writes that may be retried, and expensive work moved to background jobs. Separate layers (routes → services → data access) so each can change independently. Don't prematurely optimize — but never ship an unbounded loop, query or payload.

Details and examples: `references/production-code.md`.

### 1.4 Secure by default

Treat every input from outside the process (HTTP, files, env, queues, LLM output, third-party APIs) as hostile. Non-negotiables:

- Validate input at the boundary with a schema (allow-lists, not deny-lists).
- Parameterized queries / ORM only — never string-built SQL, shell commands or paths.
- Authorization on **every** request, checked server-side against the resource owner (prevents IDOR).
- Secrets never in code, logs, URLs, client bundles or git history.
- Output-encode for the context (HTML, URL, shell); set security headers; strict CORS.
- Least privilege for services, tokens, DB users and Claude's own permissions.
- Use vetted crypto/auth libraries; never roll your own. Hash passwords with argon2id/bcrypt.
- Rate-limit auth and expensive endpoints; cap request body sizes.

Full checklist mapped to OWASP Top 10, plus language-specific traps: `references/security.md`. **Read it whenever code touches auth, user input, file handling, SQL, shell, payments, secrets, uploads, or external APIs.**

### 1.5 The workflow for every non-trivial change

**Explore → Plan → Code → Verify → Ship.**

1. **Explore** (read-only): read the relevant code and its callers before proposing anything. Restate the goal and constraints.
2. **Plan**: for anything touching more than ~2 files, write a short plan (files to change, approach, risks, security considerations, test plan) and get approval before coding. This is the cheapest place to fix mistakes.
3. **Code**: one step at a time. Give yourself a way to check: failing test first, typecheck, or running the app.
4. **Verify**: run tests, typecheck and lint; do a self-review of the diff using the review checklist below; for sensitive areas run the security checklist.
5. **Ship**: one logical change per commit, conventional commit message, PR description stating what, why, how it was tested, and any security impact.

### 1.6 Self-review checklist (run on every diff before saying "done")

- [ ] Is every added line necessary? Anything deletable?
- [ ] Inputs validated; authz checked; errors handled; no secrets; nothing sensitive logged
- [ ] No string-built SQL/shell/paths; no `eval`, unsafe deserialization, or disabled TLS verification
- [ ] Unbounded anything? (queries, loops, uploads, retries, memory)
- [ ] Tests added/updated and passing; typecheck and lint clean
- [ ] Public API / schema changes are backward compatible or flagged
- [ ] New dependencies justified and pinned

When reporting back, state what was verified and how, and flag anything not verified. Never claim tests pass without running them.

---

## Part 2 — Configuring Claude Code to enforce this

Claude Code's setup has six layers; put each concern in the layer that fits:

| Layer | Holds | Loaded |
|---|---|---|
| `CLAUDE.md` + `.claude/rules/` | Facts and rules Claude can't infer from code | Every session (rules can be path-scoped) |
| Auto memory | Claude's notes from your corrections | Every session (first 200 lines) |
| Skills (`.claude/skills/<name>/SKILL.md`) | Reusable procedures & slash commands | When relevant or invoked with `/name` |
| Subagents (`.claude/agents/<name>.md`) | Specialist workers with own context/tools | When delegated or @-mentioned |
| Hooks (`hooks` in settings.json) | Things that must always happen | On lifecycle events |
| MCP + plugins | External tools; packaged bundles | When connected/installed |

Rule of thumb: **CLAUDE.md = what to know, skills = how to do, subagents = who does side work, hooks = what must happen regardless.**

### 2.1 Setting up a repo

This skill ships inside the `claude-code-production` plugin, which already provides, in every repo where it's enabled:
- **Hooks:** `protect-paths.sh` (blocks edits to secrets, keys, `.git/`, `src/generated/`, lockfiles), `scan-secrets.sh` (blocks hardcoded credentials), `format.sh` (formats edited files). They need `jq`.
- **Agents:** `code-reviewer`, `security-auditor` (both read-only), `test-runner`.
- **Skills:** `plan-feature`, `commit`, `verify`, `security-review`.

Plugins can't ship permission rules or project facts, so each repo still needs those. When asked to set up or harden a repo:

1. Inspect it first: language, package manager, test/lint/build commands, existing `.claude/` and `CLAUDE.md`. Never overwrite existing config without showing the diff and asking.
2. Run `scripts/setup-repo.sh <repo>` (non-destructive), or copy by hand:
   - `assets/CLAUDE.md.template` → `CLAUDE.md`: fill in real commands; keep under ~100 lines.
   - `assets/rules/*.md` → `.claude/rules/`: adjust `paths:` to the real source dirs.
   - `assets/settings.json` → `.claude/settings.json`: permission allow/deny rules. Replace the example `pnpm` commands with the project's real ones. If the file exists, merge the deny rules in.
3. Adapt to the stack (e.g. `pytest` instead of `pnpm test`).
4. Commit `.claude/` and `CLAUDE.md`; gitignore `CLAUDE.local.md` and `.claude/settings.local.json`.
5. Recommend `/doctor`, `/context`, `/hooks` and `/agents` to confirm everything is active.

### 2.2 Key enforcement facts to get right

- Hook exit codes: **0 = continue, 2 = block and send stderr to Claude, anything else = non-blocking error.** A policy hook that exits 1 enforces nothing.
- Permission `deny` always beats `allow`. Deny reads of `.env*` and `secrets/**`, `git push --force`, `rm -rf`.
- Hooks run with the user's full credentials — review any hook a repo ships before trusting it.
- Avoid `bypassPermissions` / `--dangerously-skip-permissions` outside a sandbox or container.
- Every connected MCP server costs context; scope heavy ones (e.g. Playwright) to a single subagent via `mcpServers`.

### 2.3 Common mistakes to steer the user away from

| Mistake | Fix |
|---|---|
| 500-line CLAUDE.md | Short brief; procedures → skills; topics → `.claude/rules/` |
| Must-hold rules written as advice | Make them hooks or deny rules |
| One endless session | `/clear` per task; research in subagents |
| Vague skill/agent descriptions | Say what it does + "Use when..." |
| Every MCP server connected | Connect only what you use |
| Coding before planning | Plan mode first for multi-file changes |
| No way for Claude to check work | Tests, typecheck, `/verify`, reviewer subagent |

---

## Reference map

- `references/production-code.md` — production & scalability patterns with examples
- `references/security.md` — OWASP-mapped checklist, secure patterns, language traps, LLM-app risks
- `references/setup-layers.md` — complete Claude Code configuration reference
- `assets/` — per-repo templates (CLAUDE.md, rules, permission settings)
- `scripts/setup-repo.sh` — non-destructive installer for those templates
