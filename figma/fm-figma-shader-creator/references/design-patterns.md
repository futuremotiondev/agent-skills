# Design patterns from Figma's first-party shaders

Twenty first-party shaders were read in source on 2026-11-02. These are the patterns that recur,
with the shader that shows each one best. Copy the shape, not the shader.

## Infrastructure

### Format-keyed pipeline cache (every shader)

```ts
var outputFormat = frame.output.format
if (frame.state.pipeline == null || frame.state.pipelineFormat !== outputFormat) {
  frame.state.pipeline = device.createRenderPipeline({
    layout: "auto",
    vertex: { module: frame.state.module, entryPoint: "vs_main", buffers: frame.state.vertexBuffers },
    fragment: { module: frame.state.module, entryPoint: "fs_main", targets: [{ format: outputFormat }] },
    primitive: { topology: "triangle-list" },
  })
  frame.state.pipelineFormat = outputFormat
}
```

Intermediate passes that render into textures you own are pinned to a fixed format you choose
(`rgba8unorm`, `r16float`) and built once in `setup` or on first use.

### Fullscreen quad (official)

Six interleaved vertices (clip-space position, UV), `arrayStride: 16`, drawn with `pass.draw(6)`.
Moving gradient and Moving blobs use a bufferless triangle from `@builtin(vertex_index)` with
`draw(3)` instead; either is fine.

### Null-input handling (effects)

Two styles. Early return: `if (frame.input == null) { return }` (Halftone, Warp, Bloom). Placeholder:
bind a 1x1 transparent `rgba8unorm` texture written once in `setup` so the bind-group shape never
changes (Filter presets, Gradient map, fm-halftone). The placeholder style is simpler to reason
about when the shader has several passes.

### Dirty-checked uniform writes (Moving blobs, Channel mixer, Pattern grid, Bloom)

```ts
function writeUniformsIfChanged(device, buffer, data, lastData) {
  var changed = false
  for (var i = 0; i < data.length; i += 1) {
    if (!Object.is(data[i], lastData[i])) { changed = true; break }
  }
  if (changed) { device.queue.writeBuffer(buffer, 0, data); lastData.set(data) }
}
// setup: frame.state.lastUniforms = new Float32Array(N).fill(NaN)   // NaN forces the first upload
```

### Cache by identity, destroy on resize (Bloom, Halftone, Light rays)

Rebuild bind groups only when `frame.state.inputTexture !== frame.input`, and null every dependent
cache when you do ("the composite also references the input"). When an intermediate texture's size
no longer matches, call `.destroy()` on the old one before `createTexture`. Gooey merge forgets to
destroy; do not copy it.

### Gaussian weights in a storage buffer (Halftone, fm-halftone)

Compute the 65-tap kernel on the CPU only when the f32-rounded radius changes, write it to a
`var<storage, read>` buffer, and sample with `textureSampleLevel(..., 0.0)` in a fixed loop.

## Controls and units

### Percent and degrees are converted in JS (every shader)

`centerX = (centerPct / 100) * w`, `angleRad = angleDeg * Math.PI / 180`, `threshold = 0.85 -
(p.threshold / 100) * 0.75`. WGSL receives engineering units only.

### Select decode (every shader)

```wgsl
// warpMode: 0 Sine, 1 Twist, 2 Bulge, 3 Pinch, 4 Ripple, 5 Flag, 6 Squeeze, 7 Swirl
let mode = i32(u.warpMode + 0.5);
```

Mode-specific controls stay visible for every mode (Figma has no conditional UI) and are simply
reinterpreted or ignored per mode. Say so in the control label or the header.

### Gradient packing (Gradient map, Outlines, fm-halftone)

Eight RGBA colours, eight positions packed four per `vec4f`, then a count. WGSL reads
`fn stopPos(i: u32) -> f32 { return u.gradPos[i >> 2u][i & 3u]; }` and walks the stops in a fixed
loop of 8, using `select(f, 0.0, i32(i) >= n)` to ignore unused slots.

### Transform handle (Pattern grid, Glowing wave, Fractal noise)

A single `point-angle-radius` control named `transform` replaces separate X, Y, scale, and rotation
sliders. Position in percent, radius in percent of the smaller dimension (or `px` when it doubles as
a cell size), angle in degrees converted to radians in JS.

## Resolution independence

- Compute design-point dimensions once (`physical / renderScale`) and derive everything from them.
- Quantise grain and dither to points: `hashPixel(vec2u(floor(in.position.xy / u.renderScale)))`
  (Moving blobs).
- Work on a logical grid and box-average `renderScale` physical texels per logical texel when
  seeds must not depend on subpixels (Outlines).
- Anti-alias SDF edges with `max(fwidth(d) * softness, radius * feather)` so edges stay crisp at any
  zoom while a separate feather gives resolution-independent softness (fm-halftone). Pattern grid
  uses `clamp(fwidth(d), 0.0, 1.5)`.

## Multi-pass and compute

### Downsampled blur chain (Bloom)

Extract at full resolution, six separable blur passes ping-ponging through half- and
quarter-resolution `rgba8unorm` textures (downsampling is implicit when rendering into a smaller
target with linear sampling, radius halves per level), then composite. Fixed 33-tap loop.

### Half-resolution field cached across frames (Moving blobs)

Render the expensive noise field into a half-size texture only when its inputs (phase, scale,
detail, padding, size) change; the full-resolution pass just samples it.

### Mip-pyramid mask (Light rays)

Render into per-mip views with `createView({ baseMipLevel: level, mipLevelCount: 1 })` on an
`r16float` texture; record the whole chain only when the control that needs it is non-zero.

### Jump-flood SDF in compute (Outlines)

`rg32float` storage textures, `@workgroup_size(8, 8)` with a bounds guard, `log2(maxDim)` passes
halving the step, ping-pong between two textures, all on one command encoder before the render.

### Error diffusion in a single invocation (Dither)

`@workgroup_size(1)`, `dispatchWorkgroups(1)`, walking anti-diagonals so error writes to future
pixels are data-race free. Ordered dithering runs at 8x8 instead.

### Runtime WGSL specialisation (Lens distortion)

Patch constants into the WGSL string with `String.replace` and cache `{ module, pipeline }` under a
key such as `` `${format}:q${quality}:mode${mode}` ``. Bucket continuous sliders so dragging does
not compile per frame.

### Adaptive supersampling (Warp, Moving blobs)

Estimate the sampling footprint from finite differences of the warped UV, choose N up to a fixed
`MAX_GRID = 6`, and loop the full grid with `continue` past N (fixed-bound loop rule). Moving blobs
supersamples only where `fwidth(luma) + fwidth(alpha)` exceeds a threshold.

## Animation, Motion, and mouse

### Keyframable phase with a seamless loop (Glowing wave, Nebula, Outlines, Pattern grid)

A static shader (`isAnimated: false`) exposes a 0..100 "Phase" slider mapped to one full period
(`phase * 2 * Math.PI / 100`), so that keyframing 0 to 100 in Motion loops exactly. The period is
the pattern's own repeat (one line pitch, one tile, one wave), never a fixed distance, so the loop
survives changes to spacing or scale. Fade elements in at phase 0 and out at phase 1 so the two
ends are identical. Phase controls are exempt from the factory-preset invariant (see
factory-presets.md) so a preset layer can still loop. This design survives the
one-animated-shader-per-page limit and the capability gate, and it exports as video cleanly.
**Design every animated effect so it can also be driven this way.**

### Time-driven with a speed slider (Moving gradient, Light rays, Moving blobs)

```ts
var speed = Math.max(0, Math.min(100, num("speed", 10)))
var loopLength = 90 - (speed / 100) * 78            // seconds for one exact loop
var t = (Number(frame.time) || 0) * 0.001
var phase = speed > 0 ? (t / loopLength + 0.45) : 0.45
phase -= Math.floor(phase)                           // wrap to avoid float drift
// cos/sin of phase * 2π drive a circle through the extra dimensions of 4D noise
```

Set `isAnimated: true`. Wrap long-running time (`phase - floor(phase / tau) * tau`) because f32
loses precision after minutes. Keyframing `speed` itself jumps the phase.

### Mouse (Shape-based particles)

Treat a missing mouse as far away (`-9999`), divide coordinates by `renderScale`, offset by the pads,
and reset previous-position state when the mouse becomes invalid so re-entry does not draw a
teleport path. Set `usesMouse: true`.

## Debugging without a console

Render the value you want to inspect as colour. A flag row of green/red squares and bars with
tick marks every 10% read reliably from a screenshot. The probe used to verify this skill drew
`frame.renderScale / 4` as a bar and `frame.output.format` as a colour code. Keep such a probe in
your repo; it costs nothing to run through `update_shader` on a throwaway shader.
