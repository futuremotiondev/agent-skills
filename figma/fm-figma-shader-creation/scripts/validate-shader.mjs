#!/usr/bin/env node
// validate-shader.mjs — static checks for a Figma custom shader main.ts
//
// Usage:
//   node validate-shader.mjs <main.ts> [--kind effect|fill] [--features features.json]
//                            [--animated true|false] [--mouse true|false]
//                            [--allow-string-select] [--json]
//
// Dependency-free. It does not compile WGSL or TypeScript; it checks the Figma authoring
// rules that the build and runtime enforce (module shape, module-scope data, diagnostic
// directive, uniform sizing, forbidden globals, metadata flags, select types) and the
// house factory-preset consistency rules (defaults / live / presets / options agree).
// Exit code 1 when any error is reported, 0 otherwise.

import { readFileSync } from "node:fs"

const args = process.argv.slice(2)
if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
  console.log(`Usage: node validate-shader.mjs <main.ts> [--kind effect|fill] [--features features.json]
       [--animated true|false] [--mouse true|false] [--allow-string-select] [--json]`)
  process.exit(args.length === 0 ? 1 : 0)
}

function opt(name) {
  const i = args.indexOf(name)
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null
}
const file = args.find((a) => !a.startsWith("--") && !["effect", "fill", "true", "false"].includes(a) && !a.endsWith(".json") || (a.endsWith(".ts") || a.endsWith(".js")))
const kind = opt("--kind")
const featuresPath = opt("--features")
const wantAnimated = opt("--animated")
const wantMouse = opt("--mouse")
const allowStringSelect = args.includes("--allow-string-select")
const asJson = args.includes("--json")

// Normalise CRLF so every line-based regex (and `.`, which never matches `\r`) behaves.
const source = readFileSync(file, "utf8").replace(/\r\n?/g, "\n")
const lines = source.split("\n")
const findings = []
function report(severity, rule, message, line) {
  findings.push({ severity, rule, message, line: line ?? null })
}
function lineOf(index) {
  return source.slice(0, index).split(/\r?\n/).length
}

// ---------------------------------------------------------------------------
// Tokenizer: classify every character as code, comment, string, or template, and
// track brace depth of code. Template literal ${} nesting is handled with a stack.
// ---------------------------------------------------------------------------
const CODE = 0, LINE_COMMENT = 1, BLOCK_COMMENT = 2, SQ = 3, DQ = 4, TPL = 5
const kindAt = new Uint8Array(source.length)
const depthAt = new Int16Array(source.length)
const templates = [] // { start, end, text }
{
  let state = CODE
  let depth = 0
  const tplStack = [] // depth at which each template started (for ${ } nesting)
  let tplStart = -1
  let braceStackForTpl = []
  for (let i = 0; i < source.length; i += 1) {
    const ch = source[i]
    const next = source[i + 1]
    kindAt[i] = state
    depthAt[i] = depth
    if (state === CODE) {
      if (ch === "/" && next === "/") { state = LINE_COMMENT; kindAt[i] = state; continue }
      if (ch === "/" && next === "*") { state = BLOCK_COMMENT; kindAt[i] = state; continue }
      if (ch === "'") { state = SQ; kindAt[i] = state; continue }
      if (ch === '"') { state = DQ; kindAt[i] = state; continue }
      if (ch === "`") { state = TPL; kindAt[i] = state; tplStart = i + 1; continue }
      if (ch === "{") { depth += 1; continue }
      if (ch === "}") {
        if (braceStackForTpl.length && braceStackForTpl[braceStackForTpl.length - 1] === depth) {
          // closing a ${ } inside a template literal
          braceStackForTpl.pop()
          depth -= 1
          state = TPL
          continue
        }
        depth -= 1
        continue
      }
      continue
    }
    if (state === LINE_COMMENT) { if (ch === "\n") state = CODE; continue }
    if (state === BLOCK_COMMENT) { if (ch === "*" && next === "/") { kindAt[i + 1] = state; i += 1; state = CODE } continue }
    if (state === SQ) { if (ch === "\\") { i += 1; kindAt[i] = state; continue } if (ch === "'") state = CODE; continue }
    if (state === DQ) { if (ch === "\\") { i += 1; kindAt[i] = state; continue } if (ch === '"') state = CODE; continue }
    if (state === TPL) {
      if (ch === "\\") { i += 1; kindAt[i] = state; continue }
      if (ch === "$" && next === "{") {
        kindAt[i + 1] = state
        i += 1
        depth += 1
        braceStackForTpl.push(depth)
        state = CODE
        continue
      }
      if (ch === "`") {
        templates.push({ start: tplStart, end: i, text: source.slice(tplStart, i) })
        state = CODE
      }
      continue
    }
  }
}
function isCode(i) { return kindAt[i] === CODE }

// Code-only view: non-code characters replaced by spaces (keeps indices stable).
let codeOnly = ""
{
  const parts = new Array(source.length)
  for (let i = 0; i < source.length; i += 1) parts[i] = isCode(i) ? source[i] : (source[i] === "\n" ? "\n" : " ")
  codeOnly = parts.join("")
}

// ---------------------------------------------------------------------------
// R1  Imports
// ---------------------------------------------------------------------------
{
  // Import lines are matched against the raw source (the code-only view blanks string
  // contents), but only where the `import` keyword itself sits in code, not in a comment.
  const importRe = /^[ \t]*import\s[^\n]*$/gm
  const imports = [...source.matchAll(importRe)].filter((m) => isCode(m.index + m[0].search(/\S/)))
  const good = /^\s*import\s*\{\s*defineProperties\s*\}\s*from\s*["']figma:shaders["']\s*;?\s*$/
  if (!imports.some((m) => good.test(m[0]))) {
    report("error", "R1-import", 'Missing `import { defineProperties } from "figma:shaders"` (the only allowed import).', 1)
  }
  for (const m of imports) {
    if (!good.test(m[0])) report("error", "R1-import", `Disallowed import: ${m[0].trim()} — only figma:shaders may be imported.`, lineOf(m.index))
  }
  const req = /\brequire\s*\(/g
  for (const m of codeOnly.matchAll(req)) report("error", "R1-import", "`require()` is not available in the shader sandbox.", lineOf(m.index))
}

// ---------------------------------------------------------------------------
// R2  Exports and defineProperties
// ---------------------------------------------------------------------------
{
  if (!/export\s+default\s+function\s+Effect\s*\(/.test(codeOnly)) report("error", "R2-exports", "Missing `export default function Effect() {}`.")
  if (!/export\s+function\s+setup\s*\(/.test(codeOnly)) report("error", "R2-exports", "Missing `export function setup(device, frame)`.")
  if (!/export\s+function\s+render\s*\(/.test(codeOnly)) report("error", "R2-exports", "Missing `export function render(device, frame)`.")
  const dp = [...codeOnly.matchAll(/defineProperties\s*\(\s*Effect\s*,/g)]
  if (dp.length === 0) report("error", "R2-defineProperties", "Missing `defineProperties(Effect, { ... })` at module scope.")
  for (const m of dp) if (depthAt[m.index] !== 0) report("error", "R2-defineProperties", "`defineProperties` must be called at module scope.", lineOf(m.index))
}

// ---------------------------------------------------------------------------
// R3  Module-scope data declarations (stripped by the runtime)
// ---------------------------------------------------------------------------
{
  const decl = /^[ \t]*(?:export\s+)?(var|let|const)\s+([A-Za-z_$][\w$]*)/gm
  for (const m of codeOnly.matchAll(decl)) {
    if (depthAt[m.index] === 0) {
      report("error", "R3-module-scope", `Module-scope \`${m[1]} ${m[2]}\` is stripped by the runtime and rejected by the build. Move it into setup/render or frame.state.`, lineOf(m.index))
    }
  }
}

// ---------------------------------------------------------------------------
// R4  Forbidden globals in JS
// ---------------------------------------------------------------------------
{
  const banned = [
    ["console\\.", "console"], ["\\bsetTimeout\\s*\\(", "setTimeout"], ["\\bsetInterval\\s*\\(", "setInterval"],
    ["\\brequestAnimationFrame\\s*\\(", "requestAnimationFrame"], ["\\bfetch\\s*\\(", "fetch"], ["\\bwindow\\.", "window"],
    ["\\bdocument\\.", "document"], ["\\bnavigator\\.", "navigator"], ["\\bFloat64Array\\b", "Float64Array"],
    ["\\bFloat16Array\\b", "Float16Array"], ["\\blocalStorage\\b", "localStorage"], ["\\bqueueMicrotask\\s*\\(", "queueMicrotask"],
  ]
  for (const [re, name] of banned) {
    for (const m of codeOnly.matchAll(new RegExp(re, "g"))) report("error", "R4-sandbox", `\`${name}\` does not exist in the shader sandbox.`, lineOf(m.index))
  }
  for (const m of codeOnly.matchAll(/(?<![\w.$])(sin|cos|tan|sqrt|abs|floor|ceil|pow|exp|log|min|max|clamp|mix|fract)\s*\(/g)) {
    report("warn", "R4-js-math", `Bare \`${m[1]}(\` in JavaScript; use \`Math.${m[1]}\` (or this is WGSL leaking into JS).`, lineOf(m.index))
  }
}

// ---------------------------------------------------------------------------
// R5  WGSL template literals
// ---------------------------------------------------------------------------
const wgslTemplates = templates.filter((t) => /@(vertex|fragment|compute)\b/.test(t.text))
if (wgslTemplates.length === 0) report("error", "R5-wgsl", "No WGSL module found (no template literal containing @vertex/@fragment/@compute).")
// Some shaders assemble one WGSL module from several template fragments (a shared header plus
// per-pass bodies). Per-fragment structure checks are then only warnings; the directive must
// still open at least one fragment in the file.
const multiFragment = wgslTemplates.length > 1
const startsWithDirective = (text) => {
  for (const l of text.split("\n")) { const s = l.trim(); if (s === "" || s.startsWith("//")) continue; return /^diagnostic\s*\(\s*off\s*,\s*derivative_uniformity\s*\)\s*;/.test(s) }
  return false
}
if (multiFragment && !wgslTemplates.some((t) => startsWithDirective(t.text)) && !templates.some((t) => startsWithDirective(t.text))) {
  report("error", "R5-diagnostic", "No WGSL string begins with `diagnostic(off,derivative_uniformity);`; every module must open with it.", lineOf(wgslTemplates[0].start))
}
for (const t of wgslTemplates) {
  const startLine = lineOf(t.start)
  const wl = t.text.split("\n")
  if (!startsWithDirective(t.text)) {
    report(multiFragment ? "warn" : "error", "R5-diagnostic", multiFragment
      ? "WGSL fragment does not begin with the diagnostic directive; fine only if it is concatenated after a header that does."
      : "WGSL module must begin with `diagnostic(off,derivative_uniformity);` as its first declaration.", startLine)
  }
  const isRender = /@fragment/.test(t.text) || /@vertex/.test(t.text)
  if (isRender && !multiFragment) {
    if (!/fn\s+vs_main\s*\(/.test(t.text)) report("error", "R5-entrypoints", "Render module lacks `vs_main` entry point.", startLine)
    if (!/fn\s+fs_main\s*\(/.test(t.text)) report("error", "R5-entrypoints", "Render module lacks `fs_main` entry point.", startLine)
  }
  if (isRender && multiFragment && !/fn\s+(vs_main|fs_main)\s*\(/.test(t.text)) {
    report("info", "R5-entrypoints", "WGSL fragment has no vs_main/fs_main; confirm the assembled module defines both.", startLine)
  }
  if (/@compute/.test(t.text) && !/fn\s+main\s*\(/.test(t.text)) report("warn", "R5-entrypoints", "Compute module does not use the conventional `main` entry point.", startLine)
  // GLSL leftovers
  for (const m of t.text.matchAll(/\b(gl_FragCoord|gl_Position|gl_FragColor|texture2D|texelFetch|mod\s*\(|mix\s*\(\s*\)|varying|uniform\s+\w+\s+\w+;|#version|precision\s+(high|medium|low)p)/g)) {
    report("error", "R5-glsl", `GLSL construct \`${m[1]}\` is not WGSL.`, startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  // swizzle assignment
  // Multi-component swizzle assignment is illegal in core WGSL. A struct member that happens to
  // be named `xy` (multi-target outputs do this) looks identical, so this is a warning.
  for (const m of t.text.matchAll(/\b[\w.\]\[]+\.([xyzw]{2,4}|[rgba]{2,4})\s*(?:[-+*/]?=)(?!=)/g)) {
    report("warn", "R5-swizzle", `Looks like a multi-component swizzle assignment \`.${m[1]} =\`, which core WGSL rejects; assign the whole vector (ignore if \`${m[1]}\` is a struct member name).`, startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  // function-scope const: const inside braces of a fn
  {
    let d = 0
    wl.forEach((l, i) => {
      const stripped = l.replace(/\/\/.*$/, "")
      if (d > 0 && /^\s*const\s+/.test(stripped)) report("error", "R5-const", "Function-scope `const` is rejected by Figma's build; use `let`.", startLine + i)
      for (const ch of stripped) { if (ch === "{") d += 1; else if (ch === "}") d -= 1 }
    })
  }
  // bracket array literal (rough): `= [` or `( [` followed by numbers
  for (const m of t.text.matchAll(/[=(,]\s*\[\s*[-\d.]/g)) {
    report("error", "R5-array", "Bracket array literal in WGSL; use `array(a, b, ...)`.", startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  // reserved / discouraged identifiers as declarations
  // `meta` and `mod` are reserved by the WGSL spec (error). `texture`, `sampler`, `sample`,
  // `min`, `max` are shadowable predeclared names that Figma's guidance says to avoid (warning).
  for (const m of t.text.matchAll(/\b(?:let|var|fn|const)\s+(meta|mod)\b/g)) {
    report("error", "R5-names", `Identifier \`${m[1]}\` is a reserved WGSL word.`, startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  // WGSL keywords and reserved words (spec section 16; the list has changed across drafts, so
  // this is reported as a warning rather than an error).
  const WGSL_RESERVED = new Set(("alias break case const const_assert continue continuing default diagnostic discard else enable false fn for if let loop override requires return struct switch true var while " +
    "NULL Self abstract active alignas alignof as asm asm_fragment async attribute auto await become binding_array cast catch class co_await co_return co_yield coherent column_major common compile compile_fragment concept const_cast consteval constexpr constinit crate debugger decltype delete demote demote_to_helper do dynamic_cast enum explicit export extends extern external fallthrough filter final finally friend from fxgroup get goto groupshared half highp impl implements import inline instanceof interface layout lowp macro macro_rules match mediump module move mut mutable namespace new nil noexcept noinline nointerpolation non_coherent noncoherent noperspective null nullptr of operator package packoffset partition pass patch pixelfragment precise precision premerge priv protected pub public readonly ref regardless register reinterpret_cast require resource restrict self set shared sizeof smooth snorm static static_assert static_cast std subroutine super target template this thread_local throw trait try type typedef typeid typename typeof union unless unorm unsafe unsized use using varying virtual volatile wgsl where with writeonly yield").split(/\s+/))
  for (const m of t.text.matchAll(/\b(?:let|var|fn|const)\s+([A-Za-z_]\w*)\b/g)) {
    if (WGSL_RESERVED.has(m[1])) report("warn", "R5-reserved", `Identifier \`${m[1]}\` is a WGSL keyword or reserved word; rename it.`, startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  for (const m of t.text.matchAll(/^\s*([A-Za-z_]\w*)\s*:\s*[\w<>, ]+,?\s*(?:\/\/.*)?$/gm)) {
    if (WGSL_RESERVED.has(m[1])) report("warn", "R5-reserved", `Struct member \`${m[1]}\` is a WGSL keyword or reserved word; rename it.`, startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  // Uniform struct size versus buffer size (WGSL alignment rules, uniform address space).
  {
    const structs = {}
    // Split struct members on commas that are not inside <...> or (...), after stripping
    // line comments, so `array<vec4f, 8>` and `@location(0)` survive intact.
    function splitMembers(body) {
      const noComments = body.split("\n").map((l) => l.replace(/\/\/.*$/, "")).join("\n")
      const out = []; let cur = ""; let angle = 0; let paren = 0
      for (const ch of noComments) {
        if (ch === "<") angle += 1; else if (ch === ">") angle -= 1
        else if (ch === "(") paren += 1; else if (ch === ")") paren -= 1
        if (ch === "," && angle === 0 && paren === 0) { out.push(cur); cur = ""; continue }
        cur += ch
      }
      out.push(cur)
      return out.map((s) => s.trim()).filter(Boolean)
    }
    for (const sm of t.text.matchAll(/struct\s+(\w+)\s*\{([^}]*)\}/g)) {
      structs[sm[1]] = splitMembers(sm[2])
        .map((l) => { const mm = l.match(/^(?:@\w+(?:\([^)]*\))?\s*)*(\w+)\s*:\s*(.+)$/s); return mm ? { name: mm[1], type: mm[2].trim() } : null }).filter(Boolean)
    }
    const prim = { f32: [4, 4], i32: [4, 4], u32: [4, 4], f16: [2, 2], vec2f: [8, 8], vec2i: [8, 8], vec2u: [8, 8], vec3f: [16, 12], vec3i: [16, 12], vec3u: [16, 12], vec4f: [16, 16], vec4i: [16, 16], vec4u: [16, 16], mat2x2f: [8, 16], mat3x3f: [16, 48], mat4x4f: [16, 64], mat2x3f: [16, 32], mat3x2f: [8, 24], mat4x2f: [8, 32], mat2x4f: [16, 32], mat3x4f: [16, 48], mat4x3f: [16, 64] }
    const roundUp = (k, n) => Math.ceil(n / k) * k
    const seen = new Set()
    function layout(type) {
      type = type.replace(/\s+/g, "")
      const gen = type.match(/^vec([234])<(f32|i32|u32|f16)>$/)
      if (gen) type = `vec${gen[1]}${gen[2][0]}`
      const matg = type.match(/^mat(\d)x(\d)<f32>$/)
      if (matg) type = `mat${matg[1]}x${matg[2]}f`
      if (prim[type]) return { align: prim[type][0], size: prim[type][1] }
      const arr = type.match(/^array<(.+),\s*(\d+)>$/)
      if (arr) {
        const e = layout(arr[1]); if (!e) return null
        const stride = roundUp(16, roundUp(e.align, e.size))   // uniform address space: 16-byte stride
        return { align: Math.max(16, e.align), size: stride * Number(arr[2]) }
      }
      if (structs[type]) {
        if (seen.has(type)) return null
        seen.add(type)
        let off = 0, maxAlign = 16
        for (const mbr of structs[type]) {
          const l = layout(mbr.type); if (!l) { seen.delete(type); return null }
          off = roundUp(l.align, off) + l.size
          maxAlign = Math.max(maxAlign, l.align)
        }
        seen.delete(type)
        return { align: maxAlign, size: roundUp(maxAlign, off) }
      }
      return null
    }
    const uniformDecls = [...t.text.matchAll(/var\s*<\s*uniform\s*>\s*\w+\s*:\s*(\w+)\s*;/g)].map((m) => m[1])
    const bufferSizes = [...codeOnly.matchAll(/createBuffer\s*\(\s*\{([^}]*UNIFORM[^}]*)\}/g)].map((m) => {
      const s = (m[1].match(/size\s*:\s*([^,}]+)/) || [])[1]
      if (!s) return null
      try { return /^[\d\s*+\-/().]+$/.test(s.trim()) ? Function(`"use strict"; return (${s})`)() : null } catch { return null }
    }).filter((n) => Number.isFinite(n))
    for (const name of uniformDecls) {
      const l = layout(name)
      if (!l) continue
      if (bufferSizes.length && !bufferSizes.includes(l.size)) {
        report("warn", "R6-struct-size", `Uniform struct \`${name}\` is ${l.size} bytes by WGSL layout rules, but no uniform buffer in this file is created with size ${l.size} (sizes found: ${bufferSizes.join(", ")}).`, startLine)
      } else {
        report("info", "R6-struct-size", `Uniform struct \`${name}\` lays out to ${l.size} bytes; a buffer of that size exists.`, startLine)
      }
    }
  }
  for (const m of t.text.matchAll(/\b(?:let|var|fn|const)\s+(texture|sampler|sample|min|max)\b/g)) {
    report("warn", "R5-names", `Identifier \`${m[1]}\` shadows a predeclared WGSL name; Figma's guidance says to avoid it (later calls to the builtin break in that scope).`, startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  for (const m of t.text.matchAll(/@group\(\d+\)\s*@binding\(\d+\)\s*var\s+(texture|sampler|sample)\s*:/g)) {
    report("warn", "R5-names", `Binding named \`${m[1]}\` shadows a WGSL predeclared name; rename it (e.g. inputTex, samp).`, startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  // textureSample inside a branch is only detectable roughly: flag any textureSample( and suggest Level
  for (const m of t.text.matchAll(/\btextureSample\s*\(/g)) {
    report("info", "R5-uniformity", "`textureSample(` relies on implicit derivatives; prefer `textureSampleLevel(..., 0.0)` unless mip selection is wanted and the call is in uniform control flow.", startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
  // ternary
  for (const m of t.text.matchAll(/\?\s*[^:\n]+\s*:\s*[^;\n]+;/g)) {
    report("error", "R5-ternary", "C-style ternary is not WGSL; use `select(falseValue, trueValue, cond)`.", startLine + t.text.slice(0, m.index).split("\n").length - 1)
  }
}

// ---------------------------------------------------------------------------
// R6  Uniform buffer sizes are multiples of 16
// ---------------------------------------------------------------------------
{
  const re = /createBuffer\s*\(\s*\{([^}]*)\}/g
  for (const m of codeOnly.matchAll(re)) {
    const body = m[1]
    if (!/UNIFORM/.test(body)) continue
    const sizeM = body.match(/size\s*:\s*([^,}]+)/)
    if (!sizeM) continue
    const expr = sizeM[1].trim()
    let value = null
    if (/^[\d\s*+\-/().]+$/.test(expr)) { try { value = Function(`"use strict"; return (${expr})`)() } catch { value = null } }
    if (value != null && value % 16 !== 0) report("error", "R6-uniform-size", `Uniform buffer size ${expr} = ${value} is not a multiple of 16.`, lineOf(m.index))
    if (value == null) report("info", "R6-uniform-size", `Uniform buffer size \`${expr}\` is not a literal; confirm it is a multiple of 16.`, lineOf(m.index))
  }
}

// ---------------------------------------------------------------------------
// R7  Output pipeline keyed by frame.output.format
// ---------------------------------------------------------------------------
{
  if (!/frame\.output\.format/.test(codeOnly)) report("error", "R7-format", "No use of `frame.output.format`; the output pipeline must be keyed by it, never a hardcoded format.")
  if (!/frame\.output\.createView\s*\(/.test(codeOnly)) report("error", "R7-output", "Nothing renders into `frame.output.createView()`.")
  if (!/COPY_DST/.test(codeOnly) && /writeBuffer\s*\(/.test(codeOnly)) report("error", "R7-usage", "`writeBuffer` used but no buffer declares `GPUBufferUsage.COPY_DST`.")
  if (!/queue\.submit\s*\(/.test(codeOnly)) report("error", "R7-submit", "No `device.queue.submit(...)` found.")
}

// ---------------------------------------------------------------------------
// R8  Kind-specific rules and resolution independence
// ---------------------------------------------------------------------------
{
  const usesInput = /frame\.input\b/.test(codeOnly)
  if (kind === "fill" && usesInput) report("error", "R8-fill-input", "A fill must not read or bind `frame.input`.")
  if (kind === "effect" && !usesInput) report("warn", "R8-effect-input", "An effect normally samples `frame.input`; none found.")
  if (kind === "effect" && usesInput && !/frame\.input\s*(==|!=|===|!==)\s*null|frame\.input\s*\?|hasInput|frame\.input\s*&&|!\s*frame\.input|frame\.input\s*\)\s*\{|if\s*\(\s*!?frame\.input\b/.test(codeOnly)) {
    report("warn", "R8-input-guard", "No visible null guard for `frame.input` before `createView()`.")
  }
  const usesOutputSize = /frame\.output\.(width|height)/.test(codeOnly)
  if (usesOutputSize && !/renderScale/.test(codeOnly)) report("warn", "R8-renderscale", "Uses `frame.output.width/height` without `frame.renderScale`; sizes in design points should be `physical / renderScale`.")
  if (/physicalWidth|physicalHeight/.test(codeOnly) && !/physicalWidth\s*\?\?|physicalHeight\s*\?\?/.test(codeOnly)) report("warn", "R8-physical", "`physicalWidth/Height` used without a `?? width/height` fallback; the field is absent on version-2 manifests.")
  if (/frame\.renderScale/.test(codeOnly) && !/Number\s*\(\s*frame\.renderScale\s*\)\s*\|\|\s*1|frame\.renderScale\s*\|\|\s*1/.test(codeOnly)) report("info", "R8-renderscale-guard", "Guard `frame.renderScale` with `Number(frame.renderScale) || 1`.")
  if (kind === "fill") {
    for (const t of wgslTemplates) {
      // Any fragment return of the form vec4f(<expr containing "* X.a">, X.a) premultiplies.
      for (const m of t.text.matchAll(/return\s+vec4f\s*\(([^;]*?)\)\s*;/g)) {
        const inner = m[1]
        const am = inner.match(/,\s*([\w.]+)\.a\s*$/)
        if (!am) continue
        const base = am[1].replace(/[.$]/g, "\\$&")
        if (new RegExp(`\\*\\s*${base}\\.a\\b|${base}\\.a\\s*\\*`).test(inner.slice(0, inner.length - am[0].length))) {
          report("warn", "R8-fill-alpha", "Fill returns premultiplied output (rgb multiplied by alpha); fills must return straight alpha.", lineOf(t.start) + t.text.slice(0, m.index).split("\n").length - 1)
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// R9  Metadata flags vs source
// ---------------------------------------------------------------------------
{
  const readsTime = /frame\.(time|deltaTime|frame)\b/.test(codeOnly)
  const readsMouse = /frame\.mousePosition\b/.test(codeOnly)
  let features = null
  if (featuresPath) { try { features = JSON.parse(readFileSync(featuresPath, "utf8")) } catch (e) { report("warn", "R9-features", `Could not read ${featuresPath}: ${e.message}`) } }
  const declaredAnimated = wantAnimated != null ? wantAnimated === "true" : features ? !!features.isAnimated : null
  const declaredMouse = wantMouse != null ? wantMouse === "true" : features ? !!features.usesMouse : null
  if (declaredAnimated == null) report("info", "R9-metadata", `Source ${readsTime ? "READS" : "does not read"} frame.time/deltaTime/frame → send metadata.isAnimated: ${readsTime}.`)
  else if (declaredAnimated !== readsTime) report("error", "R9-metadata", `isAnimated is ${declaredAnimated} but source ${readsTime ? "reads" : "never reads"} frame.time/deltaTime/frame.`)
  if (declaredMouse == null) report("info", "R9-metadata", `Source ${readsMouse ? "READS" : "does not read"} frame.mousePosition → send metadata.usesMouse: ${readsMouse}.`)
  else if (declaredMouse !== readsMouse) report("error", "R9-metadata", `usesMouse is ${declaredMouse} but source ${readsMouse ? "reads" : "never reads"} frame.mousePosition.`)
  if (/frame\.time\b/.test(codeOnly) && !/frame\.time\s*\)?\s*\*\s*0?\.001|\/\s*1000/.test(codeOnly)) report("info", "R9-time-units", "`frame.time` is milliseconds; convert with `* 0.001` when seconds are intended.")
}

// ---------------------------------------------------------------------------
// R10 defineProperties: parse property objects
// ---------------------------------------------------------------------------
function extractBlock(startIndex) {
  // startIndex points at '{'; returns { text, end } of the matching brace block, using code-only depth awareness
  let d = 0
  for (let i = startIndex; i < source.length; i += 1) {
    if (!isCode(i)) continue
    if (source[i] === "{") d += 1
    else if (source[i] === "}") { d -= 1; if (d === 0) return { text: source.slice(startIndex, i + 1), start: startIndex, end: i + 1 } }
  }
  return null
}
function topLevelKeys(blockText, blockStart) {
  // keys at depth 1 of an object literal block; returns [{key, valueText, index}]
  const out = []
  let d = 0
  let i = 0
  while (i < blockText.length) {
    const gi = blockStart + i
    const ch = blockText[i]
    if (!isCode(gi)) { i += 1; continue }
    if (ch === "{" || ch === "[" || ch === "(") { d += 1; i += 1; continue }
    if (ch === "}" || ch === "]" || ch === ")") { d -= 1; i += 1; continue }
    if (d === 1) {
      const m = /^\s*(?:"([^"]+)"|'([^']+)'|([A-Za-z_$][\w$]*)|(\d+))\s*:/.exec(blockText.slice(i))
      if (m && (i === 0 || /[,{\s]/.test(blockText[i - 1]))) {
        const key = m[1] ?? m[2] ?? m[3] ?? m[4]
        const valStart = i + m[0].length
        // value extends to the next depth-1 comma or the closing brace
        let j = valStart, dd = 0
        while (j < blockText.length) {
          const gj = blockStart + j
          if (isCode(gj)) {
            const c = blockText[j]
            if (c === "{" || c === "[" || c === "(") dd += 1
            else if (c === "}" || c === "]" || c === ")") { if (dd === 0) break; dd -= 1 }
            else if (c === "," && dd === 0) break
          }
          j += 1
        }
        out.push({ key, valueText: blockText.slice(valStart, j), index: blockStart + i })
        i = j
        continue
      }
    }
    i += 1
  }
  return out
}

let props = []
{
  const m = /defineProperties\s*\(\s*Effect\s*,\s*\{/.exec(codeOnly)
  if (m) {
    const braceIndex = m.index + m[0].length - 1
    const block = extractBlock(braceIndex)
    if (block) props = topLevelKeys(block.text, block.start)
  }
  const keys = new Set()
  for (const p of props) {
    if (keys.has(p.key)) report("error", "R10-props", `Duplicate control key \`${p.key}\`.`, lineOf(p.index))
    keys.add(p.key)
    const v = p.valueText
    const type = (v.match(/type\s*:\s*["']([\w-]+)["']/) || [])[1]
    const control = (v.match(/control\s*:\s*["']([\w-]+)["']/) || [])[1]
    const ln = lineOf(p.index)
    if (!type) { report("error", "R10-props", `Control \`${p.key}\` has no \`type\`.`, ln); continue }
    if (!/defaultValue\s*:/.test(v)) report("error", "R10-props", `Control \`${p.key}\` has no \`defaultValue\`.`, ln)
    if (!/label\s*:/.test(v)) report("warn", "R10-props", `Control \`${p.key}\` has no \`label\`.`, ln)
    if (type === "string" && control === "select") report(allowStringSelect ? "warn" : "error", "R10-string-select", `Control \`${p.key}\` is a string select; dropdowns must be numeric selects (type "number", control "select", numeric option values). Use --allow-string-select only for an existing shipped control.`, ln)
    if (type === "number" && control === "slider") {
      for (const f of ["min", "max", "step"]) if (!new RegExp(`\\b${f}\\s*:`).test(v)) report("warn", "R10-slider", `Slider \`${p.key}\` lacks \`${f}\`.`, ln)
      const mn = Number((v.match(/\bmin\s*:\s*(-?[\d.]+)/) || [])[1]), mx = Number((v.match(/\bmax\s*:\s*(-?[\d.]+)/) || [])[1]), dv = Number((v.match(/defaultValue\s*:\s*(-?[\d.]+)/) || [])[1])
      if ([mn, mx, dv].every(Number.isFinite) && (dv < mn || dv > mx)) report("error", "R10-slider", `Slider \`${p.key}\` default ${dv} is outside [${mn}, ${mx}].`, ln)
      else if ([mn, mx, dv].every(Number.isFinite) && (dv === mn || dv === mx) && p.key !== "phase") report("info", "R10-slider", `Slider \`${p.key}\` default sits on a range edge (${dv}); review guidelines prefer defaults off the edges.`, ln)
    }
    if (control === "select" && type === "number") {
      const vals = [...v.matchAll(/value\s*:\s*(-?\d+(?:\.\d+)?)/g)].map((x) => Number(x[1]))
      if (vals.length === 0) report("error", "R10-select", `Select \`${p.key}\` has no numeric option values.`, ln)
      const dv = Number((v.match(/defaultValue\s*:\s*(-?[\d.]+)/) || [])[1])
      if (Number.isFinite(dv) && vals.length && !vals.includes(dv)) report("error", "R10-select", `Select \`${p.key}\` default ${dv} is not one of its option values.`, ln)
      if (new Set(vals).size !== vals.length) report("error", "R10-select", `Select \`${p.key}\` has duplicate option values.`, ln)
    }
    if (/unitLabel\s*:/.test(v)) report("info", "R10-unit", `Control \`${p.key}\` uses undocumented \`unitLabel\`; prefer \`unit\`.`, ln)
    if (/\bdescription\s*:/.test(v)) report("info", "R10-description", `Control \`${p.key}\` sets \`description\` (harmless; no first-party shader uses it).`, ln)
  }
  if (props.length === 0) report("warn", "R10-props", "No controls parsed from defineProperties.")
}

// ---------------------------------------------------------------------------
// R11 Factory-preset consistency (only when the pattern is present)
// ---------------------------------------------------------------------------
{
  const hasPresets = /\bfactoryPresets\b/.test(codeOnly)
  const hasPresetProp = props.some((p) => p.key === "preset")
  if (hasPresets || hasPresetProp) {
    function objectBlockAfter(re) {
      const m = re.exec(codeOnly)
      if (!m) return null
      const brace = m.index + m[0].length - 1
      return extractBlock(brace)
    }
    const defaultsBlock = objectBlockAfter(/\bvar\s+defaults\s*=\s*\{/)
    const liveBlock = objectBlockAfter(/\bvar\s+live\s*=\s*\{/)
    const presetsBlock = objectBlockAfter(/\bvar\s+factoryPresets\s*=\s*\{/)
    if (!hasPresetProp) report("error", "R11-presets", "factoryPresets exists but there is no `preset` control.")
    if (!defaultsBlock) report("error", "R11-presets", "Preset pattern requires a `var defaults = { ... }` table inside render().")
    if (!liveBlock) report("error", "R11-presets", "Preset pattern requires a `var live = { ... }` table inside render().")
    if (!presetsBlock) report("error", "R11-presets", "Preset pattern requires `var factoryPresets = { ... }` inside render().")
    if (!/Object\.assign\s*\(\s*\{\s*\}\s*,\s*defaults\s*,\s*factoryPresets\s*\[/.test(codeOnly)) report("error", "R11-resolver", "Resolver must be `Object.assign({}, defaults, factoryPresets[presetId])` (delta over defaults, never over live).")
    for (const b of [defaultsBlock, liveBlock, presetsBlock]) if (b && depthAt[b.start] === 0) report("error", "R11-scope", "Preset tables must live inside render(), not at module scope.", lineOf(b.start))
    if (defaultsBlock && liveBlock && presetsBlock) {
      const dKeys = topLevelKeys(defaultsBlock.text, defaultsBlock.start).map((k) => k.key)
      const lKeys = topLevelKeys(liveBlock.text, liveBlock.start).map((k) => k.key)
      const controlKeys = props.map((p) => p.key).filter((k) => k !== "preset")
      const dSet = new Set(dKeys), lSet = new Set(lKeys), cSet = new Set(controlKeys)
      for (const k of controlKeys) if (!dSet.has(k)) report("error", "R11-defaults", `Control \`${k}\` has no entry in \`defaults\`.`)
      for (const k of dKeys) if (!cSet.has(k)) report("error", "R11-defaults", `\`defaults.${k}\` has no matching control in defineProperties.`)
      for (const k of dKeys) if (!lSet.has(k)) report("error", "R11-live", `\`defaults.${k}\` is missing from \`live\`.`)
      for (const k of lKeys) if (!dSet.has(k)) report("error", "R11-live", `\`live.${k}\` has no \`defaults\` entry.`)
      const entries = topLevelKeys(presetsBlock.text, presetsBlock.start)
      const ids = entries.map((e) => Number(e.key)).filter(Number.isFinite)
      for (const e of entries) {
        // Each preset entry's value is an object literal; find its opening brace.
        const inner = extractBlock(source.indexOf("{", e.index))
        if (!inner) continue
        for (const k of topLevelKeys(inner.text, inner.start).map((x) => x.key)) {
          if (!dSet.has(k)) report("error", "R11-delta", `Preset ${e.key} sets \`${k}\`, which is not a key of \`defaults\`.`, lineOf(e.index))
        }
      }
      const presetProp = props.find((p) => p.key === "preset")
      if (presetProp) {
        const optVals = [...presetProp.valueText.matchAll(/value\s*:\s*(\d+)/g)].map((m) => Number(m[1]))
        if (!optVals.includes(0)) report("error", "R11-options", "`preset` options must include value 0 (Custom).")
        for (const id of ids) if (!optVals.includes(id)) report("error", "R11-options", `factoryPresets[${id}] has no matching option in the \`preset\` select.`)
        for (const ov of optVals) if (ov !== 0 && !ids.includes(ov)) report("error", "R11-options", `Preset option value ${ov} has no factoryPresets[${ov}] entry.`)
        if (!/defaultValue\s*:\s*0\b/.test(presetProp.valueText)) report("error", "R11-options", "`preset` defaultValue must be 0 (Custom).")
      }
      // defaultValue vs defaults for simple numbers and booleans
      const dEntries = topLevelKeys(defaultsBlock.text, defaultsBlock.start)
      for (const p of props) {
        if (p.key === "preset") continue
        const d = dEntries.find((x) => x.key === p.key)
        if (!d) continue
        const dvNum = p.valueText.match(/defaultValue\s*:\s*(-?[\d.]+)\s*[,}\n]/)
        const dvBool = p.valueText.match(/defaultValue\s*:\s*(true|false)/)
        const dvStr = d.valueText.trim()
        if (dvNum && /^-?[\d.]+$/.test(dvStr) && Number(dvNum[1]) !== Number(dvStr)) report("error", "R11-drift", `Control \`${p.key}\` defaultValue ${dvNum[1]} differs from defaults.${p.key} = ${dvStr}.`, lineOf(p.index))
        if (dvBool && /^[01]$/.test(dvStr) && ((dvBool[1] === "true") !== (dvStr === "1"))) report("error", "R11-drift", `Control \`${p.key}\` defaultValue ${dvBool[1]} differs from defaults.${p.key} = ${dvStr} (booleans are 0/1 in defaults).`, lineOf(p.index))
      }
      // frame.params usage after the resolver
      const resolverIdx = codeOnly.search(/Object\.assign\s*\(\s*\{\s*\}\s*,\s*defaults/)
      if (resolverIdx > 0) {
        const after = codeOnly.slice(resolverIdx)
        const renderEnd = after.indexOf("\ndefineProperties")
        const tail = renderEnd > 0 ? after.slice(0, renderEnd) : after
        for (const m of tail.matchAll(/frame\.params\b|\bp\s*\[\s*["']/g)) report("warn", "R11-v", "Reads params directly after the preset resolver; everything downstream should read `v.*`.", lineOf(resolverIdx + m.index))
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------
const order = { error: 0, warn: 1, info: 2 }
findings.sort((a, b) => order[a.severity] - order[b.severity] || (a.line ?? 0) - (b.line ?? 0))
const errors = findings.filter((f) => f.severity === "error").length
const warns = findings.filter((f) => f.severity === "warn").length
if (asJson) {
  console.log(JSON.stringify({ file, kind, errors, warnings: warns, findings }, null, 2))
} else {
  for (const f of findings) console.log(`${f.severity.toUpperCase().padEnd(5)} ${f.rule.padEnd(22)} ${f.line ? `L${f.line}`.padEnd(6) : "".padEnd(6)} ${f.message}`)
  console.log(`\n${file}: ${errors} error(s), ${warns} warning(s), ${findings.length - errors - warns} info. ${errors ? "FAIL" : "PASS"}`)
}
process.exit(errors ? 1 : 0)
