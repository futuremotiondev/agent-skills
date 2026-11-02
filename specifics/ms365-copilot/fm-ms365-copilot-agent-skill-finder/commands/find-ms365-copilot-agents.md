---
description: Research and rank Microsoft 365 Copilot extensions for a topic, then emit a scored report and .xlsx catalog.
argument-hint: <topic> [--depth quick|standard|exhaustive] [--max N] [--min-score N] [--outputs report,xlsx,json,install] [--exclude <org>] [--include-unverified] [--types agent,plugin,skill,connector,studio,cea] [--source-form code|store|both]
---

Use the `fm-ms365-copilot-agent-skill-finder` skill to research Microsoft 365 Copilot extensions.

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
| `--source-form` | `source_form` | `both` |

Unrecognized flags: warn in one line, ignore, continue. Do not stop the run over a typo'd flag.

Echo the resolved arguments in one line before starting, then follow the skill's workflow from step
2 onward — the topic is already supplied, so no clarification is needed unless the topic itself is
empty or meaningless.

## Examples

```
/find-ms365-copilot-agents HR onboarding and policy Q&A over SharePoint

/find-ms365-copilot-agents ServiceNow and Jira ticket triage --types agent,plugin,connector --depth exhaustive --max 40

/find-ms365-copilot-agents Sales pipeline summaries from Dynamics 365 --source-form store --depth quick --outputs report

/find-ms365-copilot-agents Contract analysis skills --types skill --min-score 60 --min-score 65 --outputs report,xlsx,install
```
