---
name: verify
description: Build-and-check recipe run before each commit — typecheck, lint, tests, build, dependency audit. Use when verifying a change works end to end.
---
Use the commands listed under "Commands" in this repo's CLAUDE.md. If none are listed, detect them from package.json scripts, pyproject.toml, Makefile, go.mod or Cargo.toml, and suggest adding them to CLAUDE.md.

Run in order, stopping at the first failure:
1. Typecheck + lint
2. Tests
3. Build (if the project has one)
4. Dependency audit (e.g. `npm audit --omit=dev`, `pip-audit`, `govulncheck ./...`, `cargo audit`) if the tool is available

Report each step as pass/fail with the key error lines. Never report a step as passing without running it.
