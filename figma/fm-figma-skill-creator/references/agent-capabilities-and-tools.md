# What the in-app agent can do, and which tools a skill body may name

A skill is instructions to the same agent the user is already chatting with. It inherits that
agent's abilities and its gaps. Figma publishes no capability list specific to skills, so the
Design agent's own "Currently supported features" table is the authority. Supported rows are safe
to instruct. "Coming soon" and unsupported rows must be written as plan-only output or handed back
to the user.

## Design agent capability table (Documented, 2026-11-02)

| Capability | Status | What a skill can safely instruct |
| --- | --- | --- |
| Use skills; use MCP connectors; attach files to prompts | Supported | Reference connectors and attachments with a fallback when absent |
| Search the web | Supported on paid plans with edit access | Make web lookups optional |
| Create code layers | Supported (open beta from 2026-10-15) | Code-layer builds |
| Create shaders and advanced visual effects; generate plugins | Supported | Say "build a plugin" or "shader" explicitly; building costs credits, running does not |
| Add motion and animation | Supported | Figma Motion keyframes and easing |
| 0-to-1 generation; bulk content generation and edits | Supported | Generate inside a new frame |
| Edit layout (auto layout, spacing, alignment, convert across sizes, restructure sections) | Supported | Layout edits on the selection |
| Edit component instances (properties, variants, overrides of text, images, size, visibility, layout) | Supported | Swaps and overrides |
| Use styles; use variables (apply, switch modes, update bound properties) | Supported | Bindings and mode switches |
| Author design-system components, styles, and variables (edit main components, update parent variants, sync or overwrite) | Supported | Library authoring |
| Create and edit images; convert images to vectors | Supported | AI image generation and image edits |
| Rename layers; search libraries; search files; select objects on the canvas | Supported | Selection commands such as "select all primary buttons" |
| Review comments; provide design feedback; file actions (add comments, file metadata) | Supported | Comment synthesis, annotations |
| Vector editing and Draw tools; create icons; use slots; prototyping and interactions | **Coming soon** | Plan or spec only; ask the user to do it |
| Export assets | **Not supported** | Ask the user to export |
| Create diagrams and data visualizations | **Not supported** (FigJam AI) | Route elsewhere |

Boundaries that matter as much as the table:

- **Make is a different action surface.** Design edits canvas layers; Make edits project code and
  publishes apps. One skill can serve both only if it checks the surface first and branches.
- **FigJam and Slides** are closed beta; the agent does not appear in those files today.
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
  belongs in the skill.

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
| `ask_user_question` | Figma-co-authored `catch-me-up` (per search); **available** in the Figma Design agent probe of 2026-11-03 | Structured multiple choice; renders a card with lettered clickable options plus an "Add a custom response" option; the card does not render Markdown | Name it in `target:figma-app` for every gate, with the plain-text question as the fallback |
| `create_design` | Figma-co-authored `feedback-map` (per search) | Declarative design creation | Unverified; avoid |
| Web search, connectors | Documented capabilities | No tool names in any skill | Describe in prose; handle absence |
| `use_figma`, `create_session`, `get_design_context`, `get_screenshot`, `download_assets`, `skillNames` | Official **MCP** tools for external agents | Absent from every in-app body; a Figma-authored skill states the in-app agent "cannot... there is no MCP tool available to it" | MCP section only |
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
- In-app, a return carrying a 50,000-character sample did not arrive whole; the same return
  measured 52,907 bytes over MCP, so the in-app limit is somewhere below that total. Over MCP,
  `use_figma` rejects returns over 48,000 bytes. Keep results small in both.
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
one dated table per runtime (Figma Design agent, Figma Make agent, MCP); a newer paste-back for a
runtime replaces its older table (Workflow F step 5). After replacing one, revisit every
`target:figma-app` section that relies on an API now marked `missing` or `error`.

Format: three columns, `| API | Status | Detail |`. Status is `available`, `missing`, or
`error`; Detail is the probe's own text (the first 120 characters of an error), or `—` when there
is nothing to say, and `presence only` marks rows that were checked for existence but not called.
The in-app tables end with the two experiment rows (`ask_user_question` and `show_widget`), and
every table is followed by the four scalar lines: payload bytes returned, walk time, nodes
walked, and style counts.

### Figma Design agent (evaluate_script), 2026-11-03

Seed file `fm-spacing-audit-seed` (key `hSEurPqV8Dgzn9yTwPSnnL`), nothing selected, upload of
`fm-figma-capability-probe` 1.0, Futuremotion's paste-back. Runtime line: `Figma Design agent;
script reports editorType figma, mode unknown, apiVersion 1.0.0`. The disclosure question rendered as
plain text (1.0 did not name the structured question tool for it); the first card, the
`ask_user_question` experiment, appeared 1 m 23 s after the answer. Credits were not recorded in
Round 3; testing-and-maintenance step 5 says where to read them.

| API | Status | Detail |
| --- | --- | --- |
| figma.getNodeByIdAsync | available | resolved the current page |
| figma.currentPage.selection | available | 0 selected |
| node.getMainComponentAsync | available | main component Card |
| node.boundVariables | available | 0 bound properties on Card |
| figma.variables.getVariableByIdAsync | available | resolved legacy/odd-18 |
| figma.variables.getLocalVariablesAsync | available | 7 variables |
| figma.variables.getLocalVariableCollectionsAsync | available | 2 collections |
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
| ask_user_question | available | Yes |
| show_widget | missing | — |

- Payload bytes returned: 50000 truncated
- Walk time: 3 ms
- Nodes walked: 20
- Style counts: text 0 · paint 0 · effect 0 · grid 0

What this run shows: the in-app script runtime matches MCP on every API row the scratch file could
test, and the seed file fills the rows MCP missed for lack of content (instance, bound variables,
variables, collections). `setPluginData` and `clientStorage` error with the same text as over MCP;
`setSharedPluginData` works; `figma.notify` returns. The return carrying the 50,000-character
sample did not arrive whole; the same return measured 52,907 bytes over MCP, so the in-app limit is
somewhere below that total and a too-large return fails quietly; keep helper results small. `ask_user_question` renders a card with clickable options;
`show_widget` is missing, so every picker needs its numbered-options text fallback.

Decision-gate UI (Round 3, 2026-11-03, screenshots of every gate): a gate whose skill text names the
structured question tool renders as a card with lettered clickable options (A, B, ...) plus "Add a
custom response"; a gate that does not name it renders as plain text, answered by typing. The
audit's mode and fix questions rendered as cards; its scope question and the probe's disclosure
rendered as plain text. A free-text follow-up shows as a card reading "Awaiting custom response",
and there the agent added presets the skill never defined. House rule since then: every gate names
the tool, with the plain-text wording as the fallback, and free-text follow-ups say "no preset
options".

### MCP (use_figma), 2026-11-03 UTC

Scratch file `fm-probe-scratch` (key `kXhDI9zBD5rbh00c3Lzt9i`), empty design file, nothing
selected. Runtime line: `editorType figma, mode unknown, apiVersion 1.0.0` (`figma.mode` read as
unknown: undefined or threw). A 50,000-character payload was rejected before any result returned
(`Return value exceeds the 48000-byte limit (52907 bytes). Canvas edits from this run were not
committed.`), so this table is from the rerun with `PAYLOAD = 30000`.

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

The two in-app experiment rows are omitted over MCP.

- Payload bytes returned: 30000 (a 50,000-character sample is rejected: the bridge limits the whole return to 48,000 bytes)
- Walk time: 1 ms
- Nodes walked: 0
- Style counts: text 0, paint 0, effect 0, grid 0

What this run shows: `setPluginData` errors and `setSharedPluginData` works; `clientStorage`
is unsupported; `figma.notify` did not throw over MCP, although the figma-use guidance says it
does; and `use_figma` rejects any return over 48,000 bytes and discards the run's canvas edits.
The rows that miss for lack of content (instance, auto layout, style, image) need a seeded file
to test.

Added 2026-11-03 UTC, outside the probe: over `use_figma`, `figma.root.name` reads back as
"Document" whatever the file is called in Figma, and `figma.root.name = "..."` throws `Error: in
set_name: Setting the document name is currently not supported`. The root name identifies nothing;
use the file key. `create_new_file` does apply the `fileName` it is given. Plan 2 adds this check
to the probe.

## Credits-aware instructions

Every run costs credits proportional to the work. Write skills that scope to the selection, read
before they write, cap output, and avoid re-explaining the system (that belongs in the library).
Tell the user up front when a step will be expensive (whole-page audits, bulk generation).
