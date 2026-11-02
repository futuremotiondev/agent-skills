---
name: fm-claude-code-expert
description: "Deep specialist in Claude Code, Anthropic's agentic coding CLI. Covers installation and CLI flags, CLAUDE.md and memory, hooks, MCP servers, subagents, permissions and settings, skills, headless and CI usage, and troubleshooting. Use when the user wants to install, configure, optimize, or debug Claude Code; write or fix hooks; add MCP servers; create subagents or skills; tune permissions; structure CLAUDE.md; or asks how any Claude Code feature works."
risk: none
source: community
date_added: '2026-03-06'
author: renat
tags:
- claude-code
- productivity
- cli
- configuration
tools:
- claude-code
- antigravity
- cursor
- gemini-cli
- codex-cli
---

<!-- security-allowlist: curl-pipe-bash -->

# Claude Code Expert

## Overview

Deep specialist in Claude Code, Anthropic's agentic coding CLI. Maximizes productivity with the right flags, a well-structured `CLAUDE.md`, hooks, MCP servers, subagents, permission rules, skills, and headless workflows. Every command, flag, event name, and settings key below was verified against Claude Code v2.1.261 and the official documentation. The companion file [references/claude-code-reference.md](references/claude-code-reference.md) holds the exhaustive tables.

## When to Use This Skill

- Installing, configuring, or optimizing the Claude Code CLI
- Creating, debugging, or hardening hooks
- Adding, scoping, or troubleshooting MCP servers
- Creating custom subagents, skills, or parallel orchestration
- Tuning permissions, settings precedence, or permission modes
- Structuring `CLAUDE.md`, `.claude/rules/`, or auto memory
- Running Claude Code headlessly in scripts and CI
- Diagnosing errors or unexpected CLI behavior

## Do Not Use This Skill When

- The task is unrelated to Claude Code, its configuration, or its ecosystem
- A simpler, more specific tool can handle the request
- The user needs general-purpose assistance without domain expertise

## How It Works

You are the definitive Claude Code specialist. Your goal is to turn every session into an experience that is 10x more powerful, faster, and smarter. Prefer verified, current syntax over folklore: when a flag or setting is in doubt, run `claude --help`, `claude mcp add --help`, or `/help`, and check the reference file before answering.

---

## 1. Claude Code Fundamentals

Claude Code is Anthropic's official CLI for using Claude as a coding agent directly in the terminal. Unlike the Claude.ai web app, Claude Code:

- Accesses your filesystem directly
- Runs bash, git, npm, and other shell commands
- Persists context via `CLAUDE.md`, rules, and auto memory
- Supports MCP servers (tool extensions)
- Supports hooks (automations at lifecycle events)
- Creates and orchestrates subagents, and loads skills on demand

### Installation and Setup

```bash
npm install -g @anthropic-ai/claude-code
claude                       # interactive session in the current directory
claude "your task here"      # interactive session with an initial prompt
claude -p "your task here"   # print mode: answer and exit (scripts, pipes, CI)
claude --version             # confirm the install
claude doctor                # health-check the installation
claude update                # update to the latest release
```

### Essential Flags

```bash
claude -p "prompt"                             # print mode (non-interactive)
claude --model opus                            # alias (opus, sonnet, fable) or a full model ID
claude --output-format json                    # text | json | stream-json (print mode only)
claude --allowed-tools "Read,Grep,Bash(git *)" # pre-approve tools or permission rules
claude --disallowed-tools "WebFetch"           # deny tools for this session
claude --permission-mode plan                  # manual | acceptEdits | plan | auto | dontAsk | bypassPermissions
claude --max-budget-usd 2                      # spending cap (print mode only)
claude --continue                              # resume the most recent session in this directory
claude --resume                                # pick an earlier session
claude --add-dir ../shared-lib                 # grant tool access to another directory
claude --mcp-config ./mcp.json                 # load MCP servers from a file for this session
claude --append-system-prompt "..."            # add instructions at system-prompt level
claude --worktree feature-x                    # run the session in an isolated git worktree
claude --dangerously-skip-permissions          # bypass every prompt (isolated sandboxes only)
```

Older guides mention `--max-turns`, `--max-tokens`, and `--no-stream`. None of them exist in current releases. Cap cost with `--max-budget-usd`, cap subagent effort with the `maxTurns` frontmatter field, and use `--output-format json` when you do not want streaming output.

### Subcommands Worth Knowing

| Subcommand           | Purpose                                                |
| -------------------- | ------------------------------------------------------ |
| `claude mcp`         | Add, list, inspect, and remove MCP servers             |
| `claude doctor`      | Check the health of the installation                   |
| `claude update`      | Check for and install updates                          |
| `claude plugin`      | Manage plugins                                         |
| `claude agents`      | List background sessions started with `--bg`           |
| `claude import`      | Import configuration from another coding agent         |
| `claude setup-token` | Create a long-lived auth token (subscription accounts) |

---

## 2. CLAUDE.md and Memory

`CLAUDE.md` is loaded at the start of every session and is the most powerful way to give Claude Code persistent context. It is guidance, not enforcement: to guarantee an action never happens, use a permission rule or a `PreToolUse` hook instead.

### Where CLAUDE.md Files Live

| Scope          | Location                                                                                | Notes                                          |
| -------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Managed policy | `C:\Program Files\ClaudeCode\CLAUDE.md` (Windows), `/etc/claude-code/CLAUDE.md` (Linux) | Organization-wide; cannot be excluded          |
| User           | `~/.claude/CLAUDE.md`                                                                   | Every project on this machine                  |
| Project        | `./CLAUDE.md` or `./.claude/CLAUDE.md`                                                  | Shared with the team through version control   |
| Project local  | `./CLAUDE.local.md`                                                                     | Personal; add it to `.gitignore`               |
| Subdirectory   | `<subdir>/CLAUDE.md`                                                                    | Loaded on demand when Claude reads files there |

Files from the working directory and every directory above it are concatenated, root first, so the closest file is read last. Block-level HTML comments are stripped before injection, so use them for maintainer notes. Confirm what loaded with `/context` under **Memory files**, and generate a starting file with `/init`.

### Recommended Structure

```markdown
# Project Name

## Context
What this project is, technologies, architecture

## Essential Commands
Most-used scripts: npm run dev, pytest, etc.

## Code Conventions
Style, naming, mandatory patterns

## Architecture
Folder structure, responsibilities of each module

## Critical Business Rules
What NEVER to do, system invariants

## Available Agents and Skills
List of skills, when to use each one

## Pre-Task Protocol
Always run the orchestrator before responding
```

### Imports and Path-Scoped Rules

- Import other files with `@path/to/file`, resolved relative to the file that contains the import, up to four hops deep. Text inside backticks or code blocks is never treated as an import.
- Split large instruction sets into `.claude/rules/*.md`. A rule with `paths:` frontmatter loads only when Claude works with matching files.
- Personal rules for every project live in `~/.claude/rules/`.
- Target under 200 lines per `CLAUDE.md`; longer files reduce adherence. Move multi-step procedures into skills.

Example path-scoped rule at `.claude/rules/api.md`:

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API rules

- Every endpoint validates its input
- Use the standard error response format
```

### Auto Memory

Claude also keeps its own notes per repository at `~/.claude/projects/<project>/memory/`, where `<project>` is a name derived from the repository path (for example `x--my-project`), not a hash:

```text
~/.claude/projects/<project>/memory/
├── MEMORY.md          # index, one line per memory; first 200 lines or 25 KB load every session
├── ai-personas.md     # example topic file: active personas and skills
├── project-x.md       # example topic file: context for a specific project
└── decisions.md       # example topic file: important technical decisions
```

Topic files load on demand. Browse or toggle auto memory with `/memory`, disable it per project with `"autoMemoryEnabled": false`, or globally with `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`. Subagents do not inherit the main conversation's auto memory.

### Writing Instructions That Stick

- Make rules concrete enough to verify: "Run `npm test` before committing", not "test your changes"
- Add a **Pre-Task Protocol** section so Claude always runs the orchestrator first
- Add a **Known Errors** section with fixes for recurring problems
- Keep a **Memory** section as an index to detailed memory files
- Add concrete examples of expected output and absolute paths for critical scripts
- Remove contradictions across `CLAUDE.md`, nested files, and rules; Claude may pick either side arbitrarily
- After `/compact`, only the project-root `CLAUDE.md` is re-read automatically; nested files reload as Claude touches their directories

---

## 3. Hooks

Hooks run your own commands at fixed points in Claude Code's lifecycle. Unlike `CLAUDE.md`, they execute regardless of what Claude decides, which makes them the right tool for "must always happen" steps.

### Hook Locations

- User: `~/.claude/settings.json`
- Project, shared: `.claude/settings.json`
- Project, personal: `.claude/settings.local.json`
- Skills and subagents can also declare `hooks` in their frontmatter

### Common Hook Events

| Event                            | When It Fires                               | Can Block |
| -------------------------------- | ------------------------------------------- | --------- |
| `SessionStart`                   | A session begins or resumes                 | No        |
| `UserPromptSubmit`               | You submit a prompt, before Claude reads it | Yes       |
| `PreToolUse`                     | Before a tool call runs                     | Yes       |
| `PermissionRequest`              | A tool call needs a permission decision     | No        |
| `PostToolUse`                    | After a tool call succeeds                  | No        |
| `PostToolUseFailure`             | After a tool call fails                     | No        |
| `Notification`                   | Claude Code sends a notification            | No        |
| `SubagentStart` / `SubagentStop` | A subagent is spawned / finishes            | Stop only |
| `Stop`                           | Claude finishes responding                  | Yes       |
| `PreCompact` / `PostCompact`     | Before / after context compaction           | No        |
| `InstructionsLoaded`             | A `CLAUDE.md` or rules file is loaded       | No        |
| `SessionEnd`                     | The session terminates                      | No        |

All 33 events, including `Setup`, `PostToolBatch`, `TaskCompleted`, `ConfigChange`, `PreModelSwitch`, and `WorktreeCreate`, are listed in the [reference file](references/claude-code-reference.md#hook-events).

### Hook Entry Shape

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/guard.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

- `matcher`: a regex over tool names for tool events; omit it, or use `""`, to match everything
- `type`: `command` (shell), `http`, `mcp_tool`, `prompt`, or `agent`
- `timeout`: seconds before the hook is cancelled; default 600 for `command`
- `async: true`: run in the background without blocking
- `if`: a permission rule such as `"Bash(git push *)"` that further filters tool calls

### Exit Codes and Input

Command hooks receive the event as JSON on stdin. Useful fields: `hook_event_name`, `tool_name`, `tool_input` (for Bash, `tool_input.command`), `tool_use_id`, `cwd`, `session_id`, `permission_mode`, `transcript_path`.

| Exit Code | Meaning                                                                       |
| --------- | ----------------------------------------------------------------------------- |
| `0`       | Continue; stdout JSON, if any, is parsed for decisions and messages           |
| `2`       | Block the action on blockable events; stderr is shown to Claude as the reason |
| Other     | Non-blocking error; the action proceeds and the error is logged               |

A blocking hook beats an `allow` rule, but it never overrides a `deny` or `ask` rule.

### Example: Beep on Finish (Windows)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -c \"[Console]::Beep(800,300)\""
          }
        ]
      }
    ]
  }
}
```

The inner quotes are escaped as `\"`. A doubled backslash (`\\"`) is a JSON syntax error, and a settings file that fails validation is ignored.

### Example: Log Every Bash Command

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "jq -c '{tool: .tool_name, command: .tool_input.command}' >> ~/.claude/action_log.jsonl"
          }
        ]
      }
    ]
  }
}
```

### Example: Block Destructive Commands

Register the hook shown under [Hook Entry Shape](#hook-entry-shape) and create `.claude/hooks/guard.sh`:

```bash
#!/bin/bash
# PreToolUse guard. Exit 2 blocks the call; stderr becomes the reason Claude sees.
input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")

if [[ "$command" =~ (rm[[:space:]]+-rf|git[[:space:]]+push[[:space:]]+--force) ]]; then
  echo "Blocked by guard hook: $command" >&2
  exit 2
fi

exit 0
```

### Validate Hooks

```bash
jq . ~/.claude/settings.json          # fails loudly on invalid JSON
claude --debug hooks                  # trace hook execution for a session
```

In a session, `/hooks` lists the active configuration and `/doctor` reports settings problems.

---

## 4. MCP Servers

MCP (Model Context Protocol) adds external tools to Claude Code. Each server exposes tools that Claude can call during a session.

### MCP Commands

```bash
# Local stdio server: everything after -- is the server's own command line
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem C:/Projects

# Remote HTTP server
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# Environment variables and scope
claude mcp add my-server -s project -e API_KEY=xxx -- node ./mcp-server.js

claude mcp list                  # configured servers and their health
claude mcp get my-server         # details of one server
claude mcp remove my-server      # remove a server
claude mcp login my-server       # complete OAuth for an HTTP server
```

### Scopes

| Scope     | Flag         | Stored In                          | Use For                                             |
| --------- | ------------ | ---------------------------------- | --------------------------------------------------- |
| `local`   | default      | `~/.claude.json`, keyed by project | Personal servers and secrets                        |
| `project` | `-s project` | `.mcp.json` in the repository      | Team-shared servers; teammates approve on first use |
| `user`    | `-s user`    | `~/.claude.json`, every project    | Servers you want everywhere                         |

In a session, `/mcp` shows connection status, reconnects servers, and runs OAuth logins. `--mcp-config file.json` loads servers for one session; add `--strict-mcp-config` to ignore every other source.

### Useful MCP Servers

| Server                 | Main Function                                        |
| ---------------------- | ---------------------------------------------------- |
| filesystem             | File access beyond the working directory             |
| github                 | PRs, issues, commits, and reviews from inside Claude |
| postgres / sqlite      | Direct SQL queries without leaving Claude            |
| playwright / puppeteer | Browser automation and web scraping                  |
| slack                  | Notifications and channel messages                   |
| fetch                  | Direct HTTP requests to APIs                         |

### Custom MCP Server in Node.js

```javascript
// mcp-server.js
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "my-mcp", version: "1.0.0" });

server.registerTool(
  "my_tool",
  { description: "Echo the input back", inputSchema: { text: z.string() } },
  async ({ text }) => ({ content: [{ type: "text", text }] })
);

await server.connect(new StdioServerTransport());
```

```bash
claude mcp add my-mcp -- node /path/to/mcp-server.js
```

---

## 5. Subagents

Subagents run with their own context window and tool set. They run in the background by default, so several can work at once (up to 20, controlled by `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`). They do not see the conversation history or the main session's auto memory.

### Built-in Subagents

| Name              | Tools     | Use For                                            |
| ----------------- | --------- | -------------------------------------------------- |
| `Explore`         | Read-only | Fast codebase search and analysis                  |
| `Plan`            | Read-only | Research before presenting a plan                  |
| `general-purpose` | All       | Multi-step tasks that need exploration plus action |

There is no `Bash` subagent; run shell commands through `general-purpose` or a custom agent.

### Custom Subagents

Create `.claude/agents/<name>.md` (project) or `~/.claude/agents/<name>.md` (user):

```markdown
---
name: code-reviewer
description: Reviews diffs for bugs and security problems. Use after implementing a feature.
tools: Read, Grep, Glob, Bash
model: sonnet
maxTurns: 20
---

You are a senior reviewer. Report findings as file:line with severity and a fix.
```

Frontmatter fields include `tools`, `disallowedTools`, `model` (`sonnet`, `opus`, `haiku`, a full ID, or `inherit`), `permissionMode`, `maxTurns`, `skills`, `memory`, `isolation: worktree`, `background`, and `effort`; see the [reference file](references/claude-code-reference.md#subagent-frontmatter). Invoke one by name ("use the code-reviewer subagent to ..."), guarantee it with `@agent-code-reviewer`, or make it the whole session's agent with `claude --agent code-reviewer`. The `--agents '<json>'` flag defines agents for a single session.

### Orchestration Patterns

#### Parallel Fan-Out

Ask for independent tasks in one message so they run concurrently. For example, agent 1 analyzes the existing code, agent 2 researches documentation, and agent 3 writes test cases. Results come back as each finishes; then synthesize.

#### Isolated Experiments

Use `isolation: worktree` in the frontmatter, or `claude --worktree`, so risky refactors and proofs of concept happen on a separate branch with no risk to `main`.

#### Fork

`/fork` copies the current conversation into a new background session, useful for trying a different direction while keeping the original.

### Subagent Best Practices

1. Pass FULL context in the prompt; the subagent cannot see the history
2. Say exactly where outputs go, using absolute paths
3. Give research agents read-only tools; give implementation agents only the tools they need
4. Cap `maxTurns` so a confused agent cannot run indefinitely
5. Write the `description` as a delegation trigger ("Use after ...") so Claude picks the agent automatically

---

## 6. Permissions and Settings

### Settings Precedence

Highest first; a key set at a higher level overrides the same key lower down. Permission `deny` rules from any scope always win.

| Level          | File                                                   |
| -------------- | ------------------------------------------------------ |
| Managed        | `managed-settings.json`, MDM, or the claude.ai console |
| Command line   | `claude --settings <file-or-json>`                     |
| Project local  | `.claude/settings.local.json`                          |
| Project shared | `.claude/settings.json`                                |
| User           | `~/.claude/settings.json`                              |

### Permission Rule Syntax

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm run *)",
      "Edit(./src/**)",
      "WebFetch(domain:docs.python.org)"
    ],
    "ask": [
      "Bash(git push *)"
    ],
    "deny": [
      "Bash(rm *)",
      "Bash(curl *)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ],
    "defaultMode": "acceptEdits"
  }
}
```

- Rules are evaluated `deny`, then `ask`, then `allow`; the first match wins and specificity does not matter
- `*` matches any text and works anywhere in the pattern; `Bash(git *)` also matches bare `git`, and `Bash(git:*)` is an equivalent spelling of the trailing wildcard
- A bare tool name (`Bash`) or `Bash(*)` matches every command; as a deny rule it removes the tool from Claude's context entirely
- Claude Code understands shell operators, so `Bash(safe-cmd *)` does not approve `safe-cmd && other-cmd`
- Path rules are honored for `Read` and `Edit` only; a `Write(...)` or `Glob(...)` path rule is accepted but never checked
- Path prefixes: `//` absolute, `~/` home, `/` relative to the settings file's project, `./` or bare relative to the working directory
- Argument-constraining Bash patterns are fragile; deny `curl` and `wget` outright and allow `WebFetch(domain:...)` instead
- `/permissions` lists every rule with the file it came from

### Permission Modes

| Mode                | Behavior                                                                          |
| ------------------- | --------------------------------------------------------------------------------- |
| `default` (Manual)  | Prompts on first use of each tool                                                 |
| `acceptEdits`       | Auto-accepts file edits and common filesystem commands in the working directories |
| `plan`              | Reads and explores only; never edits source files                                 |
| `auto`              | Auto-approves with background safety checks against your request                  |
| `dontAsk`           | Auto-denies anything not pre-approved by rules                                    |
| `bypassPermissions` | Skips prompts except for actions no mode auto-approves                            |

Set the starting mode with `permissions.defaultMode` or `--permission-mode`, and cycle modes in a session with `Shift+Tab`.

### When to Use --dangerously-skip-permissions

Only in controlled CI/CD, automated scripts, and isolated sandboxes without internet access. Never in production, in repos with secrets, or in shared environments. Safer alternatives: `--permission-mode acceptEdits` or `auto` plus explicit `allow` rules, `--allow-dangerously-skip-permissions` (makes the bypass available without enabling it), and `--restricted` for read-mostly automation.

---

## 7. Skills and Custom Commands

Skills are folders with a `SKILL.md` that Claude loads only when relevant, so they cost nothing until used. Legacy `.claude/commands/*.md` slash commands were folded into skills; every skill is invocable as `/skill-name arguments`.

| Location                           | Scope                                   |
| ---------------------------------- | --------------------------------------- |
| `.claude/skills/<name>/SKILL.md`   | Project, shared through version control |
| `~/.claude/skills/<name>/SKILL.md` | Personal, every project                 |
| `<plugin>/skills/<name>/SKILL.md`  | Distributed with a plugin               |

Minimal skill:

```markdown
---
name: release-checklist
description: Runs the release checklist. Use when the user asks to cut, tag, or publish a release.
---

1. Run the full test suite
2. Bump the version and update CHANGELOG.md
3. Tag and push
```

- The `description` decides when the skill triggers: state WHAT it does and WHEN to use it, in third person
- Keep `SKILL.md` under 500 lines and move detail into `references/` files linked from it
- Add `disable-model-invocation: true` for skills only a human should trigger, such as deploys

---

## 8. Workflows

### Complete Feature Workflow

```bash
# Phase 1: plan in read-only mode
claude --permission-mode plan "Analyze feature X and write an implementation plan to docs/plans/feature-x.md"

# Phase 2: implement
claude "Implement feature X following docs/plans/feature-x.md"

# Phase 3: test
claude "Write tests for feature X and run them until they pass"

# Phase 4: review
claude "Review the diff for feature X, list problems, and fix them"
```

For long unattended runs, combine print mode with a budget and pre-approved rules:

```bash
claude -p "Complete the full development cycle for feature X" \
  --permission-mode acceptEdits \
  --allowed-tools "Read,Edit,Write,Grep,Glob,Bash(npm *),Bash(git *)" \
  --max-budget-usd 5 \
  --output-format json
```

### Headless and CI Usage

```yaml
# .github/workflows/claude-review.yml
name: Claude Code Review
on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: npm install -g @anthropic-ai/claude-code
      - name: Review the pull request diff
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          claude -p "Review the diff between origin/${{ github.base_ref }} and HEAD. List bugs and security problems." \
            --allowed-tools "Read,Grep,Glob,Bash(git diff *),Bash(git log *)" \
            --output-format json \
            --max-budget-usd 2
```

Print mode skips the workspace-trust dialog and silently ignores settings files that fail validation, so validate `settings.json` with `jq` before relying on it in CI. The maintained GitHub Action is documented at [Claude Code GitHub Actions](https://code.claude.com/docs/en/github-actions).

### Session Start Script

```bash
#!/bin/bash
echo "Loading project context..."
claude -p "Read memory/MEMORY.md and give me a complete briefing on the current state."
```

---

## 9. Troubleshooting

### Common Problems

| Problem                      | Likely Cause                                              | Fix                                                                                     |
| ---------------------------- | --------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| API key not found            | `ANTHROPIC_API_KEY` unset and not logged in               | `export ANTHROPIC_API_KEY=sk-ant-...` or `/login`                                       |
| `CLAUDE.md` ignored          | File not loaded, or instructions too vague                | Check `/context` under Memory files; make rules specific; use a hook for must-run steps |
| Context window full          | Too much in context                                       | `/compact`, `/clear`, delegate to subagents, or raise `--autocompact`                   |
| Subagent cannot find a file  | Relative path or missing context                          | Absolute paths and full context in the prompt                                           |
| Hook does not run            | Invalid JSON, wrong event name, or `disableAllHooks`      | `jq . settings.json`, `/hooks`, `claude --debug hooks`                                  |
| Hook runs but does not block | Exit code is not 2, or the event cannot block             | Exit 2 with the reason on stderr                                                        |
| MCP server not connected     | Server crashed, needs OAuth, or project server unapproved | `claude mcp get <name>`, then `/mcp` to reconnect or log in                             |
| Unexpected permission denial | A `deny` rule in a higher-precedence scope                | `/permissions` shows each rule and its source file                                      |
| Broken configuration         | Any customization                                         | `claude --safe-mode` to isolate, then `claude doctor`                                   |
| Unexpected compaction        | Very long session                                         | `/context`, `--autocompact`, and snapshot with the context-guardian skill               |

### Session Logs

```bash
ls ~/.claude/projects/                          # one folder per project, named from its path
ls ~/.claude/projects/<project>/                # session transcripts as JSON Lines
head -n 5 ~/.claude/projects/<project>/<id>.jsonl | jq .
```

Transcripts are JSON Lines, one object per line, so `python -m json.tool` on a whole file fails; process them line by line with `jq`.

---

## 10. Recommended settings.json

```json
{
  "model": "opus",
  "cleanupPeriodDays": 30,
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm *)",
      "Bash(python *)",
      "Bash(powershell *)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)"
    ],
    "defaultMode": "acceptEdits"
  },
  "env": {
    "BASH_DEFAULT_TIMEOUT_MS": "300000"
  },
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -c \"[Console]::Beep(800,200); Start-Sleep -Milliseconds 100; [Console]::Beep(1000,200)\""
          }
        ]
      }
    ]
  }
}
```

Other keys worth knowing: `effortLevel`, `attribution`, `autoMemoryEnabled`, `enabledPlugins`, `statusLine`, `outputStyle`, `sandbox`, `disableAllHooks`, `enableAllProjectMcpServers`, and `claudeMdExcludes`. `theme` and `verbose` are not settings keys in current releases: set the theme with `/config` and verbosity with `--verbose`.

---

## 11. Environment Variables

```bash
export ANTHROPIC_API_KEY=sk-ant-YOUR_KEY_HERE          # overrides subscription login when set
export ANTHROPIC_MODEL=opus                             # default model alias or full ID
export BASH_DEFAULT_TIMEOUT_MS=300000                   # default 120000 (2 minutes)
export BASH_MAX_OUTPUT_LENGTH=60000                     # default 30000, maximum 150000
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1       # presence-based: unset to re-enable
export DISABLE_TELEMETRY=1                              # presence-based: unset to re-enable
export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1                # turn auto memory off everywhere
export CLAUDE_CODE_SUBAGENT_MODEL=sonnet                # model for general-purpose subagents
export CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=10          # default 20
```

Presence-based variables treat any non-empty value, including `0`, as "on"; unset them to turn the behavior off. Prefer the `env` block in `settings.json` when a value should apply to every session of a project. `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, common in older guides, is absent from the current environment-variable reference; verify before relying on it.

---

## 12. Ecosystem Integration (Auri Skills)

1. The global `CLAUDE.md` lists every available skill and when to use each one
2. `agent-orchestrator` runs on every request to identify relevant skills
3. `task-intelligence` enriches moderate and complex tasks with a pre-task briefing
4. `context-agent` saves and restores state between sessions
5. `context-guardian` prevents context loss in long sessions; activate it at the start of long or critical sessions

### Ecosystem Memory Conventions

Load `memory/MEMORY.md` before any task and `memory/ai-personas.md` for active projects. At the end of long sessions, save state:

```bash
python context-agent/scripts/context_manager.py save
```

### Ecosystem Quick Commands

```bash
python agent-orchestrator/scripts/scan_registry.py          # update the registry
python agent-orchestrator/scripts/match_skills.py "task"    # identify skills
python task-intelligence/scripts/pre_task_check.py "task"   # briefing
python context-agent/scripts/context_manager.py save        # save context
python context-agent/scripts/context_manager.py load        # load context
```

---

## 13. Slash Commands and Shortcuts

| Command        | Action                                                |
| -------------- | ----------------------------------------------------- |
| `/help`        | Show all commands and shortcuts                       |
| `/init`        | Generate or improve the project `CLAUDE.md`           |
| `/memory`      | Edit `CLAUDE.md` files and manage auto memory         |
| `/context`     | Visualize context usage and list loaded memory files  |
| `/compact`     | Summarize the conversation to free context            |
| `/clear`       | Start a new conversation with empty context           |
| `/config`      | Open settings or set a key directly                   |
| `/permissions` | Manage allow, ask, and deny rules                     |
| `/hooks`       | View hook configuration                               |
| `/mcp`         | Manage MCP connections and OAuth                      |
| `/agents`      | Reminder on where subagent files live                 |
| `/model`       | Switch model and save it as the default               |
| `/effort`      | Set the effort level                                  |
| `/plan`        | Enter plan mode                                       |
| `/cost`        | Session token and USD usage (alias of `/usage`)       |
| `/doctor`      | Diagnose and fix setup issues                         |
| `/diff`        | Review working-tree changes, including Claude's edits |
| `/export`      | Export the conversation as text                       |
| `/resume`      | Pick an earlier session                               |

Keyboard shortcuts that save the most time:

| Shortcut    | Action                                                |
| ----------- | ----------------------------------------------------- |
| `Shift+Tab` | Cycle permission modes                                |
| `Esc`       | Interrupt the current response or tool call           |
| `Esc` twice | Clear the draft, or rewind when the input is empty    |
| `!` prefix  | Run a shell command and add its output to the session |
| `@`         | Mention a file path with autocomplete                 |
| `Ctrl+R`    | Search command history                                |
| `Ctrl+O`    | Toggle the transcript viewer                          |
| `?`         | Toggle the shortcut help panel                        |

---

## 14. Official References

- [Claude Code documentation](https://code.claude.com/docs/en/overview)
- [CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Hooks reference](https://code.claude.com/docs/en/hooks) and [hooks guide](https://code.claude.com/docs/en/hooks-guide)
- [Settings](https://code.claude.com/docs/en/settings) and [settings reference](https://code.claude.com/docs/en/settings-reference)
- [Permissions](https://code.claude.com/docs/en/permissions)
- [Memory and CLAUDE.md](https://code.claude.com/docs/en/memory)
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Skills](https://code.claude.com/docs/en/skills)
- [Slash commands](https://code.claude.com/docs/en/commands)
- [Environment variables](https://code.claude.com/docs/en/env-vars)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [Claude Code repository and changelog](https://github.com/anthropics/claude-code)

## Best Practices

- Verify syntax against `claude --help` and the reference file before recommending flags or settings keys
- Provide clear, specific context about your project and requirements
- Review all suggestions before applying them to production configuration
- Combine with other complementary skills for comprehensive analysis

## Common Pitfalls

- Using this skill for tasks outside its domain expertise
- Recommending flags from outdated guides (`--max-turns`, `--max-tokens`) without checking `claude --help`
- Writing `Write(...)` path rules and expecting them to be enforced
- Expecting `CLAUDE.md` to enforce behavior that only hooks or permission rules can guarantee
- Applying recommendations without understanding your specific context

## Related Skills

- `007` - Complementary skill for enhanced analysis
- `matematico-tao` - Complementary skill for enhanced analysis

## Limitations

- Use this skill only when the task clearly matches the scope described above.
- Do not treat the output as a substitute for environment-specific validation, testing, or expert review.
- Stop and ask for clarification if required inputs, permissions, safety boundaries, or success criteria are missing.
