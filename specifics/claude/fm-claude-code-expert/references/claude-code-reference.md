# Claude Code Reference

Exhaustive tables backing `SKILL.md`. Verified against Claude Code v2.1.261 (`claude --help`, `claude mcp add --help`) and the official documentation at code.claude.com on 2026-09-05. When a row here disagrees with the installed CLI, trust `claude --help`.

## Contents

- [CLI Flags](#cli-flags)
- [Subcommands](#subcommands)
- [Hook Events](#hook-events)
- [Hook Handler Fields](#hook-handler-fields)
- [Hook Input Fields](#hook-input-fields)
- [Subagent Frontmatter](#subagent-frontmatter)
- [Permission Rule Reference](#permission-rule-reference)
- [Settings Keys](#settings-keys)
- [Environment Variables](#environment-variables)
- [CLAUDE.md Locations](#claudemd-locations)

## CLI Flags

| Flag                                   | Purpose                                                                                         |
| -------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `-p`, `--print`                        | Print the response and exit; skips the workspace-trust dialog                                   |
| `--model <alias-or-id>`                | Model for the session: `opus`, `sonnet`, `fable`, or a full ID                                  |
| `--fallback-model <models>`            | Comma-separated fallbacks when the primary model is overloaded (print mode)                     |
| `--output-format <format>`             | `text`, `json`, or `stream-json` (print mode)                                                   |
| `--input-format <format>`              | `text` or `stream-json` (print mode)                                                            |
| `--json-schema <schema>`               | Validate structured output against a JSON Schema                                                |
| `--max-budget-usd <amount>`            | Maximum spend on API calls (print mode)                                                         |
| `--allowed-tools <tools...>`           | Tools or permission rules to allow, for example `"Bash(git *) Edit"`                            |
| `--disallowed-tools <tools...>`        | Tools or permission rules to deny                                                               |
| `--tools <tools...>`                   | Restrict the built-in tool set; `""` disables all, `default` restores all                       |
| `--permission-mode <mode>`             | `manual`, `acceptEdits`, `plan`, `auto`, `dontAsk`, or `bypassPermissions`                      |
| `--permission-prompts <target>`        | Who answers prompts in print mode: `host` or `none`                                             |
| `--dangerously-skip-permissions`       | Bypass all permission checks; sandboxes only                                                    |
| `--allow-dangerously-skip-permissions` | Make the bypass available without enabling it by default                                        |
| `--restricted`                         | Remove command-running tools and WebFetch, confine file tools, ignore user and project settings |
| `--safe-mode`                          | Disable every customization (CLAUDE.md, skills, plugins, hooks, MCP) for troubleshooting        |
| `--bare`                               | Minimal mode: no hooks, plugins, auto memory, or CLAUDE.md discovery                            |
| `-c`, `--continue`                     | Continue the most recent conversation in this directory                                         |
| `-r`, `--resume [id]`                  | Resume a session by ID or open the picker                                                       |
| `--fork-session`                       | Create a new session ID when resuming                                                           |
| `--session-id <uuid>`                  | Use a specific session ID                                                                       |
| `-n`, `--name <name>`                  | Display name for the session                                                                    |
| `--add-dir <dirs...>`                  | Additional directories the tools may access                                                     |
| `-w`, `--worktree [name]`              | Create a git worktree for the session                                                           |
| `--bg`, `--background`                 | Start in the background and print the session ID                                                |
| `--agent <name>`                       | Run the whole session as a named subagent                                                       |
| `--agents <json>`                      | Define custom agents for this session                                                           |
| `--mcp-config <configs...>`            | Load MCP servers from JSON files or strings                                                     |
| `--strict-mcp-config`                  | Use only the servers from `--mcp-config`                                                        |
| `--settings <file-or-json>`            | Load additional settings                                                                        |
| `--setting-sources <sources>`          | Comma-separated subset of `user`, `project`, `local`                                            |
| `--system-prompt <prompt>`             | Replace the default system prompt                                                               |
| `--append-system-prompt <prompt>`      | Append to the default system prompt                                                             |
| `--effort <level>`                     | `low`, `medium`, `high`, `xhigh`, or `max`                                                      |
| `--autocompact <auto\|tokens>`         | Auto-compact window: `auto` or 100k to 1M tokens                                                |
| `--verbose`                            | Override the verbose setting                                                                    |
| `-d`, `--debug [filter]`               | Debug output, optionally filtered, for example `hooks` or `api,hooks`                           |
| `--ide`                                | Connect to the IDE when exactly one is available                                                |
| `--chrome` / `--no-chrome`             | Enable or disable the Claude in Chrome integration                                              |
| `-v`, `--version`                      | Print the version                                                                               |

Flags that do not exist in current releases despite appearing in older guides: `--max-turns`, `--max-tokens`, `--no-stream`.

## Subcommands

| Subcommand                                                              | Purpose                                                                                                                               |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `claude mcp add [options] <name> <commandOrUrl> [args...]`              | Add a server; `--transport stdio\|sse\|http`, `-s local\|user\|project`, `-e KEY=value`, `-H header`; put `--` before a stdio command |
| `claude mcp add-json <name> <json>`                                     | Add a server from a JSON definition                                                                                                   |
| `claude mcp list` / `get <name>` / `remove <name>`                      | Inspect and manage servers                                                                                                            |
| `claude mcp login <name>` / `logout <name>`                             | Manage OAuth credentials for HTTP and SSE servers                                                                                     |
| `claude mcp reset-project-choices`                                      | Forget approvals and rejections of `.mcp.json` servers                                                                                |
| `claude mcp serve`                                                      | Run Claude Code itself as an MCP server                                                                                               |
| `claude doctor`                                                         | Check installation health                                                                                                             |
| `claude update`                                                         | Check for and install updates                                                                                                         |
| `claude install [target]`                                               | Install the native build (`stable`, `latest`, or a version)                                                                           |
| `claude plugin`                                                         | Manage plugins                                                                                                                        |
| `claude agents` / `attach <id>` / `logs <id>` / `stop <id>` / `rm <id>` | Manage background sessions started with `--bg`                                                                                        |
| `claude import [source]`                                                | Import configuration from another coding agent                                                                                        |
| `claude auth`                                                           | Manage authentication                                                                                                                 |
| `claude setup-token`                                                    | Create a long-lived auth token (subscription accounts)                                                                                |
| `claude ultrareview [target]`                                           | Cloud-hosted multi-agent review of the current branch or a PR                                                                         |

## Hook Events

| Event                 | When It Fires                                                         | Can Block |
| --------------------- | --------------------------------------------------------------------- | --------- |
| `SessionStart`        | A session begins or resumes                                           | No        |
| `Setup`               | One-time preparation with `--init`, `--init-only`, or `--maintenance` | No        |
| `UserPromptSubmit`    | You submit a prompt, before Claude processes it                       | Yes       |
| `UserPromptExpansion` | A typed command expands into a prompt                                 | Yes       |
| `PreToolUse`          | Before a tool call executes                                           | Yes       |
| `PermissionRequest`   | A tool call needs a permission decision                               | No        |
| `PermissionDenied`    | Auto mode denies a tool call                                          | No        |
| `PostToolUse`         | After a tool call succeeds                                            | No        |
| `PostToolUseFailure`  | After a tool call fails                                               | No        |
| `PostToolBatch`       | After a batch of parallel tool calls resolves                         | Yes       |
| `Notification`        | Claude Code sends a notification                                      | No        |
| `MessageDisplay`      | Assistant text is displayed                                           | No        |
| `SubagentStart`       | A subagent is spawned                                                 | No        |
| `SubagentStop`        | A subagent finishes                                                   | Yes       |
| `TaskCreated`         | A task is created via `TaskCreate`                                    | Yes       |
| `TaskCompleted`       | A task is marked completed                                            | Yes       |
| `Stop`                | Claude finishes responding                                            | Yes       |
| `StopFailure`         | The turn ends because of an API error                                 | No        |
| `TeammateIdle`        | An agent-team teammate is about to go idle                            | Yes       |
| `InstructionsLoaded`  | A `CLAUDE.md` or `.claude/rules/*.md` file is loaded                  | No        |
| `ConfigChange`        | A configuration file changes during the session                       | Yes       |
| `CwdChanged`          | The working directory changes                                         | No        |
| `DirectoryAdded`      | A working directory is added mid-session                              | No        |
| `FileChanged`         | A watched file changes on disk                                        | No        |
| `WorktreeCreate`      | A worktree is being created                                           | No        |
| `WorktreeRemove`      | A worktree is being removed                                           | No        |
| `PreCompact`          | Before context compaction                                             | No        |
| `PostCompact`         | After context compaction                                              | No        |
| `PreModelSwitch`      | Before a requested model switch                                       | Yes       |
| `PostModelSwitch`     | After the session's model changes                                     | No        |
| `Elicitation`         | An MCP server requests user input during a tool call                  | No        |
| `ElicitationResult`   | After the user answers an MCP elicitation                             | No        |
| `SessionEnd`          | The session terminates; hooks share a 1.5-second budget               | No        |

Exit code 2 blocks the action only on events marked Yes. On events that cannot block, output and stderr are ignored.

## Hook Handler Fields

| Field                              | Applies To        | Meaning                                                                                                      |
| ---------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------ |
| `type`                             | all               | `command`, `http`, `mcp_tool`, `prompt`, or `agent`                                                          |
| `command`                          | `command`         | Shell command to run; receives the event JSON on stdin                                                       |
| `args`                             | `command`         | Argument list; when present the command is spawned without a shell                                           |
| `shell`                            | `command`         | Shell used to run `command`                                                                                  |
| `if`                               | all               | Permission-rule filter, for example `"Bash(rm *)"`, applied before the hook runs                             |
| `timeout`                          | all               | Seconds before cancellation; defaults 600 for `command`, `http`, `mcp_tool`, 30 for `prompt`, 60 for `agent` |
| `async`                            | `command`         | Run in the background without blocking; `timeout` is not enforced                                            |
| `asyncRewake`                      | `command`         | Run in the background and wake Claude when the hook exits with code 2                                        |
| `once`                             | all               | Run only once per session                                                                                    |
| `statusMessage`                    | all               | Custom status text while the hook runs                                                                       |
| `url`, `headers`, `allowedEnvVars` | `http`            | POST the event JSON to a URL                                                                                 |
| `server`, `tool`, `input`          | `mcp_tool`        | Call an MCP tool; `input` may reference `${tool_input.file_path}`                                            |
| `prompt`, `model`                  | `prompt`, `agent` | Ask a model to evaluate; `$ARGUMENTS` carries the event                                                      |

Some events lower the default timeout: `UserPromptSubmit`, `PreModelSwitch`, and `PostModelSwitch` to 30 seconds, `MessageDisplay` to 10 seconds.

## Hook Input Fields

| Field                    | Present On       | Meaning                                                                              |
| ------------------------ | ---------------- | ------------------------------------------------------------------------------------ |
| `session_id`             | all              | Current session identifier                                                           |
| `prompt_id`              | most             | UUID of the user prompt                                                              |
| `transcript_path`        | all              | Path to the conversation transcript (`.jsonl`)                                       |
| `cwd`                    | all              | Current working directory                                                            |
| `permission_mode`        | all              | `default`, `plan`, `acceptEdits`, `auto`, `dontAsk`, or `bypassPermissions`          |
| `effort`                 | all              | Object with a `level` field                                                          |
| `hook_event_name`        | all              | Name of the event that fired                                                         |
| `agent_id`, `agent_type` | inside subagents | Subagent identifier and name                                                         |
| `tool_name`              | tool events      | Tool being called                                                                    |
| `tool_input`             | tool events      | Tool arguments; `tool_input.command` for Bash, `tool_input.file_path` for file tools |
| `tool_use_id`            | tool events      | Identifier for this tool use                                                         |

## Subagent Frontmatter

Files live in `.claude/agents/<name>.md` (project), `~/.claude/agents/<name>.md` (user), or a plugin's `agents/` directory. The `--agents` flag and managed settings can also define them.

| Field             | Meaning                                                                                |
| ----------------- | -------------------------------------------------------------------------------------- |
| `name`            | Unique identifier; lowercase letters and hyphens                                       |
| `description`     | When Claude should delegate to this subagent                                           |
| `tools`           | Allowed tools (allowlist)                                                              |
| `disallowedTools` | Denied tools (denylist)                                                                |
| `model`           | `sonnet`, `opus`, `haiku`, `fable`, a full ID, or `inherit`                            |
| `permissionMode`  | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, or `plan`            |
| `maxTurns`        | Maximum agentic turns before stopping                                                  |
| `skills`          | Skills preloaded into the subagent's context                                           |
| `mcpServers`      | MCP servers available to the subagent                                                  |
| `hooks`           | Lifecycle hooks scoped to the subagent                                                 |
| `memory`          | Persistent memory scope: `user`, `project`, or `local`                                 |
| `background`      | `true` keeps the subagent in the background                                            |
| `effort`          | `low`, `medium`, `high`, `xhigh`, or `max`                                             |
| `isolation`       | `worktree` runs the subagent in an isolated git worktree                               |
| `color`           | Display color: `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, or `cyan` |
| `initialPrompt`   | First turn submitted automatically when the agent runs as the main session             |

Built-in subagents: `Explore` (read-only search), `Plan` (read-only research for plan mode), and `general-purpose` (every tool). `general-purpose` uses `CLAUDE_CODE_SUBAGENT_MODEL` when set. Up to 20 subagents run concurrently by default (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`).

## Permission Rule Reference

Rules take the form `Tool` or `Tool(specifier)` and are evaluated `deny`, then `ask`, then `allow`; the first match wins.

### Bash Pattern Examples

| Rule                   | Matches                                            | Does Not Match                         |
| ---------------------- | -------------------------------------------------- | -------------------------------------- |
| `Bash(npm run build)`  | `npm run build`                                    | `npm run build --watch`                |
| `Bash(npm run *)`      | `npm run build`, `npm run test --watch`, `npm run` | `npm install`                          |
| `Bash(git log * main)` | `git log --oneline main`, `git log -5 main`        | `git log main`, `git push origin main` |
| `Bash(* --version)`    | `node --version`                                   | `node -v`                              |
| `Bash(ls *)`           | `ls -la`, `ls`                                     | `lsof`                                 |
| `Bash(ls*)`            | `ls -la`, `lsof`                                   |                                        |
| `Bash(*)` or `Bash`    | Every command                                      |                                        |

- The space before a trailing `*` is significant; `Bash(ls:*)` is an equivalent spelling of `Bash(ls *)`, and `:*` is recognized only at the end of a pattern
- Shell operators (`&&`, `||`, `;`, `|`, `&`, newline) split commands; deny and ask rules apply to every subcommand, including subshells
- Wrappers `timeout`, `time`, `nice`, `nohup`, `stdbuf`, bare `xargs`, and leading assignments of known-safe variables are stripped before matching
- Exec wrappers such as `watch`, `setsid`, `flock`, and `find -exec` always prompt in Manual mode
- Patterns that constrain arguments (`Bash(curl http://github.com/ *)`) are fragile; deny the tool and use `WebFetch(domain:...)` instead

### Other Tools

| Rule                                             | Meaning                                                               |
| ------------------------------------------------ | --------------------------------------------------------------------- |
| `Read(./.env)`, `Read(./secrets/**)`             | Gitignore-style path patterns; honored for `Read` and `Edit` only     |
| `Edit(/src/**/*.ts)`                             | Path relative to the settings file's project                          |
| `Read(//Users/alice/secrets/**)`                 | Absolute path                                                         |
| `Read(~/Documents/*.pdf)`                        | Path from the home directory                                          |
| `WebFetch(domain:example.com)`                   | Fetches to one domain; `domain:*.example.com` matches subdomains only |
| `Agent(model:opus)`, `Agent(isolation:worktree)` | Parameter rules, one parameter per rule                               |
| `mcp__server__tool`                              | An MCP tool; `mcp__server` matches every tool on that server          |

Output redirects (`> file`) are checked against `Edit` rules, protected paths, and the working directories. A `PreToolUse` hook that exits 2 blocks a call even when an allow rule matches, but hooks never override deny or ask rules.

### Permission Modes

| Mode                | Behavior                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------ |
| `default`           | Prompts on first use of each tool; labeled Manual in the UI, `manual` accepted as an alias |
| `acceptEdits`       | Accepts file edits and common filesystem commands in the working directories               |
| `plan`              | Reads and runs read-only commands only; never edits source files                           |
| `auto`              | Auto-approves with a classifier that checks actions against your request                   |
| `dontAsk`           | Auto-denies anything not pre-approved via `/permissions` or `permissions.allow`            |
| `bypassPermissions` | Skips prompts except for the actions no mode auto-approves                                 |

## Settings Keys

Precedence, highest first: managed settings, `claude --settings`, `.claude/settings.local.json`, `.claude/settings.json`, `~/.claude/settings.json`.

| Key                          | Meaning                                                                       |
| ---------------------------- | ----------------------------------------------------------------------------- |
| `permissions`                | `allow`, `ask`, `deny` rule arrays plus `defaultMode`                         |
| `hooks`                      | Lifecycle hooks, keyed by event name                                          |
| `env`                        | Environment variables for every session and subprocess                        |
| `model`                      | Model the session starts with                                                 |
| `effortLevel`                | Default effort level                                                          |
| `cleanupPeriodDays`          | Days transcripts are kept before deletion                                     |
| `attribution`                | Commit and PR attribution text; `includeCoAuthoredBy` is deprecated           |
| `autoMemoryEnabled`          | Turn auto memory on or off                                                    |
| `autoMemoryDirectory`        | Store auto memory somewhere other than `~/.claude/projects/<project>/memory/` |
| `claudeMdExcludes`           | Glob patterns for `CLAUDE.md` files to skip, matched against absolute paths   |
| `enabledPlugins`             | Turn individual plugins on or off                                             |
| `enableAllProjectMcpServers` | Approve every server in project `.mcp.json` files without a prompt            |
| `statusLine`                 | Command that renders a status line below the prompt                           |
| `outputStyle`                | Change Claude's role, tone, and output format                                 |
| `sandbox`                    | Isolate Bash commands from the filesystem and network (macOS, Linux, WSL2)    |
| `disableAllHooks`            | Turn off hooks, the custom status line, and the custom `@` suggestion command |
| `alwaysThinkingEnabled`      | Extended-thinking default for every session                                   |
| `agent`                      | Run every session as a named subagent                                         |

`theme` and `verbose` are not settings keys in current releases.

## Environment Variables

| Variable                                       | Meaning                                                            |
| ---------------------------------------------- | ------------------------------------------------------------------ |
| `ANTHROPIC_API_KEY`                            | API key; when set it is used instead of a subscription login       |
| `ANTHROPIC_MODEL`                              | Model setting to use                                               |
| `BASH_DEFAULT_TIMEOUT_MS`                      | Default timeout for Bash commands; default 120000                  |
| `BASH_MAX_TIMEOUT_MS`                          | Maximum timeout the model may request; default 600000              |
| `BASH_MAX_OUTPUT_LENGTH`                       | Characters of Bash output read back; default 30000, maximum 150000 |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`     | Presence-based; disables non-essential network traffic             |
| `DISABLE_TELEMETRY`                            | Presence-based; disables telemetry                                 |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY`              | `1` disables auto memory                                           |
| `CLAUDE_CODE_SUBAGENT_MODEL`                   | Model for `general-purpose` subagents                              |
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`         | Concurrent subagent cap; default 20                                |
| `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` | `1` also loads `CLAUDE.md` files from `--add-dir` directories      |
| `CLAUDE_CODE_SIMPLE`                           | Set to `1` by `--bare`                                             |
| `CLAUDE_CODE_SAFE_MODE`                        | Set to `1` by `--safe-mode`                                        |

Presence-based variables treat any non-empty value, including `0`, as enabled; unset the variable to disable the behavior.

## CLAUDE.md Locations

| Scope          | Location                                                                                                                                               | Loaded                                                     |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------- |
| Managed policy | macOS `/Library/Application Support/ClaudeCode/CLAUDE.md`; Linux and WSL `/etc/claude-code/CLAUDE.md`; Windows `C:\Program Files\ClaudeCode\CLAUDE.md` | Always; cannot be excluded                                 |
| User           | `~/.claude/CLAUDE.md`                                                                                                                                  | Every session                                              |
| Project        | `./CLAUDE.md` or `./.claude/CLAUDE.md`                                                                                                                 | Every session in the project and its subdirectories        |
| Project local  | `./CLAUDE.local.md`                                                                                                                                    | Alongside the project file; keep it out of version control |
| Subdirectory   | `<subdir>/CLAUDE.md`                                                                                                                                   | When Claude reads files in that subdirectory               |
| Rules          | `.claude/rules/*.md`, `~/.claude/rules/*.md`                                                                                                           | At launch, or on demand when a `paths:` pattern matches    |

Imports use `@path` syntax, resolve relative to the importing file, and nest up to four hops. A project-level import that resolves outside the working directory triggers a one-time approval dialog. Files above 4 MiB are skipped; target under 200 lines.
