# File structure and commenting standard for `main.ts`

One file carries the entire shader, so its internal order and comments are the documentation.
Figma's own files are terse; the house standard is richer and is the one to follow. The goal is
that the next editor, human or agent, can add a control or a preset without reading every line.

## Canonical file order

```text
1. import { defineProperties } from "figma:shaders"
2. Header comment block (see below)
3. export default function Effect() {}
4. Module-scope helper FUNCTIONS only (never var/let/const data)
5. export function setup(device, frame)
   a. WGSL source strings, one per pass, each with its own banner
   b. Shader modules
   c. Fullscreen quad vertex buffer and the shared vertex layout
   d. Uniform buffers, each with a byte-layout comment above createBuffer
   e. Samplers, placeholder textures
   f. Cache fields initialised to null (pipeline, pipelineFormat, intermediate textures)
6. export function render(device, frame)
   a. Param readers
   b. defaults table
   c. live table
   d. factoryPresets and the resolver (when the shader has presets)
   e. Geometry in design points: renderScale, padding, content size
   f. Per-frame derived values (weights, packed gradients, glyph ids)
   g. Intermediate texture (re)allocation with destroy on resize
   h. Uniform packing, with index comments matching the WGSL struct
   i. Pipeline cache keyed by frame.output.format; bind groups
   j. Pass encoding and submit
7. defineProperties(Effect, { ... }) with the preset select first and group comments
```

## Naming

| Thing | Convention | Example |
| --- | --- | --- |
| Library shader name (effect) | `fm-<name>-shader` | `fm-halftone-shader` |
| Library shader name (fill) | `fm-<name>-fill` | `fm-scanlines-fill` |
| Repo folder | same as the library name | `shaders/fm-scanlines-fill/` |
| Header first line | library name, then studio | `// fm-scanlines-fill — Futuremotion Studio` |
| Control keys | `camelCase` | `lineOpacity` |
| Preset labels | Title case, short | `Classic print` |

## Header block

```ts
import { defineProperties } from "figma:shaders"

// fm-<name>-shader — Futuremotion Studio
// <Effect|Fill> shader: <one sentence on what it does and what it samples>.
//
// Pipeline per frame:
//   1. <pass>: <what it reads, what it writes, size and format>
//   2. <pass>: ...
//
// Units: all user-facing sizes are design points; JS divides physical sizes by
// frame.renderScale and multiplies back only for texel offsets (blur taps, pixel grids).
// Alpha: <premultiplied in and out | straight out>.
//
// Presets ("<Label>") are resolved in render(): a preset is the control defaults plus an
// explicit delta, so a preset renders identically on every layer regardless of where the
// live sliders happen to sit. While a preset is selected the sliders do nothing.
```

## Banners and section comments

Pick one banner style per file. The house style is a 75-dash rule above and below a short title:

```ts
  // ---------------------------------------------------------------------------
  // WGSL — pass 1/2: separable Gaussian blur (horizontal, then vertical).
  // 65 taps across ±radius texels; weights come from a storage buffer that render()
  // refreshes only when the radius changes. Operates on premultiplied colour.
  // ---------------------------------------------------------------------------
```

Inside `defineProperties`, use short group comments: `// ---- Screen geometry ----`.
`//#region Name` / `//#endregion` pairs are acceptable for editor folding around the WGSL strings.

## Comment rules

- `//` for all implementation comments. Multi-line comments are consecutive `//` lines, never boxed
  `/* */` blocks. Reserve `/** */` for documenting a declaration (TSDoc `@param name - text`).
- Comment the **why**, not the what. "Blur in premultiplied space, the correct space for alpha
  edges" earns its line; "increment i" does not.
- Every uniform struct gets a per-slot comment, and the JS packing block gets matching index
  comments. These two must move together:

```wgsl
// Uniform layout — every slot is a vec4f so padding is explicit (480 bytes total).
struct U {
  p0: vec4f,  // cellPx, screenAngle(rad), gridType, jitter
  p1: vec4f,  // originX(px), originY(px), outW, outH
  ...
};
```

```ts
  // Screen-pass uniforms: 16 vec4 slots + 8 gradient colors + 2 gradient pos + 4 glyph id slots.
  frame.state.uniforms = device.createBuffer({ size: 480, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST })
```

- Every numeric select gets an encoding comment next to its WGSL decode:
  `// gridType: 0 Square, 1 Hexagonal, 2 Line screen ...` above `let g = i32(u.p0.z + 0.5);`.
- State the unit on every value whose unit is not obvious: `(rad)`, `(px)`, `(points)`, `0..1`.
- When something is a deliberate deviation from a Figma rule or a known limitation, say so where it
  happens and again in the header. Flag anything suboptimal rather than hiding it.
- Keep comments inside WGSL template literals as WGSL `//` comments; they ship to the compiler and
  are harmless.
- Line length: wrap comments at about 95 characters so diffs stay readable.

## Where logic belongs

| Put it in JS when | Put it in WGSL when |
| --- | --- |
| The result is the same for every pixel: percent to fraction, degrees to radians, slider to engineering range, render-scale division, gradient packing, weight tables | It varies per pixel |
| It changes only when a control changes (dirty-check and upload once) | It is cheap and keeps the uniform small |
| It needs `Math.fround` to match GPU precision | It is a lookup into uploaded data |

Expensive constant tables are computed on the CPU and uploaded once (Dither's Bayer matrices,
Halftone's Gaussian weights recomputed only when the radius changes) or patched into the WGSL
source and cached per variant (Lens distortion).

## Companion files in the repo

One folder per shader in the source repository:

```text
shaders/<fm-name>/
  main.ts            the shader, byte-identical to the live library version
  features.json      mirrored manifest, never pushed
  SHADER-NOTES.md    architecture reference: passes, uniform layout, mode ids, presets, limits
```

Templates for `SHADER-NOTES.md` and a handoff file are in `templates/`. Record the live shader id
and the returned version SHA after every `update_shader`.
