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
| `show_widget` with `sendPrompt(...)` and `read_me` | Figma's own help-center example (`hifi-mockup-presenter`) and one third-party skill; undocumented; contract appears to match Anthropic's visualize tool | Renders an interactive HTML widget in chat; widget JS calls `sendPrompt(text)` as if the user typed it; `read_me` supplies the stylesheet | In-app pickers only, always with a numbered-options text fallback |
| `get_comments` | Figma-co-authored skill; third-party | Params `pageId`, `nextCursor`; returns `id`, `message`, `user.handle`, `position.nodeId`, `reactions` | In-app only |
| `list_shader_fills`, `get_shader_fill` | Figma-co-authored `shader-starter` | Lists and reads shader fills ("Do not guess a type string") | In-app only |
| "Figma's AI image creation tool" | Figma help-center example | Generates an image used as a fill | Yes, by capability name |
| Library search (`use-design-system`, `select-design-libraries`) | Figma Advocates `update-components` | Runtime skills, not tools; returns component sets with `componentSetKey` | Describe as "search the connected library" |
| `ask_user_question` | Figma-co-authored `catch-me-up` (per search) | Structured multiple choice | Optional; numbered options in text work everywhere |
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

- Send results back with `return`; `console.log` is not returned; `figma.notify()` throws.
- Load fonts before any text edit (`figma.loadFontAsync`), every call.
- Re-fetch nodes by id in every call (`figma.getNodeByIdAsync`); node references and ids can stop
  resolving between calls.
- Measure in a later call than the one that builds: `node.width` on a freshly appended `FILL`
  child can read `0` in the same call.
- `setPluginData` / `getPluginData` are silently unavailable; `figma.loadAllPagesAsync` is "not
  implemented" (feature-check and degrade to the current page); wrap per-node inspection in
  try/catch because malformed remote components throw.
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
| `figma.loadAllPagesAsync` | "Not implemented" | Pages load incrementally | Feature-check |
| `setPluginData` / `getPluginData` | Silently unavailable | Not supported | Use `setSharedPluginData` or layer names |
| `node.query()`, `node.set()`, `figma.io.write`, `node.placeholder` | Zero in-app uses | Documented extensions | Unverified in-app; MCP sections only |

## Credits-aware instructions

Every run costs credits proportional to the work. Write skills that scope to the selection, read
before they write, cap output, and avoid re-explaining the system (that belongs in the library).
Tell the user up front when a step will be expensive (whole-page audits, bulk generation).
