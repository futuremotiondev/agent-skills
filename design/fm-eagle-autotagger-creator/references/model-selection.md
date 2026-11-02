# Model Selection

Which model to recommend with a preset, and how to settle it on the user's own images.
Prices change often: the table is a **snapshot from September 2026**. Re-check the linked pricing
pages before quoting numbers, and say which date the numbers come from.

## Principles

- **One model does everything.** AI Autotagger sends the image and every rule to a single
  multimodal model; there is no separate "language model" to choose.
- **General vision benchmarks no longer separate frontier models** (MMMU-Pro is saturated around
  81–83%). For tagging, what differs is:
  1. reading small text in large images (OCR rules, brand detection, UI labels),
  2. following many fields and closed vocabularies at once,
  3. cost across thousands of items.
- **Rule count sets the tier.** Small/cheap models handle about 8 rules with Specific lists well;
  presets with 15+ rules, open vocabularies, and long descriptions need a mid- or top-tier model.
- **The plugin doesn't use provider batch APIs**, so batch discounts don't apply.
- **Settle it with a test run, not a leaderboard** (below).

## Snapshot (September 2026, standard API prices per 1M tokens)

| Model                    | Input → Output | Fit                                                                                             |
| ------------------------ | -------------- | ----------------------------------------------------------------------------------------------- |
| Claude Sonnet 5          | $2 → $10       | Default for complex presets; strong instruction-following                                       |
| Gemini 3.8 Flash         | $0.75 → $3.75  | Value pick; strong OCR. Introductory price doubles from 2027-01-01                              |
| GPT-6 Sol                | $2 → $10       | Peer of Sonnet 5; include it in test runs                                                       |
| Gemini 3.1 Pro (preview) | $2 → $12       | Alternative top tier                                                                            |
| Claude Opus 5.5          | $4 → $20       | Rarely worth it for tagging                                                                     |
| GPT-6 Astra              | $10 → $50      | Overkill for tagging                                                                            |
| Claude Haiku 4.5         | $1 → $5        | Small presets (≤ 8 rules)                                                                       |
| Gemini 3.1 Flash-Lite    | $0.25 → $1.50  | Small presets, huge libraries                                                                   |
| GPT-6 Luna               | $0.10 → $0.50  | Small presets, huge libraries                                                                   |
| Ollama / LM Studio       | free (local)   | Only 3–6 rule presets; one request per rule, no Global Instructions                             |
| Claude Code / Codex CLI  | subscription   | No per-call cost; experimental, slower; one image per item (no slicing, first video frame only) |

Retired or outdated models that still appear in older advice or in the plugin's dropdown:
Claude 3.5 Sonnet (retired from the API), GPT-4o, Gemini 1.5.

Sources: [Claude pricing](https://platform.claude.com/docs/en/about-claude/pricing),
[Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing),
[OpenAI API pricing](https://developers.openai.com/api/docs/pricing).

## Estimating cost

Per item ≈ (prompt tokens + image tokens) × input price + output tokens × output price.

- Prompt tokens ≈ words in the rendered prompt × 1.4. Get the words with
  `python scripts/render_prompt.py preset.json --stats`.
- Image tokens: roughly 1,000–2,000 per screenshot-sized image at Original resolution, and more
  for tall images, which are sliced into several.
- Output tokens: about 1.4 × total words requested (descriptions dominate; OCR can double it).
  Thinking tokens bill as output when enabled.

Worked example, UI Design v2 (18 rules, OCR on): about 5k input and 1.3k output tokens per item,
so about $23 per 1,000 items on Sonnet 5 or GPT-6 Sol, and about $9 on Gemini 3.8 Flash.

## Test-run method

1. Pick 10–20 items that span the library's variety, including hard cases (tiny text, unusual
   styles, unbranded concepts).
2. Duplicate the preset once per candidate model, changing only the skip tag suffix (for example
   `… v2 (sonnet)`), or run each model on a copy of the items in a scratch library.
3. Compare in Eagle: wrong tags, missing obvious tags, empty-list discipline on Brand and
   Design System, Specific values chosen correctly, description accuracy, and cost-widget totals.
4. Pick the cheapest model with no systematic errors. Re-test when the preset changes a lot.

## Settings to recommend with a preset

- **Image Resolution: Original** for UI, text, icons, and fine detail. Low (512 px) only for
  simple photo presets.
- **Temperature 0–0.2** where the model accepts it, for consistent vocabularies. Reasoning models
  may ignore or reject temperature; leave it unset for them.
- **Thinking budget blank** (not `0`: zero enables thinking and the Anthropic API rejects it). Add a
  budget of 1,024 or more only if rules get skipped. Watch the cost widget, because some
  Flash-class models think by default.
- **Max Output Tokens 8,000–12,000** when using a custom model name; the plugin otherwise caps
  unknown Anthropic models at 4,096 output tokens.
- **Custom model name** for models newer than the plugin's dropdown (the v11 list stops at
  Claude 4.5, Gemini 3 preview, and GPT-5.2), then enter the model's prices under Settings → Pricing →
  Edit Token Prices so the cost widget stays accurate.
- **Maximum Processes** Medium (5) for cloud APIs, High (25) only on high usage tiers; 2–4 for CLI providers (each item is a
  separate process); 1 for local models.
- **CLI providers:** Extra CLI Args `--strict-mcp-config --disable-slash-commands
  --no-session-persistence`; never unknown flags or `--bare`
  (see [plugin-internals.md](plugin-internals.md#cli-providers)).
