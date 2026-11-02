# Security Reference

Read this whenever code touches: auth/sessions, user input, SQL/NoSQL, shell, file paths or uploads, secrets, payments, external APIs, deserialization, or LLM calls.

## Contents
1. Threat-model in 60 seconds
2. OWASP Top 10 checklist
3. Secure patterns (with examples)
4. Secrets management
5. Dependencies & supply chain
6. Language/framework traps
7. LLM / AI-app specific risks
8. Security review output format

---

## 1. Threat-model in 60 seconds

For each change, answer briefly (in the plan):
- **What's the trust boundary?** Where does untrusted data enter?
- **What's the asset?** User data, money, credentials, availability.
- **Who's the attacker?** Anonymous user, authenticated user acting on another's data, malicious dependency, compromised internal service.
- **What's the worst outcome**, and which control prevents it?

## 2. OWASP Top 10 checklist

| Risk | Check |
|---|---|
| A01 Broken access control | Authz on every endpoint, server-side, per-resource (`WHERE id = ? AND owner_id = ?`). Deny by default. No trust in client-sent role/user IDs. Check IDOR on every `:id` route. |
| A02 Cryptographic failures | TLS everywhere; argon2id/bcrypt for passwords; vetted libs (libsodium, `crypto` built-ins) for encryption; no MD5/SHA1 for security; secure random (`crypto.randomBytes`, `secrets`) for tokens. |
| A03 Injection | Parameterized queries; no shell string building (use arg arrays); no `eval`/`Function`/`exec` on input; template engines with auto-escaping. |
| A04 Insecure design | Rate limits, quotas, idempotency, abuse cases considered in the plan. |
| A05 Security misconfiguration | Debug off in prod; security headers (CSP, HSTS, X-Content-Type-Options, frame-ancestors); strict CORS allow-list (never `*` with credentials); no default creds; minimal error detail to clients. |
| A06 Vulnerable components | Lockfile committed; `npm audit` / `pip-audit` / `govulncheck` in CI; pinned versions; Dependabot/Renovate. |
| A07 Auth failures | MFA-ready; session rotation on login; `HttpOnly; Secure; SameSite` cookies; short-lived access tokens; brute-force protection; generic login errors. Validate JWT `alg`, `iss`, `aud`, `exp` — never accept `alg: none`. |
| A08 Integrity failures | No unsafe deserialization (`pickle`, `yaml.load`, Java native); verify webhook signatures with constant-time compare; signed artifacts in CI. |
| A09 Logging failures | Log auth events, authz denials, admin actions — without secrets/PII. Alertable. |
| A10 SSRF | Allow-list outbound hosts for user-supplied URLs; block private/link-local/metadata IPs (169.254.169.254) after DNS resolution; disable redirects or re-validate. |

## 3. Secure patterns

**Input validation at the boundary (TypeScript/Zod):**
```ts
const CreateOrder = z.object({
  productId: z.string().uuid(),
  quantity: z.number().int().min(1).max(100),
}).strict();                       // reject unknown fields (mass-assignment)
const input = CreateOrder.parse(req.body);
```

**Authorization scoped in the query (prevents IDOR):**
```ts
const order = await db.order.findFirst({ where: { id, userId: session.userId } });
if (!order) return notFound();     // same response for "missing" and "not yours"
```

**Parameterized SQL (Python):**
```python
cur.execute("SELECT * FROM users WHERE email = %s", (email,))   # good
# cur.execute(f"SELECT * FROM users WHERE email = '{email}'")   # never
```

**Shell without injection:**
```python
subprocess.run(["convert", src_path, dst_path], check=True, timeout=30)  # arg list, no shell=True
```

**Path traversal guard:**
```python
base = Path(UPLOAD_DIR).resolve()
target = (base / user_filename).resolve()
if not target.is_relative_to(base): raise Forbidden()
```

**Webhook signature (constant-time):**
```ts
const expected = createHmac("sha256", secret).update(rawBody).digest();
if (!timingSafeEqual(expected, Buffer.from(sigHeader, "hex"))) return unauthorized();
```

**File uploads:** cap size; check type by magic bytes, not extension; random server-side names; store outside web root or in object storage; serve with `Content-Disposition: attachment` and correct `Content-Type`; scan if risk warrants.

## 4. Secrets management

- Load from env / secret manager; validate presence at startup; never default to a real value.
- Never in: source, tests fixtures with real values, logs, error messages, URLs/query strings, front-end bundles, Docker images, CI output.
- `.env*` in `.gitignore`; provide `.env.example` with placeholders.
- Claude Code: deny `Read(./.env)`, `Read(./.env.*)`, `Read(./secrets/**)`; the `scan-secrets.sh` hook blocks writes containing key patterns.
- If a secret is committed: rotate it first, then purge history. Rotation is the fix; purging is cleanup.

## 5. Dependencies & supply chain

- Prefer standard library and existing deps. Each new dep: maintained? popular? license OK? transitive footprint?
- Watch for typosquats (check exact package name and publisher).
- Pin versions; commit lockfiles; run audit in CI; enable automated update PRs.
- CI: least-privilege tokens, pinned action SHAs, no secrets exposed to forked PRs.

## 6. Language/framework traps

- **JS/TS:** prototype pollution (`Object.assign` / deep-merge from user JSON — use `Object.create(null)` or schema parse); `dangerouslySetInnerHTML`/`innerHTML`; ReDoS in user-facing regex; `child_process.exec` with strings.
- **Python:** `pickle`, `yaml.load` (use `safe_load`), `eval`, `shell=True`, `assert` for security checks (stripped with `-O`), `requests` without `timeout`, `verify=False`.
- **Go:** unchecked errors; `html/template` vs `text/template`; missing `http.Server` timeouts; goroutine leaks.
- **Java/Kotlin:** native deserialization, XXE (disable external entities), SpEL/OGNL injection.
- **SQL/ORMs:** raw query helpers (`$queryRawUnsafe`, `.raw()`, `extra()`) with interpolation.
- **Containers:** run as non-root; minimal base image; no secrets in layers; read-only FS where possible.

## 7. LLM / AI-app specific risks

- Treat model output as untrusted input: validate/parse before acting; never pass it to `eval`, shell, or SQL.
- Prompt injection: content from web pages, files, emails or tool results can carry instructions. Keep privileged actions behind explicit confirmation and least-privilege tools.
- Don't put secrets or other users' data into prompts unnecessarily; scope retrieval by the requesting user's permissions.
- Cap tokens, cost and tool-call loops per request.

## 8. Security review output format

Report findings as:

```
### [Critical|High|Medium|Low] <title>
File: path/to/file.ts:42
Issue: what's wrong and how it's exploitable (1–2 sentences)
Fix: concrete change (code if short)
```

Order by severity. If nothing is found, say what was checked rather than just "looks fine".
