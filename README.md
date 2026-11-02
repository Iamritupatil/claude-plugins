# my-claude-plugins

A Claude Code plugin marketplace containing **claude-code-production**: a production-grade, security-first coding standard.

## What the plugin adds

| Component | Contents |
|---|---|
| Skill | `claude-code-production`: coding standard, security checklist (OWASP), scalability patterns, Claude Code setup reference |
| Skills | `plan-feature`, `commit`, `verify`, `security-review` |
| Agents | `code-reviewer` (read-only), `security-auditor` (read-only), `test-runner` (haiku) |
| Hooks | block edits to secrets/keys/lockfiles/generated code, block hardcoded credentials, auto-format edited files |

## Install

Requires `jq` (the security hooks block all edits without it):
`brew install jq` · `sudo apt install jq` · `winget install jqlang.jq`

In Claude Code (terminal or VS Code):

```
/plugin marketplace add iamritupatil/claude-plugins
/plugin install claude-code-production@my-claude-plugins
```

Then start a new session and check with `/hooks`, `/agents` and `/skills`.

## Per-repo setup

Plugins can't ship permission rules or project facts. In each repo, ask Claude:

> Use the claude-code-production skill to set up this repo.

This adds `CLAUDE.md`, `.claude/rules/` and `.claude/settings.json` (deny rules for `.env`, secrets, force-push, `rm -rf`) without overwriting existing files.

## Updating

Edit the files, bump `version` in `plugins/claude-code-production/.claude-plugin/plugin.json`, push, then run `/plugin` in Claude Code to update.

## Notes

- Hooks apply in every repo where the plugin is enabled. Edit the `protected` list in `hooks/protect-paths.sh` if a path doesn't fit your projects.
- Hooks are bash scripts; on Windows use Git Bash or WSL.
