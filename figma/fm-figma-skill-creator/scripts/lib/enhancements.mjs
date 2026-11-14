// enhancements.mjs — the enhancement-pack contract as code.
//
// The contract is references/enhancement-packs.md; this module is its executable form, and
// scripts/enhancement-packs.mjs is the command line over it. Exports:
//   loadPack(dir)                          read and check enhancements/<name>/pack.json
//   findUnits(lines, pack, { warn })       every unit of one pack in a master, in line order
//   stripUnits(lines, units)               the master without those units, blank runs collapsed
//   insertUnits(lines, units, { fallback }) the reverse; not implemented yet (expand comes next)
//
// A unit is { kind, start, end, col, text, anchor: { section, helper, after } } with 0-based lines;
// a line-rewrite unit also carries `to`. Contract errors (nested regions, an unpartnered marker, an
// ambiguous declared line, a declared prose sentence missing or repeated, the phrase in a table row)
// throw; any other declared item the master does not contain is passed to `warn`.
//
// Dependency-free. Parsing of frontmatter and fences goes through skill-md.mjs.

import { readFileSync, existsSync } from "node:fs"
import { join, basename } from "node:path"
import {
  parseFrontmatter, getField, scanFences, fenceBlocks, collapseBlankRuns,
  OPEN_MARKER, CLOSE_MARKER, HELPER_FENCE_LANG, HELPER_MARKER,
} from "./skill-md.mjs"

export const UNIT_KINDS = ["code-region", "fence", "block", "heading-block", "sentence", "prose-sentence", "template-line", "line-rewrite", "description-sentence", "tag"]
export const SURFACES = ["figma-design", "figma-make", "figma-spec"]
export const DEFAULT_SURFACES = ["figma-design", "figma-make"]
export const VOCABULARY = ["confirm-tiered", "always-write", "dry-run"]

const REGION_MARKER = /^\s*\/\/ enhancement: ([a-z0-9][a-z0-9-]*) (begin|end)\s*$/
const LIST_LEAD = /^(\s*)((?:[-*+]|\d+[.)])\s+(?:\[[ xX]\]\s+)?)?/
const HEADING = /^(\s*)(#{1,6})\s+/

// ---------------------------------------------------------------------------
// pack.json
// ---------------------------------------------------------------------------

/** Read enhancements/<name>/pack.json, check it against the contract, and fill the defaults. */
export function loadPack(dir) {
  const file = join(dir, "pack.json")
  if (!existsSync(file)) throw new Error(`no pack.json in ${dir}`)
  let pack
  try { pack = JSON.parse(readFileSync(file, "utf8")) } catch (e) { throw new Error(`${file}: ${e.message}`) }
  const bad = (msg) => { throw new Error(`${file}: ${msg}`) }
  if (pack.name !== basename(dir)) bad(`name "${pack.name}" must equal its folder name "${basename(dir)}"`)
  if (typeof pack.phrase !== "string" || pack.phrase.trim() === "") bad("phrase must be a non-empty string")
  if (typeof pack.codeRegion !== "string" || !/^[a-z0-9][a-z0-9-]*$/.test(pack.codeRegion)) bad("codeRegion must be a lowercase name")
  for (const k of ["templateLines", "proseSentences", "descriptionSentences", "tags", "lineRewrites", "requires", "conflicts"]) {
    if (pack[k] === undefined) pack[k] = []
    if (!Array.isArray(pack[k])) bad(`${k} must be an array`)
  }
  for (const k of ["templateLines", "proseSentences", "descriptionSentences", "tags"]) for (const v of pack[k]) if (typeof v !== "string" || v === "") bad(`each ${k} entry must be a non-empty string`)
  for (const r of pack.lineRewrites) if (typeof r?.from !== "string" || typeof r?.to !== "string") bad("each lineRewrites entry needs string from and to")
  for (const k of ["requires", "conflicts"]) for (const v of pack[k]) if (!VOCABULARY.includes(v)) bad(`${k} value "${v}" is not one of ${VOCABULARY.join(", ")}`)
  if (pack.surfaces !== undefined) {
    if (!Array.isArray(pack.surfaces) || pack.surfaces.length === 0) bad("surfaces must be a non-empty array when present")
    for (const s of pack.surfaces) if (!SURFACES.includes(s)) bad(`surface "${s}" is not one of ${SURFACES.join(", ")}`)
  }
  return { ...pack, surfacesDeclared: pack.surfaces !== undefined, surfaces: pack.surfaces ?? [...DEFAULT_SURFACES] }
}

// ---------------------------------------------------------------------------
// Small text helpers
// ---------------------------------------------------------------------------

const indentOf = (l) => /^\s*/.exec(l)[0].length
const isBlank = (l) => l.trim() === ""
const isMarker = (l) => OPEN_MARKER.test(l) || CLOSE_MARKER.test(l)

const isTableRow = (l) => /^\s*\|/.test(l)

/**
 * Index of the last character of the sentence starting at `pos` (rule d): the first `.`, `?`, or `!`
 * followed by a space or the end of the line and not inside parentheses opened within the sentence;
 * or, when a closing parenthesis comes first that the sentence did not open, the character before it.
 */
function sentenceEnd(text, pos) {
  let depth = 0
  for (let k = pos; k < text.length; k++) {
    const c = text[k]
    if (c === "(") depth++
    else if (c === ")") { if (depth === 0) return k - 1; depth-- }
    else if ((c === "." || c === "?" || c === "!") && depth === 0 && (k + 1 === text.length || text[k + 1] === " ")) return k
  }
  return text.length - 1
}

/** True when `pos` sits inside an inline code span (an odd number of backticks before it). */
const inCodeSpan = (text, pos) => ((text.slice(0, pos).match(/`/g) || []).length % 2) === 1

/** The last sentence of `text` (by the rule-d boundary), trimmed; null when empty. */
function lastSentence(text) {
  const t = text.trimEnd()
  if (!t) return null
  let start = 0, k = 0
  while (k < t.length) {
    const e = sentenceEnd(t, k)
    if (e >= t.length - 1) break
    start = e + 2
    k = start
  }
  return t.slice(start).trim() || null
}

// ---------------------------------------------------------------------------
// findUnits
// ---------------------------------------------------------------------------

/**
 * Every unit of `pack` in the master `lines` (an array of lines, LF-normalised), sorted by line and
 * column. `warn(message)` receives each declared item (template line, rewrite, description sentence,
 * tag) that the master does not contain. Throws on a contract error.
 */
export function findUnits(lines, pack, { warn = () => {} } = {}) {
  const fm = parseFrontmatter(lines)
  const bodyStart = fm.present ? fm.closeLine + 1 : 0
  const inFence = scanFences(lines)
  const fences = fenceBlocks(lines).map((f) => {
    const m = f.close > f.open + 1 && HELPER_FENCE_LANG.test(f.lang) ? HELPER_MARKER.exec(lines[f.open + 1]) : null
    return { ...f, helper: m ? m[1] : null }
  })
  const fenceAt = (i) => fences.find((f) => i >= f.open && (f.close === -1 || i <= f.close)) || null

  // Section per line: the nearest level-two heading above it, outside fences; "frontmatter" before the body.
  const sectionOf = new Array(lines.length).fill("")
  let section = ""
  for (let i = 0; i < lines.length; i++) {
    if (i < bodyStart) { sectionOf[i] = "frontmatter"; continue }
    const h = !inFence[i] && /^##\s+(.*?)\s*$/.exec(lines[i])
    if (h) section = h[1]
    sectionOf[i] = section
  }
  const prevNonBlank = (i) => { for (let k = i - 1; k >= 0; k--) if (!isBlank(lines[k])) return lines[k]; return null }
  const anchorFor = (i, after) => ({ section: sectionOf[i], helper: fenceAt(i)?.helper ?? null, after: after === undefined ? prevNonBlank(i) : after })

  const units = []
  const add = (kind, start, end, col, text, anchor, extra = {}) => units.push({ kind, start, end, col, text, anchor, ...extra })

  // (a) Code regions: scan every fenced line for region markers of any pack, so nesting and
  // interleaving are caught across packs; keep this pack's regions.
  let open = null
  for (let i = 0; i < lines.length; i++) {
    if (!inFence[i]) continue
    const m = REGION_MARKER.exec(lines[i])
    if (!m) continue
    const [, name, edge] = m
    if (edge === "begin") {
      if (open) throw new Error(`line ${i + 1}: region "${name}" begins inside region "${open.name}" (line ${open.line + 1}); regions never nest or interleave`)
      open = { name, line: i, fence: fenceAt(i) }
      continue
    }
    if (!open) throw new Error(`line ${i + 1}: "// enhancement: ${name} end" has no begin`)
    if (open.name !== name) throw new Error(`line ${i + 1}: region "${open.name}" (line ${open.line + 1}) is closed by an end for "${name}"`)
    if (fenceAt(i) !== open.fence) throw new Error(`line ${i + 1}: region "${name}" ends in a different fence from its begin (line ${open.line + 1})`)
    if (name === pack.codeRegion) {
      const f = open.fence
      if (f && f.helper && open.line === f.open + 2 && i === f.close - 1) {
        add("fence", f.open, f.close, 0, lines.slice(f.open, f.close + 1).join("\n"), anchorFor(f.open))
      } else {
        add("code-region", open.line, i, 0, lines.slice(open.line, i + 1).join("\n"), anchorFor(open.line))
      }
    }
    open = null
  }
  if (open) throw new Error(`line ${open.line + 1}: region "${open.name}" never ends`)

  // (b, c, d) Prose units: body lines outside fences and target markers.
  const claimed = new Set()
  for (let i = bodyStart; i < lines.length; i++) {
    if (inFence[i] || isMarker(lines[i]) || claimed.has(i)) continue
    const line = lines[i]
    // (d) A unit cannot sit in a table row: cutting it would break the table.
    if (isTableRow(line)) {
      for (let p = line.indexOf(pack.phrase); p !== -1; p = line.indexOf(pack.phrase, p + 1)) {
        if (!inCodeSpan(line, p)) throw new Error(`line ${i + 1}: the phrase "${pack.phrase}" is inside a table row; move the sentence out of the table`)
      }
      continue
    }
    const h = HEADING.exec(line)
    if (h) {
      let lead = h[0].length
      if (line.startsWith("**", lead) || line.startsWith("__", lead)) lead += 2
      if (!line.startsWith(pack.phrase, lead)) continue
      // (c) Heading block: to the next heading of the same or higher level, or a target marker.
      const level = h[2].length
      let end = lines.length - 1
      for (let j = i + 1; j < lines.length; j++) {
        if (inFence[j]) continue
        const hj = HEADING.exec(lines[j])
        if ((hj && hj[2].length <= level) || isMarker(lines[j])) { end = j - 1; break }
      }
      while (end > i && isBlank(lines[end])) end--
      for (let k = i; k <= end; k++) claimed.add(k)
      add("heading-block", i, end, 0, lines.slice(i, end + 1).join("\n"), anchorFor(i))
      continue
    }
    const ll = LIST_LEAD.exec(line)
    let lead = ll[0].length
    if (line.startsWith("**", lead) || line.startsWith("__", lead)) lead += 2
    if (!isBlank(line) && line.startsWith(pack.phrase, lead)) {
      // (b) Block: the line plus continuation lines, each more indented than the first line (a
      // blockquote under a list item is), up to the next blank line or a line that is not.
      const base = indentOf(line)
      let end = i
      for (let j = i + 1; j < lines.length; j++) {
        const l = lines[j]
        if (isBlank(l) || isMarker(l) || indentOf(l) <= base) break
        end = j
      }
      for (let k = i; k <= end; k++) claimed.add(k)
      add("block", i, end, 0, lines.slice(i, end + 1).join("\n"), anchorFor(i))
      continue
    }
  }
  // (d) Sentences: the phrase, with its colon, mid-line.
  for (let i = bodyStart; i < lines.length; i++) {
    if (inFence[i] || isMarker(lines[i]) || claimed.has(i) || isTableRow(lines[i])) continue
    const line = lines[i]
    let from = 1
    for (;;) {
      const pos = line.indexOf(pack.phrase, from)
      if (pos === -1) break
      from = pos + 1
      if (inCodeSpan(line, pos)) continue
      const end = sentenceEnd(line, pos)
      add("sentence", i, i, pos, line.slice(pos, end + 1), anchorFor(i, lastSentence(line.slice(0, pos))))
      from = end + 1
    }
  }

  // (f) Declared prose sentences: exact text in body prose, matched exactly once; anything else is an error.
  for (const s of pack.proseSentences) {
    const hits = []
    for (let i = bodyStart; i < lines.length; i++) {
      if (inFence[i] || isMarker(lines[i])) continue
      for (let p = lines[i].indexOf(s); p !== -1; p = lines[i].indexOf(s, p + 1)) hits.push({ i, p })
    }
    if (hits.length === 0) throw new Error(`${pack.name}: declared prose sentence not found: ${s}`)
    if (hits.length > 1) throw new Error(`${pack.name}: declared prose sentence matches ${hits.length} times, at ${hits.map((h) => `line ${h.i + 1}`).join(" and ")}: ${s}`)
    const { i, p } = hits[0]
    // A declared sentence must not overlap a unit the phrase already found.
    const clash = claimed.has(i) || units.some((u) => u.kind === "sentence" && u.start === i && p < u.col + u.text.length && u.col < p + s.length)
    if (clash) throw new Error(`line ${i + 1}: declared prose sentence overlaps a unit tagged by the phrase: ${s}`)
    add("prose-sentence", i, i, p, s, anchorFor(i, lastSentence(lines[i].slice(0, p))))
  }

  // (e) Template lines: exact lines inside the body's non-helper fences.
  for (const t of pack.templateLines) {
    const hits = []
    for (const f of fences) {
      if (f.helper || f.open < bodyStart) continue
      const last = f.close === -1 ? lines.length - 1 : f.close - 1
      for (let k = f.open + 1; k <= last; k++) if (lines[k] === t) hits.push(k)
    }
    if (hits.length > 1) throw new Error(`template line matches ${hits.length} lines (${hits.map((k) => k + 1).join(", ")}); a declared line must match exactly one: ${t}`)
    if (hits.length === 0) { warn(`${pack.name}: template line not found: ${t}`); continue }
    add("template-line", hits[0], hits[0], 0, t, anchorFor(hits[0]))
  }

  // (f) Line rewrites: one whole line, matched exactly once anywhere in the body.
  for (const r of pack.lineRewrites) {
    const hits = []
    for (let k = bodyStart; k < lines.length; k++) if (lines[k] === r.from) hits.push(k)
    if (hits.length > 1) throw new Error(`line rewrite matches ${hits.length} lines (${hits.map((k) => k + 1).join(", ")}): ${r.from}`)
    if (hits.length === 0) { warn(`${pack.name}: line rewrite not found: ${r.from}`); continue }
    add("line-rewrite", hits[0], hits[0], 0, r.from, anchorFor(hits[0]), { to: r.to })
  }

  // (f) Description sentences and tags, in the frontmatter.
  const desc = fm.present ? getField(fm.fields, "description") : null
  for (const s of pack.descriptionSentences) {
    let found = false
    if (desc) {
      const first = desc.line - 1
      const last = desc.block ? first + desc.value.split("\n").length + 1 : first
      for (let k = first; k <= Math.min(last, fm.closeLine - 1) && !found; k++) {
        const col = lines[k].indexOf(s)
        if (col === -1) continue
        if (lines[k].indexOf(s, col + 1) !== -1) throw new Error(`description sentence occurs twice on line ${k + 1}: ${s}`)
        const before = String(desc.value).slice(0, String(desc.value).indexOf(s))
        add("description-sentence", k, k, col, s, { section: "frontmatter", helper: null, after: lastSentence(before) })
        found = true
      }
    }
    if (!found) warn(`${pack.name}: description sentence not found: ${s}`)
  }
  const meta = fm.present ? getField(fm.fields, "metadata") : null
  const tagsField = meta?.children?.find((c) => c.key === "tags") ?? null
  const tagItems = tagsField ? String(tagsField.value).split(",").map((t) => t.trim()).filter(Boolean) : []
  for (const t of pack.tags) {
    const idx = tagItems.indexOf(t)
    if (idx === -1) { warn(`${pack.name}: tag not found in metadata.tags: ${t}`); continue }
    const k = tagsField.line - 1
    add("tag", k, k, lines[k].indexOf(t), t, { section: "frontmatter", helper: null, after: idx > 0 ? tagItems[idx - 1] : null })
  }

  return units.sort((a, b) => a.start - b.start || a.col - b.col)
}

// ---------------------------------------------------------------------------
// stripUnits
// ---------------------------------------------------------------------------

/**
 * The master without `units` (all found on these same `lines`): line units removed (a whole-fence
 * unit with the blank line before it), sentences cut with the space before them, rewrites applied,
 * tags dropped from metadata.tags. Runs of blank lines are collapsed. Throws when a unit no longer
 * matches the lines it was found on.
 */
export function stripUnits(lines, units) {
  const out = lines.slice()
  const drop = new Set()
  const stale = (u) => { throw new Error(`stale ${u.kind} unit at line ${u.start + 1}: the master changed since findUnits`) }

  // In-line cuts first, right to left per line, so earlier columns stay valid.
  const cuts = units.filter((u) => ["sentence", "prose-sentence", "description-sentence"].includes(u.kind)).sort((a, b) => a.start - b.start || b.col - a.col)
  for (const u of cuts) {
    const l = out[u.start]
    if (!l.startsWith(u.text, u.col)) stale(u)
    let from = u.col, to = u.col + u.text.length
    if (from > 0 && l[from - 1] === " ") from--
    else if (l[to] === " ") to++
    out[u.start] = l.slice(0, from) + l.slice(to)
  }
  // Tags: rebuild the list without them, keeping the quoting and the ", " separator.
  const tagLines = new Map()
  for (const u of units.filter((x) => x.kind === "tag")) tagLines.set(u.start, [...(tagLines.get(u.start) || []), u.text])
  for (const [k, gone] of tagLines) {
    const m = /^(\s*tags:\s*)(["']?)(.*?)\2\s*$/.exec(out[k])
    if (!m) throw new Error(`line ${k + 1}: metadata.tags is not a one-line list`)
    const items = m[3].split(",").map((t) => t.trim()).filter(Boolean)
    for (const t of gone) if (!items.includes(t)) stale({ kind: "tag", start: k })
    out[k] = m[1] + m[2] + items.filter((t) => !gone.includes(t)).join(", ") + m[2]
  }
  for (const u of units) {
    if (u.kind === "line-rewrite") {
      if (out[u.start] !== u.text) stale(u)
      out[u.start] = u.to
    } else if (["code-region", "block", "heading-block", "template-line", "fence"].includes(u.kind)) {
      if (lines.slice(u.start, u.end + 1).join("\n") !== u.text) stale(u)
      for (let k = u.start; k <= u.end; k++) drop.add(k)
      if (u.kind === "fence" && u.start > 0 && isBlank(lines[u.start - 1])) drop.add(u.start - 1)
    }
  }
  return collapseBlankRuns(out.filter((_, k) => !drop.has(k)))
}

// ---------------------------------------------------------------------------
// insertUnits
// ---------------------------------------------------------------------------

/** Insert units after their anchors (rule h). Not implemented yet: `expand` builds it. */
export function insertUnits(lines, units, { fallback } = {}) { // eslint-disable-line no-unused-vars
  throw new Error("insertUnits: not implemented")
}
