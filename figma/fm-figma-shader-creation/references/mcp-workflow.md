# MCP workflow: create, read, update, apply, verify

Everything here uses the official Figma MCP server tools. The Figma plugin's own `figma-shaders`
skill is a mandatory prerequisite before `create_shader` or `update_shader`; load it if the host
has it. `figma-use` is mandatory before `use_figma`.

## Tools

| Tool | Purpose | Notes |
| --- | --- | --- |
| `whoami` | Plan key for creation | `plans[].key` matches `^(team\|organization)::\d+$`; ask when several qualify |
| `list_shaders` | Your shaders plus Figma's and publishers' | Paged by `cursor`; returns `owner` |
| `list_file_shaders({ fileKey })` | Shaders a file uses, pinned to the version the file references | Up to 100; needs only view access; the same shader appears once per pinned version |
| `get_shader({ id, includeSource, version })` | Name, description, owner, type, version SHA, files | `includeSource: true` inlines `features.json` and `main.ts`; large results land in a tool-results file, extract with `jq` |
| `create_shader({ name, description, planKey, kind })` | Starter scaffold | Never the final shader; manifest is version 2 |
| `update_shader({ id, kind, commitMessage, files, metadata })` | Build, version, deploy | Only `main.ts`; whole file, never a diff; `metadata` carries `name`, `description`, `isAnimated`, `usesMouse` |
| `get_design_context` / `get_metadata` / `get_screenshot` | Read layers | Design context resolves applied params by control name and ships the web runtime; it is large |
| `use_figma` | Plugin API scripts | Apply shaders, read definition ids, screenshot |

## Create a new shader

1. Decide `effect` (samples the layer beneath) or `fill` (generates pixels, never binds input).
   Ask only when the visual intent does not resolve it.
2. `whoami`, pick the plan key.
3. `create_shader` once with a concise name, a one-sentence description, the kind, and the plan key.
4. `get_shader` with `includeSource: true`. Read the scaffold and the manifest. The scaffold's fill
   returns premultiplied output; do not keep that line.
5. Author the complete `main.ts` from `templates/effect-main.ts` or `templates/fill-main.ts`.
6. `node scripts/validate-shader.mjs main.ts --kind <kind> --animated <bool> --mouse <bool>`; fix
   every error, justify any warning you keep, read the info lines.
7. `update_shader` with the same kind, `files: [{ path: "main.ts", content }]`, a specific
   `commitMessage`, and `metadata.isAnimated` / `metadata.usesMouse` matching the source.
8. On a build error, make the smallest fix the compiler output asks for and retry once. If it fails
   again, surface the error instead of rewriting.
9. Record the returned version SHA in the repo (HANDOFF or SHADER-NOTES).
10. Verify on a layer (next section), then report: name, kind, id, version, controls added, and the
    try-it link:

```text
https://www.figma.com/file/new?try-tool-resource-content-id=<id>&try-tool-resource-type=<gen_effect|gen_fill>&type=design&mode=design
```

Exactly one type value, no brackets. To open in an existing file, append the same two parameters to
a file URL the user supplied; never guess a file URL.

## Apply and verify through the Plugin API

`use_figma` can apply a shader without the user touching the UI. The id to pass is the one returned
by `listAvailableShaders()`, which is `<libraryId>/<versionSha>` for owned shaders and
`published:<communityId>/<version>` for Community shaders.

```js
const shaders = await figma.listAvailableShaders()
let s = shaders.find(x => x.id.startsWith('<libraryId>'))
if (!s.imported) s = await figma.importShaderById(s.id)
const rect = figma.createRectangle()
rect.resize(500, 250)
figma.currentPage.appendChild(rect)
rect.fills = [{ type: 'SHADER', id: s.id, properties: {} }]     // fill
// node.effects = [{ type: 'SHADER', id: s.id, visible: true, properties: {} }]   // effect
await rect.screenshot({ scale: 1 })
return { createdNodeIds: [rect.id], shaderId: s.id, applied: rect.fills[0].properties }
```

`properties` is keyed by definition id; after apply it is populated with author defaults, so you
can discover ids and set values: `properties[defId] = value`. Screenshots at `scale: 0.5` render the
shader at a lower render scale, which is a cheap resolution-independence test. Export scales above
1 rendered at 1x in testing, so test high-DPI behaviour by zooming in the app.

## Read the parameters applied on a layer

Prefer this over `get_design_context`, which returns the whole shader source inline.

```js
const shaders = await figma.listAvailableShaders()
const byVersion = Object.fromEntries(shaders.map(s => [s.id.split('/')[1], s]))
const node = await figma.getNodeByIdAsync('<nodeId>')
const eff = node.effects.find(e => e.type === 'SHADER')         // or node.fills.find(...)
const sha = eff.id.split('/')[1]                                 // applied id is <fileHash>/<sha>
const defs = byVersion[sha].propertyDefinitions
return Object.entries(eff.properties).map(([id, v]) => ({ name: defs[id].name, type: defs[id].type, value: v }))
```

Facts to rely on:

- The applied id embeds the version SHA. Layers pin the version they were applied with; a file can
  hold several versions of one shader. Resolve definitions for the **same** SHA.
- Definition `type` values: `NUMBER`, `BOOLEAN`, `COLOR`, `POINT`, `TEXT` (for `string`),
  `GRADIENT`. Value shapes match `frame.params`.
- Numbers return float32-rounded; round to the control's `step` before comparing with defaults.
- A layer whose `preset` is non-zero renders a factory preset; its slider values are meaningless
  for harvesting.

## Harvest presets from configured layers

1. `get_metadata` on the frame or section to enumerate candidate layers.
2. Run the read script above per layer (or one script over all layers on the page).
3. Skip layers with a non-zero `preset`.
4. Diff each parameter set against the `defaults` table; keep only differing keys, converting to
   delta formats (colours to `[r,g,b,a]`, booleans to `0/1`, points to `[x,y]`).
5. Screenshot each source layer for later comparison.
6. Ask the user for names, or propose names from the look and let them approve.
7. Add options and deltas (factory-presets.md), validate, push, re-screenshot with the preset
   selected, compare.

## Versions and pinned layers

- Each `update_shader` returns a 40-character SHA. `get_shader` can read any version.
- Layers keep rendering the version they were applied with until updated. In the app, a layer on an
  older version shows an "Update to latest version" control. The Plugin API shows the pinned SHA in
  the applied id; to migrate a layer programmatically, reapply with the new `listAvailableShaders()`
  id and copy `properties` across by definition **name** (ids can differ between versions).
- Keys and ids you must keep stable across versions: control keys, numeric option values, preset
  ids. Labels, ranges, and descriptions are free to change.

## Errors the server reports

| Error | Cause | Fix |
| --- | --- | --- |
| Kind mismatch | `update_shader.kind` differs from the resource | Use `get_shader.type` |
| Invalid planKey | Not `team::N` / `organization::N` | Take it from `whoami` |
| Missing commitMessage | Required on every update | Write a specific one |
| Wrong file path | Only `main.ts` is accepted | `files: [{ path: "main.ts", content }]` |
| Not owner | Editing a shader you do not own | Create your own copy from the source |
| Build error with compiler output | WGSL (naga wording) or TS/ESLint failure | Smallest fix, retry once, then surface |
| Animation or mouse unavailable | Capability gate | Terminal; offer a static shader with a keyframable phase |

Never put API keys, tokens, or signed URLs in source. Anyone with access can read it.
