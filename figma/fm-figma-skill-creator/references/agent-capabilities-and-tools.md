# What the in-app agent can do, and which tools a skill body may name

A skill is instructions to the same agent the user is already chatting with. It inherits that
agent's abilities and its gaps. Figma publishes no capability list specific to skills, so the
Design agent's own "Currently supported features" table is the authority. Supported rows are safe
to instruct. "Coming soon" and unsupported rows must be written as plan-only output or handed back
to the user.

## Design agent capability table (Documented, 2026-11-13)

Re-read on 2026-11-13 against the agent's help page, the release notes, and
`references/figma-changelog.md` (Last reviewed 2026-11-13). A status that changed since the
2026-11-02 table cites the changelog row by date, or the Figma page it came from when the changelog
has no row for it.

| Capability | Status | What a skill can safely instruct |
| --- | --- | --- |
| Use skills; use MCP connectors; attach files to prompts | Supported. Text files are the strong attachment type with the Design agent today and images the weak one (documented: Figma's attachments help page, read 2026-11-13) | Reference connectors and attachments with a fallback when absent; prefer a text or token file to a reference image, and say a result from an image is best-effort |
| Search the web | Supported on paid plans with edit access | Make web lookups optional |
| Create code layers | Supported (open beta from 2026-10-15) | Code-layer builds |
| Create shaders and advanced visual effects; generate plugins | Supported | Say "build a plugin" or "shader" explicitly; building costs credits, running does not |
| Add motion and animation | Supported | Figma Motion keyframes and easing |
| Compose 3D transforms (depth, perspective, tilt) | Supported (documented: release notes, changelog 2026-11-12) | Feature-check first: `transform3d` reads undefined when 3D is not enabled in the session |
| 0-to-1 generation; bulk content generation and edits | Supported | Generate inside a new frame |
| Edit layout (auto layout, spacing, alignment, convert across sizes, restructure sections) | Supported | Layout edits on the selection |
| Edit component instances (properties, variants, overrides of text, images, size, visibility, layout) | Supported | Swaps and overrides |
| Use styles; use variables (apply, switch modes, update bound properties) | Supported | Bindings and mode switches |
| Author design-system components, styles, and variables (edit main components, update parent variants, sync or overwrite) | Supported | Library authoring |
| Create and edit images; convert images to vectors | Supported | AI image generation and image edits |
| Rename layers; search libraries; search files; select objects on the canvas | Supported | Selection commands such as "select all primary buttons" |
| Review comments; provide design feedback; file actions (add comments, file metadata) | Supported | Comment synthesis, annotations |
| Generate vector icons and illustrations, with reference illustrations as a style source | Documented as available, not tested by us (documented: release note and vectors help page, changelog 2026-11-05 as corrected by the Product row of 2026-11-13). Figma's pages disagree: the agent's feature table still lists "Create icons" as coming soon | Ask for generated icons or illustrations in a new frame, then check stroke, fill, and layer conformance against the style; say the result is best-effort |
| Vector editing and Draw tools (editing existing vector paths and points); use slots; prototyping and interactions | **Coming soon** | Plan or spec only; ask the user to do it |
| Export assets | **Not supported** | Ask the user to export |
| Create diagrams and data visualizations | **Not supported** (FigJam AI) | Route elsewhere |

Boundaries that matter as much as the table:

- **Make is a different action surface.** Design edits canvas layers; Make edits project code and
  publishes apps. One skill can serve both only if it checks the surface first and branches.
  Figma's pages disagree on attachments per Make prompt: the attachments help page says up to 10
  files, the Make troubleshooting page says up to 3 (both documented, read 2026-11-13). Plan for 3
  until a run settles it.
- **A Spec file has no canvas.** A standalone Spec is a Markdown document: there is no canvas API,
  so frames, text layers, annotations, and motion are absent (observed over MCP, 2026-11-13). The
  Specs agent opens from "Ask anything" and lists uploaded skills in its slash menu, where they fire
  (observed in-app, Browser run 2026-11-13). A skill without a Spec branch says it needs a Design
  file and stops; see "Figma Specs (observed 2026-11-13)" below.
- **FigJam and Slides** are closed beta today; the agent does not appear in those files. Figma's
  AI credits help page announces general availability in FigJam and Slides from 2026-11-19, with
  AI credits applying (documented, read 2026-11-13). Keep FigJam and Slides steps plan-only until a
  run shows the agent there.
- **Generative plugins and shaders need explicit trigger words**; otherwise the agent places layers.
- **Connectors are conditional**: verified partners (Asana, Atlassian, GitHub, Linear, Notion,
  Slack, zeroheight), custom connectors on paid plans, write tools off by default. Always say what
  to do when the connector is absent.
- **Verification is thin**: the chat shows steps and result; Undo reverts only the most recent
  change; there is no diff view. Skills that make many edits must work on a duplicate or a new frame
  placed next to the source, never on the source.
- **Non-determinism**: Figma says results "may not be exactly the same each time you use the
  skill". Determinism comes from numeric rules, verify steps, and read-backs, not from wording.
- **Four context layers** (Figma, 2026-10-22): library guidelines hold standing rules, examples
  pages hold reference components, attached context covers the task, and skills hold repeatable
  process. Token names and component lists change too often and belong in the library; process
  belongs in the skill. Guidelines have limits (documented: Figma's guidelines help page, read
  2026-11-13): three to eight files with a combined size under 100 KB are advised, the combined size
  has a hard cap of 200 KB, and they need Professional and up and are in open beta. A library holds
  at most 200 examples (Figma's teach-the-agent help page). Figma also says guidelines work best
  when the agent creates designs from scratch and are applied less consistently when it edits
  existing designs (Figma blog, 2026-10-22), so a skill that modifies existing work restates its few
  hard rules at the point of editing and verifies afterwards.

## Tool vocabulary a skill body may name

Figma's own Community skills name tools directly. None of these tools is documented by Figma. Grade
each by evidence and always pair an in-app tool with a prose fallback.

| Tool or phrase | Evidence | Observed contract | Safe to name? |
| --- | --- | --- | --- |
| `evaluate_script` | Figma-co-authored Community skills (`comments-do-try-consider`, `figma-ux-writing-style`) and many third-party skills; undocumented | Runs Plugin API JavaScript in the open file; the `return` value is the result; `console.log` is not returned; node references, loaded fonts, and helpers do not persist between calls; "has output limits" (no number); a third-party author caps batches at 25 rows | In-app only. Feature-detect ("if a script-execution tool is available") and give a prose fallback |
| `show_widget` with `sendPrompt(...)` and `read_me` | Figma's own help-center example (`hifi-mockup-presenter`) and one third-party skill; undocumented; contract appears to match Anthropic's visualize tool | Renders an interactive HTML widget in chat; widget JS calls `sendPrompt(text)` as if the user typed it; `read_me` supplies the stylesheet. **Missing** in the Figma Design agent probe of 2026-11-03: no picker rendered | Never the only path: in-app pickers only, always with a numbered-options text fallback, and expect the fallback to run |
| `get_comments` | Figma-co-authored skill; third-party | Params `pageId`, `nextCursor`; returns `id`, `message`, `user.handle`, `position.nodeId`, `reactions` | In-app only |
| `list_shader_fills`, `get_shader_fill` | Figma-co-authored `shader-starter` | Lists and reads shader fills ("Do not guess a type string") | In-app only |
| "Figma's AI image creation tool" | Figma help-center example | Generates an image used as a fill | Yes, by capability name |
| Library search (`use-design-system`, `select-design-libraries`) | Figma Advocates `update-components` | Runtime skills, not tools; returns component sets with `componentSetKey` | Describe as "search the connected library" |
| `ask_user_question` | Figma-co-authored `catch-me-up` (per search); **available** in the Figma Design agent probe of 2026-11-03 | Structured multiple choice; renders a card with lettered clickable options plus an "Add a custom response" option; the card does not render Markdown. Note: once a card is answered, the chat shows the tool's full name, `mcp__plugin_conversation_ask_user_question__ask_user_question` (observed 2026-11-13); skills keep naming it `ask_user_question` | Name it in `target:figma-app` for every gate, with the plain-text question as the fallback |
| `create_design` | Figma-co-authored `feedback-map` (per search) | Declarative design creation | Unverified; avoid |
| Web search, connectors | Documented capabilities | No tool names in any skill | Describe in prose; handle absence |
| `use_figma`, `create_session`, `get_design_context`, `get_screenshot`, `download_assets`, `skillNames` | Official **MCP** tools for external agents | Absent from every in-app body; a Figma-authored skill states the in-app agent "cannot... there is no MCP tool available to it" | MCP section only |
| `sessionId` | `figma-use` at plugin 2.2.208 | `create_session` returns it; pass it on every later call for the task, including calls to other files | MCP section only |
| `figma-generate-design`, `figma-generate-library` skills | `figma-use` at plugin 2.2.208 | A call that changes the canvas loads one beside `figma-use` and names both in `skillNames`: `figma-generate-library` when the deliverable is a reusable component, variable collection, or style, `figma-generate-design` otherwise; read-only calls need neither. Over MCP `skillNames` is a logging parameter; no call was rejected for it (observed 2026-11-13) | MCP section only |
| `figma-spec` skill | Official skill, added 2026-10-15 | Load before any step that reads or writes a Spec; edit with `editContent`, verify with `getContent`, never with screenshots | MCP section only |
| `create_new_file` with `editorType: "figspec"`, `whoami` | Official MCP tools, named by `figma-spec` | `whoami` reports the plan and whether Specs and code layers are enabled (observed 2026-11-13: `specs_enabled`, `code_layers_enabled`); `create_new_file` with `editorType: "figspec"` and the plan key makes a standalone Spec file; load `figma-create-new-file` first | MCP section only |
| `get_libraries` | Official MCP tool | A file tool that reads the libraries available to the file; call `create_session` first, as for `search_design_system` | MCP section only |
| `set_hyperlink` | Not a tool: an error-message prefix (`in set_hyperlink: ...`) | Same `in set_<property>:` format as `use_figma` errors | Never name as a tool |

Tension to design around: the Figma Advocates skill `update-components` says "Do not assume
external MCP tools, shell access, or the Plugin API are available, and do not invent operations",
while Figma Community skills ship hundreds of lines of `evaluate_script` code. Both positions hold
only if script access is treated as an optional, feature-detected accelerator behind a tool-neutral
core.

## The in-app script runtime (reconstructed)

`evaluate_script` and the MCP `use_figma` tool share error formats, quirks, and helpers, so the
strong inference is one runtime with the in-app host missing some features. Rules an in-app script
block must follow:

- Write each helper with top-level `await` and a final `return`, with no function wrapper. Both
  script tools take the result from `return`; a wrapped function that is never returned gives back
  nothing in-app (probe 1.2, 2026-11-13: the wrapped 1.1 form answered `Plugin executed
  successfully` with no result, and the top-level form returned every row in both runtimes).
- Send results back with `return`; `console.log` is not returned. `figma.notify()` was called
  and returned a handler in both probe runs (2026-11-03), although the figma-use guidance says it
  throws; a skill should still not depend on a toast.
- Load fonts before any text edit (`figma.loadFontAsync`), every call.
- Re-fetch nodes by id in every call (`figma.getNodeByIdAsync`); node references and ids can stop
  resolving between calls.
- Measure in a later call than the one that builds: `node.width` on a freshly appended `FILL`
  child can read `0` in the same call.
- `setPluginData` throws ("not supported in this host runtime") and `figma.clientStorage` is
  "not a supported API" in both runtimes; `setSharedPluginData` round-trips. `figma.loadAllPagesAsync`
  is present but its call is untested (third-party reports say "not implemented"), so feature-check
  and degrade to the current page; wrap per-node inspection in try/catch because malformed remote
  components throw.
- Return limits. Over MCP, `use_figma` refuses a return over 48,000 bytes and discards that call's
  canvas edits (measured 2026-11-03 and again 2026-11-13). In-app, a return of about 55,000 bytes
  arrived whole on 2026-11-13, where about 53,000 bytes did not on 2026-11-03, so the in-app limit
  is now above 55,000 bytes. MCP is the stricter runtime: size every return for 48,000 bytes, and
  never write to the canvas and return a large report in the same call.
- Keep batches small (a third-party author caps at 25 rows per call) and keep helper code under
  about 150 lines, re-pasted per call because nothing persists.
- Text sizing order: `resize(width, 16)`, then `textAutoResize = 'HEIGHT'`, then `characters`.
  Setting `characters` first produces extreme heights.

| Plugin API surface | In-app evidence | MCP `use_figma` | Guidance |
| --- | --- | --- | --- |
| `figma.createAutoLayout()` | Used by Figma-authored `image-audit` and `make-a-type-scale` | Documented helper | Safe in both |
| `await node.screenshot()` | Third-party in-app skills | Documented | Probably safe; feature-detect |
| `figma.motion.*` | Figma-authored motion skills | Not listed | In-app motion only |
| `getNodeByIdAsync`, `loadFontAsync`, `figma.variables.*`, `figma.teamLibrary.*`, `importComponentByKeyAsync` | Dozens of uses | Standard API | Safe |
| `figma.loadAllPagesAsync` | Present, call untested (probe, 2026-11-03); third parties report "not implemented" | Pages load incrementally | Feature-check |
| `setPluginData` / `getPluginData` | Throws: not supported in this host runtime (probe, 2026-11-03) | Throws, same text | Use `setSharedPluginData` or layer names |
| `figma.clientStorage` | Throws: not a supported API (probe, 2026-11-03) | Throws, same text | Do not persist state; nothing survives between calls anyway |
| `node.query()`, `node.set()`, `figma.io.write`, `node.placeholder` | `node.query` and `node.set` present in-app (probe, 2026-11-03, presence only); zero in-app uses | Documented extensions | Calls unverified in-app; MCP sections only |

## Observed in-app (probe results)

These tables come from running `examples/fm-figma-capability-probe/` and are observed, not
reconstructed: each row is what one run of the probe helper returned in one runtime on the stated
date. They take precedence over the reconstructed rules above for the same runtime and date. Keep
one dated table per runtime (Figma Design agent, Figma Make agent, MCP), and one more for a runtime
run in a Spec file; a newer paste-back for a runtime replaces its older table (Workflow F step 5).
After replacing one, revisit every `target:figma-app` section that relies on an API now marked
`missing` or `error`.

Format: three columns, `| API | Status | Detail |`. Status is `available`, `missing`, or
`error`; Detail is the probe's own text (the first 120 characters of an error), or `—` when there
is nothing to say, and `presence only` marks rows that were checked for existence but not called.
The in-app tables end with the two experiment rows (`ask_user_question` and `show_widget`), and
every table is followed by the four scalar lines: payload bytes (sent and received, from probe
1.2), walk time, nodes walked, and style counts.

### Figma Design agent (evaluate_script), 2026-11-13

Scratch file `fm-probe-scratch` (key `kXhDI9zBD5rbh00c3Lzt9i`), empty page, nothing selected,
`fm-figma-capability-probe` 1.2. This is the second in-app run of the day; the first, still in the
1.1 helper form, returned no result (below). Runtime line: `editorType figma, mode default,
apiVersion 1.0.0`; `figma.mode` now reads `default` where it read unknown on 2026-11-03. The
disclosure question rendered as a card with lettered options (`A` "1. Yes", `B` "2. No", `C` "Add a
custom response"). Credits: three turns, read as 52, 52 and 10, 114 in total, one reading each. The
MCP run in the same file returned the same status and detail on all 43 rows (next table).

| API | Status | Detail |
| --- | --- | --- |
| figma.getNodeByIdAsync | available | resolved the current page |
| figma.currentPage.selection | available | 0 selected |
| node.getMainComponentAsync | missing | no instance on page |
| node.boundVariables | missing | no auto-layout node on page |
| figma.variables.getVariableByIdAsync | available | no variable in file; null for a dummy id |
| figma.variables.getLocalVariablesAsync | available | 0 variables |
| figma.variables.getLocalVariableCollectionsAsync | available | 0 collections |
| figma.teamLibrary.getAvailableLibraryVariableCollectionsAsync | available | 0 library collections |
| figma.variables.importVariableByKeyAsync | available | presence only |
| node.setBoundVariable | available | presence only |
| figma.getLocalTextStylesAsync | available | 0 styles |
| figma.getLocalPaintStylesAsync | available | 0 styles |
| figma.getLocalEffectStylesAsync | available | 0 styles |
| figma.getLocalGridStylesAsync | available | 0 styles |
| figma.getStyleByIdAsync | missing | no local style in file |
| node.setFillStyleIdAsync | available | presence only |
| node.setTextStyleIdAsync | available | presence only |
| figma.getImageByHash + image.getBytesAsync | missing | no image on page |
| figma.createImage | available | presence only |
| node.setPluginData / getPluginData | error | Error: in setPluginData: figma.setPluginData is not supported in this host runtime (only private plugins on web can use |
| node.setSharedPluginData / getSharedPluginData | available | round trip ok |
| figma.clientStorage.setAsync / getAsync | error | Error: in setAsync: "setAsync" is not a supported API |
| node.query | available | presence only |
| node.set | available | presence only |
| figma.createAutoLayout | available | created and removed; layoutMode HORIZONTAL |
| figma.loadAllPagesAsync | available | presence only |
| figma.ui | available | presence only |
| text sizing: resize, textAutoResize, characters | available | height 15 at width 200 |
| figma.notify | available | called; handler returned |
| figma.root.name | available | read "Document"; set: Error: in set_name: Setting the document name is currently not supported |
| figma.motion | available | presence only |
| figma.commitUndo | error | Error: in commitUndo: "commitUndo" is not a supported API |
| figma.saveVersionHistoryAsync | error | Error: in saveVersionHistoryAsync: "saveVersionHistoryAsync" is not a supported API |
| node.annotations | available | 1 annotation read back |
| figma.annotations.getAnnotationCategoriesAsync | available | 4 categories |
| node.exportAsync PNG | available | 372 bytes |
| node.screenshot | available | presence only |
| node.transform3d / scene3d / transformOrigin | available | present: transform3d, scene3d, transformOrigin |
| figma.teamLibrary.getVariablesInLibraryCollectionAsync + importVariableByKeyAsync | available | presence only; no library collection enabled |
| figma.variables.setBoundVariableForPaint | available | presence only; no local colour variable |
| figma.spec members | available | 8 of 8 are functions |
| figma.spec.getContent | missing | no Spec on this page |
| figma.spec.createOnCanvasAsync | available | created and removed; 850 x 1100 |
| ask_user_question | available | 1. Yes |
| show_widget | missing | — |

- Payload bytes: 50000 sent, 50000 received
- Walk time: 1 ms
- Nodes walked: 0
- Style counts: text 0 · paint 0 · effect 0 · grid 0

What this run shows: a helper must be written with top-level `await` and a final `return`, with no
function wrapper. The first in-app run of 1.2 sent the 1.1 form, an async function wrapped and
invoked on its last line, exactly as written; the script tool answered `Plugin executed
successfully` with no result object, and the agent confirmed afterwards that it had added no outer
`return` or `await`. Earlier runs worked only because the agent quietly added a `return`. The
top-level form returned all 43 rows. The return of about 55,000 bytes (the 50,000-character payload
plus 43 rows) arrived whole, where about 53,000 bytes did not on 2026-11-03, so the in-app limit is
now above the 48,000 bytes `use_figma` accepts and MCP is the stricter runtime. `commitUndo` and
`saveVersionHistoryAsync` are functions that throw when called, so a checkpoint needs a duplicated
page or frame, never version history. Annotations, PNG export, the three 3D transform members and
`figma.motion` are available, and an embedded Spec can be created on the Design canvas and removed
again; `figma.spec` is present in a Design file, so its presence never identifies a Spec file.
`setPluginData` and `clientStorage` still error and `setSharedPluginData` still round-trips, as on
2026-11-03. The library rows and the paint-binding row stay presence only because the scratch file
has no enabled library and no local colour variable; they need a seeded file. The `ask_user_question`
experiment rendered as a card; once a card is answered, the chat prints a tool-result block that
shows the tool's full name, `mcp__plugin_conversation_ask_user_question__ask_user_question`, and the
answering user's id, which is never copied into a record. `show_widget` is still missing, so every
picker needs its numbered-options text fallback.

Decision-gate UI (Round 3, 2026-11-03, screenshots of every gate): a gate whose skill text names the
structured question tool renders as a card with lettered clickable options (A, B, ...) plus "Add a
custom response"; a gate that does not name it renders as plain text, answered by typing. The
audit's mode and fix questions rendered as cards; its scope question and the probe's disclosure
rendered as plain text. A free-text follow-up shows as a card reading "Awaiting custom response",
and there the agent added presets the skill never defined. House rule since then: every gate names
the tool, with the plain-text wording as the fallback, and free-text follow-ups say "no preset
options".

### MCP (use_figma), 2026-11-13

Scratch file `fm-probe-scratch` (key `kXhDI9zBD5rbh00c3Lzt9i`), the same empty page as the in-app
run, nothing selected, `fm-figma-capability-probe` 1.2 sent through `use_figma` as written. Runtime
line: `editorType figma, mode default, apiVersion 1.0.0`. Every row has the same status and detail
as the in-app table above.

| API | Status | Detail |
| --- | --- | --- |
| figma.getNodeByIdAsync | available | resolved the current page |
| figma.currentPage.selection | available | 0 selected |
| node.getMainComponentAsync | missing | no instance on page |
| node.boundVariables | missing | no auto-layout node on page |
| figma.variables.getVariableByIdAsync | available | no variable in file; null for a dummy id |
| figma.variables.getLocalVariablesAsync | available | 0 variables |
| figma.variables.getLocalVariableCollectionsAsync | available | 0 collections |
| figma.teamLibrary.getAvailableLibraryVariableCollectionsAsync | available | 0 library collections |
| figma.variables.importVariableByKeyAsync | available | presence only |
| node.setBoundVariable | available | presence only |
| figma.getLocalTextStylesAsync | available | 0 styles |
| figma.getLocalPaintStylesAsync | available | 0 styles |
| figma.getLocalEffectStylesAsync | available | 0 styles |
| figma.getLocalGridStylesAsync | available | 0 styles |
| figma.getStyleByIdAsync | missing | no local style in file |
| node.setFillStyleIdAsync | available | presence only |
| node.setTextStyleIdAsync | available | presence only |
| figma.getImageByHash + image.getBytesAsync | missing | no image on page |
| figma.createImage | available | presence only |
| node.setPluginData / getPluginData | error | Error: in setPluginData: figma.setPluginData is not supported in this host runtime (only private plugins on web can use |
| node.setSharedPluginData / getSharedPluginData | available | round trip ok |
| figma.clientStorage.setAsync / getAsync | error | Error: in setAsync: "setAsync" is not a supported API |
| node.query | available | presence only |
| node.set | available | presence only |
| figma.createAutoLayout | available | created and removed; layoutMode HORIZONTAL |
| figma.loadAllPagesAsync | available | presence only |
| figma.ui | available | presence only |
| text sizing: resize, textAutoResize, characters | available | height 15 at width 200 |
| figma.notify | available | called; handler returned |
| figma.root.name | available | read "Document"; set: Error: in set_name: Setting the document name is currently not supported |
| figma.motion | available | presence only |
| figma.commitUndo | error | Error: in commitUndo: "commitUndo" is not a supported API |
| figma.saveVersionHistoryAsync | error | Error: in saveVersionHistoryAsync: "saveVersionHistoryAsync" is not a supported API |
| node.annotations | available | 1 annotation read back |
| figma.annotations.getAnnotationCategoriesAsync | available | 4 categories |
| node.exportAsync PNG | available | 372 bytes |
| node.screenshot | available | presence only |
| node.transform3d / scene3d / transformOrigin | available | present: transform3d, scene3d, transformOrigin |
| figma.teamLibrary.getVariablesInLibraryCollectionAsync + importVariableByKeyAsync | available | presence only; no library collection enabled |
| figma.variables.setBoundVariableForPaint | available | presence only; no local colour variable |
| figma.spec members | available | 8 of 8 are functions |
| figma.spec.getContent | missing | no Spec on this page |
| figma.spec.createOnCanvasAsync | available | created and removed; 850 x 1100 |

The two in-app experiment rows are omitted over MCP.

- Payload bytes: not measured by this run: it used `PAYLOAD` 1000 and returned its result packaged as strings, a maintainer deviation to save context; the 48,000-byte limit was measured directly the same day
- Walk time: 1 to 2 ms (the run record gives one range for this run and the Spec run)
- Nodes walked: not stated in the run record; the page was empty
- Style counts: text 0 · paint 0 · effect 0 · grid 0

What this run shows: the top-level helper form runs unchanged over `use_figma`, and the two
runtimes agree on every row an empty Design page can test, including the fourteen rows added in
1.2. `use_figma` still refuses a return over 48,000 bytes and discards that call's canvas edits
(measured the same day, outside the probe), so MCP is now the stricter runtime and the probe's MCP
section keeps `PAYLOAD` at 30000. Nothing was left behind in the file. The rows that miss for lack
of content (instance, auto layout, style, image, a Spec on the page) and the presence-only library
and paint-binding rows need a seeded file to test.

Added 2026-11-03 UTC, outside the probe: over `use_figma`, `figma.root.name` reads back as
"Document" whatever the file is called in Figma, and `figma.root.name = "..."` throws `Error: in
set_name: Setting the document name is currently not supported`. The root name identifies nothing;
use the file key. `create_new_file` does apply the `fileName` it is given. Probe 1.2 tests it: see
the `figma.root.name` row of the 2026-11-13 tables, where assigning the root name throws in-app as
well.

### MCP (use_figma) in a Spec file, 2026-11-13

Spec file `fm-spec-scratch` (key `CLZvom3IjzGswGa8yuuUrV`), `fm-figma-capability-probe` 1.2 sent
through `use_figma` as written. Runtime line: `editorType figspec, mode default, apiVersion 1.0.0`.
The helper's Spec guard skipped the twenty rows that need a canvas or a write; they print as
`missing | skipped in a Spec file`. The two rows whose detail reads `no such property` were recorded
as `error` in this run; the helper was changed afterwards to record that text as `missing`, which
is how they are shown.

| API | Status | Detail |
| --- | --- | --- |
| figma.getNodeByIdAsync | available | resolved the current page |
| figma.currentPage.selection | available | 0 selected |
| node.getMainComponentAsync | missing | skipped in a Spec file |
| node.boundVariables | missing | skipped in a Spec file |
| figma.variables.getVariableByIdAsync | available | no variable in file; null for a dummy id |
| figma.variables.getLocalVariablesAsync | available | 0 variables |
| figma.variables.getLocalVariableCollectionsAsync | available | 0 collections |
| figma.teamLibrary.getAvailableLibraryVariableCollectionsAsync | available | 0 library collections |
| figma.variables.importVariableByKeyAsync | available | presence only |
| node.setBoundVariable | missing | skipped in a Spec file |
| figma.getLocalTextStylesAsync | available | 0 styles |
| figma.getLocalPaintStylesAsync | available | 0 styles |
| figma.getLocalEffectStylesAsync | available | 0 styles |
| figma.getLocalGridStylesAsync | available | 0 styles |
| figma.getStyleByIdAsync | missing | no local style in file |
| node.setFillStyleIdAsync | missing | skipped in a Spec file |
| node.setTextStyleIdAsync | missing | skipped in a Spec file |
| figma.getImageByHash + image.getBytesAsync | missing | no image on page |
| figma.createImage | available | presence only |
| node.setPluginData / getPluginData | missing | skipped in a Spec file |
| node.setSharedPluginData / getSharedPluginData | missing | skipped in a Spec file |
| figma.clientStorage.setAsync / getAsync | missing | skipped in a Spec file |
| node.query | missing | skipped in a Spec file |
| node.set | missing | skipped in a Spec file |
| figma.createAutoLayout | missing | skipped in a Spec file |
| figma.loadAllPagesAsync | available | presence only |
| figma.ui | available | presence only |
| text sizing: resize, textAutoResize, characters | missing | skipped in a Spec file |
| figma.notify | missing | skipped in a Spec file |
| figma.root.name | available | read "Document"; set skipped in a Spec file |
| figma.motion | missing | TypeError: figma.motion: no such property 'motion' on the figma global object |
| figma.commitUndo | missing | skipped in a Spec file |
| figma.saveVersionHistoryAsync | missing | skipped in a Spec file |
| node.annotations | missing | skipped in a Spec file |
| figma.annotations.getAnnotationCategoriesAsync | missing | TypeError: figma.annotations: no such property 'annotations' on the figma global object |
| node.exportAsync PNG | missing | skipped in a Spec file |
| node.screenshot | missing | skipped in a Spec file |
| node.transform3d / scene3d / transformOrigin | missing | skipped in a Spec file |
| figma.teamLibrary.getVariablesInLibraryCollectionAsync + importVariableByKeyAsync | available | presence only; no library collection enabled |
| figma.variables.setBoundVariableForPaint | available | presence only; no local colour variable |
| figma.spec members | available | 8 of 8 are functions |
| figma.spec.getContent | available | totalLines 26, hasMore true |
| figma.spec.createOnCanvasAsync | missing | skipped in a Spec file |

The two in-app experiment rows are omitted over MCP.

- Payload bytes: not measured by this run: `PAYLOAD` 1000 and the result packaged as strings, the same maintainer deviation as the MCP Design run
- Walk time: 1 to 2 ms (the run record gives one range for this run and the MCP Design run)
- Nodes walked: 1, the `SPEC_BLOCK`
- Style counts: text 0 · paint 0 · effect 0 · grid 0

What this run shows: a standalone Spec file has no canvas API. `figma.motion` and
`figma.annotations` are absent (reading either throws `no such property`), and the guard keeps
every canvas and write row from running, so the probe changes nothing there. The reads a Spec skill
needs work: `getNodeByIdAsync` resolves the page, the variable, style and library reads return empty
lists, all eight `figma.spec` members are functions, `figma.spec.getContent` read the document
(`totalLines 26, hasMore true`), and `figma.root.name` reads "Document" as in a Design file. The
guard detects the Spec by `figma.editorType === "figspec"`, because `figma.spec` is present in a
Design file too. Nothing was left behind in the file. The in-app run in a Spec file was not
started, to save credits; it would add the Spec disclosure and the question card in the Specs
agent.

## Figma Specs (observed 2026-11-13)

Observed over `use_figma`, one run each, on 2026-11-13 (run record "MCP probe 2026-11-13" in
`references/figma-changelog.md`): the standalone Spec file `fm-spec-scratch` and an embedded Spec in
the Design file `fm-probe-scratch`. The comment objects the API returns carry the author's user id
and display name; never copy them into a record.

### Standalone Spec file over MCP

| Check | Result |
| --- | --- |
| figma.editorType | `figspec` |
| Feature detection | `Object.keys(figma.spec)` is empty; every method is still callable. Test members by name. |
| Canvas API in a Spec | `createFrame`, `createText`, `createPage`, `figma.annotations`, `figma.motion` absent; `createAutoLayout` present but untested |
| Structure | one page, one `SPEC_BLOCK`, `specBlockType` `DOCUMENT`; `figma.root.name` reads `Document` |
| getContent | keys `specNodeId, markdown, title, totalLines, linesReturned, offset, hasMore` |
| getContent paging | default call returned all 1,803 lines (26,911 characters) with `hasMore` false; `offset: 1000, maxLines: 5` returned 5 lines with `hasMore` true |
| setContent | works on an empty document and as a whole-document replace; returns `undefined` |
| editContent, unique match | works; returns `undefined`; two edits in one call both applied |
| editContent, zero matches | error: `edit 1 failed — text not found in the current document. ... Re-read with figma.spec.getContent() and retry.` |
| editContent, two matches | error: `edit 1 failed — found 2 matches for the provided oldText. Include more surrounding context to make the match unique.` |
| Formatting round trip | bold, italic, code, `<ins>`, to-do items, quote, table, fenced code and rule all survive |
| Normalisation on readback | the table separator row comes back in a shorter form (three hyphens per cell); two extra blank lines appear after the title H1; the trailing newline is dropped |
| comments.create | works with `anchorText` alone, with `anchorText` plus `contextText`, and without `specNodeId` (single-Spec file) |
| comments.create on text written in the same call | error: HTTP 400 `Bad request` from the comments endpoint, twice out of two attempts |
| comments.create on older text, after an edit in the same call | works |
| comments.reply, comments.getThread | work; `getThread` given a reply id returns the whole thread from its root |
| Comment markers | each thread appears in the Markdown as `[comment:<uuid>]text[/comment:<uuid>]` |
| Edit inside a marked span, markers kept | works; the thread and its reply survive |
| comments list, resolve, delete | absent: only `create`, `getThread` and `reply` exist |
| getBlockContent | `typeof` is `function`; calling it over MCP throws `"getBlockContent" is not a supported API` |

### Embedded Spec on a Design canvas over MCP

One mutating call in `fm-probe-scratch`, cleaned up in the same call.

| Check | Result |
| --- | --- |
| `findAllWithCriteria({ types: ["SPEC_BLOCK"] })` with no Spec in the file | returns 0, no error |
| `figma.spec.getContent({})` with no Spec in the file | error: `no Spec was found in this file. Pass a valid specNodeId.` |
| `figma.spec.createOnCanvasAsync({ title, content })` | returns `{ specNodeId }`; the node is a `SPEC_BLOCK`, `specBlockType` `DOCUMENT`, child of the page |
| Size and position | 850 x 1100, placed at 0, 0: a skill must move it clear of existing content |
| Name and title | the node name is the `title` passed; `getContent` reports `title` as `Document` |
| `getContent` on the new Spec | returns the Markdown written, 3 lines |
| `node.remove()` | works; the page was empty again afterwards |

### Rules for skill authors

1. **Detect the surface with `figma.editorType`, not with `figma.spec`.** `figma.spec` exists in
   Design files too. `figspec` means a standalone Spec, where there is no canvas API: no frames,
   no text nodes, no annotations.
2. **Test by calling, not by `typeof`.** `saveVersionHistoryAsync`, `commitUndo` and
   `getBlockContent` are functions that throw when called. A presence-only probe row reports them
   as available and is wrong.
3. **A comment cannot anchor on text the same call just wrote.** Write or edit content in one
   call, comment in the next. Anchoring on text that was already there is fine.
4. **Keep the whole return under 48,000 bytes, and treat an oversized return as a lost write.**
   The bridge discards the canvas edits of the failed call. A script that writes and then returns
   a large report loses both. Measure the serialized size before returning.
5. **Compare Spec content after normalising.** A byte-for-byte compare between what was written
   and what `getContent` returns fails on the table separator, the blank lines after the title and
   the trailing newline. Verify with `includes` on the sentences that matter, as the official
   `figma-spec` skill does.
6. **Read a Spec in one call when it is small, in pages when it is not.** A 27,000-character
   document came back whole. A long Spec plus other returned fields can pass 48,000 bytes; page
   with `offset` and `maxLines` and return counts, not the text.

## Credits-aware instructions

Every run costs credits proportional to the work. Write skills that scope to the selection, read
before they write, cap output, and avoid re-explaining the system (that belongs in the library).
Tell the user up front when a step will be expensive (whole-page audits, bulk generation).
