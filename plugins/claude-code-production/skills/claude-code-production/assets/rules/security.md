---
paths: ["src/**", "app/**", "lib/**", "server/**", "api/**"]
---
# Security rules (always apply in source code)
- Treat all external input (HTTP, files, env, queues, LLM output, 3rd-party APIs) as hostile; validate with a strict schema at the boundary.
- Parameterized queries only. No string-built SQL, shell commands, or file paths. No eval/exec on input.
- Authorize every request server-side against the resource owner; return 404 for "not yours".
- Never hardcode, log, or return secrets/tokens/passwords/PII. Config comes from validated env.
- Every outbound call has a timeout. Never disable TLS verification.
- Use vetted crypto/auth libs; argon2id/bcrypt for passwords; secure random for tokens.
- Cap request/upload sizes; rate-limit auth and expensive endpoints.
- New dependency? Justify it, pin it, check it's maintained.
