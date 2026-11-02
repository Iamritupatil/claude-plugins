# Claude Code Setup Reference

Distilled from "The Claude Code Setup Playbook" (Oct 28, 2026). Features evolve — when in doubt, check the official Claude Code docs.

## Contents
1. Folder map & precedence
2. CLAUDE.md & rules
3. Auto memory
4. Skills
5. Subagents
6. Settings & permissions
7. Hooks
8. MCP & plugins
9. Daily workflow & context hygiene
10. Setup checklist

---

## 1. Folder map & precedence

```
~/.claude/                       # YOU, every project
├── CLAUDE.md                    # personal preferences
├── settings.json                # personal permissions, hooks, env, statusline
├── skills/<name>/SKILL.md       # personal skills
├── agents/<name>.md             # personal subagents
└── projects/<project>/memory/   # auto memory

your-repo/                       # TEAM, committed
├── CLAUDE.md                    # project brief
├── CLAUDE.local.md              # private notes (gitignore)
├── .mcp.json                    # shared MCP servers
└── .claude/
    ├── settings.json            # shared permissions, hooks, plugins
    ├── settings.local.json      # your overrides (auto-gitignored)
    ├── rules/*.md               # modular, optionally path-scoped
    ├── skills/<name>/SKILL.md
    ├── agents/<name>.md
    ├── hooks/                   # scripts hooks call
    └── agent-memory/<agent>/    # subagent memory (memory: project)
```

**Settings precedence (most specific wins):** managed policy → CLI flags → `settings.local.json` → project `settings.json` → user `settings.json`.
**Skills with same name:** personal beats project. **Subagents:** project beats personal.
**MCP:** user/local in `~/.claude.json`, team in `.mcp.json`.

## 2. CLAUDE.md & rules

Loads every session — every line costs context every turn. Keep under ~100 lines. Run `/init` once, then cut by hand. Edit in-session with `/memory`.

Loading: walks up from the start directory loading every `CLAUDE.md` / `CLAUDE.local.md`; subdirectory `CLAUDE.md` files load on demand when Claude works there; `~/.claude/CLAUDE.md` loads everywhere.

| Put in | Keep out |
|---|---|
| Build/test/lint commands Claude can't guess | What Claude can learn by reading code |
| Style that differs from language defaults | Generic advice ("write clean code") |
| How to run one test; what "done" means | Long API docs (link or `@import`) |
| Branch/commit/PR etiquette | File-by-file descriptions |
| Architecture decisions + why | Weekly-changing info |
| Env quirks, required vars, gotchas | Multi-step procedures (→ skills) |

Anti-bloat:
1. **Imports:** `@path/to/file.md`, `@~/.claude/my-prefs.md` (ignored inside code spans).
2. **Rules folder:** `.claude/rules/*.md` with optional `paths:` frontmatter:
   ```
   ---
   paths: ["src/api/**/*.ts"]
   ---
   All endpoints validate input with Zod and return { data, error }.
   ```
3. **Nested CLAUDE.md** per package in monorepos.

`/doctor` flags derivable content and offers to move procedures into skills. `claudeMdExcludes` skips irrelevant CLAUDE.md files in large monorepos.

## 3. Auto memory

Claude writes notes to `~/.claude/projects/<project>/memory/MEMORY.md` when corrected; first 200 lines (or 25KB) load each session. Say "add this to CLAUDE.md" when a lesson should be shared with the team. Toggle from `/memory`.

## 4. Skills

Folder with `SKILL.md`; only the description sits in context until triggered or invoked via `/name`. Make one when you paste the same instructions twice or a CLAUDE.md section becomes a procedure. `.claude/commands/x.md` still works; new work goes in `.claude/skills/x/SKILL.md`.

Placement: personal habits → `~/.claude/skills/`; codebase/team process → `.claude/skills/`; monorepo package → `<package>/.claude/skills/`; cross-repo → a plugin.

Anatomy: `SKILL.md` (<500 lines), `reference.md` (loaded when pointed to), `examples/`, `scripts/` (executed, not loaded).

| Frontmatter | Use |
|---|---|
| `description` | The trigger. What it does + "Use when...". Capped at 1,536 chars in listing |
| `disable-model-invocation: true` | Side-effect workflows only the user fires (`/deploy`, `/commit`) |
| `user-invocable: false` | Background knowledge, hidden from `/` menu |
| `allowed-tools` | Pre-approve tools for that turn |
| `context: fork` + `agent:` | Run in an isolated subagent |
| `paths` | Auto-load on matching files |
| `model`, `effort` | Cheaper/stronger model per skill |
| `hooks` | Enforce rules while active |
| `argument-hint` | Shown in the `/` menu |

Live data: a line `` !`git diff HEAD` `` runs before Claude reads the skill and inlines output. Args: `$ARGUMENTS`, `$0`, `$1`. Skill dir: `${CLAUDE_SKILL_DIR}`.

A project skill named `verify` runs before each commit.

Bundled skills to use before writing your own: `/code-review`, `/debug`, `/simplify`, `/batch`, `/loop`, `/run`, `/verify`, `/doctor`. `/skill-doctor` finds unused skills.

## 5. Subagents

Own context window, prompt, tools and model. Use for noisy work (searching many files, test runs, logs) returning a short summary. Skill = playbook in main thread; subagent = work done elsewhere.

Priority: managed → `--agents` CLI → `.claude/agents/` → `~/.claude/agents/` → plugin. Identity comes from `name` only; keep unique.

| Field | Does |
|---|---|
| `name`, `description` | Required. Add "use proactively" to encourage auto use |
| `tools` / `disallowedTools` | Allow/deny list. Reviewers get no Edit/Write |
| `model` | `haiku` cheap search; `sonnet`/`opus` judgment; `inherit` |
| `skills` | Preload skill content |
| `memory` | `project` / `user` / `local` persistent notes |
| `isolation: worktree` | Throwaway git worktree |
| `permissionMode` | e.g. `plan` read-only, `acceptEdits` |
| `mcpServers` | MCP server only for this agent |
| `hooks`, `maxTurns`, `effort`, `color` | Guardrails, loop caps, tuning, UI |

Invoke: automatic by description; by name ("use the code-reviewer subagent"); guaranteed `@"code-reviewer (agent)"`; whole session `claude --agent code-reviewer`. Subagents don't see your conversation — restate critical context. Built-ins: Explore, Plan, general-purpose.

## 6. Settings & permissions

CLAUDE.md is advice; settings and hooks are enforced. `deny` always beats `allow`.

Permission modes (Shift+Tab): `default`, `acceptEdits`, `plan` (read-only), `auto` (classifier approves routine actions). Avoid `bypassPermissions` outside a sandbox.

Other settings: `env`, `model`, `effort`, `agent`, `skillOverrides`, `claudeMdExcludes`, `$schema: https://json.schemastore.org/claude-code-settings.json`.

## 7. Hooks

Commands run at lifecycle events, configured under `hooks` in settings (or skill/agent frontmatter). Receive JSON on stdin (e.g. `.tool_input.file_path`). **Exit 0 = continue; exit 2 = block, stderr sent to Claude; other = non-blocking error.**

| Event | Good for |
|---|---|
| `PreToolUse` | Block protected paths, unsafe SQL, `.env` reads, secrets in writes |
| `PostToolUse` | Format/lint edited files |
| `UserPromptSubmit` | Inject context |
| `Stop` / `SubagentStop` | Run tests, notify |
| `SessionStart` | Load branch, issues, env checks |
| `Notification` | Desktop/phone alert |
| `PreCompact` | Save notes |

Hooks can also call HTTP, ask a model a yes/no question, or spawn an agent. `/hooks` shows what's active. Hooks run with full user credentials — review any a repo ships.

## 8. MCP & plugins

```
claude mcp add --transport http github https://api.githubcopilot.com/mcp/ --scope project
claude mcp add playwright --scope user -- npx -y @playwright/mcp@<pinned-version>
```
Scopes: `local`, `project` (→ `.mcp.json`), `user`. `/mcp` for status. Each server's tool descriptions cost context; scope heavy ones to one subagent via `mcpServers`. Prefer pinned versions over `@latest` for supply-chain safety.

Plugins bundle skills, agents, hooks, MCP:
```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install skill-creator@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
```
Package a stable setup as a plugin to share across repos.

Extras: `/statusline`, output styles, IDE integration, `/doctor`, `/context`.

## 9. Daily workflow & context hygiene

Explore (plan mode) → Plan (`docs/plans/<feature>.md`, interview for edge cases) → Code (one step, with self-check) → Verify (reviewer subagent, `/verify`, read the diff) → Commit (`/commit`, hooks format/test).

Debugging: exact error → hypothesis → failing test → fix → re-run.

Hygiene: `/clear` between tasks; `/compact <focus>`; Esc to stop, Esc×2 or `/rewind` to restore; `/context`; `/btw` for side questions.

Scale: `claude --worktree`, `claude -p "..."` headless for CI, background agents.

Prompting: state goal + constraint, `@path` files, define success, correct early, "add that to CLAUDE.md".

## 10. Setup checklist

- [ ] `/init`, cut CLAUDE.md to commands, conventions, gotchas
- [ ] `~/.claude/CLAUDE.md` personal prefs
- [ ] `.claude/settings.json`: allow safe commands; deny secrets & destructive git
- [ ] PostToolUse format hook; PreToolUse protect + secret-scan hooks; Notification hook
- [ ] 2–3 project skills (`/plan-feature`, `/commit`, `verify`, `/security-review`)
- [ ] Read-only code-reviewer + security-auditor; cheap test-runner
- [ ] Only needed MCP servers; LSP plugin for your language
- [ ] Commit `.claude/` + `CLAUDE.md`; gitignore `CLAUDE.local.md`
- [ ] `/doctor` and `/context`
