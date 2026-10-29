---
description: Research and rank Figma skills for a topic, then emit a scored report and .xlsx catalog.
argument-hint: <topic> [--depth quick|standard|exhaustive] [--max N] [--min-score N] [--outputs report,xlsx,json,install] [--exclude <org>] [--include-unverified] [--surface community|mcp|both] [--agents claude-code,cursor,...] [--products figjam,slides,...]
---

Use the `fm-figma-design-skill-finder` skill to research Figma skills.

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
| `--surface` | `surface` | `both` |
| `--agents` | `agents` (comma-separated) | `all` |
| `--products` | `products` (comma-separated) | `all` |

Unrecognized flags: warn in one line, ignore, continue. Do not stop the run over a typo'd flag.

Echo the resolved arguments in one line before starting, then follow the skill's workflow from step
2 onward — the topic is already supplied, so no clarification is needed unless the topic itself is
empty or meaningless.

## Examples

```
/find-figma-skills design tokens and variables sync between Figma and code

/find-figma-skills FigJam diagrams, workshop boards, and project plans --surface mcp --agents claude-code,cursor --depth exhaustive --max 40

/find-figma-skills accessibility and design-system compliance audits --surface community --depth quick --outputs report

/find-figma-skills Code Connect and design-to-code for React --products code-connect,dev-mode --min-score 65 --outputs report,xlsx,install
```
