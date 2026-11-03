# Skill idea catalog

A curated, gated list of concept seeds for new Figma-agent skills. The gap grid is computed from `skill-landscape.md`; seeds sit in the cells they fill, and every seed has passed the admission rules below. Workflow 0 reads this file to turn a vague wish into concept cards. Credit estimates use the observed model until a fuller cost reference exists: about 10 credits to ask a question, 22 to 24 credits per page-scale audit, and about 18 credits per five fixes.

## Gaps

Counts of landscape rows per pattern and surface, computed from the `Pattern` and `Surface` columns of `skill-landscape.md` (100 rows, 2026-11-03).

| Pattern | components | variables | type | colour | layout | content | accessibility | motion | handoff | documentation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| audit | 6 | 1 | 0 | 2 | 6 | 2 | 1 | 2 | 3 | 0 |
| generator | 2 | 1 | 2 | 1 | 5 | 1 | 0 | 2 | 3 | 4 |
| critique | 0 | 0 | 0 | 0 | 6 | 2 | 0 | 1 | 0 | 1 |
| synthesis | 0 | 0 | 0 | 0 | 0 | 8 | 0 | 0 | 1 | 4 |
| workflow | 2 | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 4 | 7 |
| conventions | 1 | 3 | 0 | 2 | 1 | 2 | 1 | 3 | 3 | 0 |

Every cell with a count of 0 or 1, and why it is that thin:

- **audit × variables (1):** nobody has tried an in-file variable audit; the one row compares variables with code, and in-file binding work sits under conventions and workflow.
- **audit × type (0):** nobody has tried; text-style usage is checked in passing by broad critiques and never on its own.
- **audit × accessibility (1):** covered mostly by critique-pattern reviews that fold accessibility into a wider rubric, so one dedicated audit is all that exists.
- **audit × documentation (0):** nobody has tried; documentation is always generated and never checked for coverage.
- **generator × variables (1):** nobody beyond one starter-system generator has tried; variables are bound or repaired (conventions), not derived from usage.
- **generator × colour (1):** covered by conventions-pattern skills that bind existing colours; the one generator builds shaders, not palettes.
- **generator × content (1):** covered by stress tests and inventories under other patterns; one copy drafter exists.
- **generator × accessibility (0):** nobody has tried; accessibility output is always a report in chat, never an artefact on the canvas.
- **critique × components (0):** covered by the audit pattern, which checks component sets against rules rather than judging how usable their property API is.
- **critique × variables (0):** covered by audit and conventions; variable data is structured enough to check, so judgement adds little.
- **critique × type (0):** covered inside the rubrics of broad critiques; nobody has written a type-only crit.
- **critique × colour (0):** covered inside the rubrics of broad critiques; nobody has written a colour-only crit.
- **critique × accessibility (0):** covered by the audit pattern, because WCAG criteria are checkable rules rather than matters of judgement.
- **critique × motion (1):** one read-only opportunity finder exists; motion review otherwise sits under audit.
- **critique × handoff (0):** nobody has tried; handoff is treated as a preparation workflow, never as something to review from the engineer's side.
- **critique × documentation (1):** one competitor teardown exists; documents are generated far more often than critiqued.
- **synthesis × components (0):** nobody has tried; component usage is audited for defects, never summarized for recurring patterns.
- **synthesis × variables (0):** covered by audit and conventions; variable data is already structured, so there is little raw material to synthesize.
- **synthesis × type (0):** covered by audit; type data is numeric and small, so it is measured rather than synthesized.
- **synthesis × colour (0):** covered by audit and conventions; colour use is mapped to tokens rather than summarized.
- **synthesis × layout (0):** nobody has tried; layout is critiqued screen by screen and never summarized across a flow.
- **synthesis × accessibility (0):** covered by audit; accessibility findings are pass or fail and need no theming.
- **synthesis × motion (0):** nobody has tried, and the motion API is in-app only and unprobed over MCP, which keeps it out of dual-target skills.
- **synthesis × handoff (1):** one handoff summary exists; a second would duplicate it.
- **workflow × type (0):** nobody has tried a staged font migration; type changes are one-shot generators or conventions.
- **workflow × colour (0):** nobody has tried; the only theming process fits one fixed variable model.
- **workflow × layout (0):** covered by generators and critiques that edit in place; each layout edit is small enough that nobody stages it.
- **workflow × content (0):** nobody has tried; a copy review needs comment round trips, and comments can be read in-app but not over MCP.
- **workflow × accessibility (0):** nobody has tried; every accessibility skill stops at the report.
- **conventions × components (1):** covered by audit-pattern component skills; one naming enforcer applies a standard.
- **conventions × type (0):** nobody has tried; type rules are encoded as scales (generator) rather than applied as conventions.
- **conventions × layout (1):** covered by audit-pattern spacing skills; one container normaliser applies conventions.
- **conventions × accessibility (1):** covered by audits; the one guideline skill is known by name only.
- **conventions × documentation (0):** nobody has tried; file and page conventions live in team wikis, not in skills.

## Admission rules

A seed is admitted only if it (1) names a concrete output, (2) has a description that passes `validate-figma-skill.mjs --description` with no warnings, (3) is feasible today in-app or over MCP, with plan-only parts labelled, (4) differs from every landscape row in a stated way, (5) carries a credit estimate. Each cell holds at most three seeds, ranked; a new seed enters by displacing a weaker one, and the displaced seed is deleted, not archived. Tiers: A build-ready on a proven pattern, B plausible, C waits on a probe result.

## Concept seeds

Each seed is a bullet block with fixed lowercase keys: `tier`, `description`, `tags`, `fits when`, `feasibility`, `credits`, `differs from`. Feasibility is judged against `agent-capabilities-and-tools.md`: its capability table, its reconstructed script rules, and the MCP probe baseline of 2026-11-03. Seeds are ranked within a cell, strongest first.

### audit × variables

- **fm-variable-mode-gap-audit**
  - tier: B
  - description: Audits local variable collections for values missing in a mode, aliases that point at deleted variables, and values identical across every mode, and lists each variable with the mode and a suggested value. Use whenever the user asks to check variable modes, find broken aliases, audit dark mode values, or clean up a variable collection. Not for comparing variables with code tokens (use design-tokens-sync).
  - tags: variables; audit; drift, consistency, review
  - fits when: A team adds a second mode to an existing collection and needs to know which variables were never given a value in it.
  - feasibility: supported. Using variables is Supported in the capability table, and the MCP probe returned available for getLocalVariablesAsync, getLocalVariableCollectionsAsync, and getVariableByIdAsync. The probe ran on a file with no variables, so real collections, modes, and alias chains were not exercised; the first live run confirms how a broken alias reads.
  - credits: 22 to 24 credits per collection pass [page-scale audit]; about 18 credits per five values set after confirmation [five-fix model]
  - differs from: design-tokens-sync, which compares Figma variables with code tokens; this checks the collections against themselves and needs no codebase.

### audit × type

- **fm-type-style-drift-audit**
  - tier: A
  - description: Audits the selected frames for text layers that carry no text style or drift from their style's size, weight, or line height, and lists each with the nearest local or library style; it applies a style after the user confirms. Use whenever the user asks to check typography, find unstyled text, audit text styles, or clean up type before handoff. Not for building a new type scale (use make-a-type-scale) or rewriting copy.
  - tags: type; audit; drift, consistency, handoff
  - fits when: A designer is about to hand off a screen and suspects some text was styled by hand instead of with the library's text styles.
  - feasibility: supported. Using styles is Supported in the capability table; the MCP probe returned available for getLocalTextStylesAsync and, by presence, setTextStyleIdAsync. Fonts are loaded before any text edit, per the script rules.
  - credits: 22 to 24 credits per page [page-scale audit]; about 18 credits per five styles applied [five-fix model]
  - differs from: make-a-type-scale, which generates a new scale; this measures existing text against the styles already in the file and repeats the proven fm-spacing-rhythm-audit shape on a different surface.

### audit × accessibility

- **fm-target-size-audit**
  - tier: A
  - description: Measures the controls in the selected frames, found by component and layer name, against the 24 by 24 px WCAG 2.2 AA target minimum and an optional 44 px goal, and lists each failure with its size and the padding that fixes it. Use whenever the user asks to check tap targets, touch targets, hit areas, or button sizes for accessibility. Not for colour contrast or a full accessibility review (use accessibility-audit).
  - tags: accessibility; audit; accessibility, handoff, review
  - fits when: A mobile flow is close to done and someone asks whether its buttons and links are big enough to tap.
  - feasibility: supported. Prototype reactions are not readable by the agent, so interactive instances are found by component and layer name (button, link, toggle, and similar) and the list is shown for confirmation before measuring. Reading sizes and editing auto-layout padding are Supported (edit layout); measurements are taken in a later call than any build, per the script rules.
  - credits: 22 to 24 credits per page [page-scale audit]; about 18 credits per five padding fixes [five-fix model]
  - differs from: accessibility-audit, which checks five WCAG areas at summary level; this measures each confirmed control with a number and offers the exact padding change.

### audit × documentation

- **fm-component-docs-coverage-audit**
  - tier: B
  - description: Audits the components used in the selected frames for a missing description, a missing documentation link, or an undocumented property, and lists each main component with the gap and a drafted description. Use whenever the user asks to check component documentation, find undocumented components, or prepare a library for publishing. Not for building documentation frames (use component-handoff) or reviewing library structure.
  - tags: components, documentation; audit; onboarding, handoff, review
  - fits when: A library team is about to publish and wants every component a product screen uses to carry a description a newcomer can read.
  - feasibility: plan-only for writing descriptions to remote library components, which the open file cannot edit; local components take the description directly, since authoring components is Supported. Reading main components is standard Plugin API; the MCP probe could not exercise getMainComponentAsync on its empty page, so the first live run confirms it.
  - credits: 22 to 24 credits per page [page-scale audit]; about 10 credits per drafted description the user asks about [ask]
  - differs from: library-health-report, which reviews a whole library's documentation health; this starts from the instances on a real screen and drafts the missing text.

### audit × layout

- **fm-alignment-drift-audit**
  - tier: A
  - description: Audits absolutely positioned sibling layers in the selected frames for edges and centres that sit 1 to 3 px off a shared alignment line, and lists each with the offset and the line it should snap to; it moves layers after the user confirms. Use whenever the user asks to check alignment, find misaligned elements, or clean up nudged layers. Not for spacing values inside auto layout (use fm-spacing-rhythm-audit).
  - tags: layout; audit; consistency, drift, review
  - fits when: A marketing page built without auto layout looks slightly off and nobody can say which layers were nudged.
  - feasibility: supported. Alignment edits are Supported (edit layout); auto-layout children are skipped because their position is set by the frame.
  - credits: 22 to 24 credits per page [page-scale audit]; about 18 credits per five moves [five-fix model]
  - differs from: spacing-audit and fm-spacing-rhythm-audit, which check padding and gap values; this checks position against shared edges, which neither reads.

### generator × variables

- **fm-spacing-variables-from-usage**
  - tier: B
  - description: Derives a spacing scale from the padding and gap values actually used in the selected frames, ranks them by frequency, and creates number variables in a collection the user names after confirmation. Use whenever the user asks to create spacing tokens, turn spacing into variables, or build a spacing scale from an existing design. Not for snapping off-grid values (use fm-spacing-rhythm-audit).
  - tags: variables, layout; generator; consistency, drift, onboarding
  - fits when: A team with a mature file but no spacing variables wants tokens that match what it already ships.
  - feasibility: supported. Authoring variables is Supported in the capability table, and the MCP probe returned available for the variable collection reads.
  - credits: 22 to 24 credits to collect the values [page-scale audit]; about 10 credits to confirm the scale [ask]; about 18 credits per five variables created [five-fix model]
  - differs from: design-system-gen, which builds a starter system from a style guide; this derives the scale from values already in use and ranks them by frequency.

### generator × content

- **fm-placeholder-copy-replacer**
  - tier: B
  - description: Replaces lorem ipsum and placeholder strings in a duplicate of the selected frames with realistic copy matched to each layer's role and length, and lists every replacement. Use whenever the user asks to remove lorem ipsum, fill in realistic content, replace placeholder text, or make a mockup feel real. Not for drafting final product copy (use microcopy-generator) or stress-testing extremes (use content-stress-test).
  - tags: content; generator; review, consistency
  - fits when: A designer is about to show a mockup to stakeholders and it is still full of lorem ipsum.
  - feasibility: supported. Bulk content edits are Supported; work happens on a duplicate, and fonts are loaded before each text edit.
  - credits: 22 to 24 credits to collect the strings [page-scale audit]; about 18 credits per five frames filled [five-fix model]
  - differs from: microcopy-generator, which drafts UI strings in chat for one screen; this finds placeholder text across the selection and writes realistic fill into a duplicate.

### generator × accessibility

- **fm-focus-order-annotator**
  - tier: B
  - description: Generates a numbered focus-order overlay beside a copy of the selected screen, derived from layer order and position, and flags every step where the tab order jumps against reading order. Use whenever the user asks to annotate focus order, show tab order, plan keyboard navigation, or prepare accessibility notes for developers. Not for contrast or target-size checks (use fm-target-size-audit).
  - tags: accessibility, handoff; generator; accessibility, handoff
  - fits when: A web screen is going to engineering and nobody has written down the keyboard order.
  - feasibility: supported. Creating frames and reading layer order are Supported; the overlay is built beside a duplicate, never on the source.
  - credits: 22 to 24 credits per screen [page-scale audit]; about 18 credits to build the overlay [five-fix model, counted as five placements]
  - differs from: accessibility-audit, which reports focus order implied by layers as a finding; this draws the order on the canvas as a handoff artefact.

### critique × components

- **fm-component-api-critique**
  - tier: B
  - description: Critiques a selected component set's property API, flagging variant explosions that should be boolean or instance-swap properties, unclear property names, and combinations no screen uses, each with a ranked recommendation. Use whenever the user asks to review a component's properties, simplify variants, or critique a component API before publishing. Not for structural consistency checks (use component-audit).
  - tags: components; critique; naming, review, consistency
  - fits when: A component set has grown to dozens of variants and the team wants to know which axes should become properties before others build on it.
  - feasibility: supported. Reading component property definitions is standard Plugin API, and editing main components is Supported (author design-system components); the critique itself changes nothing.
  - credits: 22 to 24 credits per component set [page-scale audit, read-only]
  - differs from: component-audit, which checks a set against structural rules; this judges how easy the property API is to use and recommends a smaller one.

### critique × type

- **fm-type-hierarchy-critique**
  - tier: B
  - description: Critiques the type hierarchy of the selected screen by counting distinct sizes, weights, and colours per level, measuring the ratio between levels, and ranking where reading order breaks, each with a specific fix. Use whenever the user asks to review typography, check the type hierarchy, or asks why a screen feels hard to scan. Not for checking style bindings (use fm-type-style-drift-audit).
  - tags: type; critique; review, consistency
  - fits when: A screen feels busy and the designer wants to know whether too many type levels are competing.
  - feasibility: supported. It reads text properties and changes nothing; a chat report needs no tool beyond reading the canvas.
  - credits: 22 to 24 credits per screen [page-scale audit, read-only]
  - differs from: superfuture-design-review, which covers type as one of ten rubric areas; this goes deep on type alone and backs every finding with counts and ratios.

### critique × colour

- **fm-colour-meaning-critique**
  - tier: B
  - description: Critiques how colour carries meaning in the selected screen, counting distinct fills, measuring accent coverage, and flagging status colours used decoratively, each finding ranked with a fix and its contrast ratio. Use whenever the user asks to review the colour, critique the palette use, or asks whether a screen uses too many colours. Not for mapping colours to variables (use apply-color-variables).
  - tags: colour; critique; consistency, accessibility, review
  - fits when: A dashboard uses red and green for both status and decoration, and the designer wants an outside eye before review.
  - feasibility: supported. It reads fills and computes ratios from their values; nothing is edited.
  - credits: 22 to 24 credits per screen [page-scale audit, read-only]
  - differs from: accessibility-audit, which reports contrast pass or fail; this judges whether colour carries a consistent meaning and uses contrast as supporting evidence.

### critique × handoff

- **fm-dev-readiness-critique**
  - tier: B
  - description: Critiques the selected frames from a front-end developer's point of view and lists every question an engineer would have to ask, such as unstated breakpoints, missing states, and unexplained one-off values, ranked by build risk. Use whenever the user asks whether a design is ready for development, wants a developer's eye review, or asks what engineers will ask. Not for adding annotations or renaming layers (use dev-handoff-prep).
  - tags: handoff; critique; handoff, review, onboarding
  - fits when: A designer is a day from handoff and wants to answer the engineers' questions before they are asked.
  - feasibility: supported. It reads the canvas and reports in chat; the MCP edition can add a code-side check where a repository is open.
  - credits: 22 to 24 credits per flow page [page-scale audit, read-only]
  - differs from: dev-handoff-prep, which prepares and annotates the file; this reviews it from the engineer's side and leaves the fixing to the designer.

### synthesis × components

- **fm-component-usage-digest**
  - tier: B
  - description: Summarizes how library components are used across the current page, grouping instances by component, counting overrides by property, and naming the recurring override patterns that suggest a missing variant. Use whenever the user asks how a component is used, which overrides keep repeating, or whether the library is missing a variant. Not for auditing component definitions (use analyze-components).
  - tags: components; synthesis; drift, consistency, review
  - fits when: A design-system lead sees the same override on a button in every product file and wants evidence that a variant is missing.
  - feasibility: supported on the current page. Loading every page is present in-app but its call is untested (third parties report it not implemented), so feature-check first and the digest names the page it read; instance and override reads are standard Plugin API, and the first live run confirms them over MCP, where the probe's empty page held no instance.
  - credits: 22 to 24 credits per page [page-scale audit, read-only]
  - differs from: analyze-components, which audits component definitions for orphans and duplicates; this reads how instances are overridden in practice and turns the patterns into variant proposals.

### synthesis × layout

- **fm-layout-template-digest**
  - tier: B
  - description: Groups the screens in the selected flow by layout structure, such as column count, header pattern, and content grid, and names each recurring template with its screens and the one-offs that match none. Use whenever the user asks which layouts a flow repeats, wants to find page templates, or asks how consistent the screen structure is. Not for spacing or alignment checks (use visual-consistency-check).
  - tags: layout; synthesis; consistency, onboarding, review
  - fits when: A new designer joins a product with forty screens and needs to know which layouts are the real templates.
  - feasibility: supported. It reads frame structure and reports in chat.
  - credits: 22 to 24 credits per page of screens [page-scale audit, read-only]
  - differs from: visual-consistency-check, which flags inconsistencies between screens; this names the templates the flow already follows.

### synthesis × motion

- **fm-motion-language-digest**
  - tier: C
  - description: Collects every animated layer's durations and easings on the current page and clusters them into the file's de facto motion language, naming each cluster and listing the outliers as a draft motion spec. Use whenever the user asks what motion the file uses, wants to document existing animation, or asks for a motion inventory. Not for flagging inconsistent transitions (use animation-consistency-check).
  - tags: motion, documentation; synthesis; consistency, handoff, onboarding
  - fits when: A team has animated a product for months and needs to write down the motion system it actually uses.
  - feasibility: plan-only for the coding-agent edition, where the motion API is not listed for MCP. Adding motion is Supported in-app and Figma-authored skills call the motion API, but no in-app probe table exists yet, so this waits on one.
  - credits: 22 to 24 credits per page [page-scale audit, read-only]
  - differs from: animation-consistency-check, which flags transitions out of step; motion-spec-generator, which documents intended motion; this derives the language bottom-up from what is already animated.

### workflow × type

- **fm-typeface-migration**
  - tier: B
  - description: Migrates the selected frames from one typeface to another in checked stages: an inventory of fonts and weights, a weight-mapping table to confirm, the swap on a duplicate, and a list of text layers that reflowed or overflowed. Use whenever the user asks to change the font, swap the typeface, migrate to a new brand font, or replace a font across a design. Not for exploring font pairings (use font-pairings).
  - tags: type; workflow; consistency, review
  - fits when: A rebrand changes the typeface and the team needs every screen moved over with no clipped labels.
  - feasibility: supported. Text edits and styles are Supported; fonts are loaded before each edit, the swap runs on a duplicate, and overflow is measured in a later call than the swap.
  - credits: 22 to 24 credits for the inventory [page-scale audit]; about 10 credits to confirm the mapping [ask]; about 18 credits per five frames swapped [five-fix model]
  - differs from: font-pairings, which explores alternate pairings as variants; this executes one confirmed migration and reports what reflowed.

### workflow × colour

- **fm-dark-mode-bootstrap**
  - tier: B
  - description: Builds a first dark mode from the file's own colour variables in checked stages: a role inventory, proposed dark values with contrast ratios to confirm, a new mode in the collection, and a duplicate frame switched to it for review. Use whenever the user asks to create a dark mode, add a dark theme, or derive dark colours from an existing palette. Not for matching the shadcn theme model (use shadcn-theme-variables).
  - tags: colour, variables; workflow; accessibility, consistency
  - fits when: A product with a light-only palette is asked for a dark theme and the designer wants a starting point grounded in the existing roles.
  - feasibility: supported. Authoring variables and switching modes are Supported; the result is reviewed on a duplicate frame before anything else is rebound.
  - credits: 22 to 24 credits for the role inventory [page-scale audit]; about 10 credits to confirm the values [ask]; about 18 credits per five roles created [five-fix model]
  - differs from: shadcn-theme-variables, which fits variables to one fixed theming model; this derives dark values from the file's own palette and roles.

### workflow × content

- **fm-copy-review-round**
  - tier: B
  - description: Runs a copy review round on the selected frames: it proposes each copy change as a comment pinned to its text layer, waits for a writer to approve in the thread, then applies the approved lines and lists what changed. Use whenever the user asks to run a copy review, get copy approved, or route text changes to a writer before applying them. Not for judging tone (use content-tone-review).
  - tags: content; workflow; review, handoff, consistency
  - fits when: A product writer has to approve every string before it ships, and the designer wants the approvals recorded where the copy lives.
  - feasibility: plan-only for posting and reading comments over MCP, which has no comment tool. In-app, adding and reviewing comments are Supported in the capability table, but pinning a comment to a text layer and reading approvals back from its thread are untested; no probe covers comments, so this rests on documented capability alone.
  - credits: 22 to 24 credits to collect strings and post proposals [page-scale audit]; about 18 credits per five approved lines applied [five-fix model]
  - differs from: content-tone-review, which flags off-voice lines in chat; this runs the approval loop through comment threads and applies what was approved.

### workflow × accessibility

- **fm-accessibility-fix-sprint**
  - tier: B
  - description: Runs a confirmed accessibility fix list on the selected frames in batches of five, applying each fix, reading the canvas back, and recording progress on the frames so a later run resumes where this one stopped. Use whenever the user asks to fix accessibility issues, work through an accessibility audit, or apply contrast and target-size fixes. Not for finding issues in the first place (use accessibility-audit).
  - tags: accessibility; workflow; accessibility, review, cost
  - fits when: An audit returned forty accessibility findings and the designer wants them fixed in safe, resumable batches.
  - feasibility: supported. Progress is written with shared plugin data, which the MCP probe round-tripped; private plugin data and client storage both errored there and are not used. Shared plugin data is untested in-app, so the in-app edition rests on that MCP evidence until an in-app probe table is pasted back.
  - credits: about 18 credits per batch of five fixes [five-fix model]; about 10 credits to confirm each batch [ask]
  - differs from: accessibility-audit, which reports issues; this applies a confirmed list in verified batches and can resume.

### conventions × type

- **fm-type-conventions**
  - tier: A
  - description: Applies a team's typography conventions to the selected text layers, snapping line heights to a 4 px grid, setting letter spacing by size band, and raising text below 12 px, and lists every change before applying it. Use whenever the user asks to apply type rules, fix line heights, normalise letter spacing, or enforce a minimum text size. Not for binding text styles (use fm-type-style-drift-audit).
  - tags: type; conventions; consistency, drift, accessibility
  - fits when: A team has written type rules in a wiki and wants them enforced on a screen before review.
  - feasibility: supported. Text property edits are Supported; fonts are loaded before every edit, and the text sizing order from the script rules is followed.
  - credits: 22 to 24 credits per page [page-scale audit]; about 18 credits per five changes [five-fix model]
  - differs from: make-a-type-scale, which generates a scale; this applies numeric rules to existing text, on the same confirm-then-apply pattern as fm-spacing-rhythm-audit.

### conventions × documentation

- **fm-file-cover-standard**
  - tier: B
  - description: Applies a team's file conventions to the open file: a cover frame with title, status, owner, and date, page names and order from a fixed list, and section labels on each page, listing every change before it is made. Use whenever the user asks to add a cover page, set the file status, standardise page names, or set up a file the team way. Not for reorganising exploration work (use file-cleanup).
  - tags: documentation; conventions; onboarding, naming, consistency
  - fits when: A new project file is created and the team wants every file to open on the same cover and page order.
  - feasibility: supported. Renaming and creating frames are Supported, as are file metadata actions; labels on other pages wait until each page is loaded, because loading all pages at once is present in-app but its call is untested (third parties report it not implemented); feature-check first. The probe ran on a one-page empty file, so renaming and reordering real pages was not exercised.
  - credits: about 10 credits to confirm the cover fields [ask]; about 18 credits per five pages renamed or labelled [five-fix model]
  - differs from: file-cleanup, which reorganizes a messy file around its content; this stamps a fixed house template on any file, new or old.

## Promoted from sessions

When a Workflow 0 user picks a card, add it here as a seed with the date, then move it into its cell at the next refresh if it survives the admission rules.

No cards have been promoted yet.

## How Workflow 0 uses these files

1. Map the user's grounding answer to surfaces and patterns by matching it against the seeds' `tags` and `fits when` lines.
2. Read the matched cells first, in this file and in the landscape.
3. Compose at least two cards from matched cells, at least one from an empty cell, and one wildcard.
4. Check the landscape before pitching, so every card says either "new" or "better than X" with X a landscape row.
5. Reshape an idea the runtime cannot support into plan-only form, or drop it; pitch at most one plan-only card.
6. After the user picks, append the card to `## Promoted from sessions`.
