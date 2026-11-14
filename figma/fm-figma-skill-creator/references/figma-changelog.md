# Figma changelog for skill authors

A dated record of the changes to Figma, the Figma MCP server, Figma's official skills and the Plugin API that affect how a skill is written. The newest row is first. `references/agent-capabilities-and-tools.md` holds the current state of each runtime; this file holds how it got there.

<!-- last-reviewed -->

- Last reviewed: 2026-11-13
- Reviewed against: figma/mcp-server-guide at 5f3024c (plugin 2.2.208); Figma release notes and Plugin API updates through 2026-11-13; probe 1.2 runs of 2026-11-13
- Review again: when the Figma plugin updates, when a probe row changes, or 60 days after the date above

<!-- /last-reviewed -->

## How to add a row

1. One row per change.
2. Never edit or delete an old row. Add a new row that corrects it, and say in its Change cell which row it corrects (by date and track).
3. No pipe character inside a cell, not even inside a code span. Write the value in words instead.
4. A row carries a source a reader can open, or the name of our own run record listed under Source keys.
5. After adding rows, update the review block above.

## Changes, newest first

Track is one of `Product`, `MCP`, `Official skills`, `Plugin API`, `Observed`, and rows within one date follow that order. Basis is `documented` (stated on a Figma-owned page or repository), `observed` (seen in one of our own runs; the Source cell names the run record), or `secondary` (reported elsewhere and not confirmed).

| Date | Track | Change | What it means for skill authors | Source | Basis |
| --- | --- | --- | --- | --- | --- |
| 2026-11-13 | Product | Corrects the 2026-11-05 Product row, which read as having no effect on skills: the release note and Figma's vectors help page document that the agent generates vector icons and illustrations and accepts reference illustrations as a style source, while the agent's feature table still lists Create icons as coming soon | A skill may now ask the agent to generate icons or illustrations, and must still check the result for conformance to the style; editing existing vector paths is still coming soon, so keep it plan-only. | RN | documented |
| 2026-11-13 | Official skills | Version 2.2.208: `figma-generate-design` drops its `html_to_figma` exception rules | Re-read `figma-generate-design` before writing a target:mcp section that imports HTML, and do not carry the removed exception rules over. | MSG | documented |
| 2026-11-13 | Observed | `use_figma` still refuses a return over 48,000 bytes, with the same error text as on 2026-11-03, and the refusal discards that call's canvas edits | Measure the serialized return before returning it, and never write to the canvas and return a large report in the same call. | MCP probe 2026-11-13 | observed |
| 2026-11-13 | Observed | In-app, a return of about 55,000 bytes (a 50,000-character payload plus 43 rows) arrived whole; on 2026-11-03 about 53,000 bytes did not | Size every return for MCP, now the stricter runtime at 48,000 bytes, not for the higher in-app limit. | Probe 1.2 2026-11-13; Browser run 2026-11-13 | observed |
| 2026-11-13 | Observed | Both script tools take a result only from `return`; an async function that is wrapped and invoked but never returned yields nothing in-app | Write every helper with top-level `await` and a final `return`, with no function wrapper, so it runs as written in both runtimes. | Probe 1.2 2026-11-13 | observed |
| 2026-11-13 | Observed | `saveVersionHistoryAsync` and `commitUndo` are functions that throw "not a supported API" when called, in both runtimes | Never checkpoint through version history; duplicate the page or frame instead, and test an API by calling it, not by `typeof`. | MCP probe 2026-11-13; Probe 1.2 2026-11-13 | observed |
| 2026-11-13 | Observed | `figma.spec` exists in Design files as well as in Spec files | Never use the presence of `figma.spec` to detect a Spec file; read `figma.editorType` instead. | MCP probe 2026-11-13 | observed |
| 2026-11-13 | Observed | `figma.editorType` reads `figspec` in a standalone Spec file, over MCP and in-app | Branch every surface check on `figspec` and treat that surface as one with no canvas to edit. | MCP probe 2026-11-13; Browser run 2026-11-13 | observed |
| 2026-11-13 | Observed | A standalone Spec file has no canvas API: `createFrame`, `createText`, `createPage`, `figma.annotations` and `figma.motion` are absent | Skip every canvas or write step in a Spec file and say so, instead of letting the call throw. | MCP probe 2026-11-13; Browser run 2026-11-13 | observed |
| 2026-11-13 | Observed | `Object.keys(figma.spec)` is empty although its eight members (five methods and three comment methods) are functions reachable by name; `getBlockContent` among them throws when called over MCP | Test Specs members by name, never by enumerating keys, and do not rely on `getBlockContent`. | MCP probe 2026-11-13; Probe 1.2 2026-11-13 | observed |
| 2026-11-13 | Observed | The Specs content and comment methods work over MCP. `editContent` with zero matches fails with `edit 1 failed — text not found in the current document. ... Re-read with figma.spec.getContent() and retry.` and with two matches fails with `edit 1 failed — found 2 matches for the provided oldText. Include more surrounding context to make the match unique.` | Give each `editContent` edit enough surrounding text to match exactly once; on either error, re-read with `getContent` and retry. | MCP probe 2026-11-13 | observed |
| 2026-11-13 | Observed | `figma.spec.comments.create` fails with HTTP 400 `Bad request` when it anchors on text written earlier in the same call; anchoring on older text works | Write or edit Spec content in one call and add comments on that text in the next call. | MCP probe 2026-11-13 | observed |
| 2026-11-13 | Observed | `getContent` returns normalised Markdown: the table separator row comes back in a shorter form, two blank lines follow the title heading, and the trailing newline is dropped | Verify a Spec write with `includes` checks on the sentences that matter, never with a byte-for-byte compare. | MCP probe 2026-11-13 | observed |
| 2026-11-13 | Observed | `figma.spec.createOnCanvasAsync` places an 850 by 1100 `SPEC_BLOCK` at 0, 0 on a Design page, in both runtimes, and `node.remove()` deletes it | Move a new embedded Spec clear of existing content straight after creating it, and remove it in cleanup when it was temporary. | MCP probe 2026-11-13; Probe 1.2 2026-11-13 | observed |
| 2026-11-13 | Observed | Annotations, PNG export and the 3D transform members are available in both runtimes in a Design file; SVG export is available over MCP | Write findings as annotations and capture before-and-after evidence as PNG exports; both work in either runtime. | MCP probe 2026-11-13; Probe 1.2 2026-11-13 | observed |
| 2026-11-13 | Observed | An installed skill can be edited in place in Manage skills (More actions, Edit, Save) at no credit cost | Push a rebuilt upload edition into an installed skill through Manage skills, Edit, rather than asking the agent, which spends credits. | Probe 1.2 2026-11-13 | observed |
| 2026-11-13 | Observed | The in-app agent lists uploaded skills with a `user-` prefix and Community skills with a `community-` prefix; the slash menu shows the plain name | Expect `user-fm-...` when the agent names an uploaded skill in a test transcript; it is the same skill, not a duplicate. | Browser run 2026-11-13 | observed |
| 2026-11-13 | Observed | Uploaded skills appear in a Spec file's slash menu and fire there; the probe honoured its own surface rule and changed nothing | Test each new skill once in a Spec file, because it loads there and its surface rule must stop or adapt cleanly. | Browser run 2026-11-13 | observed |
| 2026-11-13 | Observed | The in-app agent refuses to name its internal tools, while confirming it can run JavaScript against the file | Learn in-app tool behaviour by running a probe helper, never by asking the agent to list its tools. | Browser run 2026-11-13 | observed |
| 2026-11-13 | Observed | The agent's built-in skills include `audit-design`, `check-designs`, `fix-contrast`, `annotations`, `clean-up-file`, `analyze-tokens` and `create-documentation-page` | Give a skill that overlaps a built-in one a stated reason to exist and a description that routes clearly away from it. | Browser run 2026-11-13 | observed |
| 2026-11-12 | Product | 3D transform ships | Feature-check 3D before posing layers in depth: `transform3d` reads undefined when 3D is not enabled in the session. | RN | documented |
| 2026-11-12 | MCP | `get_comments` tool listed | A target:mcp section may now name `get_comments`, so recon and review skills can read comments over MCP as well as in-app. | MSG | documented |
| 2026-11-12 | Official skills | `figma-3d-transforms` added, version 2.2.207 | Load `figma-3d-transforms` before any target:mcp step that sets depth, and put perspective on the container, never on the posed layer. | MSG | documented |
| 2026-11-12 | Plugin API | `transform3d`, `transformOrigin`, `scene3d` documented as beta; not yet in a typings release | Read these members before writing them and expect no type definitions; treat a 3D step as beta that may change. | Plugin API updates | documented |
| 2026-11-10 | Product | Motion: physics-based springs, style previews | No effect on skills; context only. | RN | documented |
| 2026-11-09 | MCP | `generate_vector_illustration` first referenced in `figma-generate-design` | A target:mcp section that needs icons or illustrations may name `generate_vector_illustration`, with a fallback for hosts that lack it. | MSG | documented |
| 2026-11-05 | Product | Agent-generated vector illustrations and icons improved | No effect on skills; context only. | RN | documented |
| 2026-11-03 | Product | Code layers read prototype connections | No effect on skills; context only. | RN | documented |
| 2026-11-03 | Observed | Probe 1.0 run in the Design agent and over MCP: shared plugin data works; `setPluginData` and `clientStorage` error; a 52,907-byte return was rejected over MCP with a stated 48,000-byte limit | Persist run state with `setSharedPluginData` only, never `setPluginData` or `clientStorage`, and keep every return under 48,000 bytes. | Probe tables 2026-11-03 | observed |
| 2026-11-02 | Product | Shaders generally available | Shader fills may be named in target:figma-app as a shipped feature; route shader authoring itself to fm-figma-shader-creation. | RN | documented |
| 2026-10-27 | Product | Version history for generative plugins and shaders | No effect on skills; context only. | RN | documented |
| 2026-10-26 | MCP | Weave image and video models reachable through MCP | No effect on skills; context only. | RN | documented |
| 2026-10-19 | MCP | `create_session` first appears in `figma-use`; Antigravity plugin support | Call `create_session` with the file key before any file tool in every target:mcp section, and pass its `sessionId` on later calls. | MSG | documented |
| 2026-10-16 | Plugin API | Typings 1.142.0 add `sourceColor` | No effect on skills; context only. | PT | documented |
| 2026-10-15 | Product | Config India: Specs (open beta), code layers (open beta), guidelines (open beta), code sources (closed beta) | Give every surface check a branch for Spec files; a skill whose first rule names only Design and Make stops there. | RN | documented |
| 2026-10-15 | Official skills | `figma-spec` and `figma-code-workflows` added, version 2.2.157 | Load `figma-spec` for any target:mcp step that reads or writes a Spec: edit with `editContent`, verify with `getContent`, never with screenshots. | MSG | documented |
| 2026-10-13 | Official skills | `figma-use-motion` added to the default tree | Load `figma-use-motion` beside `figma-use` in a target:mcp section that adds or edits animation. | MSG | documented |
| 2026-10-06 | Product | Figma agent generally available; library guidelines; generative plugins GA; custom skills on Starter; agent starts using AI credits | Every agent turn now spends AI credits, Starter included: gate scope with a question and state the expected cost of whole-file runs. | RN | documented |
| 2026-10-05 | MCP | `generate_image` guidance released | A target:mcp section may name `generate_image` for raster images; follow its guidance and keep image generation out of the core. | MSG | documented |
| 2026-09-30 | Product | Motion: custom animation styles, audio, text animation, Lottie export | No effect on skills; context only. | RN | documented |
| 2026-09-30 | Plugin API | Typings 1.140.0 add custom animation styles | No effect on skills; context only. | PT | documented |
| 2026-09-25 | Product | Vertical wrap in auto layout | No effect on skills; context only. | RN | documented |
| 2026-09-23 | Plugin API | Typings 1.139.0 add `VariableComposedColor` and the `COLOR_OPACITY` scope | Token skills must expect composed colour variables and the `COLOR_OPACITY` scope, and must not read them as plain RGBA values. | PT | documented |
| 2026-09-10 | Official skills | `skills-figquery/` tree added, served to Cursor only | Port from the `skills/` tree only; the `skills-figquery/` variants are generated for Cursor and are not the reference text. | MSG | documented |
| 2026-09-03 | Product | Opacity controllable in variables | Token audits must accept a variable-bound opacity as conforming instead of flagging it as a raw value. | RN | documented |
| 2026-09-03 | Plugin API | Typings 1.138.0 add variable fonts | No effect on skills; context only. | PT | documented |
| 2026-09-01 | Product | Generative plugins and shaders: animation, publishing, code viewer | No effect on skills; context only. | RN | documented |
| 2026-09-01 | Official skills | `figma-generative-plugins` and `figma-shaders` added | Load `figma-shaders` or `figma-generative-plugins` before any target:mcp step that creates or updates a shader or generative plugin. | MSG | documented |
| 2026-08-24 | MCP | Enterprise-managed authorization generally available | No effect on skills; context only. | RN | documented |
| 2026-08-21 | Product | Auto layout spacing gains Around and Evenly | No effect on skills; context only. | RN | documented |
| 2026-08-14 | Product | Text wrap: Balance and Pretty | No effect on skills; context only. | RN | documented |
| 2026-08-13 | Product | Community skills library, agent can create skills, publish skills to Community | Search the Community skills library before building, so each concept card can honestly say "new" or "better than X". | RN | documented |
| 2026-08-11 | MCP | Weave tools runnable from external agents | No effect on skills; context only. | RN | documented |
| 2026-08-06 | Plugin API | Typings 1.133.0 add `EASING` and `TIMING` variable types | Variable audits must expect `EASING` and `TIMING` variables and skip them in colour, spacing and type checks instead of failing. | PT | documented |
| 2026-08-05 | Product | AI credit user limits and credit requests for admins | Keep each turn cheap and state the expected credit cost up front, since a user can hit an admin-set limit mid-run. | RN | documented |
| 2026-07-24 | Product | Auto layout updated to sit closer to CSS; legacy switchable until January 2027 | Re-test layout skills on the updated auto layout, and do not depend on legacy behaviour after January 2027. | RN | documented |
| 2026-07-16 | Product | Code-backed screens brought onto canvas bind to existing variables | No effect on skills; context only. | RN | documented |
| 2026-07-09 | Official skills | `figma-design-to-code` added; made mandatory 2026-07-13 | Load `figma-design-to-code` before any `get_design_context` call in a target:mcp section. | MSG | documented |
| 2026-06-24 | Product | Config 2026: Motion, 3D transforms, shaders, code layers, agent skills, generative plugins, Weave tools | Agent skills start here: write each as one Markdown file invoked by slash command, as this creator's hard rules require. | RN, Figma blog | documented |
| 2026-06-24 | Official skills | `figma-implement-motion` and `figma-use-motion` added | Load `figma-use-motion` to write animation over MCP and `figma-implement-motion` to turn Figma motion into code. | MSG | documented |
| 2026-06-24 | Plugin API | Typings 1.130.0 add Motion and shader paints | Feature-check `figma.motion` before any motion step; it is present in Design files and absent in standalone Spec files. | PT | documented |
| 2026-06-23 | Product | Agent opens to all paid plans in open beta (date inferred from the Config recap) | No effect on skills; context only. | Figma blog | secondary |
| 2026-06-18 | Product | Web search in the design agent | An in-app research skill may ask the agent to search the web; require the source of each finding in the output contract. | RN | documented |
| 2026-06-16 | MCP | `use_figma` supports Slides; uploaded local fonts; new `download_assets` tool | A target:mcp section may name `download_assets`, and may script Slides files when it loads `figma-use-slides`. | RN | documented |
| 2026-06-11 | Product | Chrome extension captures webpages as editable layers, beta | No effect on skills; context only. | RN | documented |
| 2026-06-08 | Official skills | `figma-swiftui` added | No effect on skills; context only. | MSG | documented |
| 2026-06-04 | Product | Check designs linter: variable and style suggestions, contrast fixes, detached component detection; Organization and Enterprise | Do not rebuild Check designs: an audit skill must say what it adds beyond the linter and still work on plans without it. | RN | documented |
| 2026-06-03 | Product | Pay-as-you-go AI credits on Professional; Make Plan mode | No effect on skills; context only. | RN | documented |
| 2026-06-01 | Product | Slots generally available, with new slot settings | Keep slot work plan-only for the in-app agent until a probe shows it can create slots; editor support is not agent support. | RN | documented |
| 2026-05-28 | Product | Make connected to a local codebase, closed beta | No effect on skills; context only. | RN | documented |
| 2026-05-22 | Product | Grid auto layout generally available | Layout skills may build and audit grid auto layout as well as horizontal and vertical stacks. | RN | documented |
| 2026-05-20 | Product | The Figma agent enters gradual beta with a waitlist; no credits during beta | No effect on skills; context only. | RN, Figma blog | documented |
| 2026-05-13 | Official skills | `figma-use-slides` added; `implement-design` and `create-design-system-rules` removed | Never port from `implement-design` or `create-design-system-rules`; they are gone upstream, and any local copy is stale. | MSG | documented |
| 2026-04-24 | Official skills | `figma-generate-diagram` and `figma-use-figjam` added | In target:mcp sections, load `figma-generate-diagram` before any `generate_diagram` call and `figma-use-figjam` before FigJam scripts. | MSG | documented |
| 2026-03-30 | Official skills | `figma-code-connect-components` replaced by `figma-code-connect` | Name `figma-code-connect`, never `figma-code-connect-components`, in a target:mcp section that maps components to code. | MSG | documented |
| 2026-03-26 | Plugin API | Typings 1.124.0 add `SlotNode` | Expect slot nodes when walking a layer tree and skip node types a helper does not handle, rather than failing. | PT | documented |
| 2026-03-24 | MCP | Write to canvas opens in beta through `use_figma`, free during beta, with skills as Markdown instructions | Build every canvas-changing target:mcp section on `use_figma`, with the `figma-use` skill loaded before the first call. | Figma blog | documented |
| 2026-03-24 | Official skills | Skills renamed with a `figma-` prefix; `figma-use`, `figma-create-new-file`, `figma-generate-design`, `figma-generate-library` added | Name official skills by their `figma-` prefixed names when porting an older coding-agent skill. | MSG | documented |
| 2026-02-17 | MCP | Claude Code to Figma announced: live UI into editable frames | No effect on skills; context only. | Figma blog | documented |
| 2026-02-13 | MCP | Cursor plugin support added | No effect on skills; context only. | MSG | documented |
| 2026-02-10 | MCP | Code Connect skill switches to `get_code_connect_suggestions` | No effect on skills; context only. | MSG | documented |
| 2025-12-12 | MCP | Claude Code plugin added to the guide repository | A coding-agent edition may assume the official Figma plugin supplies `figma-use` and its sibling skills in Claude Code. | MSG | documented |
| 2025-11-20 | Plugin API | Typings 1.121.0 add extended variable collections | Token skills must read extended collections as well as local ones and report which collection each token came from. | PT | documented |
| 2025-10-28 | MCP | "Updates for MCP server GA" | No effect on skills; context only. | MSG | documented |
| 2025-10-23 | MCP | `get_code` renamed to `get_design_context` | Name `get_design_context`, never `get_code`, when porting an older coding-agent skill. | MSG | documented |
| 2025-10-23 | Plugin API | Typings 1.119.0 add Buzz APIs | No effect on skills; context only. | PT | documented |
| 2025-09-23 | MCP | Guide repository gains remote-server and Make setup instructions | No effect on skills; context only. | MSG | documented |
| 2025-06-04 | MCP | Dev Mode MCP server announced in beta | No effect on skills; context only. | Figma blog | documented |

## Conflicts and open questions

- **Return size.** The help center documents 20 KB per tool call; treat that as a budget to aim for. `use_figma` refuses a return over 48,000 bytes, measured on 2026-11-03 and again on 2026-11-13, and discards the call's canvas edits. The in-app limit is above 55,000 bytes (2026-11-13). Neither figure appears in the official skills.
- **Low-seat rate limit.** The `figma/mcp-server-guide` README says 6 calls a month for View and Collab seats; the developer docs say 20. The docs are newer.
- **Agent dates.** Gradual beta 2026-05-20, open beta on paid plans 2026-06-23 (inferred from the Config recap), general availability 2026-10-06.
- **Not covered.** Product changes before 2026-05-18 (the release-notes feed starts there), the REST API changelog, and the first-ship dates of `get_libraries` and `search_design_system`.
- **No Schema 2026.** The Schema site is the 2025 event. Config 2027 is announced for 2027-05-25 to 27.

## Source keys

- **RN:** [Figma release notes](https://www.figma.com/release-notes/).
- **PT:** [figma/plugin-typings](https://github.com/figma/plugin-typings) release date, used as a proxy because the Plugin API updates feed shows no dates.
- **Figma blog:** [Figma blog](https://www.figma.com/blog/), the announcement post for the row's event.
- **Plugin API updates:** [Plugin API updates](https://www.figma.com/plugin-docs/updates/), Figma's feed of Plugin API changes.
- **MSG:** [figma/mcp-server-guide](https://github.com/figma/mcp-server-guide) commit date.
- **Probe tables 2026-11-03:** the capability probe 1.0 run in the Figma Design agent and over MCP. Their tables in `references/agent-capabilities-and-tools.md` were replaced by the 2026-11-13 tables; the MCP table survives as the MCP baseline in `examples/fm-figma-capability-probe/EVAL-LOG.md`, the in-app run as its 2026-11-03 entry, and both tables in git history.
- **MCP probe 2026-11-13:** the MCP-side run of 2026-11-13 (Specs over MCP, the 1.1 probe rerun, the return-size measurement, an embedded Spec on a Design canvas); run record `docs/superpowers/notes/2026-11-13-mcp-probe-and-specs-over-mcp.md`, local only.
- **Probe 1.2 2026-11-13:** the capability probe 1.2 runs in the Design agent and over MCP in a Design and a Spec file; run record `docs/superpowers/notes/2026-11-13-probe-1.2-runs.md`, local only, with its tables recorded in `references/agent-capabilities-and-tools.md` under "Figma Design agent (evaluate_script), 2026-11-13", "MCP (use_figma), 2026-11-13" and "MCP (use_figma) in a Spec file, 2026-11-13".
- **Browser run 2026-11-13:** the Figma agent driven from a coding agent through a browser, including the in-app checks in a Spec file; run record `docs/superpowers/notes/2026-11-13-figma-browser-automation-experiment.md`, local only.
