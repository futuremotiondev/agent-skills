---
name: fm-<topic>-synthesis
description: Synthesises <input: e.g. "the file's comments", "a pasted interview transcript", "the sticky notes in the selected FigJam section"> into <output: e.g. "a ranked list of themes with evidence, open questions, and next steps"> as a chat report and, on request, a summary frame next to the source. Use whenever the user asks to "summarise the feedback", "what are the themes", "synthesise this research", "pull insights from", or wants a readout before a review. Not for critiquing the design itself (use /fm-<lens>-critique).
metadata:
  version: "1.0"
  author: "Futuremotion Studio"
  category: "<one of the six Community categories>"
  tags: "<comma-separated, lowercase>"
  applies-to: "<pattern and surface>"
  runtimes: "figma-design, figma-make, mcp"
---

# <Topic> synthesis

Turns raw qualitative input into a short, evidence-backed readout. Every theme cites the quotes or comments that support it, nothing is invented, and the output states its own confidence. Default output is chat; a canvas summary is built only when asked, as a new frame next to the source.

## When to use

- The user asks for themes, insights, a summary, or a readout from comments, transcripts, notes, or stickies.
- The user pastes research text and asks what it means.
- **Do not** critique the design under discussion; this skill reports what people said. For design critique use /fm-<lens>-critique.

## Before you start

1. **Identify the input.** One of: file comments, a selected FigJam section of stickies, pasted text, or a text layer. If several are present, ask, verbatim (through a structured question tool when the runtime has one; plain text otherwise):
   > Which input should I synthesise? 1. File comments, 2. the selected stickies or frames, 3. the text you pasted?
2. **Confirm the question.** Synthesis needs a question. If none was given, ask: "What decision will this readout inform?" and wait. Do not synthesise against an unstated goal.
3. **Check the volume.** Under <5> items: say the sample is too small for themes and return a plain list instead. Over <200> items: say so, sample the most recent <100>, and state the cut.

## Instructions

1. **Collect.** Read every item once. Keep the author or participant id, the timestamp if present, and the verbatim text. Skip resolved comments unless asked.
2. **Code.** Tag each item with one or two short codes (noun phrases). Do not pre-decide the codes; let them emerge from the text.
3. **Cluster.** Merge codes into at most <7> themes. A theme needs at least <3> items from at least <2> sources; otherwise it is an observation, not a theme.
4. **Rank.** Order themes by frequency, then by severity of the underlying problem for the stated decision.
5. **Evidence.** For each theme, pick the <2 to 3> most representative verbatims. Quote exactly; do not paraphrase inside quotation marks.
6. **Separate findings from recommendations.** Findings are what people said. Recommendations are what to do and are labelled as yours.
7. **Verify.** Re-count each theme's items against the source before reporting.

## Output contract

```markdown
## <Topic> synthesis
- Input: <source and count> · Sources: <n participants or authors>
- Question: <the decision this informs>
- Confidence: <high / medium / low and why>

## Themes (ranked)
### 1. <Theme name> — <n> items from <n> sources
- Finding: <one sentence>
- Evidence: "<verbatim>" (<author>), "<verbatim>" (<author>)
- Recommendation (mine): <one sentence>

## Observations (below theme threshold)
- <one line each>

## Open questions
- <what the data cannot answer>

## Next steps
- <2 to 4 actions>
```

If a canvas summary is requested: a frame named `Synthesis / <topic>` placed 80 px to the right of the source, one auto-layout column per theme, verbatims as separate text layers. Never edit or move the source stickies or comments.

## Do and do not

### Quote, do not paraphrase in quotes

- **Do:** Evidence: "I couldn't find where to change my plan" (P4)
- **Do not:** Evidence: "Users struggled with plan changes"

### Count before claiming

- **Do:** "Navigation confusion — 9 items from 6 participants"
- **Do not:** "Most users were confused by navigation"

### Label your opinion

- **Do:** "Recommendation (mine): move Plan into Account."
- **Do not:** "Users want Plan moved into Account."

## Examples

**Request:** "What are the themes in the comments on this file?"
**Result:** The question prompt if none was given, then the ranked report with counts and verbatims.

**Request:** "Synthesise these stickies and put it on the board" with a FigJam section selected.
**Result:** The chat report, then a `Synthesis / <topic>` frame beside the section; stickies untouched.

## Common edge cases

- **Too few items.** Return a plain list with a note; no themes.
- **Mixed languages.** Quote in the original language with a one-line translation after it.
- **Personal data in the input.** Do not reproduce names, emails, or identifiers beyond a participant code.
- **Make file.** Treat the project's feedback or issues text as the input; output in chat only.

## Final gate: do not finish until every line is true

- [ ] Every theme meets the item and source thresholds
- [ ] Every quote is verbatim and attributed
- [ ] Findings and recommendations are separated and labelled
- [ ] The source was not edited, moved, or resolved

<!-- target:figma-app -->
## In-app execution (Figma agent)

If a structured question tool such as `ask_user_question` is available, ask every numbered question through it with the same options; the plain-text wording is the fallback and the record of what was asked. Read comments with the comments capability if available; read stickies and text layers from the selection. If a script-execution tool such as `evaluate_script` is available, use it to collect sticky text (`node.text.characters` for stickies, `node.characters` for text) in batches of about 50 nodes and return plain arrays; build the optional summary frame in a separate call with `figma.createAutoLayout()`, loading fonts first.
<!-- /target -->

<!-- target:mcp -->
## MCP execution (Claude Code, Cursor, Codex)

Load the `figma-use` skill before any `use_figma` call; for FigJam use `get_figjam` to read the board and load `figma-use-figjam` before writing. Use `create_session`, collect text with `use_figma` (pass `skillNames: "fm-<topic>-synthesis"`), and build the optional summary frame in a second call.
<!-- /target -->
