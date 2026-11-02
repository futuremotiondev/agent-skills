import { defineProperties } from "figma:shaders"

// fm-<name>-fill — Futuremotion Studio
// Fill shader template: procedural two-colour wave pattern with a keyframable phase.
// Replace the WGSL body and the controls; keep the structure.
//
// Pipeline per frame:
//   1. Screen pass: UV → design points → wave field → colour ramp → frame.output.
//
// Units: user-facing sizes are design points. JS derives point dimensions as
// physical / frame.renderScale; WGSL works in points so the pattern keeps its size
// at any zoom or export scale.
// Alpha: straight out (fill contract). Fills never bind frame.input.
// Motion: static shader; keyframe "Phase" 0 → 100 for one seamless loop (isAnimated false).
// `phase` is exempt from the preset invariant and is always read live.
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
  dims: vec4f,     // width(pt), height(pt), renderScale, unused
  p0: vec4f,       // wavelength(pt), amplitude 0..1, phase(rad), angle(rad)
  colorA: vec4f,   // straight RGBA
  colorB: vec4f,   // straight RGBA
};
@group(0) @binding(0) var<uniform> u: U;

struct VsIn { @location(0) pos: vec2f, @location(1) uv: vec2f };
struct VsOut { @builtin(position) position: vec4f, @location(0) uv: vec2f };

@vertex fn vs_main(in: VsIn) -> VsOut {
  var out: VsOut;
  out.position = vec4f(in.pos, 0.0, 1.0);
  out.uv = in.uv;
  return out;
}

fn rot2(v: vec2f, a: f32) -> vec2f {
  let c = cos(a);
  let s = sin(a);
  return vec2f(c * v.x - s * v.y, s * v.x + c * v.y);
}

@fragment fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  // Work in design points so the wavelength is resolution independent.
  let pt = rot2((uv - vec2f(0.5)) * u.dims.xy, u.p0.w);
  let wavelength = max(u.p0.x, 1.0);
  let wave = sin(pt.x / wavelength * 6.28318530718 + u.p0.z);
  let ridge = 0.5 + 0.5 * sin((pt.y + wave * u.p0.y * wavelength) / wavelength * 6.28318530718);
  // Anti-aliased threshold: fwidth runs before any branch, in uniform control flow.
  let w = max(fwidth(ridge), 0.001);
  let t = smoothstep(0.5 - w, 0.5 + w, ridge);
  let color = mix(u.colorA, u.colorB, t);
  return color; // straight alpha out
}
`
  frame.state.module = device.createShaderModule({ code: wgsl })
  frame.state.pipeline = null
  frame.state.pipelineFormat = null

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
}

export function render(device, frame) {
  var p = frame.params || {}

  // ---------------------------------------------------------------------------
  // Param readers (see controls.md). Readers return exactly the shapes `defaults` uses.
  // ---------------------------------------------------------------------------
  function fin(x, fb) { var n = Number(x); return Number.isFinite(n) ? n : fb }
  function num(name, fb) { return fin(p[name], fb) }
  function color(name, fb) { var c = p[name] || {}; return [fin(c.r, fb[0]), fin(c.g, fb[1]), fin(c.b, fb[2]), fin(c.a, fb[3])] }

  // ---------------------------------------------------------------------------
  // Control defaults. MUST mirror the defaultValue of every control in
  // defineProperties() below (module-scope constants are stripped by the build, so
  // the table lives here). Presets are applied on top of these, never on top of the
  // live sliders.
  // ---------------------------------------------------------------------------
  var defaults = {
    wavelength: 40, amplitude: 30, angle: 0, phase: 0,
    colorA: [0.08, 0.1, 0.25, 1], colorB: [0.98, 0.93, 0.78, 1],
  }

  var live = {
    wavelength: num("wavelength", defaults.wavelength),
    amplitude: num("amplitude", defaults.amplitude),
    angle: num("angle", defaults.angle),
    phase: num("phase", defaults.phase),
    colorA: color("colorA", defaults.colorA),
    colorB: color("colorB", defaults.colorB),
  }

  // ---------------------------------------------------------------------------
  // Factory presets. Deltas on `defaults`; ids are permanent (styles store them).
  // To add one: (1) add { value: N, label } to `preset` options; (2) add factoryPresets[N].
  // ---------------------------------------------------------------------------
  var factoryPresets = {
    1: { // Fine lines
      wavelength: 12, amplitude: 10,
    },
    2: { // Bold waves
      wavelength: 90, amplitude: 60, angle: 20, colorA: [0.95, 0.3, 0.2, 1], colorB: [1, 0.9, 0.6, 1],
    },
  }

  // Resolve the effective control set: a preset fully replaces the live panel, except the
  // exempt keyframable control `phase`, which stays live so a preset layer can still loop.
  var presetId = num("preset", 0)
  var v = live
  if (presetId > 0 && factoryPresets[presetId]) {
    v = Object.assign({}, defaults, factoryPresets[presetId], { phase: live.phase })
  }

  // Geometry in design points. output.* are physical texels; divide by renderScale.
  var renderScale = Math.max(Number(frame.renderScale) || 1, 0.000001)
  var w = (frame.output.physicalWidth ?? frame.output.width) / renderScale
  var h = (frame.output.physicalHeight ?? frame.output.height) / renderScale
  var D2R = Math.PI / 180

  // Uniform packing — indices match the U struct comments.
  device.queue.writeBuffer(frame.state.uniforms, 0, new Float32Array([
    w, h, renderScale, 0,                                               // dims
    v.wavelength, v.amplitude / 100, (v.phase / 100) * Math.PI * 2, v.angle * D2R, // p0
    v.colorA[0], v.colorA[1], v.colorA[2], v.colorA[3],                 // colorA
    v.colorB[0], v.colorB[1], v.colorB[2], v.colorB[3],                 // colorB
  ]))

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

  var bindGroup = device.createBindGroup({
    layout: frame.state.pipeline.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: frame.state.uniforms } }],
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
      { value: 1, label: "Fine lines" },
      { value: 2, label: "Bold waves" },
    ],
  },
  // ---- Pattern ----
  wavelength: { type: "number", label: "Wavelength", defaultValue: 40, control: "slider", min: 4, max: 200, step: 1, unit: "px" },
  amplitude: { type: "number", label: "Amplitude", defaultValue: 30, control: "slider", min: 0, max: 100, step: 1, unit: "%" },
  angle: { type: "number", label: "Angle", defaultValue: 0, control: "slider", min: -180, max: 180, step: 1 },
  // ---- Motion ----
  phase: { type: "number", label: "Phase", defaultValue: 0, control: "slider", min: 0, max: 100, step: 1, unit: "%" },
  // ---- Colors ----
  colorA: { type: "color", label: "Color A", defaultValue: { r: 0.08, g: 0.1, b: 0.25, a: 1 } },
  colorB: { type: "color", label: "Color B", defaultValue: { r: 0.98, g: 0.93, b: 0.78, a: 1 } },
})
