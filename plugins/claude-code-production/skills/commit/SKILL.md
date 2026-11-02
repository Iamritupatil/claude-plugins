---
name: commit
description: Run checks, review the diff, and create a conventional commit. Use when the user asks to commit.
disable-model-invocation: true
---
Current state:
!`git status --short`

1. Run the typecheck/lint and test commands from CLAUDE.md (or the verify skill's steps). If anything fails, stop and report; do not commit.
2. Review `git diff` for secrets, debug leftovers, commented-out code and unrelated changes. Remove or flag them.
3. If the diff mixes unrelated changes, propose splitting into separate commits.
4. Write a conventional commit: `type(scope): summary` (≤72 chars), a body explaining *why*, plus `BREAKING CHANGE:` / security notes if relevant.
5. Commit. Never use `--no-verify`, never force-push.
