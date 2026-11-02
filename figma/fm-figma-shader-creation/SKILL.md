---
name: fm-figma-shader-creation
description: Use whenever a Figma shader is being created, written, built, modified, extended, enhanced, fixed, debugged, reviewed, or published. Triggers include any mention of a Figma shader effect or shader fill, custom effect, custom fill, procedural fill, WebGPU or WGSL for Figma, a shader main.ts, defineProperties, features.json, the create_shader / update_shader / get_shader MCP tools, adding controls or factory presets to a shader, making an existing shader such as fm-halftone-shader resolution independent, harvesting presets from configured layers, shader cover artwork or thumbnails, or publishing a shader to a team library, an organization, or the Figma Community. Use before calling create_shader or update_shader and before editing any shader source, for both the Figma MCP path and the in-app Figma agent path.
---

# Figma shader creation and modification

Author, extend, validate, and ship custom Figma shaders (`effect` samples the layer beneath;
`fill` generates pixels) as a single `main.ts` that drives WebGPU through WGSL. This skill encodes
Figma's official contract, what Figma's own 20 first-party shaders actually do, a live probe of the
in-app runtime, and the Futuremotion house conventions (factory presets, commenting, repo layout).
Evidence tiers are labelled in the references: official, observed, inferred.

**Prerequisites:** when the Figma plugin's `figma-shaders` skill is available, load it before
`create_shader` or `update_shader`; load `figma-use` before `use_figma`. This skill adds to them;
it does not replace them.

## Decide the workflow

| User intent | Follow |
| --- | --- |
| New shader from a brief | Create (below), then `references/mcp-workflow.md` |
| Change, extend, fix, or add presets to an existing shader | `references/modify-existing-shader.md` first, always |
| Give a shader built-in looks | `references/factory-presets.md` (house standard, mandatory for Futuremotion shaders) |
| Turn configured layers into presets | "Harvest presets" in `references/mcp-workflow.md` |
| Cover artwork, thumbnails, publishing | `references/cover-artwork-and-publishing.md` |
| Work in the Figma UI, not through MCP | `references/in-app-workflow.md` |
| Build error, wrong render, open question | `references/troubleshooting.md` |
| No Figma MCP available (offline, review, or dry run) | Author from the templates, validate, write `SHADER-NOTES.md` with placeholder id and SHA, and hand the files over with the exact `update_shader` call to run later |

Required reading for a **fill**: `references/controls.md`, `references/factory-presets.md`,
`references/file-structure-and-comments.md`, plus `templates/fill-main.ts`. For an **effect** add
`references/runtime-contract.md` (padding and alpha) and the multi-pass section of
`references/design-patterns.md`. The WGSL rules reference is for when the validator or the build
complains, or when the shader packs a non-trivial uniform struct.

## Hard rules (the build or the runtime enforces these)

1. Only `import { defineProperties } from "figma:shaders"`. Export `default function Effect() {}`,
   `setup(device, frame)`, `render(device, frame)`; call `defineProperties(Effect, {...})` last.
2. No module-scope `var`, `let`, or `const`; module-scope `function` helpers are fine. Data lives in
   `setup`, `render`, or `frame.state`.
3. Every WGSL string begins with `diagnostic(off,derivative_uniformity);`. Entry points are
   `vs_main` and `fs_main` (compute: `main`). Prefer `textureSampleLevel(..., 0.0)`.
4. Uniform buffers are multiples of 16 bytes; pack `vec4f` slots and comment the layout.
5. Cache the output pipeline by `frame.output.format`; never hardcode it. Rebuild bind groups that
   reference `frame.input` when it changes; destroy textures you reallocate.
6. Effects: premultiplied in and out; guard `frame.input == null`. Fills: never bind input; output
   **straight** alpha (probe-verified; the official scaffold gets this wrong).
7. Dropdowns are `type: "number"`, `control: "select"` with integer values. Keys, option ids, and
   preset ids are permanent once shipped; labels and ranges are free to change.
8. `metadata.isAnimated` matches any read of `frame.time`, `frame.deltaTime`, `frame.frame`;
   `metadata.usesMouse` matches `frame.mousePosition`. `frame.time` is milliseconds.
9. Resolution independence: `frame.output.width/height` are physical texels. Compute design points
   as `(frame.output.physicalWidth ?? frame.output.width) / Math.max(Number(frame.renderScale) || 1, 1e-6)`
   and do all user-unit math in points. Figma's review rejects raw-pixel geometry.
10. No `console`, timers, `fetch`, DOM, or `Float64Array`. Debug by rendering values as colour.
11. `update_shader` takes the whole `main.ts`, never a diff, never another file. `features.json` is
    build-owned; never push it.
12. Run `node scripts/validate-shader.mjs <main.ts> --kind <effect|fill> --animated <bool> --mouse <bool>`
    (or `--features features.json`) before every push. Errors must be fixed. Warnings need a stated
    reason to remain. Info lines are advisory (a phase control resting at 0 is expected). The script
    does not compile WGSL; the build does.
13. Factory presets replace every control except the exempt keyframable ones (`phase`, `scroll`,
    `travel`, `progress`, `seed`, speeds), which stay live so a preset layer can still animate.

## Create a new shader

1. Decide `effect` or `fill`; ask only when the intent does not resolve it.
2. Plan on paper first: visible controls (name, type, default, range, unit), what stays hardcoded,
   the preset list, passes and GPU resources, the uniform layout, and the alpha contract. Do not
   write code until the WGSL struct, the packing array, `defaults`, and `defineProperties` agree.
3. Copy `templates/effect-main.ts` or `templates/fill-main.ts`. Both contain the header block,
   readers, `defaults` / `live` / `factoryPresets` / resolver with an exempt phase control,
   render-scale geometry, pipeline cache, and correct alpha; the effect template also handles input
   padding and a null input. Keep the structure; replace the WGSL body and the controls. Name the
   shader `fm-<name>-shader` (effect) or `fm-<name>-fill` (fill); keys are `camelCase`; every `%`
   says percent of what.
4. Follow `references/file-structure-and-comments.md` for order, banners, and the comment standard
   (comment the why, keep the uniform layout comments in both languages in sync, state units).
5. Validate, then push through `references/mcp-workflow.md` (whoami, create_shader, get_shader,
   update_shader with a specific commit message, record the SHA).
6. Verify on a layer with `use_figma`: apply, screenshot at 1x and 0.5x, select each preset by
   definition id, compare. Fix before reporting.
7. Create the repo folder `shaders/<fm-name>/` with `main.ts`, the mirrored `features.json`, and
   `SHADER-NOTES.md` from `templates/`.

## Modify an existing shader

Re-pull with `get_shader` and diff against the repo copy before editing; classify the change by its
compatibility risk; never rename keys, renumber ids, or delete presets; extend the WGSL struct, the
packing array, `defaults`, `live`, and `defineProperties` together; validate; push; update pinned
layers; re-screenshot. Full procedure and the `fm-halftone-shader` worked example (render-scale fix,
next preset id 8) are in `references/modify-existing-shader.md`.

## Controls, presets, patterns

- Property types, every field, value shapes, label and ordering rules, and the defensive reader
  block: `references/controls.md`.
- The seven-part factory-preset system, delta formats, maintenance rules, and the add / retire /
  add-control checklist: `references/factory-presets.md`. Standalone paste-in block:
  `templates/preset-block.ts`.
- Runtime facts (`frame` fields with evidence tier, manifest keys, sandbox, alpha, limits):
  `references/runtime-contract.md`.
- WGSL law versus Figma policy, alignment table, worked 160-byte packing, uniformity, colour
  spaces: `references/wgsl-webgpu-rules.md`.
- Reusable first-party patterns (pipeline cache, dirty-checked uniforms, gradient packing, blur
  chains, compute JFA, keyframable phase loops, mouse): `references/design-patterns.md`.

## Cover artwork and publishing

No MCP field or source file carries artwork. Documented slots exist only in the Community publish
modal (128 x 128 icon, 1920 x 1080 image or video thumbnail, up to nine carousel items) and the
internal publish modal (icon only). Build the frames with `use_figma`, export them, hand the files
and field values to the user for the modal, and never claim the in-app picker image changed without
screenshotting it. Details and the review checklist: `references/cover-artwork-and-publishing.md`.

## Completion report

Report the shader name, kind, id, and returned version; the controls and presets added or changed;
validator result; verification screenshots taken; the try-it link
`https://www.figma.com/file/new?try-tool-resource-content-id=<id>&try-tool-resource-type=<gen_effect|gen_fill>&type=design&mode=design`
with exactly one type value; anything suboptimal found (flag it, do not hide it); and what the
user must do by hand (cover upload, layer version updates, style publishing). Offer to open the
shader in an existing file the user names; never guess a file URL.

## Files in this skill

| Path | Purpose |
| --- | --- |
| `references/runtime-contract.md` | Module, manifest, sandbox, `frame` API, alpha, limits, export runtime differences |
| `references/controls.md` | Property types and fields, select rule, defaults and ordering, readers, Plugin API storage |
| `references/factory-presets.md` | The house preset system and its maintenance rules |
| `references/wgsl-webgpu-rules.md` | Language law vs policy, alignment, uniformity, WebGPU practice, alpha, colour |
| `references/file-structure-and-comments.md` | Canonical file order, header, banners, comment standard, repo layout |
| `references/design-patterns.md` | Patterns from Figma's first-party shaders |
| `references/mcp-workflow.md` | Tools, create loop, Plugin API apply and read, preset harvesting, versions, errors |
| `references/modify-existing-shader.md` | Safe modification and extension procedure, fm-halftone worked example |
| `references/in-app-workflow.md` | Figma agent chat, Tools panel, code viewer, Motion, try-it links |
| `references/cover-artwork-and-publishing.md` | Artwork slots, production workflow, publishing channels, review checklist |
| `references/troubleshooting.md` | Failure table, source contradictions with working rules, open questions |
| `templates/effect-main.ts`, `templates/fill-main.ts` | Complete starters (the fill template was build-tested on Figma 2026-11-02) |
| `templates/preset-block.ts` | Paste-in preset system |
| `templates/SHADER-NOTES.md`, `templates/HANDOFF.md` | Companion docs for the shader repo |
| `scripts/validate-shader.mjs` | Dependency-free Node validator; `--help` for options |
