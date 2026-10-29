---
description: Research and rank any AI coding agent skills for a topic, then emit a scored report and .xlsx catalog.
argument-hint: <topic> [--depth quick|standard|exhaustive] [--max N] [--min-score N] [--outputs report,xlsx,json,install] [--exclude <org>] [--include-unverified] [--agents claude-code,codex,cursor,...] [--require-native]
---

Use the `fm-universal-agent-skill-finder` skill to research any AI coding agent skills.

Raw arguments: `$ARGUMENTS`

Parse them as follows, then run the skill's workflow with the resolved values. Everything before
the first `--` flag is the topic; it may be multi-line and multi-part.

| Flag | Maps to | Default |
|---|---|---|
| *(leading text)* | `topic` | required — if absent, ask for one and stop |
| `--depth` | `depth` | `standard` |
| `--max` | `max_results` | `25` |
| `--min-score` | `min_score` | `50` |
| `--outputs` | `outputs` (comma-separated) | `report,xlsx` |
| `--exclude` | `exclude` (repeatable) | none |
| `--include-unverified` | `include_unverified` | `false` |
| `--as-of` | `as_of` | today |
| `--agents` | `agents` (comma-separated agent ids) | `all` |
| `--require-native` | `require_native` | `false` |

Unrecognized flags: warn in one line, ignore, continue. Do not stop the run over a typo'd flag.

Echo the resolved arguments in one line before starting, then follow the skill's workflow from step
2 onward — the topic is already supplied, so no clarification is needed unless the topic itself is
empty or meaningless.

## Examples

```
/find-agent-skills C# .NET desktop development — WPF, WinUI 3, and .NET 10 modern features

/find-agent-skills PostgreSQL performance tuning --agents claude-code,codex,cursor --depth exhaustive --max 40

/find-agent-skills Terraform --agents github-copilot,antigravity --require-native --depth quick --outputs report

/find-agent-skills React Server Components --min-score 65 --outputs report,xlsx,install
```
