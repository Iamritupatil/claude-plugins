#!/usr/bin/env bash
# Install per-repo templates (CLAUDE.md, rules, permission settings) WITHOUT overwriting anything.
# Hooks, agents and skills come from the plugin itself.
# Usage: setup-repo.sh <repo-dir>
set -euo pipefail
repo="${1:?usage: setup-repo.sh <repo-dir>}"
src="$(cd "$(dirname "$0")/../assets" && pwd)"
[ -d "$repo" ] || { echo "Not a directory: $repo" >&2; exit 1; }

skipped=()
copy() { if [ -e "$2" ]; then skipped+=("$2"); return; fi; mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "  + $2"; }

echo "Setting up $repo"
copy "$src/CLAUDE.md.template" "$repo/CLAUDE.md"
copy "$src/settings.json"      "$repo/.claude/settings.json"
for f in "$src"/rules/*.md; do copy "$f" "$repo/.claude/rules/$(basename "$f")"; done

gi="$repo/.gitignore"; touch "$gi"
for line in "CLAUDE.local.md" ".claude/settings.local.json" ".env" ".env.*" "!.env.example"; do
  grep -qxF -- "$line" "$gi" || echo "$line" >> "$gi"
done

command -v jq >/dev/null 2>&1 || echo "WARNING: jq not found. The plugin's security hooks block all edits until jq is installed."
if [ ${#skipped[@]} -gt 0 ]; then echo "Skipped (already exist; merge manually):"; printf '  - %s\n' "${skipped[@]}"; fi
echo "Next: replace the example pnpm commands in CLAUDE.md and .claude/settings.json with your real ones."
