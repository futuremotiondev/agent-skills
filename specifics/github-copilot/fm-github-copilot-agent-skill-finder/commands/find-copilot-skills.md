---
description: Research and rank GitHub Copilot customizations for a topic, then emit a scored report and .xlsx catalog.
argument-hint: <topic> [--depth quick|standard|exhaustive] [--max N] [--min-score N] [--outputs report,xlsx,json,install] [--exclude <org>] [--include-unverified] [--types skill,agent,instructions,prompt,hook,plugin] [--surface cloud-agent|cli|vscode|code-review|all]
---

Use the `fm-github-copilot-agent-skill-finder` skill to research GitHub Copilot customizations.

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
| `--types` | `types` (comma-separated) | `all` |
| `--surface` | `surface` | `all` |

Unrecognized flags: warn in one line, ignore, continue. Do not stop the run over a typo'd flag.

Echo the resolved arguments in one line before starting, then follow the skill's workflow from step
2 onward — the topic is already supplied, so no clarification is needed unless the topic itself is
empty or meaningless.

## Examples

```
/find-copilot-skills C# .NET desktop development — WPF, WinUI 3, and .NET 10 modern features

/find-copilot-skills Azure Functions and Bicep deployment --types skill,agent --depth exhaustive --max 40

/find-copilot-skills Playwright end-to-end testing --surface cloud-agent --depth quick --outputs report

/find-copilot-skills Code review conventions for Go --types instructions,skill --min-score 65 --outputs report,xlsx,install
```
