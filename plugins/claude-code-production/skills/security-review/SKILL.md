---
name: security-review
description: Security review of the current diff or a named module using the security-auditor subagent and an OWASP checklist. Use before merging anything touching auth, input handling, data access, files, payments, secrets or external calls.
argument-hint: [path-or-empty-for-diff]
context: fork
agent: security-auditor
---
Audit target: "$ARGUMENTS" (if empty, audit the current diff from `git diff HEAD`).
Follow your audit procedure and report findings by severity with file:line and a concrete fix.
Then list any missing tests that would have caught each finding.
