// skill-md.mjs — shared parsing helpers for single-file Figma skills.
//
// Used by validate-figma-skill.mjs and build-skill-editions.mjs so both agree on:
//   - where the frontmatter block starts and ends, and what it contains
//   - where `<!-- target:x -->` ... `<!-- /target -->` regions are
//   - which lines sit inside fenced code blocks
//
// Dependency-free. The YAML reader is a deliberate subset: top-level `key: value`,
// one level of nested map (for `metadata:`), folded/literal block scalars, quoted
// scalars, and `#` comment lines. That covers every frontmatter the Agent Skills spec
// allows and every overlay this toolchain writes. Anything fancier is reported as an
// issue rather than silently mis-parsed.

/** Normalise line endings so every line-based check behaves the same on Windows. */
export function normalize(text) {
  return text.replace(/\r\n?/g, "\n")
}

// ---------------------------------------------------------------------------
// Frontmatter
// ---------------------------------------------------------------------------

/**
 * Parse a `---` frontmatter block that starts at line 0.
 * Returns { present, closeLine, fields, issues }.
 *   fields: [{ key, value, raw, quoted, line, children }]  (children = nested map or null)
 */
export function parseFrontmatter(lines) {
  const result = { present: false, closeLine: -1, fields: [], issues: [] }
  if (lines.length === 0 || lines[0].trim() !== "---") return result

  let close = -1
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === "---") { close = i; break }
  }
  if (close === -1) {
    result.issues.push({ line: 1, message: "frontmatter opened with --- but never closed" })
    return result
  }
  result.present = true
  result.closeLine = close
  result.fields = parseYamlSubset(lines.slice(1, close), 1, result.issues)
  return result
}

/**
 * Parse the YAML subset. `lineOffset` is the 0-based index of the first line in the
 * original file so issue line numbers stay accurate (reported 1-based).
 */
export function parseYamlSubset(yamlLines, lineOffset = 0, issues = []) {
  const fields = []
  let i = 0
  const n = yamlLines.length

  const lineNo = (idx) => lineOffset + idx + 1

  while (i < n) {
    const line = yamlLines[i]
    const trimmed = line.trim()
    if (trimmed === "" || trimmed.startsWith("#")) { i++; continue }

    // Top-level key (no indentation).
    const top = /^([A-Za-z_][A-Za-z0-9_-]*):(?:\s+(.*))?$/.exec(line)
    if (!top) {
      issues.push({ line: lineNo(i), message: `unparseable frontmatter line: ${trimmed}` })
      i++
      continue
    }
    const key = top[1]
    const rest = top[2] === undefined ? "" : top[2]

    // Block scalar (> | >- |-): collect indented continuation lines.
    if (/^[>|][+-]?$/.test(rest.trim())) {
      const folded = rest.trim().startsWith(">")
      const parts = []
      let j = i + 1
      while (j < n && (yamlLines[j].trim() === "" || /^\s+/.test(yamlLines[j]))) {
        parts.push(yamlLines[j].trim())
        j++
      }
      const value = folded ? parts.filter(Boolean).join(" ") : parts.join("\n").replace(/\n+$/, "")
      fields.push({ key, value, raw: rest, quoted: false, line: lineNo(i), children: null, block: true })
      i = j
      continue
    }

    // Nested map: `key:` with indented `  sub: value` lines following.
    if (rest.trim() === "") {
      const children = []
      let j = i + 1
      while (j < n) {
        const sub = yamlLines[j]
        if (sub.trim() === "" || sub.trim().startsWith("#")) { j++; continue }
        const m = /^(\s+)([A-Za-z_][A-Za-z0-9_-]*):(?:\s+(.*))?$/.exec(sub)
        if (!m) break
        const { value, quoted } = unquote(m[3] === undefined ? "" : m[3])
        children.push({ key: m[2], value, raw: m[3] === undefined ? "" : m[3], quoted, line: lineNo(j), children: null })
        j++
      }
      if (children.length === 0) {
        // Empty scalar, e.g. `license:` with nothing after it.
        fields.push({ key, value: "", raw: "", quoted: false, line: lineNo(i), children: null })
        i++
      } else {
        fields.push({ key, value: null, raw: "", quoted: false, line: lineNo(i), children })
        i = j
      }
      continue
    }

    const { value, quoted } = unquote(rest)
    fields.push({ key, value, raw: rest, quoted, line: lineNo(i), children: null })
    i++
  }
  return fields
}

/** Strip one layer of matching quotes and unescape the common sequences. */
export function unquote(raw) {
  const s = raw.trim()
  if (s.length >= 2 && s[0] === '"' && s[s.length - 1] === '"') {
    try { return { value: JSON.parse(s), quoted: true } } catch { return { value: s.slice(1, -1), quoted: true } }
  }
  if (s.length >= 2 && s[0] === "'" && s[s.length - 1] === "'") {
    return { value: s.slice(1, -1).replace(/''/g, "'"), quoted: true }
  }
  // Strip a trailing inline comment only when it is clearly a comment (space before #).
  const hash = s.indexOf(" #")
  return { value: hash > 0 ? s.slice(0, hash).trim() : s, quoted: false }
}

/** Get a top-level field by key. */
export function getField(fields, key) {
  return fields.find((f) => f.key === key) || null
}

/**
 * Find later `---` blocks that look like a second frontmatter (a `key:` line within the
 * next two lines and a closing `---` within 40 lines). Returns [{ start, end }] 0-based.
 */
export function findFrontmatterLikeBlocks(lines, fromLine = 0) {
  const blocks = []
  const fence = scanFences(lines)
  for (let i = fromLine; i < lines.length; i++) {
    if (fence[i] || lines[i].trim() !== "---") continue
    const peek = lines.slice(i + 1, i + 3).some((l) => /^[A-Za-z_][A-Za-z0-9_-]*:\s*/.test(l))
    if (!peek) continue
    for (let j = i + 1; j < Math.min(lines.length, i + 41); j++) {
      if (lines[j].trim() === "---") { blocks.push({ start: i, end: j }); i = j; break }
    }
  }
  return blocks
}

// ---------------------------------------------------------------------------
// Fenced code
// ---------------------------------------------------------------------------

/** boolean[] marking lines inside fenced code (fence lines themselves included). */
export function scanFences(lines) {
  const inFence = new Array(lines.length).fill(false)
  let open = null
  for (let i = 0; i < lines.length; i++) {
    const m = /^\s*(`{3,}|~{3,})/.exec(lines[i])
    if (m) {
      if (!open) { open = m[1][0].repeat(m[1].length); inFence[i] = true; continue }
      if (m[1][0] === open[0] && m[1].length >= open.length) { open = null; inFence[i] = true; continue }
    }
    if (open) inFence[i] = true
  }
  return inFence
}

// ---------------------------------------------------------------------------
// Target regions
// ---------------------------------------------------------------------------

export const OPEN_MARKER = /^\s*<!--\s*target:([a-z0-9-]+)\s*-->\s*$/i
export const CLOSE_MARKER = /^\s*<!--\s*\/target\s*-->\s*$/i

/**
 * Scan `<!-- target:x -->` ... `<!-- /target -->` regions.
 * Returns { regions: [{ target, open, close }], markers: [{ line, kind, target }],
 *           regionAt(i) -> target name or "core", issues }.
 * Regions do not nest; a second open before a close is an issue.
 */
export function scanRegions(lines) {
  const regions = []
  const markers = []
  const issues = []
  const fence = scanFences(lines)
  let current = null
  for (let i = 0; i < lines.length; i++) {
    if (fence[i]) continue
    const o = OPEN_MARKER.exec(lines[i])
    if (o) {
      markers.push({ line: i, kind: "open", target: o[1].toLowerCase() })
      if (current) issues.push({ line: i + 1, message: `target:${o[1]} opened before target:${current.target} (line ${current.open + 1}) was closed` })
      current = { target: o[1].toLowerCase(), open: i, close: -1 }
      regions.push(current)
      continue
    }
    if (CLOSE_MARKER.test(lines[i])) {
      markers.push({ line: i, kind: "close", target: current ? current.target : null })
      if (!current) issues.push({ line: i + 1, message: "<!-- /target --> without an open marker" })
      else { current.close = i; current = null }
    }
  }
  if (current) issues.push({ line: current.open + 1, message: `target:${current.target} never closed` })

  const regionAt = (i) => {
    for (const r of regions) {
      const end = r.close === -1 ? lines.length - 1 : r.close
      if (i >= r.open && i <= end) return r.target
    }
    return "core"
  }
  return { regions, markers, regionAt, issues }
}

/**
 * Build the body for one target: keep `core` lines and the inside of regions whose
 * target is in `keep`; drop other regions entirely; drop every marker line.
 * Collapses runs of blank lines to a single blank line (markdownlint MD012).
 */
export function selectTarget(lines, keep) {
  const keepSet = new Set(Array.isArray(keep) ? keep : [keep])
  const { regions, regionAt } = scanRegions(lines)
  const markerLines = new Set()
  for (const r of regions) { markerLines.add(r.open); if (r.close !== -1) markerLines.add(r.close) }
  const out = []
  for (let i = 0; i < lines.length; i++) {
    if (markerLines.has(i)) continue
    const t = regionAt(i)
    if (t === "core" || keepSet.has(t)) out.push(lines[i])
  }
  return collapseBlankRuns(out)
}

export function collapseBlankRuns(lines) {
  const out = []
  let blanks = 0
  for (const l of lines) {
    if (l.trim() === "") { blanks++; if (blanks > 1) continue } else blanks = 0
    out.push(l)
  }
  while (out.length && out[0].trim() === "") out.shift()
  while (out.length && out[out.length - 1].trim() === "") out.pop()
  return out
}

// ---------------------------------------------------------------------------
// Frontmatter serialisation
// ---------------------------------------------------------------------------

const NEEDS_QUOTE = /(^[\s"'>|#&*!%@`[\]{},?:-])|(:\s)|(\s#)|(\s$)|(^(true|false|null|~|yes|no|on|off)$)|(^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$)|(^0x[0-9a-fA-F]+$)/i

/** Render one scalar; quote with JSON rules whenever plain YAML would misread it. */
export function yamlScalar(value, forceQuote = false) {
  const s = String(value)
  if (forceQuote || s === "" || NEEDS_QUOTE.test(s) || /[\n\r\t]/.test(s)) return JSON.stringify(s)
  return s
}

/** Serialise fields back to a `---` block (array of lines, including both delimiters). */
export function serializeFrontmatter(fields) {
  const out = ["---"]
  for (const f of fields) {
    if (f.children) {
      out.push(`${f.key}:`)
      for (const c of f.children) out.push(`  ${c.key}: ${yamlScalar(c.value, c.quoted)}`)
    } else {
      out.push(`${f.key}: ${yamlScalar(f.value ?? "", f.quoted)}`)
    }
  }
  out.push("---")
  return out
}

/** Merge overlay fields over base fields. Nested maps merge key-wise; overlay wins. */
export function mergeFields(base, overlay) {
  const out = base.map((f) => ({ ...f, children: f.children ? f.children.map((c) => ({ ...c })) : null }))
  for (const o of overlay) {
    const idx = out.findIndex((f) => f.key === o.key)
    if (idx === -1) { out.push({ ...o }); continue }
    if (o.children && out[idx].children) {
      for (const c of o.children) {
        const cidx = out[idx].children.findIndex((x) => x.key === c.key)
        if (cidx === -1) out[idx].children.push({ ...c })
        else out[idx].children[cidx] = { ...c }
      }
    } else {
      out[idx] = { ...o }
    }
  }
  return out
}

/** Word count of body lines (fences included; markdown punctuation ignored). */
export function wordCount(lines) {
  return lines.join(" ").split(/\s+/).filter((w) => /[A-Za-z0-9]/.test(w)).length
}
