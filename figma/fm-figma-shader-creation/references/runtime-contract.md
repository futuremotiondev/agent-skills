# Runtime contract: module, manifest, sandbox, and the `frame` object

Everything a `main.ts` can rely on, split into three evidence tiers. **Official** means stated in
Figma's help centre, developer docs, or the official `figma-shaders` MCP skill. **Observed** means
read from Figma's own shader source or measured with a live probe on 2026-11-02. **Inferred** means
a conclusion from evidence, not a statement by Figma. Treat official and observed facts as rules.
Treat inferred facts as defaults that must stay behind a guard.

## Module contract (official)

```ts
import { defineProperties } from "figma:shaders"

export default function Effect() {}

export function setup(device, frame) {
  // Compile WGSL modules, allocate format-independent GPU resources once, cache on frame.state.
}

export function render(device, frame) {
  // Read frame.params, write uniforms, build bind groups, encode passes, submit.
}

defineProperties(Effect, {
  // User-editable controls (see controls.md).
})
```

| Rule | Status | Detail |
| --- | --- | --- |
| Only import is `defineProperties` from `figma:shaders` | Official | Any other import silently proxies to dead behaviour (Studio spec); nothing else is resolvable |
| `defineProperties` stays at module scope and is called last | Official | Figma's 20 first-party shaders all end with it |
| No module-scope `var`, `let`, `const` | Official | The runtime strips top-level declarations and the build rejects them; data lives in `setup`, `render`, or `frame.state` |
| Module-scope `function` declarations are allowed | Observed | Dither, Pattern grid, Lens distortion ship 8 to 15 module-scope helper functions each |
| TypeScript annotations are allowed | Official | Build runs TypeScript and ESLint in process; Gooey merge uses `device: any`. Plain `var`-style JS stays most portable |
| WGSL entry points `vs_main` / `fs_main`; compute `main` | Official (policy) | Any name is legal WGSL; Figma's host expects these |
| Every WGSL module string starts with `diagnostic(off,derivative_uniformity);` | Official (policy) | Must be the first declaration; see wgsl-webgpu-rules.md |
| Uniform buffer sizes are multiples of 16 bytes | Official | Pack in `vec4f` slots unless you need tight packing |
| `COPY_DST` on buffers written with `writeBuffer` and textures written with `writeTexture` | Official | WebGPU validation |
| Build pipelines lazily in `render()` and cache by `frame.output.format` | Official | Never hardcode `rgba8unorm` for the output target; intermediate textures you own may use any format |
| No `cleanup()` hook | Observed | No first-party shader exports one; `frame.state` resources are never disposed by the host. Call `.destroy()` yourself when reallocating textures |

## Sandbox (official plus observed)

Available: a real `GPUDevice`, WebGPU enums (`GPUBufferUsage`, `GPUTextureUsage`, `GPUShaderStage`),
`Float32Array` and integer typed arrays, `Uint8Array`, `DataView`, `ArrayBuffer`, `Math`, `Number`,
`Object`, `Array`, `String`, `JSON`, `Map`, `Set`, promises.

Absent: `window`, `document`, `navigator`, `self`, `globalThis`, `console`, `fetch`,
`XMLHttpRequest`, `WebSocket`, timers, `requestAnimationFrame`, `queueMicrotask`, `localStorage`,
`Float64Array`, `Float16Array`, `Worker`. The Studio preview harness shadows 22 globals to
`undefined` to imitate this realm.

Consequences:

- `setup` and `render` are synchronous. Animation comes only from `frame.time`.
- There is no logging. Debug by rendering values as colour (see the probe pattern in
  design-patterns.md) or by reading the compiler output from `update_shader`.
- CPU math is double precision but uniform uploads are f32. Use `Math.fround` when a CPU value must
  match a GPU comparison exactly (Halftone does this for blur radii).
- Write math in JavaScript form (`Math.sin`), never bare WGSL names in JS.

## `features.json` manifest

The manifest is build-owned. `update_shader` can only change `name`, `description`, `isAnimated`,
and `usesMouse` through `metadata`. Never push it as a file. Keep a mirrored copy in the repo for
reference only.

| Key | Values seen | Status | Who sets it |
| --- | --- | --- | --- |
| `name` | display name | Official | `create_shader` name, `update_shader.metadata.name` |
| `version` | `2` on a fresh `create_shader` scaffold, Outlines, and fm-halftone; `3` on 19 of 20 first-party shaders | Observed | Build. No MCP field changes it |
| `isAnimated` | `true` only when source reads `frame.time`, `frame.deltaTime`, or `frame.frame` | Official | `metadata.isAnimated` |
| `usesMouse` | `true` only when source reads `frame.mousePosition` | Official | `metadata.usesMouse` |
| `renderScaleAware` | `true` on every version-3 first-party shader, absent on version 2 | Observed | Build. No MCP field |

Inferred: `renderScaleAware: true` declares that the shader renders correctly at any
`frame.renderScale` (Warp and Clouds carry it without ever reading the value). A version-2 shader
cannot be moved to version 3 through MCP, so write render-scale-correct code regardless of the
manifest version.

The web export runtime (`get_design_context` ships it) reads the manifest as a `manifest` export and
uses `isAnimated` to decide whether to run a frame clock and `usesMouse` to decide whether to track
the pointer. That is why metadata must match source: a shader that reads `frame.time` with
`isAnimated: false` freezes on the first frame.

## The `frame` object

Live probe on 2026-11-02 (version-2 fill, in-app host, measured through export renders at 0.5x, 1x,
2x, and 4x): `frame` has exactly nine own keys: `input`, `output`, `params`, `state`, `time`,
`deltaTime`, `frame`, `mousePosition`, `renderScale`.

| Field | Status | Meaning and units | How to read it |
| --- | --- | --- | --- |
| `frame.input` | Official | Input `GPUTexture` or `null`. Effects sample it; fills never bind it. Premultiplied alpha. May carry a padding halo | Guard `frame.input == null` before `createView()`, or bind a 1x1 transparent placeholder |
| `frame.output` | Official | Target `GPUTexture`: `.width`, `.height`, `.format`, `.createView()` | Render into `frame.output.createView()`; size uniforms from `.width/.height` |
| `frame.output.width/height` | Observed | Physical render texels. Equal to design pixels at 1x; 250 for a 500-pt layer at 0.5x | Convert to design points by dividing by `renderScale` |
| `frame.output.format` | Observed | `rgba8unorm` in every measurement | Still key pipelines by it |
| `frame.output.physicalWidth/Height` | Observed on v3 first-party shaders only; undefined on the v2 probe | Unclamped physical canvas size | Always `frame.output.physicalWidth ?? frame.output.width` |
| `frame.input.physicalWidth/Height` | Observed (Halftone, Warp, Bloom) | Same for the input | Same fallback |
| `frame.params` | Official | Values keyed by `defineProperties` keys | Use defensive readers; strings may arrive as `{ characters }` |
| `frame.state` | Official | Persistent mutable bag per shader instance | Modules, buffers, samplers, pipelines, caches, previous-frame values |
| `frame.time` | Official | Absolute clock in milliseconds | `Number(frame.time) * 0.001`; prefer over accumulating deltas |
| `frame.deltaTime` | Official | Milliseconds since the previous rendered frame; can be negative when a Motion playhead loops | Clamp to `[0, 100]` and zero it on discontinuities |
| `frame.frame` | Official | Zero-based rendered-frame counter | Rarely needed |
| `frame.mousePosition` | Official | `{ x, y }` in layer-local pixels; may be absent | Guard missing, divide by `renderScale`, normalise by output size |
| `frame.renderScale` | Observed, present even on v2 | Physical texels per design point. 1.0 at 1x, about 0.5 at a 0.5x export | `Math.max(Number(frame.renderScale) \|\| 1, 1e-6)` |
| `frame.inputPadding` / `frame.outputPadding` | Observed on first-party effects; undefined on the v2 fill probe | Halo inset around content in the input, and halo the output extends beyond content | `Number(frame.inputPadding) \|\| 0`; subtract pads from widths in the same unit |

### The render-scale idiom (observed, Figma's Halftone)

```ts
var renderScale = Math.max(Number(frame.renderScale) || 1, 0.000001)
// Design-unit dimensions: every user-facing size and position is computed in these.
var w = (frame.output.physicalWidth ?? frame.output.width) / renderScale
var h = (frame.output.physicalHeight ?? frame.output.height) / renderScale
var centerX = (centerXPct / 100) * w
var cellPoints = frame.params.cellSize            // a "px" control means design points
var cellTexels = cellPoints * renderScale        // only when you need texels (blur taps, pixel grids)
```

In WGSL, either work in UV space (resolution independent by construction) or convert
`@builtin(position)` to points by dividing by `renderScale` before any user-unit maths. Quantise
grain and dither to points (`floor(position.xy / renderScale)`) so noise does not change character
with zoom.

### Padding idiom (observed, Figma's Filter presets and Gradient map)

```wgsl
// p is content-relative UV (0..1 over the content rect). The bound input is the upstream padded
// output with the content inset by inputPad on every side, so map content UV -> texture UV.
fn sampleInput(p: vec2f) -> vec4f {
  let iDims = max(u.inputDimsAndPad.xy, vec2f(1.0));
  let iPad = u.inputDimsAndPad.z;
  let texCoord = (vec2f(iPad) + clamp(p, vec2f(0.0), vec2f(1.0)) * iDims) / (iDims + vec2f(2.0 * iPad));
  return textureSampleLevel(inputTex, samp, texCoord, 0.0);
}
// Transparent outside the content rect; use for samples that can land in the output halo,
// because clamping there smears the edge row into opaque streaks.
fn sampleInputOrZero(p: vec2f) -> vec4f {
  let inside = step(vec2f(0.0), p) * step(p, vec2f(1.0));
  return sampleInput(p) * (inside.x * inside.y);
}
```

CPU side: `outputPad = (Number(frame.outputPadding) || 0) / renderScale`, `inputPad` likewise,
`contentW = Math.max(1, w - 2 * outputPad)`, and the fragment maps
`uv = (fragPx - vec2f(inputPad + outputPad)) / contentDims`. Keep pads and widths in one unit.

### Time and Motion idiom (observed, Shape-based particles)

```ts
var time = Number(frame.time) || 0
var prev = frame.state.previousTimelineTime
var movedBackward = prev != null && time < prev
frame.state.previousTimelineTime = time
var dtMs = Number.isFinite(Number(frame.deltaTime)) ? Number(frame.deltaTime) : 16
if (movedBackward || dtMs < 0) { dtMs = 0 }   // Motion playhead looped: freeze integration one frame
var dt = Math.max(0, Math.min(dtMs, 100)) * 0.001
```

## Alpha contract

| Kind | Input | Output | Opacity change | Verified |
| --- | --- | --- | --- | --- |
| Effect | Premultiplied | Premultiplied | `color *= opacity` (all four channels) | Official; 12 first-party effects un-premultiply before colour maths and re-premultiply at the end |
| Fill | None (never bind `frame.input`) | **Straight** | `color.a *= opacity` | Official, and confirmed by the live probe: a fill writing `(1,0,0,0.5)` rendered identical to a native 50%-opacity red |

Do not copy the fill scaffold's `vec4f(color.rgb * color.a, color.a)` or Pattern grid's premultiplied
fill output. Both darken semi-transparent fill pixels. For opaque output they are harmless.

## Platform limits (official)

- Shaders need WebGPU; Figma's compatibility mode and Firefox do not render them.
- Only one animated or interactive shader runs on a page at a time; users press Play.
- Building and editing consume AI credits; applying does not. Available on every plan with edit
  access except K-12 Education. Internal publishing needs Organization or Enterprise.
- Shaders are absent from Dev Mode. Anyone can view or download any shader's code.

## What the export runtime does differently

`get_design_context` emits a React runtime (`ShaderEffect`, `ShaderFill`) for web implementations.
It builds `frame` with the same documented fields plus `gpu` and `mousePosition.down`, sets
`renderScale = window.devicePixelRatio`, and composites the canvas with `alphaMode: 'premultiplied'`
for both kinds. A fill's `input` there is a zeroed texture, not `null`. Write Figma-first code and
let that host adapt; do not depend on `gpu` or `.down` in Figma.
