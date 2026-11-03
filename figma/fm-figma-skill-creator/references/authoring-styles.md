# Authoring styles and Figma's house style

## The one lesson that matters most

Figma's help center shows two skills for the same fictional product, side by side. The generic one
lists adjectives ("Friendly, Encouraging, Clear"), abstract principles ("Keep it clear"), and
one-sentence product areas. The customized one declares response modes with output shapes, names
every rule, pairs each rule with **Do** and **Do not** example strings from the product, refuses to
invent ("say what is missing and ask for the relevant source of truth"), lists sensitive content to
escalate, and ends with a yes/no review checklist. Figma's verdict: "One giveaway of a skill that's
not quite right is when you find yourself editing the output more than if you'd done the work
yourself, or just ignoring the output entirely."

**Specific, named rules with concrete Do/Do-not examples beat adjectives.** Every template in this
skill reserves a block for them; never ship a skill without filling it.

Representative pair, verbatim from Figma's `cheddar-ux-writing-guide`:

```markdown
### Calm around money stress

Money can feel personal and stressful. Use neutral language for overspending, missed goals,
declined actions, security issues, and account connection problems.

**Do**
- You are $8 over your food budget
- Your account needs attention
- We could not refresh your transactions

**Do not**
- You failed your budget
- You blew past your limit
- Oops, your bank is having a moment
```

This toolchain writes the same pair as bullets with a bold lead under the named-rule heading,
`- **Do:** ...` and `- **Do not:** ...`, which keeps the content and passes markdownlint.

## Figma's recipe (developer docs, applies to both ecosystems)

1. `name`: short identifier, lowercase with hyphens, matches the folder.
2. `description`: what the skill does and when to use it. "Build a full-page screen using existing
   library components and variables" beats "Generate screens."
3. A `#` title naming the workflow.
4. `## When to use` with a few situations.
5. `## Instructions` with numbered direct instructions ("Search the library first", "Bind fills,
   strokes, and text to variables", "Prefer semantic tokens").
6. `## Examples` with at least one sample request and the expected result.
7. `## Common edge cases`: what to do when the ideal path fails.
8. Other frontmatter only for real requirements.

Best practices from the same page: "Write descriptions like routing rules... Say when to use it
and when not to." "Keep SKILL.md focused." "Make high-risk skills manual only." And the one safety
rule: "Test new skills on a duplicate or example file, not on a file you depend on."

Figma's official example also carries a boundary block worth copying verbatim: "**This skill
does:** ... **This skill does not:** ... If the user asks for something outside these boundaries,
say so and suggest what skill or approach would be appropriate."

## Idioms from Figma's own published skills

| Idiom | Verbatim source | Why it works |
| --- | --- | --- |
| Trigger phrases in the description, ending in a requirement | "Use whenever someone asks to 'present a frame', 'wrap a design in a background', 'make a mockup'... Always use this skill when the user wants to showcase a design frame with a generated backdrop." (`hifi-mockup-presenter`) | Auto-invocation routes on the description; requirement phrasing fires reliably |
| Scope gate to the selection, with a verbatim question when empty | "If nothing is selected, ask, verbatim: > Nothing's selected. **Audit the whole page**, or select the layers you want first?" (`image-audit`) | Prevents whole-file runs that burn credits and surprise the user |
| One question at a time, numbered options, hard stops | "Run this as a series of prompts. Ask one question, wait for the answer, act, then move on. Do not batch the questions and do not skip an action... Every prompt offers numbered options, and every prompt stops." (`make-a-type-scale`) | Deterministic interaction; no guessed inputs |
| Never pick silently | "Several TEXT nodes: Do not pick for them. List each by name and size, numbered, and ask which one. Stop." (`make-a-type-scale`) | "Picking the first or the largest silently is how the wrong font ends up in the whole scale" |
| Chat first, canvas on request | "Default: chat first, then canvas on request... After listing findings, ask in plain text: 'Want me to add any of these to canvas?'" (`figma-ux-writing-style`) | Reads are cheap and safe; writes are confirmed |
| Never touch the source | "The source frame is never moved, only cloned" (`hifi-mockup-presenter`); "Treat a review request as read-only... Never reparent, edit, lock, or restyle the frames under review" (`better-interface`) | One-step Undo cannot roll back a long run |
| Authorization contract for batch mutation | "By default, invoking update-components-v2 authorizes you to update deprecated instances... Complete the work in the same run: inspect, choose, capture, swap, restore, verify, report... Do not stop after recommending a clear replacement" (`update-components`) | Removes approval ping-pong for routine, reversible work while keeping inspection read-only unless asked |
| Completion response, fixed and short | "Report only: Target audit library, Audit roots, ... Confirmation that audited design layers were not changed" (`component-matchmaker`) | Output contract makes runs comparable |
| Final gate checked against the canvas | "A5 — Final gate: do not finish until every line is true", checked "against the canvas and the variables panel, not from memory" (`make-a-type-scale`) | Read-back beats assumption |
| Numeric rubrics, not adjectives | Allowed spacing "0, 4, 8, 12, 16, 24, 32, 40, 48, 56, 64, 80, 96" (`spacing-audit`) | The agent can check a number; it cannot check "harmonious" |
| Cap and reject | "Cap the output. At most 5–7 suggestions" plus a required "Rejected candidates" section (`find-animation-opportunities`) | Restraint is what separates a review from a wishlist |
| Confidence framing | "These are suggestions and not a replacement for real UX writing judgment... Don't make a user think you are capable of the gold standard." (`figma-ux-writing-style`) | Sets expectations; avoids overclaiming |

## Two styles, and when to use each

| Dimension | Script-driven wizard (Figma Community skills) | Capability-gated prose (Qredence catalogue, Figma Advocates contracts) |
| --- | --- | --- |
| Length (observed in the corpus, not a limit) | 560 to 9,160 words, median about 2,300 | 184 to 1,337 words, median 767 |
| Tool references | Names `evaluate_script`, `get_comments`, `show_widget`, shader tools | None; describes actions ("bind the color property to the matched variable") |
| Code | Plugin API JavaScript helpers, re-pasted per call | No code fences |
| Questions | Scripted verbatim prompts, one per message, hard stops | Only when a missing input blocks a safe route; at most two or three per round |
| Edit policy | Builds on canvas by default, never touches the source | Review by default; edit only when asked and supported |
| Determinism | High: computed geometry, measured fonts, verify passes | Lower: relies on the agent's own tools |
| Portability | In-app only; breaks wherever `evaluate_script` is missing | Same file runs in the Figma agent, Make, and coding agents |
| Breakage risk when Figma changes | High (undocumented tool contract) | Low, but capability gates need review as features ship |

**Script-driven** when the output is precise geometry or data that must come out the same every
run (specimen tables, audits with measured columns, motion rigs, token tables), the skill lives
in the Figma agent only, and you accept the maintenance risk.

**Capability-gated** for reviews, critiques, plans, specs, copy, and process skills; for anything
that must also run in Make or coding agents; and for anything touching a feature in flux
(prototyping, slots, FigJam, Slides). A capability gate reads: "Current Figma documentation marks
prototyping as coming soon. Do not claim that you created, wired, tested, or modified prototype
interactions unless the current session explicitly shows that capability. Default to plan-only
output."

**Neither** when the logic must run identically every time: build a generative plugin (Figma's own
split: "capture processes that benefit from context and judgment as skills, and build
deterministic plugins for workflows that should run the same way every time").

**Hybrid (the default for dual-target skills).** A tool-neutral core holds the trigger, scope
rule, ordered steps written as design actions, Do/Do-not rules, output contract, edge cases, and
final gate. Execution detail lives in two marked optional sections: an in-app section that
feature-detects `evaluate_script` or `show_widget` and keeps helper code short, and an MCP section
that loads `figma-use` and names `use_figma`. The build step keeps one section per target. The core
never depends on either section existing.

## Descriptions that route

Shape: third-person capability naming the output, then "Use whenever the user asks to '`<phrase>`',
'`<phrase>`'...", then "Not for `<nearest wrong task>` (use /`<other>`)". Put the key use case in the
first 250 characters (Claude Code truncates listings). Avoid restriction phrasing (`only when`,
`only if`, `unless`). Keep under 1,024 characters.

Good: "Audits the selected frames against an 8 pt spacing scale and lists every off-grid padding
or gap with the exact fix. Use whenever the user asks to 'check spacing', 'audit the grid', or
'find off-grid values', or selects frames and asks whether the spacing is consistent. Not for
restructuring layouts (use /fm-layout-reflow)."

Generic: "Helps with spacing and layout quality."

## Anti-patterns seen in the weakest published skills

- A one-word or one-line body.
- Pasted API reference with no workflow (2,659 words, zero users).
- A second frontmatter block, or a `name:` in the body that differs from the listing name.
- Boilerplate preambles (`## Purpose`, `## Operating Role`) that restate the description.
- Instructions that invoke other skills mid-run (only the first skill in a prompt runs).
- Adjective rubrics ("make it feel premium") instead of numbers and examples.
- Whole-file scope by default.
- Writing to the source frame instead of a duplicate or a new frame.
