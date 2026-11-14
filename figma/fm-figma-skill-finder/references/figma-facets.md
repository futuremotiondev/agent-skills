# Figma facet taxonomy

Use in step 2 to decompose the topic, pick search vocabulary for both registers (designer-facing
Community authors vs. engineer-facing MCP authors), and pre-load the fingerprint that tells a real
skill for the facet from a plugin, template, or README mention. Exemplars are **what was verified on
2026-10-25**, named so you can confirm they still exist — they are not a catalog, and every one must
be re-fetched in the run. "Community" and "MCP" columns say where coverage was observed.

The `products` argument filters by the **product surface** column; a topic usually spans several
facets, and a facet often spans several products.

## Product-surface matrix

| Product | URL / context | Agent write surface | First-party skills | MCP tools | Community coverage |
|---|---|---|---|---|---|
| Figma Design | `figma.com/design/<key>` | Yes (`use_figma`, `generate_figma_design`, `html_to_figma`) | `figma-use`, `figma-generate-design`, `figma-generate-library`, `figma-design-to-code`, `figma-swiftui`, `figma-create-new-file` | `get_design_context`, `get_metadata`, `get_screenshot`, `get_variable_defs`, `search_design_system`, `get_libraries`, `download_assets`, `upload_assets` | Dense — most of the ~300 Community skills |
| FigJam | `figma.com/board/<key>` | Yes (`use_figma` with FigJam context, `generate_diagram`) | `figma-use-figjam`, `figma-generate-diagram`, `workflow-skills/generate-project-plan` | `get_figjam`, `generate_diagram`, `create_new_file` | Thin — `create-figjam-content`, `figjam-builder`, `workshop-board` (MCP); agent in FigJam "coming soon" |
| Figma Slides | `figma.com/slides/<key>` | Yes (`use_figma` with Slides context) | `figma-use-slides` | `create_new_file` (Slides) | One MCP skill (`build-slides-figma`); agent "coming soon" |
| Figma Make | `figma.com/make/<key>` | Import only (`send_code_to_figma`); Make reads MCP resources | `figma-code-workflows` | `send_code_to_figma`; MCP resources for Make project files | **A skill host** — every Community skill runs in Make; Make accepts only single-file skills. Vendors: Carbon `/carbon-builder-figma-make-react`, shadcndesign, Uxcel product-skills |
| Dev Mode / design-to-code | Dev Mode panel, "MCP → Copy example prompt" | Read | `figma-design-to-code`, `figma-swiftui`, `figma-implement-motion` | `get_design_context`, `get_screenshot`, `get_variable_defs`, `get_code_connect_map` | Dense MCP coverage (vendors, mirrors); Community: "handoff" category |
| Code Connect | `figma.config.json`, `*.figma.ts` | Write (`add_code_connect_map`, `send_code_connect_mappings`) | `figma-code-connect` | `get_code_connect_map`, `get_code_connect_suggestions`, `get_context_for_code_connect`, `add_code_connect_map`, `send_code_connect_mappings` | MCP only; plan-gated (Org/Enterprise; parsers frozen → `.figma.ts` templates) |
| Variables / tokens | Variables panel; REST `/v1/files/:key/variables/*` (Enterprise) | Via `use_figma` scripts; REST write Enterprise-only | `figma-generate-library` (`scripts/createVariableCollection.js`, `bindVariablesToComponent.js`) | `get_variable_defs` | Dense in both — Community `build-a-variable-library`, `make-a-type-scale`, `create-color`; MCP `export/import/manage-variables-figma`, `setup-design-tokens-figma`, `sync-figma-token`, `cc-figma-tokens`, `generate-tokens-from-figma` |
| Figma Specs | `SPEC_BLOCK` node; `whoami → specs_enabled` | Yes via `use_figma` | `figma-spec` | `use_figma`, `whoami` | MCP: `annotations-figma`, uSpec `create-*`; open beta |
| Motion | Motion panel (Config 2026, open beta) | Yes | `figma-use-motion`, `figma-implement-motion` | `get_motion_context` | Community `camera-pan-and-zoom` (Figma); thin elsewhere |
| Shaders / generative plugins | Tools tab; `main.ts` / `code.ts` + `ui.html` | Yes (`create_shader`, `create_generative_plugin`, …) | `figma-shaders`, `figma-generative-plugins` | 9 tools (+4 deprecated `*_shader_effect/fill`) | Community `shader-starter` (Figma). Credits once GA |
| Weave | `/community/tools`, `/community/ai-workflows` | Yes, paid Weave account | none | 9 `weave_*` tools | **None** — Weave consumes no skills; AI workflows are node graphs |
| Sites · Buzz · Draw | `/community/file/…` templates | **No agent write surface** (`use_figma` covers `/design/`, `/board/`, `/slides/`) | none | none | **None observed** — report as Uncovered when asked, with the reason |

## Facets

Each entry: what the facet is · author vocabulary (both registers) · the fingerprint · exemplars.

### 1. Design-to-code implementation
Turn a Figma frame into production code in a target framework, honoring the project's components and tokens.
**Vocabulary:** "implement design", "design context", "Figma to React/SwiftUI/Compose/Tailwind", "pixel-perfect", "handoff", "Dev Mode", "example prompt"; Community register: "build what I designed", "export to code".
**Fingerprint:** `get_design_context` (often with `get_screenshot`, `get_variable_defs`, `get_code_connect_map`); no `use_figma`.
**Exemplars:** `figma-design-to-code` (official; alias `figma-implement-design` in OpenAI/Warp), `figma-swiftui`, `cds-design-to-code` (Coinbase), Spirit `figma-to-code`, `shadcn-design-figma-to-code` (paid), `terminalskills/figma-to-code`, `t4sh figma-to-code`, `absolutelyskilled/figma-to-code`.

### 2. MCP setup and usage patterns
Connecting an agent to `mcp.figma.com`, auth, rate limits, choosing tools, prompt hygiene.
**Vocabulary:** "Figma MCP", "connect Figma", "mcp.figma.com", "Dev Mode MCP", "OAuth", "rate limit", "tool not loading".
**Fingerprint:** body configures `mcp.figma.com/mcp` or compares tools; a bundled MCP-config reference file (OpenAI's curated skill ships `figma-mcp-config.md`).
**Exemplars:** OpenAI `.curated/figma` (setup + troubleshooting), `agent-playbook/figma-designer`, techleads.club "Figma MCP". Figma's own docs sub-pages (`remote-server-installation/`, `tools-not-loading/`, `rate-limits-access/`) are the gap-fill references.

### 3. Code Connect mapping
Writing and maintaining `.figma.ts` templates that map components to code snippets for Dev Mode and the MCP server.
**Vocabulary:** "Code Connect", "component mapping", "`.figma.ts`", "parserless template", "Dev Mode snippet", "`figma.code`", "connect components".
**Fingerprint:** `.figma.ts`, `get_code_connect_suggestions`, `add_code_connect_map`; mentions parser freeze.
**Exemplars:** `figma-code-connect` (official; alias `figma-code-connect-components`), `cc-figma-component` (One North), Carbon's auto-published Code Connect (context). Tools, not skills: `Coderrob/figma-connecter`, `JFusco/design-passport`.

### 4. Design tokens and variables — export, import, sync
Variables ↔ DTCG/Style Dictionary/Tokens Studio/CSS/Tailwind/SCSS; drift detection; collection and mode setup.
**Vocabulary:** "variables", "design tokens", "DTCG", "W3C tokens", "Style Dictionary", "Tokens Studio", "modes", "light/dark", "sync tokens", "drift"; Community: "variable library", "type scale", "color system".
**Fingerprint:** `get_variable_defs`; `use_figma` creating `VariableCollection`; REST `/variables/local` (Enterprise); DTCG JSON in `references/`.
**Exemplars:** MCP — southleft `export-tokens-figma`, `import-tokens-figma`, `manage-variables-figma`, `library-variables-figma`, `setup-design-tokens-figma`; Firebender `sync-figma-token`; One North `cc-figma-tokens`; `generate-tokens-from-figma`; `robukh/figma-suite` Sync Tokens; `oakoss/figma-developer` (REST); official `figma-generate-library`. Community — `build-a-variable-library` (UI Collective), `make-a-type-scale`, `create-color`.

### 5. Plugin-API scripting via `use_figma`
Writing JavaScript the MCP server executes against the open file: batch edits, node creation, auto-layout, instance swaps.
**Vocabulary:** "use_figma", "Plugin API", "figma.createFrame", "batch rename", "gotchas", "scripting", "automation inside the file".
**Fingerprint:** `use_figma` + `skillNames`; `references/plugin-api-standalone.d.ts` or `gotchas.md`; `plugin-api-patterns.md`.
**Exemplars:** `figma-use` (official; the mandatory gate), `figma-maxxing` ("90 Plugin API gotchas"), `Hosseinkm89/figma-skills` batch ops, `robukh/figma-suite` reference. **Flag `plugin-api-exec`** on all of these.

### 6. Plugin and widget development
Building classic plugins/widgets (`manifest.json`, `@figma/plugin-typings`) or generative plugins/shaders.
**Vocabulary:** "Figma plugin", "manifest.json", "editorType", "widget", "FigJam widget", "generative plugin", "shader", "PropsKit", "code.ts / ui.html".
**Fingerprint:** mentions of manifest fields or `@figma/plugin-typings` inside a `SKILL.md`; `create_generative_plugin` / `create_shader`.
**Exemplars:** `figma-generative-plugins`, `figma-shaders` (official, generative only); `aiskillstore/marketplace` `7nohe/figjam-plugin` (classic). **No first-party skill for classic plugin development** — `figma-use`'s bundled `.d.ts` is the closest asset. Community `shader-starter`.

### 7. REST API automation
Files, versions, comments, components, projects, team management, image export via personal access token — no MCP.
**Vocabulary:** "Figma REST API", "personal access token", "`/v1/files`", "version history", "comments", "export images", "CI", "GitHub Action".
**Fingerprint:** `FIGMA_TOKEN` / `FIGMA_ACCESS_TOKEN`; `api.figma.com/v1/`; `figma/rest-api-spec`.
**Exemplars:** `a5c-ai/babysitter figma-api`, `oakoss/figma-developer`, PatternFly `figma-diff`, southleft REST skills (version history, changelog, blame, comments), `ComposioHQ figma-automation`, `planetabhi/figma-mcp-server` `figma-agent` (50 REST tools). **Flag `rest-token`.**

### 8. FigJam and diagrams
Stickies, sections, connectors, tables; Mermaid → FigJam; workshop boards; project plans.
**Vocabulary:** "FigJam", "board", "sticky", "diagram", "flowchart", "Mermaid", "workshop", "retro", "project plan", "`figma.com/board/`".
**Fingerprint:** `get_figjam`, `generate_diagram`, `use_figma` with FigJam node types (`create-sticky.md`).
**Exemplars:** `figma-use-figjam`, `figma-generate-diagram`, `generate-project-plan` (official); `create-figjam-content` (southleft), `figjam-builder` (prasantloki), `workshop-board` (mariespreitzer). Community library: thin until the FigJam agent ships.

### 9. Figma Slides
Decks, sections, themes, speaker notes.
**Vocabulary:** "Slides", "deck", "presentation", "speaker notes", "`figma.com/slides/`".
**Fingerprint:** `use_figma` with Slides context; `references/slide-*.md`.
**Exemplars:** `figma-use-slides` (official), `build-slides-figma` (southleft). Expect **Partial** at best.

### 10. Figma Make and in-app agent skills
Skills designed to run inside Figma: Make app-building guidance, agent custom skills, brand/UX writing voice, critique frames.
**Vocabulary:** "Figma agent", "Figma Make", "slash command", "custom skill", "Add skill", "Make kit", "template".
**Fingerprint:** a Community page, or a single-file `SKILL.md` whose README documents upload into the Figma agent (`equalexperts/kuat-agent-rules` `figma-make.md`); vendor variants with `-figma-make-` in the name.
**Exemplars:** the whole Community library (`better-interface` 5.1k users, `usability-test-guide`, `figma-ux-writing-style`, `font-pairings`, `desktop-to-mobile`, `superfuture-design-review`); Carbon `/carbon-builder-figma-make-react`; shadcndesign design skills; Uxcel `product-skills` (59). The plugin "SKILLS for Figma Agent Design" distributes 60+ uploads.

### 11. Design-system audit and compliance
Lint a file against a library: detached instances, hard-coded values, naming, token adherence, readiness scores.
**Vocabulary:** "audit", "lint", "compliance", "detached", "hard-coded", "parity", "readiness score", "design system health"; Community: "design crit", "review my file".
**Fingerprint:** `get_metadata` + `get_variable_defs` traversal, or `use_figma` read scripts; scoring rubric in body.
**Exemplars:** `audit-design-system`, `apply-design-system`, `fix-design-system-finding` (Edenspiekermann), `ds-compliance-audit`, `check-design-parity-figma`, `lint-design-figma`, `design-system-inventory-figma`, `natdexterra/work-with-design-systems` (six modules, 0–100), `figma-maxxing figma-slop-check`, `robukh` audit. Community "Design systems" and "Critique" hubs.

### 12. Accessibility review
Contrast (WCAG / APCA), target sizes, reading order, screen-reader specs, axe findings mapped to Figma.
**Vocabulary:** "accessibility", "a11y", "WCAG", "APCA", "contrast", "AA/AAA", "screen reader", "voice", "axe-core".
**Fingerprint:** contrast math in body; `get_screenshot` + `get_metadata`; `use_figma` annotation frames.
**Exemplars:** `apca-compliance-figma` (Merkle-XDI), `audit-accessibility-figma`, `scan-code-accessibility-figma` (southleft), `accessibility-contrast-audit` (Hosseinkm89), uSpec `create-voice` (Uber). Community "Critique" hub.

### 13. Code-to-design generation (write to canvas)
Generate screens, libraries, or components in Figma from code, HTML, prototypes, or a PRD.
**Vocabulary:** "generate design", "code to design", "HTML to Figma", "prototype to Figma", "import my app", "build library from code", "componentize", "screens from PRD".
**Fingerprint:** `generate_figma_design`, `html_to_figma`, `use_figma` creation scripts, `search_design_system`.
**Exemplars:** `figma-generate-design`, `figma-generate-library` (official), `bridge-ds` (noemuch), `ds-init-figma`, `reconstruct-component-figma`, `cc-figma-component`, `prototype-to-figma`, `bulk-capture` (tallneil; Chrome DevTools MCP + `generate_figma_design`), `robukh` build-library, `Klionskiy` mobile MVP skills. **Flag `write-canvas`.**

### 14. Component analysis, documentation, and API design
Inspect component sets; derive props/variants; write docs or a React API from them; anatomy specs.
**Vocabulary:** "component set", "variants", "properties", "anatomy", "component doc", "props API", "spec".
**Fingerprint:** `get_metadata` deep traversal; `get_code_connect_map`; outputs Markdown docs or TS interfaces.
**Exemplars:** `analyze-component-set-figma`, `arrange-component-set-figma`, `component-properties-figma`, `deep-component-figma`, `generate-component-doc-figma` (southleft), `design-react-api` (bitovi), uSpec `create-anatomy`, `create-property`, `create-api`.

### 15. Layer hygiene, naming, and auto-layout
Rename layers, enforce spacing scales, convert absolute positioning to auto layout, arrange sets.
**Vocabulary:** "rename layers", "auto layout", "spacing", "8pt grid", "tidy", "organize", "constraints".
**Fingerprint:** `use_figma` scripts mutating `layoutMode`, `itemSpacing`, `name`.
**Exemplars:** `figma-rename-layers`, `auto-layout-refactor` (Hosseinkm89), `rad-spacing` (Rad Collab), `arrange-component-set-figma`, `robukh` naming conventions. **Flag `plugin-api-exec`.**

### 16. Prototyping and flows
Add prototype connections, click flows, screen-to-screen arrows, interactive previews.
**Vocabulary:** "prototype", "click flow", "interactions", "reactions", "user flow", "navigate to".
**Fingerprint:** `use_figma` setting `reactions`; `prototype-to-figma` imports.
**Exemplars:** `figma-maxxing figma-click-flow`, `prototype-to-figma`. Thin — likely **Partial**.

### 17. Annotations, specs, and handoff
Dev-ready annotations, measurement/redline frames, Figma Specs, handoff gates.
**Vocabulary:** "annotations", "redlines", "specs", "handoff", "dev ready", "measurements", "Specs block".
**Fingerprint:** `figma-spec` / `SPEC_BLOCK`; `use_figma` annotation frames; `get_design_context` export for handoff docs.
**Exemplars:** `figma-spec` (official, beta, `specs_enabled`), `annotations-figma`, uSpec `create-structure`, `orchestkit figma-design-handoff`, `figma-maxxing figma-handoff-gate`. Community "handoff" category exists in copy but has no hub.

### 18. Design critique, UX process, and research
Heuristic critique, UX laws, delight audits, IA from screens, usability test guides, design narratives, product-direction skills.
**Vocabulary:** "critique", "design review", "heuristics", "UX laws", "usability test", "IA", "narrative", "research synthesis", "persona".
**Fingerprint:** mostly instruction-only; may read via `get_screenshot`.
**Exemplars:** Community — `usability-test-guide` (Figma), `better-interface`, `superfuture-design-review`, the "Research and strategy" and "Critique" hubs; MCP — `throughline-skill`, `delight-audit`, `design-narrative`, `screens-to-ia`, `figma-product-design-director`, Uxcel `product-skills`. Expect Community to outscore MCP here.

### 19. Brand, content, and localization
Brand voice, UX writing style, copy generation, string extraction → i18n keys.
**Vocabulary:** "brand", "voice and tone", "UX writing", "copy", "microcopy", "localization", "i18n", "strings", "translate".
**Fingerprint:** text-node traversal (`characters`), CSV/JSON output; Community "Brand" hub and `copy-content` tag.
**Exemplars:** Community — `figma-ux-writing-style` (Figma), `font-pairings`, Brand hub; MCP — `localeflow` (loshoc), `create-voice` (Uber, also a11y).

### 20. Agent rules and design-system rules generation
Produce `CLAUDE.md` / `AGENTS.md` / `.cursor/rules/*.mdc` sections that encode a design system for coding agents.
**Vocabulary:** "design system rules", "rules file", "CLAUDE.md", "AGENTS.md", "cursor rules", "steering".
**Fingerprint:** the MCP prompt `create_design_system_rules`; outputs rules files, not designs.
**Exemplars:** OpenAI's `figma-create-design-system-rules` (older skill form), Figma's `figma-power/steering/create-design-system-rules.md`, `natdexterra` Phase 6. **Outputs are Adjacent config**, the skills that produce them are in scope.

### 21. Versioning, comments, and collaboration
Version history diffs, changelogs, blame, comment triage and fix loops.
**Vocabulary:** "version history", "diff", "changelog", "what changed", "comments", "resolve comments", "blame".
**Fingerprint:** REST `/versions`, `/comments`; `figma-comment-fix-loop`.
**Exemplars:** southleft REST skills, PatternFly `figma-diff`, `figma-maxxing figma-comment-fix-loop`. **Flag `rest-token`.**

### 22. Motion and animation
Keyframes, animation styles, motion → code (motion.dev, CSS), camera pan/zoom.
**Vocabulary:** "Figma Motion", "keyframes", "animation", "transitions", "motion tokens", "pan and zoom".
**Fingerprint:** `get_motion_context`; `references/motion-*.md`.
**Exemplars:** `figma-use-motion`, `figma-implement-motion` (official), Community `camera-pan-and-zoom` (Figma). New surface (Config 2026) — thin third-party coverage is expected, not a search failure.

### 23. Media and recordings → Figma
Video or screen recordings turned into annotated storyboards or flows; asset import/export.
**Vocabulary:** "recording", "storyboard", "video to Figma", "screenshots to flow", "asset export", "icons as SVG".
**Fingerprint:** `upload_assets`, `download_assets`, `generate_image`; `workflow-skills/`.
**Exemplars:** `video-interaction-mapper` (official, standalone), `oakoss/figma-developer` SVG icon export. Thin.

## Facets that are Uncovered by construction (say so, don't search forever)

- **Sites, Buzz, Draw** — no agent write surface and no skills observed on either surface.
- **Weave** — nine MCP tools exist but no skill consumes them; Weave itself runs no skills.
- **Classic plugin development, first-party** — Figma ships none; only generative-plugin skills.
- **Figma agent in FigJam/Slides** — announced "coming soon" at Config 2026; Community skills for those editors cannot exist yet.

For each, the gap analysis should still propose the skill a user would author (facet 6 and 8/9 are
the realistic build opportunities) and point at the closest official skill to fork.
