# Concept cards

Workflow 0 fills this template to pitch five skill ideas to a user who arrived with a vague wish. The output is the deck header, five cards, and the footer question, in that order. Repeat the card block five times with n from 1 to 5. Replace every angle-bracket placeholder. The deck rules after the footer govern the output and are never part of it.

## Concept cards for: "<the user's grounding answer, quoted>"

- **Mapping:** <surfaces and patterns the answer mapped to, e.g. variables and components; audit and conventions>
- **Observed:** <up to five recon observations with counts, or "no file inspected">
- **From the catalog:** <cells read first; which cells were empty>

### <n>. /fm-<verb>-<object> — <five-word hook>

<!-- Identity -->

- **Does:** <description in the routing formula, ready for frontmatter; first sentence under 250 characters; passes the validator with no warnings>
- **Type:** <critique | audit | generator | conventions | synthesis | workflow> → `templates/type-<file>.md`
- **Category:** <Research and strategy | Generation | Brand | Design systems | Critique | Workflows>
- **Cell:** <pattern> × <surface> (surfaces: components, variables, type, colour, layout, content, accessibility, motion, handoff, documentation)
- **Tier:** <A build-ready on a proven pattern | B plausible | C waits on a probe result>

<!-- Behaviour -->

- **Reads:** <selection | page | variables and styles | comments | raster images (fills and image nodes: metadata; pixel access only if the probe confirms it) | vector nodes (properties only) | shader fills present in the file and their parameters (in-app shader-fill tools, MCP list_file_shaders and get_shader) | Make project code and assets>
- **Writes:** <none | after confirmation | always> — <what exactly, e.g. "padding and gap on confirmed rows only">
- **Produces:** <chat report | new frame beside the source | bindings | comment | generated raster image applied as a fill (in-app image creation, MCP generate_image) | an existing shader or generative plugin applied as a fill with set parameters (in-app, needs the shader's trigger words) | Make code change>
- **Needs:** <prerequisites: what must be selected, a connected library, a spacing or colour collection, a Make project, a connector; "nothing beyond a selection" when true>
- **Try it:** "<example prompt a designer would type>"
- **Sample output:** <one line of what the user would see, e.g. the first table row or the first sentence of the report>

<!-- Fit -->

- **Fits your moment:** <one sentence linking the card to the grounding answer, in the user's words>
- **Grounded in:** <recon observation "<count> <thing>" | catalog seed <name> | landscape gap <cell with a count of 0 or 1 in the catalog's gap grid> | the user's answer alone>
- **Landscape:** <new | better than <existing skill> because <one clause>>

<!-- Feasibility -->

- **Runs in:** <Figma agent in Design | Figma agent in Make | MCP agents | both> — <capability check: supported today / plan-only for <feature> / needs MCP for <tool>>
- **Risk:** <blast radius and its mitigation, e.g. "edits main components file-wide; disclosed before applying" | "read-only">
- **Cost:** about <n> credits per run (<how estimated: from the observed cost model, scaled by scope>)
- **Build effort:** <small | medium | large> — <why: lines of instruction, helper code, number of questions>
- **Pairs with:** <sibling skills it hands off to as "Not for X (use /y)", or "none">
- **Confirm before building:** <one or two questions Workflow A must ask first, e.g. "Which spacing scale?"; "none" when the card is fully determined>

Which one should I build first? 1 to 5, or tell me what to change.

## Deck rules

1. The deck holds five cards in five distinct cells (pattern × surface).
2. At least two cards come from cells matched by the Mapping line, and at least one comes from an empty cell, a cell with a count of 0 in the gap grid of `references/skill-idea-catalog.md`.
3. Unsupported ideas are reshaped into plan-only form or dropped. At most one card is plan-only, and it is never card 1.
4. Card 5 is the wildcard and says so in its hook.
5. Vectors, slots, prototype wiring, exports, and diagrams are plan-only in-app. Authoring shader code is MCP-only and routes to /fm-figma-shader-creation.
6. A card never claims an unsupported capability as its core.
7. Every name, the part after the slash in the card heading, passes `^fm-[a-z0-9]+(-[a-z0-9]+)*$`.
8. Every Does line passes `node scripts/validate-figma-skill.mjs --description "<text>"` with no warnings. Run it on each line before showing the deck. The usual warning is `description-lead`, a first sentence over 250 characters: end the capability sentence sooner and move the detail into the next one.
9. Every card has exactly the twenty labelled lines above, in that order and grouping. A line that does not apply says "none"; it never disappears.
10. The Writes line starts with exactly one of none, after confirmation, or always.
11. The Landscape line starts with "new" or "better than", and X in "better than X" is a row of `references/skill-landscape.md`.
12. The Grounded in line names a recon observation, a catalog seed, a landscape gap, or the user's answer. A landscape gap is a cell with a count of 0 or 1 in the gap grid of `references/skill-idea-catalog.md`; a cell with more rows is not a gap, so ground that card in a seed, an observation, or the answer.
13. The four grouping comments (Identity, Behaviour, Fit, Feasibility) are reading aids for this template only. Omit them from the output; keep the blank lines between groups.
14. The deck ends with the footer question as plain text, with no Markdown, and nothing after it.
