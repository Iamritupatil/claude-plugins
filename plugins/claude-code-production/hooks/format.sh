#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit): format the edited file if a formatter exists.
# Never blocks (always exits 0); formatting is a convenience, not a policy.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
file=$(jq -r '.tool_input.file_path // empty')
[ -z "$file" ] || [ ! -f "$file" ] && exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss|*.md|*.yaml|*.yml|*.html)
    command -v npx >/dev/null 2>&1 && npx --no-install prettier --write "$file" >/dev/null 2>&1 ;;
  *.py)
    command -v ruff >/dev/null 2>&1 && { ruff format "$file" >/dev/null 2>&1; ruff check --fix "$file" >/dev/null 2>&1; } ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$file" ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$file" >/dev/null 2>&1 ;;
esac
exit 0
