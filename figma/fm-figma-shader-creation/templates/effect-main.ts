import { defineProperties } from "figma:shaders"

// fm-<name>-shader — Futuremotion Studio
// Effect shader template: samples the layer beneath, applies a tint and a vignette.
// Replace the WGSL body and the controls; keep the structure.
//
// Pipeline per frame:
//   1. Screen pass: sample input (padding-aware) → un-premultiply → tint + vignette →
//      mix with original → re-premultiply → frame.output.
//
// Units: user-facing sizes are design points. JS derives point dimensions as
// physical / frame.renderScale; WGSL works in content UV and points.
// Alpha: premultiplied in, premultiplied out (effect contract).
// UV: the fullscreen quad maps uv (0,0) to the top-left and (1,1) to the bottom-right.
//
// Presets ("Presets") are resolved in render(): a preset is the control defaults plus an
// explicit delta, so a preset renders identically on every layer regardless of where the
// live sliders happen to sit. While a preset is selected the sliders do nothing.

export default function Effect() {}

export function setup(device, frame) {
  // ---------------------------------------------------------------------------
  // WGSL — screen pass.
  // ---------------------------------------------------------------------------
  var wgsl = `diagnostic(off,derivative_uniformity);

// Uniform layout — every slot is a vec4f so padding is explicit (64 bytes total).
struct U {
  dims: vec4f,     // contentW(pt), contentH(pt), inputPad(pt), outputPad(pt)
  p0: vec4f,       // amount 0..1, vignette 0..1, mode (0 Multiply, 1 Screen), invert 0/1
  tint: vec4f,     // straight RGBA 0..1
  p1: vec4f,       // centerX(pt), centerY(pt), unused, unused
};
@group(0) @binding(0) var<uniform> u: U;
@group(0) @binding(1) var samp: sampler;
@group(0) @binding(2) var inputTex: texture_2d<f32>;

struct VsIn { @location(0) pos: vec2f, @location(1) uv: vec2f };
struct VsOut { @builtin(position) position: vec4f, @location(0) uv: vec2f };

@vertex fn vs_main(in: VsIn) -> VsOut {
  var out: VsOut;
  out.position = vec4f(in.pos, 0.0, 1.0);
  out.uv = in.uv;
  return out;
}

fn unpremul(c: vec4f) -> vec4f {
  if (c.a > 0.0001) { return vec4f(c.rgb / c.a, c.a); }
  return vec4f(0.0);
}

// Content-relative UV (0..1 over the content rect) -> texture UV, honoring the input
// halo. For a stand-alone effect inputPad is 0 and this reduces to clamp(p).
fn sampleInput(p: vec2f) -> vec4f {
  let iDims = max(u.dims.xy, vec2f(1.0));
  let iPad = u.dims.z;
  let tc = (vec2f(iPad) + clamp(p, vec2f(0.0), vec2f(1.0)) * iDims) / (iDims + vec2f(2.0 * iPad));
  return textureSampleLevel(inputTex, samp, tc, 0.0);
}

// Transparent outside the content rect; use for samples that can land in the output halo.
fn sampleInputOrZero(p: vec2f) -> vec4f {
  let inside = step(vec2f(0.0), p) * step(p, vec2f(1.0));
  return sampleInput(p) * (inside.x * inside.y);
}

@fragment fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  // Fragment position in points, then content-relative UV (output may carry a halo).
  let outDims = u.dims.xy + vec2f(2.0 * u.dims.w);
  let fragPt = uv * outDims;
  let contentPt = fragPt - vec2f(u.dims.w);
  let cuv = contentPt / max(u.dims.xy, vec2f(1.0));

  let src = sampleInputOrZero(cuv);
  let o = unpremul(src);

  // mode: 0 Multiply, 1 Screen
  let mode = i32(u.p0.z + 0.5);
  var tinted = o.rgb * u.tint.rgb;
  if (mode == 1) { tinted = 1.0 - (1.0 - o.rgb) * (1.0 - u.tint.rgb); }
  var rgb = mix(o.rgb, tinted, u.p0.x * u.tint.a);

  // Vignette in points so it keeps its shape at any render scale.
  let d = distance(contentPt, u.p1.xy) / max(length(u.dims.xy) * 0.5, 1.0);
  var v = 1.0 - smoothstep(0.4, 1.0, d) * u.p0.y;
  if (u.p0.w > 0.5) { v = 1.0 - v; }
  rgb = rgb * v;

  rgb = clamp(rgb, vec3f(0.0), vec3f(1.0));
  return vec4f(rgb * o.a, o.a); // premultiplied out
}
`
  frame.state.module = device.createShaderModule({ code: wgsl })
  frame.state.pipeline = null
  frame.state.pipelineFormat = null

  // Shared fullscreen quad (clip-space position + UV, interleaved).
  frame.state.vertexBuffers = [{
    arrayStride: 16,
    attributes: [
      { shaderLocation: 0, format: "float32x2", offset: 0 },
      { shaderLocation: 1, format: "float32x2", offset: 8 },
    ],
  }]
  frame.state.quad = device.createBuffer({ size: 6 * 4 * 4, usage: GPUBufferUsage.VERTEX, mappedAtCreation: true })
  new Float32Array(frame.state.quad.getMappedRange()).set([
    -1, -1, 0, 1,  1, -1, 1, 1,  -1, 1, 0, 0,
    -1, 1, 0, 0,   1, -1, 1, 1,   1, 1, 1, 0,
  ])
  frame.state.quad.unmap()

  // Uniforms: 4 vec4f slots = 64 bytes (see the U struct comments).
  frame.state.uniforms = device.createBuffer({ size: 64, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST })

  frame.state.sampler = device.createSampler({
    magFilter: "linear", minFilter: "linear",
    addressModeU: "clamp-to-edge", addressModeV: "clamp-to-edge",
  })

  // 1x1 transparent placeholder so the bind group shape never changes when input is null.
  frame.state.placeholder = device.createTexture({
    size: [1, 1, 1], format: "rgba8unorm",
    usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
  })
  device.queue.writeTexture({ texture: frame.state.placeholder }, new Uint8Array([0, 0, 0, 0]), { bytesPerRow: 4 }, { width: 1, height: 1, depthOrArrayLayers: 1 })
}

export function render(device, frame) {
  var p = frame.params || {}

  // ---------------------------------------------------------------------------
  // Param readers. Every control is read into `live` so the preset engine can replace
  // it wholesale. Readers return exactly the shapes `defaults` uses.
  // ---------------------------------------------------------------------------
  function fin(x, fb) { var n = Number(x); return Number.isFinite(n) ? n : fb }
  function num(name, fb) { return fin(p[name], fb) }
  function bool(name, fb) { return typeof p[name] === "boolean" ? (p[name] ? 1 : 0) : (fb ? 1 : 0) }
  function color(name, fb) { var c = p[name] || {}; return [fin(c.r, fb[0]), fin(c.g, fb[1]), fin(c.b, fb[2]), fin(c.a, fb[3])] }
  function point(name, fb) { var q = p[name] || {}; return [fin(q.x, fb[0]), fin(q.y, fb[1])] }

  // ---------------------------------------------------------------------------
  // Control defaults. MUST mirror the defaultValue of every control in
  // defineProperties() below (module-scope constants are stripped by the build, so
  // the table lives here). Presets are applied on top of these, never on top of the
  // live sliders; that is what makes a preset render identically everywhere.
  // ---------------------------------------------------------------------------
  var defaults = {
    amount: 100, mode: 0, tint: [1, 0.85, 0.6, 1], vignette: 30, invert: 0, center: [50, 50],
  }

  // Live values from the panel, in the same shape as `defaults`.
  var live = {
    amount: num("amount", defaults.amount),
    mode: num("mode", defaults.mode),
    tint: color("tint", defaults.tint),
    vignette: num("vignette", defaults.vignette),
    invert: bool("invert", defaults.invert),
    center: point("center", defaults.center),
  }

  // ---------------------------------------------------------------------------
  // Factory presets. Each entry is a delta applied to `defaults`.
  //
  // To add a preset:
  //   1. Add { value: N, label: "Name" } to the `preset` options in defineProperties().
  //   2. Add factoryPresets[N] = { ...only the controls that differ from defaults... }.
  // Keys and value formats match `defaults` exactly (colors are [r,g,b,a] in 0..1,
  // points are [x%, y%], booleans are 0/1, selects use numeric ids).
  // Anything not listed renders at its default, never at the live slider.
  // Ids are permanent: styles store them. Never renumber or reuse an id.
  // ---------------------------------------------------------------------------
  var factoryPresets = {
    1: { // Warm film
      amount: 60, tint: [1, 0.8, 0.55, 1], vignette: 45,
    },
    2: { // Cool screen
      amount: 50, mode: 1, tint: [0.55, 0.75, 1, 1], vignette: 20,
    },
  }

  // Resolve the effective control set: a preset fully replaces the live panel.
  var presetId = num("preset", 0)
  var v = live
  if (presetId > 0 && factoryPresets[presetId]) {
    v = Object.assign({}, defaults, factoryPresets[presetId])
  }

  // ---------------------------------------------------------------------------
  // Geometry in design points. output.* are physical texels; divide by renderScale.
  // physicalWidth and the padding fields are optional (version-3 manifests); fall back.
  // ---------------------------------------------------------------------------
  var renderScale = Math.max(Number(frame.renderScale) || 1, 0.000001)
  var outW = (frame.output.physicalWidth ?? frame.output.width) / renderScale
  var outH = (frame.output.physicalHeight ?? frame.output.height) / renderScale
  var outputPad = (Number(frame.outputPadding) || 0) / renderScale
  var inputPad = (Number(frame.inputPadding) || 0) / renderScale
  var contentW = Math.max(1, outW - 2 * outputPad)
  var contentH = Math.max(1, outH - 2 * outputPad)

  // ---------------------------------------------------------------------------
  // Uniform packing — indices match the U struct comments.
  // ---------------------------------------------------------------------------
  device.queue.writeBuffer(frame.state.uniforms, 0, new Float32Array([
    contentW, contentH, inputPad, outputPad,                         // dims
    v.amount / 100, v.vignette / 100, v.mode, v.invert,              // p0
    v.tint[0], v.tint[1], v.tint[2], v.tint[3],                      // tint
    (v.center[0] / 100) * contentW, (v.center[1] / 100) * contentH, 0, 0, // p1
  ]))

  var hasInput = frame.input != null
  var inputView = hasInput ? frame.input.createView() : frame.state.placeholder.createView()

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

  // Bind groups that reference frame.input are rebuilt every frame: the input texture
  // may be recreated by the host.
  var bindGroup = device.createBindGroup({
    layout: frame.state.pipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: frame.state.uniforms } },
      { binding: 1, resource: frame.state.sampler },
      { binding: 2, resource: inputView },
    ],
  })

  var encoder = device.createCommandEncoder()
  var pass = encoder.beginRenderPass({
    colorAttachments: [{ view: frame.output.createView(), loadOp: "clear", clearValue: { r: 0, g: 0, b: 0, a: 0 }, storeOp: "store" }],
  })
  pass.setPipeline(frame.state.pipeline)
  pass.setBindGroup(0, bindGroup)
  pass.setVertexBuffer(0, frame.state.quad)
  pass.draw(6)
  pass.end()
  device.queue.submit([encoder.finish()])
}

defineProperties(Effect, {
  // ---- Presets ----
  // "Custom" renders the live controls below. Any other entry renders the preset exactly
  // (defaults + delta in render()); the sliders are ignored while a preset is selected.
  preset: {
    type: "number", label: "Presets", defaultValue: 0, control: "select",
    options: [
      { value: 0, label: "Custom (use controls)" },
      { value: 1, label: "Warm film" },
      { value: 2, label: "Cool screen" },
    ],
  },
  // ---- Tint ----
  mode: {
    type: "number", label: "Blend", defaultValue: 0, control: "select",
    options: [{ value: 0, label: "Multiply" }, { value: 1, label: "Screen" }],
  },
  tint: { type: "color", label: "Tint", defaultValue: { r: 1, g: 0.85, b: 0.6, a: 1 } },
  amount: { type: "number", label: "Amount", defaultValue: 100, control: "slider", min: 0, max: 100, step: 1, unit: "%" },
  // ---- Vignette ----
  vignette: { type: "number", label: "Vignette", defaultValue: 30, control: "slider", min: 0, max: 100, step: 1, unit: "%" },
  invert: { type: "boolean", label: "Invert vignette", defaultValue: false },
  center: { type: "point", label: "Center", defaultValue: { x: 50, y: 50 }, control: "point", mode: "canvas_and_ui", unit: "%" },
})
