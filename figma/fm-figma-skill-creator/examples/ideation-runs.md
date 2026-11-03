# Workflow 0 ideation runs

Evidence from the Task 4 proving runs on 2026-11-03 UTC. A recon smoke run of the Workflow 0 script on the empty scratch file comes first. Then come two rounds of three decks, each produced by a fresh sonnet agent that followed Workflow 0 in `SKILL.md` with no file key, so recon was skipped and every card grounds in the catalog, the landscape, or the user's answer. Round 1 ran before the template fix and round 2 after it, with the same prompts and grounding answers. Every deck is pasted verbatim, defects included, and each round ends with its assertion results.

## Recon smoke run (scratch file)

Run on 2026-11-03 UTC through `use_figma` against `fm-probe-scratch` (key `kXhDI9zBD5rbh00c3Lzt9i`), the empty design file from the probe's MCP baseline. One call, read-only, no error.

```json
{"page":"Page 1","pages":[{"id":"0:1","name":"Page 1"}],"counts":{"componentSets":0,"components":0,"instances":0},"collections":[],"styles":{"text":0,"paint":0},"namingSample":[]}
```

Five observations the workflow would keep: one page named "Page 1" with no stated purpose; no component sets, components, or instances on it; no local variable collections; no text or paint styles; nothing to sample for naming. An empty file yields "no file inspected"-grade evidence, so every card in a deck built from it would ground in the catalog or the user's answer rather than in observations.

## Round 1 (before the template fix)

The round-1 assertions found six Does lines whose first sentence ran past 250 characters (Run A card 1 and all five Run B cards), and two Run A Grounded in lines that called a cell with three or four landscape rows a gap. The template then gained the 250-character limit on the Does placeholder, a deck rule to run the validator on every Does line before showing the deck, and a definition of a landscape gap as a cell with a count of 0 or 1; Workflow 0 step 3 gained the same validator step.

## Round 1, Run A: "something for our design system"

Prompt: "something for our design system". Grounding answer: "designers keep hand-checking that components use our tokens". The deck follows verbatim, from its own heading to the footer question.

## Concept cards for: "designers keep hand-checking that components use our tokens"

- **Mapping:** surfaces: components, variables, colour, type; patterns: audit, conventions
- **Observed:** no file inspected
- **From the catalog:** read first audit × components (6 landscape rows), audit × variables (1), conventions × variables (3), conventions × colour (2); empty cells used: audit × type (0) and critique × variables (0); seed used: fm-type-style-drift-audit

### 1. /fm-component-token-audit — Catch hard-coded values inside components

- **Does:** Audits the selected components and their instances for fills, strokes, effects, corner radius, padding, and gap that carry raw values instead of variable bindings, and lists each with the nearest matching variable and a binding coverage percentage per component. Use whenever the user asks to check that components use our tokens, find hard-coded values, audit variable bindings, or review a component before it is published. Not for applying fixes (use /fm-spacing-radius-token-binder) or checking text styles (use /fm-type-style-drift-audit).
- **Type:** audit → `templates/type-standards-qa-audit.md`
- **Category:** Design systems
- **Cell:** audit × components
- **Tier:** B plausible

- **Reads:** selection (component sets, components, instances); variables and styles (to find the nearest matching variable)
- **Writes:** none — report only; fixes go to the sibling skills
- **Produces:** chat report (ranked table of component, layer, property, raw value, nearest variable, plus a coverage percentage per component, capped at 25 rows)
- **Needs:** a selection of component sets or instances, and a local or connected library collection that holds the tokens; without a collection it reports raw values only
- **Try it:** "Check that the selected components use our tokens and list anything hard-coded."
- **Sample output:** Button / Primary / Hover: fill #1F6FEB is unbound; nearest variable color/action/primary (#1F6FEB, exact match). Button binding coverage 83%.

- **Fits your moment:** it replaces "designers keep hand-checking that components use our tokens" with one ranked table the designer reads once.
- **Grounded in:** the user's answer alone
- **Landscape:** better than follow-ds-guidelines because it inspects bindings property by property inside the components and names the nearest variable, instead of listing general deviations from the published system.

- **Runs in:** both — supported today (using variables and reading components); over MCP the variable reads were available in the 2026-11-03 probe, but boundVariables on real nodes is untested because the probe page held no auto-layout node, so the first live run confirms it
- **Risk:** read-only; a wrong nearest-variable suggestion is mitigated by showing the exact value gap beside every suggestion
- **Cost:** about 22 to 24 credits per run (observed page-scale audit cost, scaled down for a single component set)
- **Build effort:** medium — a property-by-property binding reader, nearest-variable matching rules, and a coverage calculation, with two intake questions
- **Pairs with:** /fm-spacing-radius-token-binder, /fm-type-style-drift-audit, /apply-color-variables
- **Confirm before building:** Which variable collections count as the official tokens? Should alias chains be followed to the primitive, or stop at the semantic variable?

### 2. /fm-spacing-radius-token-binder — Bind exact matches, list near-misses

- **Does:** Binds padding, gap, and corner radius values in the selected frames to the matching variables in a spacing or radius collection the user names, applying exact matches after confirmation and listing near matches for a decision. Use whenever the user asks to bind spacing to tokens, replace raw padding with variables, apply radius tokens, or tokenize a screen. Not for colour (use /apply-color-variables) or for snapping off-grid values (use /fm-spacing-rhythm-audit).
- **Type:** conventions → `templates/type-design-system-conventions.md`
- **Category:** Design systems
- **Cell:** conventions × variables
- **Tier:** B plausible

- **Reads:** selection (auto-layout frames); variables and styles (the named spacing or radius collection)
- **Writes:** after confirmation — padding, gap, and corner radius bindings on exact-match values, on a duplicate frame placed 80 px to the right; near matches stay unchanged until the user picks
- **Produces:** bindings
- **Needs:** a selection that uses auto layout, and a spacing or radius variable collection (local or from a connected library)
- **Try it:** "Bind the padding, gap and radius on this screen to our spacing and radius tokens."
- **Sample output:** Card: padding 16 → space/4 (exact). Chip: gap 10 has no token; nearest are space/2 (8) and space/3 (12), your call.

- **Fits your moment:** once the check shows raw values, this applies "our tokens" itself so nobody retypes them by hand.
- **Grounded in:** landscape gap conventions × variables (no row binds spacing or radius values to variables)
- **Landscape:** better than legacy-styles-to-variables because it is a scoped, confirm-first binder for spacing and radius that lists near matches instead of guessing.

- **Runs in:** both — editing layout and using variables are supported in Design; over MCP setBoundVariable was present in the probe (presence only), so the first live run confirms binding on a real auto-layout node
- **Risk:** edits layout properties; mitigated by working on a duplicate, listing every change before applying, and reading the canvas back afterwards
- **Cost:** about 40 credits per run (22 to 24 to scan a page plus about 18 per five bindings applied, from the observed cost model, scaled by scope)
- **Build effort:** medium — exact-match tables, near-match ranking, a confirmation loop, and a read-back step
- **Pairs with:** /fm-component-token-audit, /fm-spacing-rhythm-audit, /apply-color-variables
- **Confirm before building:** Which collections hold the spacing and radius tokens? Should near matches within 2 px be offered, or never?

### 3. /fm-type-style-drift-audit — Find text styled by hand

- **Does:** Audits the selected frames for text layers that carry no text style or drift from their style's size, weight, or line height, and lists each with the nearest local or library style; it applies a style after the user confirms. Use whenever the user asks to check typography, find unstyled text, audit text styles, or clean up type before handoff. Not for building a new type scale (use /make-a-type-scale) or rewriting copy.
- **Type:** audit → `templates/type-standards-qa-audit.md`
- **Category:** Design systems
- **Cell:** audit × type
- **Tier:** A build-ready on a proven pattern

- **Reads:** selection; variables and styles (local and library text styles)
- **Writes:** after confirmation — applies the matched text style to the confirmed rows only
- **Produces:** chat report, then bindings after confirmation
- **Needs:** a selection of frames and a text-style set in the file or a connected library
- **Try it:** "Find text on this screen that isn't using one of our text styles."
- **Sample output:** Hero / Subtitle: no text style, 18/28 Inter Medium; nearest style body/lg (18/28 Regular), weight differs.

- **Fits your moment:** text styles are tokens too, and unstyled text is the check designers do by clicking each text layer.
- **Grounded in:** catalog seed fm-type-style-drift-audit
- **Landscape:** new — no landscape row audits text-style usage; make-a-type-scale generates a scale instead.

- **Runs in:** both — using styles is supported in Design; over MCP getLocalTextStylesAsync was available and setTextStyleIdAsync was present in the probe, and fonts are loaded before any text edit
- **Risk:** applies styles on a duplicate; reflow after a style change is measured in a later call and reported
- **Cost:** about 40 credits per run (22 to 24 for the page audit plus about 18 per five styles applied, from the observed cost model, scaled by scope)
- **Build effort:** small — repeats the proven fm-spacing-rhythm-audit shape: one reader, one nearest-style rule, one confirmation
- **Pairs with:** /fm-component-token-audit, /make-a-type-scale
- **Confirm before building:** Do weight differences count as drift, or only size and line height? Is the library text-style set or the local set the reference?

### 4. /fm-component-token-map — Token map beside each component

- **Does:** Builds a token map frame beside the selected component, listing each part with the variable bound to its fill, stroke, radius, spacing, and text style, its resolved value, and a red mark where the value is raw. Use whenever the user asks to document a component's tokens, map tokens to component parts, or show which variables a component uses. Not for numbered part callouts (use /create-anatomy) or for auditing a whole page (use /fm-component-token-audit).
- **Type:** generator → `templates/type-generation-builder.md`
- **Category:** Design systems
- **Cell:** generator × documentation
- **Tier:** B plausible

- **Reads:** selection (one component set or component); variables and styles
- **Writes:** always — one new frame placed 80 px to the right of the source; no existing layer is changed
- **Produces:** new frame beside the source
- **Needs:** a selected component or component set; if nothing is bound, every row shows a raw value
- **Try it:** "Make a token map for the selected Button component."
- **Sample output:** A frame titled "Button token map" with the row "Container fill | color/action/primary | #1F6FEB" and the row "Label text | raw, no style" marked red.

- **Fits your moment:** a map the designer reads once beats clicking through every layer to see whether it "uses our tokens".
- **Grounded in:** landscape gap generator × documentation (create-anatomy marks parts, but no row shows the tokens bound to them)
- **Landscape:** better than create-anatomy because its table lists the bound variable and resolved value for each part, not only the part's attributes.

- **Runs in:** both — creating frames is supported in Design; over MCP boundVariables on real nodes is untested (the probe page was empty), so the first live run confirms it, and fonts are loaded before the table text is written
- **Risk:** adds one frame and never edits the source; the frame is named so it can be deleted in one step
- **Cost:** about 40 credits per run (22 to 24 to read the component plus about 18 per five table rows placed, from the observed cost model, scaled to an 8 to 12 row table)
- **Build effort:** medium — a table-building helper that follows the build-then-measure-later geometry order, plus a read-back check
- **Pairs with:** /fm-component-token-audit, /create-anatomy
- **Confirm before building:** Should the map be a table, or numbered markers over a live instance? Which properties should rows cover: fill, stroke, radius, spacing, text style?

### 5. /fm-token-structure-critique — Wildcard: judge the tokens themselves

- **Does:** Critiques the structure of the file's variable collections, flagging names that encode a raw value instead of a role, primitives that components use directly, alias chains deeper than three, and near-duplicate tokens, each ranked with a fix. Use whenever the user asks to review the token structure, check whether variable names make sense, or asks why designers keep picking the wrong token. Not for checking component bindings (use /fm-component-token-audit) or syncing with code (use /design-tokens-sync).
- **Type:** critique → `templates/type-critique-review.md`
- **Category:** Design systems
- **Cell:** critique × variables
- **Tier:** B plausible

- **Reads:** variables and styles (all local collections, modes, and aliases)
- **Writes:** none — read-only
- **Produces:** chat report
- **Needs:** at least one local variable collection; no selection is required
- **Try it:** "Review our variable structure and tell me why designers keep picking the wrong token."
- **Sample output:** P1: color/blue-500 names a value, not a role; add a semantic alias such as color/action/primary and point components at it.

- **Fits your moment:** if designers keep hand-checking, the tokens may be hard to choose between, so this critiques the tokens rather than the components.
- **Grounded in:** landscape gap critique × variables (count 0: nobody has judged the structure of variable collections)
- **Landscape:** new — design-tokens-sync compares variables with code, and no row judges the structure of the collections.

- **Runs in:** both — reading variable collections is supported in Design and was available over MCP in the probe, which ran on a file with no variables, so alias chains and modes are untested until the first live run
- **Risk:** read-only
- **Cost:** about 22 to 24 credits per run (observed page-scale audit cost, read-only)
- **Build effort:** small — read-only, one collection reader, and five named rules with no writes
- **Pairs with:** /fm-component-token-audit, /design-tokens-sync
- **Confirm before building:** Is there a layering convention (primitive, semantic, component) to judge against, or should the skill infer one from the file?

Which one should I build first? 1 to 5, or tell me what to change.

## Round 1, Run B: "help my team with handoff"

Prompt: "help my team with handoff". Grounding answer: "devs ask which frame is final every week". The deck follows verbatim, from its own heading to the footer question.

## Concept cards for: "devs ask which frame is final every week"

- **Mapping:** handoff and documentation surfaces; workflow, critique, synthesis, audit, and conventions patterns
- **Observed:** no file inspected
- **From the catalog:** read the handoff column first (audit 3, generator 3, workflow 4, conventions 3, synthesis 1, critique 0) plus conventions × documentation (0); the empty cells were critique × handoff and conventions × documentation

### 1. /fm-final-frame-resolver — Settle which frame is final

- **Does:** Groups the top-level frames on the current page into screens by name, size, and layer match, proposes the final frame in each group with the evidence for it, and after confirmation builds a handoff index frame beside the source that lists each screen's final frame and its superseded versions. Use whenever the user asks which frame is final, which version to build, which artboard is current, or to mark the finals for developers. Not for readying a finished design for Dev Mode (use dev-handoff-prep) or reorganising pages (use file-cleanup).
- **Type:** workflow → `templates/type-workflow-process.md`
- **Category:** Workflows
- **Cell:** workflow × handoff
- **Tier:** B plausible

- **Reads:** page (top-level frame names, sizes, positions, and child counts; no pixel access)
- **Writes:** after confirmation — one new "Handoff index" frame beside the source holding a row per screen; source frames are never renamed, moved, or edited
- **Produces:** new frame beside the source
- **Needs:** a page that holds more than one version of at least some screens; with nothing selected it asks the scope question first
- **Try it:** "Which of these frames is final? Sort out the versions on this page before I hand off."
- **Sample output:** | Checkout payment | Final: Checkout / payment v3 | Right-most of 3 similar frames, 97 percent layer match to v2 | Superseded: v1, v2 |

- **Fits your moment:** Devs ask which frame is final every week, and this answers it once per screen in a frame they can open instead of in a thread.
- **Grounded in:** the user's answer alone
- **Landscape:** better than file-cleanup because it decides which frame is final in each screen group, where file-cleanup marks stale explorations and leaves the finals untouched

- **Runs in:** both — Figma agent in Design, supported today (frame creation and canvas reads are Supported); MCP agents read the same page through the Plugin API
- **Risk:** adds one frame only; ambiguous groups are left unresolved and listed instead of guessed
- **Cost:** about 50 credits per run (22 to 24 to group the page, 10 to confirm, 18 to build the index, from the observed cost model)
- **Build effort:** medium — a grouping helper, one confirmation round per ambiguous group, and an index builder in a later call than the grouping
- **Pairs with:** dev-handoff-prep after the finals are named; /fm-dev-readiness-critique
- **Confirm before building:** Which signals does your team trust to mark a frame final: name suffix, position on the canvas, or a tag? Where should the index frame sit?

### 2. /fm-dev-readiness-critique — Answer engineers' questions before asked

- **Does:** Critiques the selected frames from a front-end developer's point of view and lists every question an engineer would have to ask, such as which of several similar frames is final, unstated breakpoints, missing states, and unexplained one-off values, ranked by build risk. Use whenever the user asks whether a design is ready for development, wants a developer's eye review, or asks what engineers will ask. Not for adding annotations or renaming layers (use dev-handoff-prep).
- **Type:** critique → `templates/type-critique-review.md`
- **Category:** Critique
- **Cell:** critique × handoff
- **Tier:** B plausible

- **Reads:** selection
- **Writes:** none — read-only chat report
- **Produces:** chat report
- **Needs:** the frames bound for handoff selected; nothing beyond a selection
- **Try it:** "What will the engineers ask about these frames before they start building?"
- **Sample output:** 1. High build risk: three frames named Checkout share one layout and none says which is final.

- **Fits your moment:** It puts the weekly "which frame is final" question at the top of a ranked list, with every other question engineers would raise, so the designer answers them before handoff.
- **Grounded in:** catalog seed fm-dev-readiness-critique
- **Landscape:** better than dev-handoff-prep because it reviews the file from the engineer's side and leaves the fixing to the designer, where dev-handoff-prep prepares and annotates it

- **Runs in:** both — Figma agent in Design, supported today (it reads the canvas and reports in chat); MCP agents can add a code-side check where a repository is open
- **Risk:** read-only
- **Cost:** about 23 credits per flow page (observed page-scale audit cost, read-only)
- **Build effort:** small — a ranked question list with a build-risk scale, one scope question, and a final gate
- **Pairs with:** /fm-final-frame-resolver; dev-handoff-prep
- **Confirm before building:** Which front-end stack and breakpoints do your engineers build for, so the question list uses the right vocabulary?

### 3. /fm-dev-question-digest — Mine comments for repeated questions

- **Does:** Reads the comment threads on the current page, clusters the questions developers ask into recurring types such as which frame is final, missing states, and unclear specs, counts each type with its threads, and names the file change that would stop the question coming back. Use whenever the user asks what developers keep asking, wants to turn handoff comments into fixes, or asks why the same handoff questions return. Not for sorting comments into change and decision buckets (use comment-triage).
- **Type:** synthesis → `templates/type-research-synthesis.md`
- **Category:** Workflows
- **Cell:** synthesis × handoff
- **Tier:** B plausible

- **Reads:** comments
- **Writes:** none — read-only chat report
- **Produces:** chat report
- **Needs:** a page whose comments include developer questions; if they ask elsewhere, pasted text works in place of comments
- **Try it:** "What do the developers keep asking in the comments on this page, and what would stop it?"
- **Sample output:** Which frame is final: 7 threads across 4 screens; fix: one page named Ready for dev that holds only finals.

- **Fits your moment:** It counts how often the weekly question appears and turns the pattern into the one file change that removes it.
- **Grounded in:** landscape gap synthesis × handoff
- **Landscape:** better than comment-triage because it counts recurring question types and ties each to a file change, where comment-triage sorts threads by what action they need

- **Runs in:** Figma agent in Design — supported today (reviewing comments is Supported; reading them is in-app only, so the MCP edition takes pasted text)
- **Risk:** read-only; large comment volumes cost more, so the run caps at 200 threads and says so
- **Cost:** about 23 credits per page with comments (observed page-scale audit cost, read-only)
- **Build effort:** medium — comment paging within output limits, a clustering rule with verbatim evidence, and a pasted-text fallback
- **Pairs with:** comment-triage; /fm-final-frame-resolver
- **Confirm before building:** Do developers ask in file comments or elsewhere, such as chat or tickets? Which people count as developers?

### 4. /fm-file-cover-standard — Every file opens on status

- **Does:** Applies a team's file conventions to the open file: a cover frame with title, status, owner, and date, page names and order from a fixed list that includes a Final screens page, and a note on the cover that says where the finals live, listing every change before it is made. Use whenever the user asks to add a cover page, set the file status, mark where the final screens live, or set up a file the team way. Not for reorganising exploration work (use file-cleanup).
- **Type:** conventions → `templates/type-design-system-conventions.md`
- **Category:** Workflows
- **Cell:** conventions × documentation
- **Tier:** B plausible

- **Reads:** page (page names and order; the cover frame if one exists)
- **Writes:** after confirmation — a cover frame, and page names and order from the fixed list; every change is listed before it is made
- **Produces:** new frame beside the source
- **Needs:** the team's status values and fixed page list; nothing beyond the open file
- **Try it:** "Set this file up the team way and put the status and where the finals live on the cover."
- **Sample output:** Cover: Checkout redesign | Status: In review | Owner: Dana | Finals: page 2, Final screens.

- **Fits your moment:** Every file opens on the same cover that says its status and where the finals live, so the question has an answer before anyone asks.
- **Grounded in:** catalog seed fm-file-cover-standard
- **Landscape:** better than file-cleanup because it stamps one fixed house template on any file, where file-cleanup reorganizes a messy file around its content

- **Runs in:** both — Figma agent in Design, supported today (renaming and frame creation are Supported; pages are handled one at a time because loading all pages at once is not implemented in-app); MCP agents run the same steps
- **Risk:** renames pages file-wide; every rename is listed and confirmed before it is applied
- **Cost:** about 28 credits per five-page file (10 to confirm the cover fields, 18 per five pages renamed)
- **Build effort:** small — a fixed template, one list of status values, and a confirm-then-apply loop
- **Pairs with:** /fm-final-frame-resolver; file-cleanup
- **Confirm before building:** Which status values does your team use, such as Draft, In review, and Ready for dev? What is the fixed page list and order?

### 5. /fm-find-final-frame-for-code — Wildcard: the developer's agent asks

- **Does:** Takes a Figma frame link from a developer or coding agent, lists the sibling frames on its page that look like other versions of the same screen, scores each by name, size, position, and layer match, and states which one to implement and why before any code is generated. Use whenever a coding agent is asked to build from a Figma link, a developer asks which frame is final, or a link may point at an outdated version. Not for turning the frame into code (use figma-design-to-code).
- **Type:** audit → `templates/type-standards-qa-audit.md`
- **Category:** Workflows
- **Cell:** audit × handoff
- **Tier:** B plausible

- **Reads:** page (sibling frame names, sizes, positions, and layer structure around the linked node)
- **Writes:** none — read-only chat report
- **Produces:** chat report
- **Needs:** the Figma MCP server connected to the coding agent and a link to one frame
- **Try it:** "Before you build from this Figma link, check whether a newer version of this screen exists on the page."
- **Sample output:** Linked frame "Checkout / payment v2" has 2 similar siblings; "Checkout / payment v3" is probably final (right-most, 97 percent layer match); confirm with the designer.

- **Fits your moment:** It sends the weekly question to the people who ask it, so the developer's own agent checks for a newer version before building.
- **Grounded in:** the user's answer alone
- **Landscape:** new

- **Runs in:** MCP agents — supported today (reading a page's frame metadata and a screenshot is documented); not applicable inside the Figma agent
- **Risk:** read-only; states its confidence and never claims a frame is final without designer confirmation
- **Cost:** about 10 credits per run (estimated as one ask from the observed cost model; MCP reads may cost less)
- **Build effort:** small — one scoring rule, one report format, and a stop-and-ask line when two frames tie
- **Pairs with:** figma-design-to-code; /fm-final-frame-resolver
- **Confirm before building:** Which coding agents will use it, so the install path and the link format it expects are right?

Which one should I build first? 1 to 5, or tell me what to change.

## Round 1, Run C: "make our marketing pages better"

Prompt: "make our marketing pages better". Grounding answer: "every landing page starts from a blank frame and drifts off brand". The deck follows verbatim, from its own heading to the footer question.

## Concept cards for: "every landing page starts from a blank frame and drifts off brand"

- **Mapping:** layout, components, variables, colour, and type; generator, conventions, audit, and synthesis (blank-frame starts map to generator × layout; brand drift maps to conventions × colour and audit × type)
- **Observed:** no file inspected
- **From the catalog:** generator × layout, conventions × colour, audit × colour, and audit × type first; audit × type and synthesis × layout were empty (count 0)

### 1. /fm-landing-page-scaffold — Never start from blank again

- **Does:** Builds a new landing page frame beside the selected one from the file's own section components, variables, and text styles in a confirmed section order, and lists each section with the component it used. Use whenever the user asks to start a landing page, build a page from our components, or stop starting from a blank frame. Not for resizing a finished page (use desktop-to-mobile).
- **Type:** generator → `templates/type-generation-builder.md`
- **Category:** Generation
- **Cell:** generator × layout
- **Tier:** B plausible

- **Reads:** selection (a reference page or the section components) and variables and styles
- **Writes:** after confirmation — a new frame placed 80 px to the right of the selection; the source is never moved or edited
- **Produces:** new frame beside the source
- **Needs:** section-level components (hero, feature row, pricing, call to action, footer) in the file or a connected library, plus colour and text style variables
- **Try it:** "Build a product landing page from our components: hero, three features, pricing, CTA, footer."
- **Sample output:** "Section plan: 1 Hero (Hero/Centered), 2 Features (Feature Row x3), 3 Pricing (Pricing/3-up), 4 CTA band, 5 Footer. Build this order?"

- **Fits your moment:** Your pages "start from a blank frame", so this starts every page from your own components and tokens and the page begins on brand.
- **Grounded in:** the user's answer alone
- **Landscape:** better than build-from-prd because it builds from a confirmed section list and the file's own components, not from a PRD

- **Runs in:** both — supported today (create frames, place instances, apply variables); library search needs a connected library, otherwise it uses local components
- **Risk:** creates one new frame and nothing else; the section plan is shown and confirmed before anything is built
- **Cost:** about 45 credits per run (22 to 24 to inventory the components, plus about 18 per five sections placed, scaled to a six-section page)
- **Build effort:** medium — a section plan table, instance placement, a read-back verify step, and two intake questions
- **Pairs with:** fm-brand-colour-binder, fm-type-style-drift-audit
- **Confirm before building:** Which page or library holds the section components? What is the default section order for a landing page?

### 2. /fm-brand-colour-binder — Snap stray colours to brand

- **Does:** Binds hard-coded fills and strokes in the selected landing pages to the nearest brand colour variable within a stated tolerance, and lists every match and every near-miss it will leave alone before applying. Use whenever the user asks to fix off-brand colours, bind colours to variables, clean up stray hex values, or bring a page back on brand. Not for judging how colour carries meaning (use fm-colour-meaning-critique).
- **Type:** conventions → `templates/type-design-system-conventions.md`
- **Category:** Brand
- **Cell:** conventions × colour
- **Tier:** A build-ready on a proven pattern

- **Reads:** selection and variables and styles
- **Writes:** after confirmation — fill and stroke variable bindings on confirmed rows only
- **Produces:** bindings
- **Needs:** a colour variable collection holding the brand roles, local or from a connected library, and the pages selected
- **Try it:** "Find the off-brand colours on these landing pages and bind them to our brand variables."
- **Sample output:** "14 fills bind to brand variables, 3 near-misses left alone: #3B82F5 on Hero/CTA is 2 steps from color/brand/primary."

- **Fits your moment:** Pages that "drift off brand" usually carry hand-picked hex values, and this puts each one back on the variable it was meant to use.
- **Grounded in:** the user's answer alone
- **Landscape:** better than apply-color-variables because it applies a stated tolerance and lists the near-misses it refuses to bind

- **Runs in:** both — supported today (using variables, binding fills and strokes)
- **Risk:** edits fills and strokes on the selection; every row is listed and confirmed first, and near-misses are never bound
- **Cost:** about 40 credits per run (22 to 24 for the page-scale scan, plus about 18 per five bindings applied, scaled to two batches)
- **Build effort:** small — the same confirm-then-apply shape as fm-spacing-rhythm-audit on a different surface
- **Pairs with:** fm-landing-page-scaffold, fm-type-style-drift-audit
- **Confirm before building:** Which collection holds the brand colours? What counts as the same colour: exact match, or within one named step?

### 3. /fm-type-style-drift-audit — Unstyled text, caught before launch

- **Does:** Audits the selected frames for text layers that carry no text style or drift from their style's size, weight, or line height, and lists each with the nearest local or library style; it applies a style after the user confirms. Use whenever the user asks to check typography, find unstyled text, audit text styles, or clean up type before handoff. Not for building a new type scale (use make-a-type-scale) or rewriting copy.
- **Type:** audit → `templates/type-standards-qa-audit.md`
- **Category:** Brand
- **Cell:** audit × type
- **Tier:** A build-ready on a proven pattern

- **Reads:** selection and variables and styles
- **Writes:** after confirmation — a text style applied to confirmed rows only
- **Produces:** chat report
- **Needs:** local or library text styles that define the brand type set, and the pages selected
- **Try it:** "Check these landing pages for text that is not using our text styles."
- **Sample output:** "| Layer | Current | Nearest style | Delta | 'Hero headline' | 58/64 Bold | Display/L 64/72 | size -6, line height -8 |"

- **Fits your moment:** Type is where hand-built pages "drift off brand" first, and this finds every layer that left the style set.
- **Grounded in:** catalog seed fm-type-style-drift-audit
- **Landscape:** new — no landscape row audits text-style usage on its own; make-a-type-scale generates a scale instead

- **Runs in:** both — supported today (using styles; fonts are loaded before any text edit)
- **Risk:** applies text styles on confirmed rows only; the report itself is read-only
- **Cost:** about 40 credits per run (22 to 24 per page, plus about 18 per five styles applied, scaled to two batches)
- **Build effort:** small — repeats the proven fm-spacing-rhythm-audit shape with one font-loading step
- **Pairs with:** fm-brand-colour-binder, fm-landing-page-scaffold
- **Confirm before building:** Which text styles form the brand set, and do they live in this file or a library?

### 4. /fm-landing-layout-digest — Learn which layouts you repeat

- **Does:** Groups the landing pages in the selected set by layout structure, such as column count, header pattern, and content grid, and names each recurring template with its pages and the one-offs that match none. Use whenever the user asks which layouts our pages repeat, wants to find page templates, or asks how consistent the page structure is. Not for spacing or alignment checks (use visual-consistency-check).
- **Type:** synthesis → `templates/type-research-synthesis.md`
- **Category:** Design systems
- **Cell:** synthesis × layout
- **Tier:** B plausible

- **Reads:** selection
- **Writes:** none — chat report only
- **Produces:** chat report
- **Needs:** at least four landing page frames selected or on one named page
- **Try it:** "Which layouts do our landing pages repeat, and which ones are one-offs?"
- **Sample output:** "Template A (6 pages): centred hero, three-column features, single CTA band. One-offs: Pricing v2, Event page."

- **Fits your moment:** If every page starts blank, the real templates are hidden in the pile, and this names them so the scaffold has a section order worth using.
- **Grounded in:** catalog seed fm-layout-template-digest
- **Landscape:** new — no landscape row groups screens by layout structure; visual-consistency-check flags inconsistencies instead

- **Runs in:** both — supported today (reads frame structure and reports in chat)
- **Risk:** read-only
- **Cost:** about 23 credits per run (page-scale audit, read-only, from the observed cost model)
- **Build effort:** small — one grouping table, an output cap, and a scope question
- **Pairs with:** fm-landing-page-scaffold
- **Confirm before building:** Which page holds the landing pages, or which frames should the digest read?

### 5. /fm-brand-reference-diff — Wildcard: measure against one page

- **Does:** Compares each selected landing page with one named on-brand reference page and lists every departure in section order, type, colour, and spacing, ranked by how far it drifts, each with the fix. Use whenever the user asks whether a page matches our brand page, how far a page has drifted, or to check a landing page against the approved one. Not for reviewing a screen without a reference (use superfuture-design-review).
- **Type:** critique → `templates/type-critique-review.md`
- **Category:** Critique
- **Cell:** critique × layout
- **Tier:** B plausible

- **Reads:** selection and variables and styles
- **Writes:** none — chat report only
- **Produces:** chat report
- **Needs:** one frame marked as the on-brand reference page, plus the pages to compare
- **Try it:** "Compare these two landing pages with the approved Pricing page and tell me where they drifted."
- **Sample output:** "Page B drifts most: 4 of 6 sections out of order, 9 fills not on brand variables, hero headline 56 px against the reference 64 px."

- **Fits your moment:** Drift needs a yardstick, and this makes your best existing page the yardstick for every new one.
- **Grounded in:** the user's answer alone
- **Landscape:** better than visual-consistency-check because it measures every page against one named reference page instead of against the other pages

- **Runs in:** both — supported today (reads frames, variables, and styles and reports in chat)
- **Risk:** read-only
- **Cost:** about 45 credits per run (22 to 24 per page-scale audit, read-only, scaled to two pages)
- **Build effort:** medium — a comparison table across four properties, a ranking rule, and a reference-page intake question
- **Pairs with:** fm-brand-colour-binder, fm-type-style-drift-audit
- **Confirm before building:** Which page is the on-brand reference, and which four properties count most: section order, type, colour, spacing?

Which one should I build first? 1 to 5, or tell me what to change.

## Round 1 assertion results

These come from a script run over the three round-1 decks above on 2026-11-03 UTC. It checks every Step 5 assertion and passes every Does line to `node scripts/validate-figma-skill.mjs --description`.

| Check | Run A | Run B | Run C |
| --- | --- | --- | --- |
| Exactly twenty labelled lines per card, in order | 5 of 5 | 5 of 5 | 5 of 5 |
| Does line: exit 0 with 0 errors and 0 warnings | 4 of 5 | 0 of 5 | 5 of 5 |
| Name matches `^/fm-[a-z0-9]+(-[a-z0-9]+)*$` | 5 of 5 | 5 of 5 | 5 of 5 |
| Five distinct cells | yes | yes | yes |
| Cards from an empty cell (count 0) | 2 | 2 | 2 |
| Plan-only cards (at most one, never card 1) | 0 | 0 | 0 |
| Runs in claims "supported today" for prototyping, vectors, slots, asset export, or diagrams | none | none | none |
| Writes is none, after confirmation, or always | 5 of 5 | 5 of 5 | 5 of 5 |
| Grounded in names a seed, gap, observation, or the answer | 5 of 5 | 5 of 5 | 5 of 5 |
| A named gap really is a gap (count 0 or 1) | 1 of 3 | 1 of 1 | no gaps named |
| Landscape starts with "new" or "better than", and X is a landscape row | 5 of 5 | 5 of 5 | 5 of 5 |
| Card 5's hook says wildcard | yes | yes | yes |
| Deck ends with the footer question | yes | yes | yes |

Findings, each left in its deck as evidence:

1. Six Does lines warn `description-lead` (first sentence over 250 characters): Run A card 1 (262 characters) and Run B cards 1 to 5 (293, 270, 273, 274, 271).
2. Two Grounded in lines name a cell that is not a gap: Run A card 2 cites conventions × variables (count 3), and Run A card 4 cites generator × documentation (count 4).

Template changes made in response: the Does placeholder in `templates/concept-cards.md` now states the 250-character first-sentence limit; deck rule 8 says to run the validator on every Does line before showing the deck and names the usual fix; the Grounded in placeholder and deck rule 12 define a landscape gap as a cell with a count of 0 or 1. Workflow 0 step 3 in `SKILL.md` now ends with the same validator step.

The leading slash in "Not for X (use /y)" changes nothing for the description rules. Run A writes `(use /y)` in all nine of its use clauses; Runs B and C and the catalog seeds write `(use y)`. The seed `fm-type-style-drift-audit` returns `OK: description — 0 errors, 0 warnings` both ways, because the boundary rule matches the words "not for" and the slash-invocation rule checks only the body.

## Round 2 (after the template fix)

Same three prompts and grounding answers, rerun under the tightened template; each agent ran the validator on its Does lines per deck rule 8 and reported no rewrites needed. These decks repeat the deck and card headings of round 1, so each sits verbatim inside a fenced `markdown` block to keep the file's headings unique.

## Round 2, Run A: "something for our design system"

Prompt: "something for our design system". Grounding answer: "designers keep hand-checking that components use our tokens". The deck follows verbatim inside the fence.

```markdown
## Concept cards for: "designers keep hand-checking that components use our tokens"

- **Mapping:** components and variables (token binding on component layers); audit, synthesis, generator, workflow
- **Observed:** no file inspected
- **From the catalog:** read audit × variables, audit × type, generator × variables, and conventions × variables first; audit × type and synthesis × components are empty cells (count 0 in the gap grid)

### 1. /fm-component-token-audit — Find every hard-coded component value

- **Does:** Audits the components in the selected frames for fills, strokes, corner radii, padding, gaps, and text that use a raw value instead of a variable, and lists each layer with the nearest matching variable; it binds the confirmed rows after approval. Use whenever the user asks to check token usage, find hard-coded values in components, or confirm a component uses our variables. Not for comparing variables with code tokens (use design-tokens-sync).
- **Type:** audit → `templates/type-standards-qa-audit.md`
- **Category:** Design systems
- **Cell:** audit × components
- **Tier:** B plausible

- **Reads:** selection; variables and styles
- **Writes:** after confirmation — variable bindings on the confirmed rows only, applied to a duplicate of the component set
- **Produces:** chat report, then bindings on the confirmed rows
- **Needs:** a selection of components or frames, and a local or connected library with variable collections for color, spacing, and radius
- **Try it:** "Check that the Button and Card components only use our tokens."
- **Sample output:** "Button / Primary / Hover — fill #1D4ED8 is not bound; nearest variable color/brand/700 (exact match)."

- **Fits your moment:** It does the hand-check for "components use our tokens" in one pass and names the variable each raw value should have been.
- **Grounded in:** the user's answer alone
- **Landscape:** better than follow-ds-guidelines because it checks each property against the file's variables, names the matching variable, and offers the binding instead of only flagging the deviation

- **Runs in:** both — supported today (variable reads and binding are Supported in the capability table); the MCP probe confirmed variable reads but could not exercise node.boundVariables on an empty page, so the first live run confirms it
- **Risk:** edits bindings on component layers; limited to confirmed rows and applied to a duplicate, never the source
- **Cost:** about 22 to 24 credits per page for the audit, plus about 18 credits per five bindings applied (observed cost model, scaled by the number of components)
- **Build effort:** medium — one report table, one scope gate, one confirm-then-apply step, and a small helper that matches raw values to variables
- **Pairs with:** design-tokens-sync, fm-type-style-drift-audit
- **Confirm before building:** Which properties count as tokenised (fill, stroke, radius, padding, gap, text style)? How near must a raw value be to a variable value to be offered as a match?

### 2. /fm-type-style-drift-audit — Unstyled text, caught before handoff

- **Does:** Audits the selected frames for text layers that carry no text style or drift from their style's size, weight, or line height, and lists each with the nearest local or library style; it applies a style after the user confirms. Use whenever the user asks to check typography, find unstyled text, audit text styles, or clean up type before handoff. Not for building a new type scale (use make-a-type-scale) or rewriting copy.
- **Type:** audit → `templates/type-standards-qa-audit.md`
- **Category:** Design systems
- **Cell:** audit × type
- **Tier:** A build-ready on a proven pattern

- **Reads:** selection; variables and styles
- **Writes:** after confirmation — text style applied to the confirmed rows only, on a duplicate
- **Produces:** chat report, then text style bindings on the confirmed rows
- **Needs:** a selection of frames and local or library text styles
- **Try it:** "Find text in these screens that isn't using one of our text styles."
- **Sample output:** "Checkout / Total label — Inter 15/22 Medium, no style; nearest style Body/Medium 16/24."

- **Fits your moment:** Text styles are tokens too, and typography is where hand-checking against the library is slowest.
- **Grounded in:** landscape gap audit × type (0 rows in the gap grid)
- **Landscape:** new

- **Runs in:** both — supported today (styles are Supported; the MCP probe returned available for getLocalTextStylesAsync and presence of setTextStyleIdAsync)
- **Risk:** edits text styles on confirmed rows; fonts are loaded before every edit and the work runs on a duplicate
- **Cost:** about 22 to 24 credits per page for the audit, plus about 18 credits per five styles applied (observed cost model)
- **Build effort:** small — repeats the proven fm-spacing-rhythm-audit shape on text, one table, one confirm step
- **Pairs with:** fm-component-token-audit, make-a-type-scale
- **Confirm before building:** Should a text layer within 1 px of a style's size count as matched or as drift?

### 3. /fm-token-override-digest — Where instances bypass your tokens

- **Does:** Summarizes how instances override bound properties across the current page, counting overrides that replace a variable with a raw value, and names the recurring ones that point to a missing token or variant. Use whenever the user asks which overrides keep repeating, where instances bypass our tokens, or whether a token is missing. Not for auditing component definitions (use analyze-components).
- **Type:** synthesis → `templates/type-research-synthesis.md`
- **Category:** Design systems
- **Cell:** synthesis × components
- **Tier:** B plausible

- **Reads:** page; variables and styles
- **Writes:** none — read-only digest
- **Produces:** chat report
- **Needs:** instances of library components on the current page
- **Try it:** "Which overrides on our buttons keep repeating, and do they mean a token is missing?"
- **Sample output:** "Button / Primary — 14 of 38 instances override the fill with #0F766E, which matches no variable; proposed token color/accent/teal."

- **Fits your moment:** It turns the hand-check into evidence: which components get their tokens overridden, how often, and whether the fix is a new token.
- **Grounded in:** landscape gap synthesis × components (0 rows in the gap grid)
- **Landscape:** new

- **Runs in:** both — supported on the current page only, since loading every page is not implemented in-app; instance and override reads are standard Plugin API and the first live run confirms them, because the MCP probe page held no instance
- **Risk:** read-only
- **Cost:** about 22 to 24 credits per page (observed cost model, read-only audit)
- **Build effort:** medium — grouping and counting helper code, a capped output table, and a clear statement of which page was read
- **Pairs with:** fm-component-token-audit, analyze-components
- **Confirm before building:** Should overrides of text content and images be ignored so that only token-bearing properties are counted?

### 4. /fm-spacing-variables-from-usage — Tokens that match what ships

- **Does:** Derives a spacing scale from the padding and gap values actually used in the selected frames, ranks them by frequency, and creates number variables in a collection the user names after confirmation. Use whenever the user asks to create spacing tokens, turn spacing into variables, or build a spacing scale from an existing design. Not for snapping off-grid values (use fm-spacing-rhythm-audit).
- **Type:** generator → `templates/type-generation-builder.md`
- **Category:** Design systems
- **Cell:** generator × variables
- **Tier:** B plausible

- **Reads:** selection; variables and styles
- **Writes:** after confirmation — number variables created in the named collection
- **Produces:** chat report, then new variables
- **Needs:** a selection of frames that use auto layout with padding and gap values, and permission to add a collection
- **Try it:** "We have no spacing tokens. Make some from what these screens already use."
- **Sample output:** "Found 11 distinct values; proposed scale 4, 8, 12, 16, 24, 32 (covers 94 percent of 212 uses); 16 is used 61 times."

- **Fits your moment:** Designers hand-check because some values have no token to bind to; this creates the missing ones from real usage.
- **Grounded in:** catalog seed fm-spacing-variables-from-usage
- **Landscape:** better than design-system-gen because it derives the scale from values already in use and ranks them by frequency, rather than building a starter system from a style guide

- **Runs in:** both — supported today (authoring variables is Supported; the MCP probe returned available for the collection reads)
- **Risk:** adds variables to a collection; the scale is shown and confirmed before anything is created
- **Cost:** about 22 to 24 credits to collect the values, about 10 credits to confirm the scale, and about 18 credits per five variables created (observed cost model)
- **Build effort:** medium — a collection helper, a frequency table, and a confirm step before creation
- **Pairs with:** fm-spacing-rhythm-audit, fm-component-token-audit
- **Confirm before building:** Which collection name and mode should the new variables use? Should values used fewer than three times be dropped from the scale?

### 5. /fm-token-adoption-sprint — Wildcard: resumable token binding batches

- **Does:** Binds raw values on the selected components to their matching variables in checked batches of five, reads each batch back from the canvas, and records progress so a later run resumes where it stopped. Use whenever the user asks to bind components to tokens, work through a token audit, or finish moving a file onto variables. Not for finding the unbound values first (use fm-component-token-audit).
- **Type:** workflow → `templates/type-workflow-process.md`
- **Category:** Workflows
- **Cell:** workflow × variables
- **Tier:** B plausible

- **Reads:** selection; variables and styles
- **Writes:** always — variable bindings in batches of five, each batch confirmed first; progress is stored in shared plugin data on the frames
- **Produces:** bindings, with a short progress note after each batch
- **Needs:** a confirmed list of raw values with their target variables, such as the output of a token audit, and a selection to work on
- **Try it:** "Work through the token fixes on these twelve components, five at a time."
- **Sample output:** "Batch 2 of 5 done: 5 bindings applied and read back, 0 mismatches; next run resumes at Card / Elevated."

- **Fits your moment:** It replaces the repeated manual re-checking with verified batches, so a half-finished token cleanup can stop and pick up again.
- **Grounded in:** the user's answer alone
- **Landscape:** better than legacy-styles-to-variables because it works from a confirmed list in verified batches of five and can resume, instead of migrating in one pass

- **Runs in:** both — supported today (variable binding is Supported; the MCP probe round-tripped shared plugin data, untested in-app, and private plugin data is not used)
- **Risk:** edits bindings on the selected components; each batch needs confirmation and is read back before the next, and the work is done on a duplicate
- **Cost:** about 18 credits per batch of five bindings, plus about 10 credits to confirm each batch (observed cost model)
- **Build effort:** large — staged instructions, a resume record, per-batch read-back, and the most questions to ask
- **Pairs with:** fm-component-token-audit, legacy-styles-to-variables
- **Confirm before building:** Should progress be recorded on the frames or only reported in chat? Is a batch size of five right for the file's size?

Which one should I build first? 1 to 5, or tell me what to change.
```

## Round 2, Run B: "help my team with handoff"

Prompt: "help my team with handoff". Grounding answer: "devs ask which frame is final every week". The deck follows verbatim inside the fence.

```markdown
## Concept cards for: "devs ask which frame is final every week"

- **Mapping:** handoff and documentation surfaces; conventions, audit, critique, and synthesis patterns
- **Observed:** no file inspected
- **From the catalog:** read the handoff and documentation cells first; conventions × documentation, critique × handoff, and generator × accessibility are empty (count 0), and synthesis × handoff holds one row

### 1. /fm-final-frame-marker — Mark which frame is final

- **Does:** Marks the selected top-level frames as Final, In review, or Superseded by placing a status tag 24 px above each one, and lists every tag before placing it. Use whenever the user asks to mark the final frame, tag frame status, show which version is current, or label what is ready for developers. Not for judging whether a design is ready for development (use fm-dev-readiness-critique).
- **Type:** conventions → `templates/type-design-system-conventions.md`
- **Category:** Workflows
- **Cell:** conventions × documentation
- **Tier:** B plausible

- **Reads:** selection
- **Writes:** after confirmation — one status tag (a new text layer) 24 px above each confirmed frame; the frames themselves are never renamed, moved, or edited
- **Produces:** new frame beside the source
- **Needs:** a selection of top-level frames; the team's status words (default Final, In review, Superseded)
- **Try it:** "Mark which of these checkout frames is final and which are superseded."
- **Sample output:** "Checkout / Payment v3 → Final; Checkout / Payment v2 → Superseded; Checkout / Payment copy → In review (3 tags, confirm to place)."

- **Fits your moment:** Devs ask which frame is final every week because nothing on the canvas says so; a tag above each frame answers it where they already look.
- **Grounded in:** landscape gap conventions × documentation (count 0 in the catalog's gap grid)
- **Landscape:** better than file-cleanup because it labels the status of every confirmed frame in place, finals included, instead of reorganising the file

- **Runs in:** both — supported today: reading frames and creating text layers are supported in Design, and MCP agents can run the same steps
- **Risk:** adds new layers to the canvas only; every tag is listed before placement and the source frames are untouched
- **Cost:** about 41 credits per page of five frames (23 for the inventory plus 18 for five tags, from the observed cost model)
- **Build effort:** small — one confirm-then-apply loop on the proven fm-spacing-rhythm-audit shape, with a short status list
- **Pairs with:** fm-dev-readiness-critique, fm-handoff-status-board
- **Confirm before building:** Which status words does the team use? Should a tag also carry a date?

### 2. /fm-superseded-frame-finder — Find the frame that's current

- **Does:** Audits the selected page for groups of frames that look like versions of one screen, such as v2, copy, or final-final, and ranks which frame in each group is most likely current from its name, position, and structure. Use whenever the user asks which frame is final, to find duplicate versions, to find old copies of a screen, or to check what is superseded. Not for tagging frames (use fm-final-frame-marker) or reorganising pages (use file-cleanup).
- **Type:** audit → `templates/type-standards-qa-audit.md`
- **Category:** Workflows
- **Cell:** audit × handoff
- **Tier:** B plausible

- **Reads:** page
- **Writes:** none — report only
- **Produces:** chat report
- **Needs:** nothing beyond a selection or an open page of frames; the team's version-naming habits help
- **Try it:** "Which of the onboarding frames on this page is the latest one?"
- **Sample output:** "Group 1, Onboarding / Welcome (4 frames): most likely current is Welcome v4 (rightmost, name suffix v4, matches 3 of 4 sibling layouts); confidence medium."

- **Fits your moment:** It answers the weekly "which frame is final" question from the page itself, with a ranked guess per screen and the evidence for it.
- **Grounded in:** the user's answer alone
- **Landscape:** new

- **Runs in:** both — supported today: it reads frame names, positions, and structure and edits nothing
- **Risk:** read-only; the ranking is a guess when names carry no version hint, so each group states its confidence and the evidence
- **Cost:** about 23 credits per page (page-scale audit, read-only, from the observed cost model)
- **Build effort:** medium — grouping heuristics, a confidence rule, and a capped report
- **Pairs with:** fm-final-frame-marker, fm-handoff-status-board
- **Confirm before building:** Which naming signals mark a version on this team (v2, copy, final)? Is the newest frame placed rightmost or lowest?

### 3. /fm-dev-readiness-critique — Answer engineers' questions first

- **Does:** Critiques the selected frames from a front-end developer's point of view and lists every question an engineer would have to ask, such as which frame is current, unstated breakpoints, and missing states, ranked by build risk. Use whenever the user asks whether a design is ready for development, wants a developer's eye review, or asks what engineers will ask. Not for adding annotations or renaming layers (use dev-handoff-prep).
- **Type:** critique → `templates/type-critique-review.md`
- **Category:** Critique
- **Cell:** critique × handoff
- **Tier:** B plausible

- **Reads:** selection
- **Writes:** none — report only
- **Produces:** chat report
- **Needs:** a selection of the frames headed to development; an optional note on the target breakpoints
- **Try it:** "Review these frames the way a front-end developer would before we hand them off."
- **Sample output:** "1. Which of the three Checkout frames is final? (build risk: high) 2. No tablet breakpoint is shown for the order summary. (medium)"

- **Fits your moment:** Developers keep asking which frame is final; this lists that question and every other one they would raise, so the designer answers them before the weekly ask.
- **Grounded in:** catalog seed fm-dev-readiness-critique
- **Landscape:** better than dev-handoff-prep because it reviews the file from the engineer's side and reports, where dev-handoff-prep edits it

- **Runs in:** both — supported today: it reads the canvas and reports in chat, and MCP agents can add a code-side check where a repository is open
- **Risk:** read-only
- **Cost:** about 23 credits per flow page (page-scale audit, read-only, from the observed cost model)
- **Build effort:** medium — a ranked-question rubric with build-risk levels and a cap on the number of questions
- **Pairs with:** fm-final-frame-marker, fm-handoff-status-board
- **Confirm before building:** Which question categories matter most (states, breakpoints, one-off values, status)? What is the cap on questions per run?

### 4. /fm-handoff-status-board — One board devs can bookmark

- **Does:** Builds a handoff board frame beside the selected page that lists each frame the user confirms as final, with its page, name, and status, so developers read one place instead of asking. Use whenever the user asks for a handoff index, a list of final screens, a ready-for-dev board, or one page developers can bookmark. Not for summarising progress and decisions (use handoff-summary).
- **Type:** synthesis → `templates/type-research-synthesis.md`
- **Category:** Workflows
- **Cell:** synthesis × handoff
- **Tier:** B plausible

- **Reads:** page
- **Writes:** after confirmation — one new board frame 80 px to the right of the selection; the source frames are untouched
- **Produces:** new frame beside the source
- **Needs:** a selection or page of frames; a confirmed list of which are final
- **Try it:** "Make a board listing every final screen in this flow so devs have one place to look."
- **Sample output:** "Handoff board, 6 rows: Flows / Checkout / Payment v3 — Final; Flows / Checkout / Confirmation v2 — Final; ..."

- **Fits your moment:** One board replaces the weekly "which frame is final" question with a list developers can open themselves.
- **Grounded in:** landscape gap synthesis × handoff (count 1 in the catalog's gap grid)
- **Landscape:** better than handoff-summary because it lists each confirmed frame by page, name, and status instead of narrating progress

- **Runs in:** both — supported today: reading frames and creating a frame with text are supported in Design, and MCP agents can run the same steps
- **Risk:** creates one new frame beside the source and never moves or edits the source; the frame list is confirmed before building
- **Cost:** about 41 credits per page of up to ten frames (23 to read the page plus 18 to build the board, from the observed cost model)
- **Build effort:** medium — a confirm step, a deterministic table layout, and a read-back of the finished board
- **Pairs with:** fm-final-frame-marker, fm-superseded-frame-finder
- **Confirm before building:** Which columns does the board need (page, name, status, owner, date)? Should it list only finals or every frame?

### 5. /fm-focus-order-annotator — Wildcard: show the keyboard order

- **Does:** Generates a numbered focus-order overlay beside a copy of the selected screen, derived from layer order and position, and flags every step where the tab order jumps against reading order. Use whenever the user asks to annotate focus order, show tab order, plan keyboard navigation, or prepare accessibility notes for developers. Not for contrast or target-size checks (use fm-target-size-audit).
- **Type:** generator → `templates/type-generation-builder.md`
- **Category:** Generation
- **Cell:** generator × accessibility
- **Tier:** B plausible

- **Reads:** selection
- **Writes:** after confirmation — a duplicate of the selected screen with numbered markers, placed beside the source; the source is untouched
- **Produces:** new frame beside the source
- **Needs:** a selected screen with a sensible layer order; nothing beyond a selection
- **Try it:** "Annotate the keyboard focus order on this checkout screen for the developers."
- **Sample output:** "Overlay built: 14 numbered stops; step 9 (Promo code) jumps above step 8 (Order total), against reading order."

- **Fits your moment:** After devs learn which frame is final, the next question they ask is how it behaves with a keyboard; this puts the answer on the canvas next to that frame.
- **Grounded in:** landscape gap generator × accessibility (count 0 in the catalog's gap grid)
- **Landscape:** better than accessibility-audit because it draws the focus order on the canvas as a handoff artefact instead of reporting it as a finding

- **Runs in:** both — supported today: creating frames and reading layer order are supported, and the overlay is built on a duplicate
- **Risk:** adds a duplicate frame and markers beside the source; the source is never edited
- **Cost:** about 41 credits per screen (23 to read the order plus 18 to place the markers, from the observed cost model)
- **Build effort:** medium — an ordering rule, a marker layout, and a jump check
- **Pairs with:** fm-target-size-audit
- **Confirm before building:** Is the target web or native, since tab order differs? Should markers use a fixed colour from the file's variables?

Which one should I build first? 1 to 5, or tell me what to change.
```

## Round 2, Run C: "make our marketing pages better"

Prompt: "make our marketing pages better". Grounding answer: "every landing page starts from a blank frame and drifts off brand". The deck follows verbatim inside the fence.

```markdown
## Concept cards for: "every landing page starts from a blank frame and drifts off brand"

- **Mapping:** layout, components, variables, colour, and type (a page built from nothing that slides away from the brand); workflow, audit, conventions, generator, and synthesis
- **Observed:** no file inspected
- **From the catalog:** read generator × layout (5 rows, not a gap), generator × variables, conventions × colour, and the empty cells workflow × layout, audit × type, and synthesis × layout (all count 0)

### 1. /fm-landing-page-scaffold — Never start from blank again

- **Does:** Builds a landing page in a new frame from the library's components and variables in checked stages, then reads it back and lists every fill or text layer not bound to a brand variable or style. Use whenever the user asks to "start a landing page", "build a marketing page", "set up a page from the brand", or "scaffold a page from the design system". Not for checking a finished page against the design system (use follow-ds-guidelines).
- **Type:** workflow → `templates/type-workflow-process.md`
- **Category:** Generation
- **Cell:** workflow × layout
- **Tier:** B plausible

- **Reads:** selection (an optional reference page), variables and styles, the connected library's components
- **Writes:** after confirmation — a new frame of sections, built only after the section list is confirmed; nothing existing is touched
- **Produces:** new frame beside the source reference page, or at the page origin when none is selected, plus a binding read-back in chat
- **Needs:** a connected library or a file with brand components, colour variables, and text styles; a standard section list or a reference landing page
- **Try it:** "Scaffold a landing page for the spring campaign from our design system: hero, three features, proof, pricing, footer."
- **Sample output:** "Built 6 sections in frame 'Landing / Spring'. Read-back: 41 of 43 fills and 28 of 29 text layers bound; unbound: footer divider fill (#E6E6E6), tagline text (no style)."

- **Fits your moment:** It replaces the blank frame, the moment where "every landing page starts" by hand, with a build from the brand's own components and variables.
- **Grounded in:** landscape gap workflow × layout (count 0)
- **Landscape:** better than build-from-prd because it assembles from the team's own library components and variables and ends with a brand-binding read-back, instead of working from a PRD

- **Runs in:** both — supported today in the Figma agent in Design (generate in a new frame, library search, apply variables) and over MCP; prototype links are left to the user
- **Risk:** adds one new frame and edits nothing else; the section list is confirmed before any build
- **Cost:** about 40 credits per page (about 10 to confirm the section list, about 18 per five sections built, scaled to eight sections)
- **Build effort:** medium — five-stage instruction, one section-recipe table, a read-back helper, two questions
- **Pairs with:** follow-ds-guidelines for later checks of the finished page
- **Confirm before building:** Which library or collection holds the brand components and variables? Which sections does a standard landing page contain, in order?

### 2. /fm-type-style-drift-audit — Unstyled text, caught before handoff

- **Does:** Audits the selected frames for text layers that carry no text style or drift from their style's size, weight, or line height, and lists each with the nearest local or library style; it applies a style after the user confirms. Use whenever the user asks to check typography, find unstyled text, audit text styles, or clean up type before handoff. Not for building a new type scale (use make-a-type-scale) or rewriting copy.
- **Type:** audit → `templates/type-standards-qa-audit.md`
- **Category:** Design systems
- **Cell:** audit × type
- **Tier:** A build-ready on a proven pattern

- **Reads:** selection, variables and styles
- **Writes:** after confirmation — text style bindings on the confirmed rows only
- **Produces:** chat report, then bindings
- **Needs:** nothing beyond a selection; a local or connected library with text styles
- **Try it:** "Check the type on this landing page against our text styles and fix what drifted."
- **Sample output:** "| Hero subhead | Inter 19 / 28, no style | Body/Large (18 / 28) | restyle |"

- **Fits your moment:** It finds the text that "drifts off brand" because someone typed it by hand on a fresh frame.
- **Grounded in:** landscape gap audit × type (count 0)
- **Landscape:** new — no row audits text-style usage on its own, and make-a-type-scale generates a scale instead

- **Runs in:** both — supported today (reading and applying text styles; fonts loaded before each text edit)
- **Risk:** restyles text layers file-wide only on confirmed rows; the source frames are duplicated first
- **Cost:** about 40 credits per page (22 to 24 for the audit, about 18 per five styles applied)
- **Build effort:** small — repeats the fm-spacing-rhythm-audit shape on text styles; one helper, two questions
- **Pairs with:** make-a-type-scale for building the scale itself
- **Confirm before building:** Which text styles are the brand set, local or from a named library? How many pixels of size drift count as the same style?

### 3. /fm-brand-colour-snap — Snap stray colours to brand

- **Does:** Matches every fill and stroke in the selected frames to the nearest brand colour variable, lists each with its distance, and binds only those within a threshold the user confirms, leaving the rest flagged as off-brand. Use whenever the user asks to "snap colours to the brand", "fix off-brand colours", "bind this page to our palette", or "find colours that are not in the system". Not for building a palette or starter system from scratch (use design-system-gen).
- **Type:** conventions → `templates/type-design-system-conventions.md`
- **Category:** Brand
- **Cell:** conventions × colour
- **Tier:** B plausible

- **Reads:** selection, variables and styles
- **Writes:** after confirmation — variable bindings on fills and strokes within the confirmed distance
- **Produces:** chat report, then bindings
- **Needs:** a colour collection holding the brand palette; a selection
- **Try it:** "Bind every colour on this landing page to our brand palette and flag anything that is not in it."
- **Sample output:** "| CTA button fill | #2F5BEA | Brand/Blue 500 (#2E5AE8) | distance 3 | bind |"

- **Fits your moment:** It pulls the colours that "drift off brand" back to the palette and shows which ones no brand colour is near.
- **Grounded in:** the user's answer alone
- **Landscape:** better than apply-color-variables because it measures each colour's distance from the nearest brand colour and flags what lies beyond the threshold instead of forcing a bind

- **Runs in:** both — supported today (apply variables; MCP probe confirmed the variable reads)
- **Risk:** rebinds fills and strokes on the selection only, confirmed row by row; the source is duplicated first and shared styles are never edited
- **Cost:** about 41 credits per page with five changes (about 23 to list the fills, about 18 per five bindings)
- **Build effort:** medium — a colour-distance rule with a stated formula, a threshold question, a bind helper
- **Pairs with:** design-system-gen for creating the palette
- **Confirm before building:** Which collection is the brand palette? What distance, in RGB steps, counts as the same colour?

### 4. /fm-spacing-variables-from-usage — Tokens from spacing you ship

- **Does:** Derives a spacing scale from the padding and gap values actually used in the selected frames, ranks them by frequency, and creates number variables in a collection the user names after confirmation. Use whenever the user asks to create spacing tokens, turn spacing into variables, or build a spacing scale from an existing design. Not for snapping off-grid values (use fm-spacing-rhythm-audit).
- **Type:** generator → `templates/type-generation-builder.md`
- **Category:** Design systems
- **Cell:** generator × variables
- **Tier:** B plausible

- **Reads:** selection, variables and styles
- **Writes:** after confirmation — number variables in the named collection
- **Produces:** bindings, with a ranked scale table in chat first
- **Needs:** a selection of existing landing pages; no spacing collection yet (it creates one)
- **Try it:** "Make spacing variables from the padding and gaps our three landing pages already use."
- **Sample output:** "| 24 | used 61 times | proposed Space/6 | |"

- **Fits your moment:** It gives the next blank frame a spacing scale taken from the pages the team already shipped, so new pages stop drifting.
- **Grounded in:** landscape gap generator × variables (count 1)
- **Landscape:** better than design-system-gen because it derives the scale from values already in use, ranked by frequency, instead of from a style guide

- **Runs in:** both — supported today (author variables; MCP probe returned available for the collection reads)
- **Risk:** creates variables in one named collection and binds nothing; the scale is confirmed before creation
- **Cost:** about 51 credits per run for a five-step scale (about 23 to collect values, about 10 to confirm, about 18 per five variables created)
- **Build effort:** medium — a value-collection helper, a frequency table, a confirm step, a create step
- **Pairs with:** fm-spacing-rhythm-audit for snapping off-grid values to the new scale
- **Confirm before building:** What should the collection be called? Round values to the nearest 4 px or keep them exact?

### 5. /fm-layout-template-digest — Wildcard: mine your own pages

- **Does:** Groups the screens in the selected flow by layout structure, such as column count, header pattern, and content grid, and names each recurring template with its screens and the one-offs that match none. Use whenever the user asks which layouts a flow repeats, wants to find page templates, or asks how consistent the screen structure is. Not for spacing or alignment checks (use visual-consistency-check).
- **Type:** synthesis → `templates/type-research-synthesis.md`
- **Category:** Workflows
- **Cell:** synthesis × layout
- **Tier:** B plausible

- **Reads:** selection, page
- **Writes:** none — it reports in chat and changes nothing
- **Produces:** chat report
- **Needs:** a selection of existing landing pages or screens; at least four to find a pattern
- **Try it:** "Which landing page layouts have we actually repeated, and which pages are one-offs?"
- **Sample output:** "Template A (hero, 3-up features, proof, CTA) appears on 7 of 11 pages; 2 pages match none."

- **Fits your moment:** It shows which landing page layouts the team already repeats, so the blank frame can start from a real template instead of from scratch.
- **Grounded in:** landscape gap synthesis × layout (count 0)
- **Landscape:** better than visual-consistency-check because it names the templates a flow already follows instead of flagging inconsistencies

- **Runs in:** both — supported today on the current page; loading every page is not implemented in-app, so the digest names the page it read
- **Risk:** read-only
- **Cost:** about 23 credits per page of screens (from the observed page-scale audit cost, read-only)
- **Build effort:** small — reads frame structure only; one grouping rule and one output table
- **Pairs with:** visual-consistency-check for spacing and alignment checks; fm-landing-page-scaffold to build from a named template
- **Confirm before building:** Which page holds the landing pages? How many columns of difference count as a different layout?

Which one should I build first? 1 to 5, or tell me what to change.
```

## Round 2 assertion results

These come from the same script as round 1, run over the three round-2 decks on 2026-11-03 UTC. It passes every Does line to `node scripts/validate-figma-skill.mjs --description` and checks each named gap against the catalog's gap grid (a gap has a count of 0 or 1).

| Check | Run A | Run B | Run C |
| --- | --- | --- | --- |
| Exactly twenty labelled lines per card, in order | 5 of 5 | 5 of 5 | 5 of 5 |
| Does line: exit 0 with 0 errors and 0 warnings | 5 of 5 | 5 of 5 | 5 of 5 |
| Name matches `^/fm-[a-z0-9]+(-[a-z0-9]+)*$` | 5 of 5 | 5 of 5 | 5 of 5 |
| Five distinct cells | yes | yes | yes |
| Cards from an empty cell (count 0) | 2 | 3 | 3 |
| Plan-only cards (at most one, never card 1) | 0 | 0 | 0 |
| Runs in claims "supported today" for prototyping, vectors, slots, asset export, or diagrams | none | none | none (one keyword hit, judged below) |
| Writes is none, after confirmation, or always | 5 of 5 | 5 of 5 | 5 of 5 |
| Grounded in names a seed, gap, observation, or the answer | 5 of 5 | 5 of 5 | 5 of 5 |
| A named gap really is a gap (count 0 or 1) | 2 of 2 | 3 of 3 | 4 of 4 |
| Landscape starts with "new" or "better than", and X is a landscape row | 5 of 5 | 5 of 5 | 5 of 5 |
| Card 5's hook says wildcard | yes | yes | yes |
| Deck ends with the footer question | yes | yes | yes |

The one keyword hit: Run C card 1's Runs in line contains both "supported today" and "prototype". Read in full, "supported today" covers generating in a new frame, library search, and applying variables, and the line ends "prototype links are left to the user". It does not claim prototyping, so the check passes. Every round-1 finding is gone: no Does line warns, and every gap a card names has a count of 0 or 1.
