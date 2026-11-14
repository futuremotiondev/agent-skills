# WGSL and WebGPU rules, split into language law and Figma policy

Knowing which layer a rule comes from tells you what an error means. A language-law violation is a
compiler error with naga's wording. A policy violation is either a Figma build rejection or a
silent runtime failure.

## Rule table

| Rule | WGSL / WebGPU status | Figma status | Why |
| --- | --- | --- | --- |
| Start every WGSL string with `diagnostic(off,derivative_uniformity);` | Directive syntax and first-position placement are spec law; turning it off is a choice | Policy, mandatory | Lets `textureSample` and derivative calls compile inside branches; directives must precede all declarations |
| `let` is immutable; use `var` to mutate | Law | Restated | Language semantics |
| No function-scope `const` | Legal WGSL | Policy | Figma's validator path; use `let` for function constants, module-scope WGSL `const` is fine |
| No multi-component swizzle assignment (`v.xy = ...`) | Law without the optional `swizzle_assignment` extension | Restated | Replace the whole vector |
| `array(a, b)`, not `[a, b]` | Law | Restated | WGSL has no bracket initialisers |
| Matrices are built from columns | Law | Restated | `mat2x2f(vec2f(c, s), vec2f(-s, c))` is a counter-clockwise rotation |
| `select(falseValue, trueValue, cond)` | Law | Restated | Opposite of a C ternary |
| Avoid naming things `texture`, `sampler`, `sample`, `min`, `max` | Not reserved; they are shadowable predeclared names | Policy | Shadowing `min` breaks later `min()` calls in scope |
| `meta`, `mod`, and keywords are off limits | Reserved by spec | Restated | There is no `mod()`; write `x - y * floor(x / y)` or use `fract` |
| No `gl_*` builtins | Law (they do not exist) | Restated | Use `@builtin(position)` and friends |
| Implicit-derivative calls in uniform control flow | Law | Restated | GPUs compute derivatives across 2x2 quads |
| Uniform buffers are multiples of 16 bytes | Derived from struct rounding and uniform array stride | Policy wording | Safe universal rule |
| Entry points `vs_main`, `fs_main`, compute `main` | Any name is legal | Policy | Host convention |
| Fixed-bound loops | Legal either way | Policy, plus review rejects unbounded loops | Predictable cost; uniformity |
| Never hardcode the output format | Preferred formats vary by platform | Policy | The pipeline target must match the attachment |
| `COPY_DST` on written buffers and textures | WebGPU law | Restated | Validation |
| No module-scope JS `var` / `let` / `const` | Not WGSL; a JS runtime rule | Policy, build-enforced | The host loader strips top-level declarations |

## Memory layout

Uniform data obeys fixed alignment and size rules (WGSL section 14.4.1), and the uniform address
space requires every array stride and nested struct offset to be a multiple of 16 (section 14.4.5).

| Type | Align | Size | Consequence in a uniform buffer |
| --- | --- | --- | --- |
| `f32`, `i32`, `u32` | 4 | 4 | Fine as members; `array<f32, N>` needs a 16-byte stride, so use `array<vec4f, N/4>` and index with `arr[i >> 2u][i & 3u]` |
| `vec2f` | 8 | 8 | Must sit at an 8-byte offset |
| `vec3f` | 16 | 12 | A following `f32` fills bytes 12..15; a following `vec2f` jumps to the next 16 |
| `vec4f` | 16 | 16 | The natural slot; `array<vec4f, N>` has stride 16 |
| `mat2x2f` | 8 | 16 | Columns contiguous |
| `mat3x3f` | 16 | 48 | Each column padded to 16 |
| `mat4x4f` | 16 | 64 | |
| struct | max member align, 16 when nested in uniform | last member end rounded up to the struct align | Total buffer size must be a multiple of 16 |

### Worked packing example (160 bytes)

```wgsl
struct Params {
  resolution : vec2f,           // off   0  size  8
  time       : f32,             // off   8
  intensity  : f32,             // off  12  (ends 16)
  center     : vec2f,           // off  16
  scale      : f32,             // off  24
  rotation   : f32,             // off  28  (ends 32)
  tint       : vec4f,           // off  32  (ends 48)
  lightDir   : vec3f,           // off  48  size 12
  softness   : f32,             // off  60  fills the vec3 tail (ends 64)
  stopCount  : u32,             // off  64
  mode       : u32,             // off  68
  seed       : f32,             // off  72
  _pad0      : f32,             // off  76  explicit padding (ends 80)
  stopColors : array<vec4f, 4>, // off  80  stride 16 (ends 144)
  stopPos    : vec4f,           // off 144  four positions in .xyzw (ends 160)
};
```

```ts
var buf = new ArrayBuffer(160)          // 10 * 16
var f32 = new Float32Array(buf)
var u32 = new Uint32Array(buf)          // same memory; use it for u32 fields
u32[16] = stopCount; u32[17] = mode     // not f32[16], which would write float bits
device.queue.writeBuffer(frame.state.uniforms, 0, buf)
```

Float index is byte offset divided by 4. The three strategies Figma uses, in order of preference
for a skill user:

1. **One `vec4f` slot per parameter group with the value in `.x`** (Filter presets, Gradient map,
   fm-halftone at 480 bytes). Wastes bytes, can never misalign, and the layout comment is trivial.
2. Scalar structs with named `pad0` members (Moving gradient, Clouds).
3. `DataView` writes at computed byte offsets (Dither). Only for dozens of mixed scalars.

Whichever you choose, write the layout as a comment above the `createBuffer` call and keep the
WGSL struct comments in sync. See file-structure-and-comments.md.

## Uniformity: why the directive exists and what it does not fix

`textureSample`, `textureSampleBias`, `textureSampleCompare`, `dpdx`, `dpdy`, and `fwidth` need
all four fragments of a 2x2 quad to execute together, because the hardware derives mip level and
derivatives from neighbour differences. WGSL requires those calls in uniform control flow and
raises `derivative_uniformity` (default severity error) when one sits inside a branch on a
per-fragment value. The global `diagnostic(off, derivative_uniformity);` silences the check.
**Silencing it does not make the derivatives correct.** A quad whose neighbours skipped the call
reads undefined values.

```wgsl
// WRONG: error without the directive; garbage derivatives even with it
if (mask > 0.5) { c = textureSample(tex, smp, uv); }

// RIGHT A: explicit level, no implicit derivative, exempt from the rule (Figma uses this everywhere)
if (mask > 0.5) { c = textureSampleLevel(tex, smp, uv, 0.0); }

// RIGHT B: exact texel fetch, integer coordinates, no sampler
c = textureLoad(tex, vec2i(uv * vec2f(textureDimensions(tex))), 0);

// RIGHT C: sample unconditionally, choose afterwards
let s = textureSample(tex, smp, uv);
c = select(vec4f(0.0), s, mask > 0.5);
```

`fwidth`-based anti-aliasing must run before any early `return` or `discard`. Compute the edge width
first, then branch.

## Other WGSL traps

- No implicit integer-to-float conversion: `2.0 * f32(n)`.
- Integer and float `%` take the sign of the dividend. Tile with `fract()` or
  `x - y * floor(x / y)`.
- Abstract numeric literals: `1` is abstract-int, `1.0` abstract-float, `1u` u32, `1i` i32.
- Decode numeric selects with `i32(u.mode + 0.5)` to absorb float error.
- Compute workgroups default to at most 256 invocations; Figma uses `@workgroup_size(8, 8)`.
- `rgba8unorm-srgb` cannot be a storage texture. Filtering samplers cannot read `r32float`
  (Outlines does manual bilinear interpolation on its SDF for that reason).
- Loops: prefer fixed bounds with `continue` past a runtime count, which is how Warp caps its
  supersample grid at 6x6.

## WebGPU practice

- Usage flags must match every way a resource is touched: `TEXTURE_BINDING` to sample,
  `RENDER_ATTACHMENT` to render into, `STORAGE_BINDING` for compute writes, `COPY_DST` for queue
  writes.
- `layout: "auto"` bind groups are exclusive to their pipeline, and bindings the entry point never
  uses vanish from the layout. Rebuild bind groups when you swap pipelines.
- Rebuild any bind group that references `frame.input` whenever `frame.input` changes identity.
  Per-frame creation is the safe baseline; caching by identity is the optimisation.
- Destroy textures you reallocate on resize. The host never disposes `frame.state`.
- Encode compute and render passes that feed each other on one command encoder before submitting.
- The sampler is `linear` / `linear` with `clamp-to-edge` in every first-party shader; edge
  behaviour (wrap, mirror, transparent outside) is written in the shader.

## Alpha math

| Kind | Rule | Code |
| --- | --- | --- |
| Effect input | Premultiplied | `fn unpremul(c: vec4f) -> vec4f { return select(vec4f(0.0), vec4f(c.rgb / c.a, c.a), c.a > 0.0001); }` before any colour maths |
| Effect output | Premultiplied | `return vec4f(res.rgb * res.a, res.a);` and keep `rgb <= a` after additive grain |
| Effect opacity | Scale all four channels | `color *= opacity;` |
| Fill output | Straight (probe-verified) | `return vec4f(rgb, a);` |
| Fill opacity | Scale alpha only | `color.a *= opacity;` |

Two first-party effects multiply alpha twice (Filter presets returns `blended * c.a` on an already
premultiplied `c`; Gooey merge weights luma by `s.a` on premultiplied RGB). Do not copy those lines.

## Colour spaces

Exact sRGB transfer functions, reusable verbatim (from Figma's Halftone):

```wgsl
fn srgbToLinearMono(v: f32) -> f32 {
  if (v > 0.04045) { return pow((v + 0.055) / 1.055, 2.4); }
  return v / 12.92;
}
fn linearToSrgbMono(v: f32) -> f32 {
  if (v > 0.0031308) { return 1.055 * pow(v, 0.41666) - 0.055; }
  return v * 12.92;
}
```

Blur and gradient interpolation look better in linear light. OKLab appears in Gradient map and
Moving gradient; their matrices differ in the fourth decimal, so copy one and use it consistently.
