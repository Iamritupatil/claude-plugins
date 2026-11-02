#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit): block content that looks like a real secret.
# Exit 2 = block and send stderr to Claude. Fails closed if jq is missing.
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "scan-secrets: jq is required for this hook; install jq to allow edits." >&2
  exit 2
fi

content=$(jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits // [] | .[].new_string)] | map(select(. != null)) | join("\n")')
[ -z "$content" ] && exit 0

# High-signal patterns only, to keep false positives low. Extend as needed.
patterns=(
  'AKIA[0-9A-Z]{16}'                                   # AWS access key ID
  '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'              # PEM private keys
  'gh[pousr]_[A-Za-z0-9]{36,}'                         # GitHub tokens
  'github_pat_[A-Za-z0-9_]{50,}'                       # GitHub fine-grained PAT
  'xox[baprs]-[A-Za-z0-9-]{10,}'                       # Slack tokens
  'sk_live_[A-Za-z0-9]{20,}'                           # Stripe live secret key
  'AIza[0-9A-Za-z_-]{35}'                              # Google API key
  'sk-ant-[A-Za-z0-9_-]{20,}'                          # Anthropic API key
  'sk-[A-Za-z0-9]{32,}'                                # Generic sk- style API keys
  '(postgres|postgresql|mysql|mongodb(\+srv)?|redis)://[^:/@[:space:]]+:[^@[:space:]$<{]{6,}@'  # DB URL with inline password
)

for p in "${patterns[@]}"; do
  if printf '%s' "$content" | grep -Eq -- "$p"; then
    echo "Blocked: the content appears to contain a hardcoded secret (pattern: $p). Load it from environment/secret manager instead, and use a placeholder in examples." >&2
    exit 2
  fi
done
exit 0
