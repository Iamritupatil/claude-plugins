#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit): block writes to protected paths.
# Exit 2 = block and send stderr to Claude. Fails closed if jq is missing.
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "protect-paths: jq is required for this hook; install jq to allow edits." >&2
  exit 2
fi

file=$(jq -r '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0

# Normalize to a path relative to the project root when possible.
rel="${file#"${CLAUDE_PROJECT_DIR:-}"/}"

# Edit this list for your project. Bash glob patterns.
protected=(
  ".env" ".env.*" "*/.env" "*/.env.*"
  "secrets/*" "*/secrets/*"
  "*.pem" "*.key" "*id_rsa*" "*.p12" "*.pfx"
  ".git/*"
  "src/generated/*"
  "package-lock.json" "pnpm-lock.yaml" "yarn.lock" "poetry.lock" "Cargo.lock" "go.sum"
)

# Allow example env files with placeholders.
case "$rel" in
  *.env.example|.env.example) exit 0 ;;
esac

for pattern in "${protected[@]}"; do
  # shellcheck disable=SC2053
  if [[ "$rel" == $pattern ]]; then
    echo "Blocked: '$rel' is a protected path ($pattern). Secrets, generated code and lockfiles must not be edited directly. Use the proper tool (e.g. the package manager or codegen) or ask the user." >&2
    exit 2
  fi
done
exit 0
