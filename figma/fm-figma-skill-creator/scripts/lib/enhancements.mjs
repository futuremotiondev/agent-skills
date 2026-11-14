// enhancements.mjs — the enhancement-pack contract as code.
//
// The contract is references/enhancement-packs.md; this module is its executable form, and
// scripts/enhancement-packs.mjs is the command line over it. Exports:
//   loadPack(dir)                          read and check enhancements/<name>/pack.json
//   findUnits(lines, pack, { warn })       every unit of one pack in a master, in line order
//   stripUnits(lines, units)               the master without those units, blank runs collapsed
//   readUnits(text)                        the units an enhancement.md records, and its source master
//   insertUnits(lines, units, { warn, skill }) the reverse of stripUnits: each unit after its anchor,
//                                          with the rule (h) fallbacks passed to `warn`
//
// A unit is { kind, start, end, col, text, anchor: { section, helper, after } } with 0-based lines;
// a line-rewrite unit also carries `to`, and a unit read from an enhancement.md may carry `pack` and
// `source` (the skill it was extracted from). Contract errors (nested regions, an unpartnered marker,
// an ambiguous declared line or prose sentence, the phrase in a table row) throw; a declared item the
// master does not contain is passed to `warn`.
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

export const REGION_MARKER = /^\s*\/\/ enhancement: ([a-z0-9][a-z0-9-]*) (begin|end)\s*$/
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

  // (f) Declared prose sentences: exact text in body prose. Missing is a warning, like the other declared
  // items (a master without the pack passes through strip); more than one match is an error.
  for (const s of pack.proseSentences) {
    const hits = []
    for (let i = bodyStart; i < lines.length; i++) {
      if (inFence[i] || isMarker(lines[i])) continue
      for (let p = lines[i].indexOf(s); p !== -1; p = lines[i].indexOf(s, p + 1)) hits.push({ i, p })
    }
    if (hits.length === 0) { warn(`${pack.name}: declared prose sentence not found: ${s}`); continue }
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
// readUnits: the units recorded in a generated enhancement.md
// ---------------------------------------------------------------------------

/** The fence starting at or after line `i`: its content and the line after its close. */
function readFence(lines, i) {
  while (i < lines.length && !/^`{3,}/.test(lines[i])) i++
  const bar = /^(`{3,})/.exec(lines[i] ?? "")
  if (!bar) throw new Error(`enhancement.md: expected a fence at line ${i + 1}`)
  let k = i + 1
  while (k < lines.length && lines[k] !== bar[1]) k++
  if (k >= lines.length) throw new Error(`enhancement.md: the fence at line ${i + 1} never closes`)
  return { content: lines.slice(i + 1, k).join("\n"), next: k + 1 }
}

/**
 * Parse an enhancement.md written by `extract` back into units: { kind, start, end, col, text, anchor },
 * plus `to` for a line rewrite, with 0-based lines in the source master. Returns { source, units }, where
 * `source` is the master path the file names (null when absent).
 */
export function readUnits(text) {
  const lines = text.replace(/\r\n?/g, "\n").split("\n")
  const src = lines.map((l) => /^Generated by .* from `([^`]+)`\./.exec(l)).find(Boolean)
  const units = []
  for (let i = 0; i < lines.length; i++) {
    const h = /^### Unit \d+: (\S+) in /.exec(lines[i])
    if (!h) continue
    const kind = h[1]
    if (!UNIT_KINDS.includes(kind)) throw new Error(`enhancement.md line ${i + 1}: unknown unit kind "${kind}"`)
    let k = i + 1
    while (k < lines.length && lines[k].trim() === "") k++
    const at = /^Master lines? (\d+)(?: to (\d+))?(?:, column (\d+))?\. Anchor:$/.exec(lines[k] ?? "")
    if (!at) throw new Error(`enhancement.md line ${k + 1}: expected "Master line n. Anchor:"`)
    const anchor = readFence(lines, k + 1)
    const first = readFence(lines, anchor.next)
    const unit = { kind, start: +at[1] - 1, end: +(at[2] ?? at[1]) - 1, col: at[3] ? +at[3] - 1 : 0, text: first.content, anchor: JSON.parse(anchor.content) }
    if (kind === "line-rewrite") unit.to = readFence(lines, first.next).content
    units.push(unit)
  }
  return { source: src ? src[1] : null, units }
}

// ---------------------------------------------------------------------------
// insertUnits
// ---------------------------------------------------------------------------

const LINE_KINDS = ["code-region", "fence", "block", "heading-block", "template-line"]
const isListItem = (l) => !!LIST_LEAD.exec(l)[2]
/** Two lines sit together with no blank line between them: a list item after a list item or its indented continuation. */
const tight = (x, y) => !isBlank(x) && isListItem(y) && (isListItem(x) || indentOf(x) > 0)
/** An anchor with no letter or digit (`};`, a bare fence) places a unit only in the master it was found in. */
const weak = (after) => after === null || after === undefined || !/[\p{L}\p{N}]/u.test(after)
const sectionKey = (name) => name.split(":")[0].trim().toLowerCase()

/** The body's level-two sections, each { name, start, end } (heading line to the line before the next H2 or target marker); "" is the preamble. */
function sectionsOf(lines, inFence, bodyStart) {
  const out = []
  let cur = { name: "", start: bodyStart, end: lines.length - 1 }
  out.push(cur)
  for (let i = bodyStart; i < lines.length; i++) {
    if (inFence[i]) continue
    const h2 = /^##\s+(.*?)\s*$/.exec(lines[i])
    if (h2 || isMarker(lines[i])) {
      if (cur) cur.end = i - 1
      cur = h2 ? { name: h2[1], start: i, end: lines.length - 1 } : null
      if (cur) out.push(cur)
    }
  }
  return out
}

/**
 * Insert `units` into the master `lines` (rule h), returning the new lines. Each unit goes after its
 * anchor: code regions after the `after` line inside the named helper, sentence units after the `after`
 * sentence on its line, blocks, heading blocks, and template lines after the `after` line, rewrites
 * reversed, description sentences and tags restored. Units are taken in recorded order (line, then
 * column), because a unit's anchor can be the unit before it; adjacent line units of the same kind go
 * in as one piece. When an anchor line occurs more than once in its scope, the occurrence nearest the
 * unit's recorded line wins. Blank lines at a seam follow Markdown: a list item after a list item or
 * its continuation joins it, anything else is set apart by one blank line.
 *
 * Without an anchor, prose units go at the end of their section (template lines at the end of the
 * section's report fence), and the orphan code regions of each helper go into one new `javascript`
 * fence with no helper marker, opened by `// <pack> regions for <helper>: place by hand`. Each fallback
 * is passed to `warn`. Options: `warn(message)`, and `skill`, the master's name: a unit that carries a
 * `source` skill other than `skill` (it came from another master's enhancement.md) is not placed by an
 * anchor with no letter or digit, which says nothing about where it belongs in a different skill.
 */
export function insertUnits(lines, units, { warn = () => {}, skill = null } = {}) {
  const out = lines.slice()
  const label = (u) => `${u.pack ? u.pack + ": " : ""}${u.kind} (master ${u.start === u.end ? "line " + (u.start + 1) : "lines " + (u.start + 1) + " to " + (u.end + 1)})`

  // Items: units in recorded order, adjacent line units of one kind merged into one piece.
  const items = []
  for (const u of units.slice().sort((a, b) => a.start - b.start || a.col - b.col)) {
    const prev = items[items.length - 1]
    const lineKind = LINE_KINDS.includes(u.kind) && u.kind !== "fence"
    if (lineKind && prev && prev.kind === u.kind && prev.end + 1 === u.start && u.anchor.after === prev.lines[prev.lines.length - 1] &&
      u.anchor.section === prev.anchor.section && u.anchor.helper === prev.anchor.helper) {
      prev.lines.push(...u.text.split("\n")); prev.end = u.end; prev.units.push(u)
      continue
    }
    items.push({ ...u, lines: u.text.split("\n"), units: [u] })
  }
  const height = (it) => (LINE_KINDS.includes(it.kind) ? it.lines.length + (it.kind === "fence" ? 1 : 0) : 0)
  const usable = (it) => !(weak(it.anchor.after) && it.source !== undefined && it.source !== skill)

  // The state of `out`, recomputed after each insertion.
  const scan = () => {
    const fm = parseFrontmatter(out)
    const bodyStart = fm.present ? fm.closeLine + 1 : 0
    const inFence = scanFences(out)
    const fences = fenceBlocks(out).map((f) => {
      const m = f.close > f.open + 1 && HELPER_FENCE_LANG.test(f.lang) ? HELPER_MARKER.exec(out[f.open + 1]) : null
      return { ...f, helper: m ? m[1] : null }
    })
    return { fm, bodyStart, inFence, fences, sections: sectionsOf(out, inFence, bodyStart) }
  }
  const findSection = (s, name) => s.sections.find((x) => x.name === name) || (name ? s.sections.find((x) => x.name && sectionKey(x.name) === sectionKey(name)) : null) || null
  const prevNonBlankAt = (i) => { for (let k = i - 1; k >= 0; k--) if (!isBlank(out[k])) return out[k]; return null }

  // Choose among candidate lines: the one nearest where the unit's anchor should be, given the units still to come.
  const pending = new Set(items)
  const nearest = (it, cands, target) => {
    const shift = [...pending].filter((p) => p !== it && p.start < it.start).reduce((s, p) => s + height(p), 0)
    const want = target - shift
    return cands.slice().sort((a, b) => Math.abs((a.line ?? a) - want) - Math.abs((b.line ?? b) - want) || Math.abs((a.col ?? 0) - it.col) - Math.abs((b.col ?? 0) - it.col))[0]
  }

  /** Put `body` after line `a`, setting it apart by blank lines per the seam rule. */
  const place = (a, body, { kind, forceRule = false, inCode = false }) => {
    const b = a + 1 < out.length && isBlank(out[a + 1]) ? 1 : 0
    const next = out[a + 1 + b]
    let before, after
    if (kind === "fence") { before = true; after = b === 1 || (next !== undefined && forceRule) }
    else if (b === 0 && !forceRule) { before = false; after = false }
    else {
      before = !tight(out[a], body[0])
      after = next !== undefined && !tight(body[body.length - 1], next)
      if (!before && !after && b === 1) after = true
      if (inCode && before && after) after = false
    }
    out.splice(a + 1, b, ...(before ? [""] : []), ...body, ...(after ? [""] : []))
  }
  /** After the last non-blank line of a section, or of the body when the section is missing. */
  const sectionEnd = (s, name) => {
    const sec = findSection(s, name)
    let k = sec ? sec.end : out.length - 1
    const floor = sec ? sec.start : s.bodyStart
    while (k > floor && isBlank(out[k])) k--
    return { at: k, found: !!sec }
  }

  // --- one attempt per item; true when it went in at its anchor -------------------------------
  const tryLine = (it, s) => {
    const { section, helper, after } = it.anchor
    let cands = []
    if (it.kind === "code-region") {
      // A region in a helper is anchored in that helper; one in an unmarked fence (an orphan fence), in its section's unmarked javascript fences.
      const sec = helper ? null : findSection(s, section)
      const hosts = helper ? s.fences.filter((x) => x.helper === helper) : sec ? s.fences.filter((x) => !x.helper && HELPER_FENCE_LANG.test(x.lang) && x.open >= sec.start && x.open <= sec.end) : []
      for (const f of hosts) for (let k = f.open + 1; k < f.close; k++) if (out[k] === after) cands.push(k)
    } else {
      const sec = findSection(s, section)
      if (!sec) return false
      for (let k = sec.start; k <= sec.end; k++) {
        if (out[k] !== after) continue
        const f = s.fences.find((x) => k >= x.open && (x.close === -1 || k <= x.close))
        if (it.kind === "template-line" ? f && !f.helper && k < f.close : !f || k === f.close) cands.push(k)
      }
    }
    if (!cands.length) return false
    const a = nearest(it, cands, it.start - 1)
    place(a, it.lines, { kind: it.kind, inCode: it.kind === "code-region" })
    return true
  }
  const tryInline = (it, s) => {
    const { section, after } = it.anchor
    const sec = findSection(s, section)
    if (!sec || after === null) return false
    const cands = []
    for (let k = sec.start; k <= sec.end; k++) {
      if (s.inFence[k] || isMarker(out[k]) || isTableRow(out[k])) continue
      for (let p = out[k].indexOf(after); p !== -1; p = out[k].indexOf(after, p + 1)) cands.push({ line: k, col: p + after.length })
    }
    if (!cands.length) return false
    const { line, col } = nearest(it, cands, it.start)
    const l = out[line]
    const glued = /[([{"'“‘]$/.test(after)
    const ins = glued ? it.text + (col < l.length && !/[\s)\]}]/.test(l[col]) ? " " : "") : " " + it.text
    out[line] = l.slice(0, col) + ins + l.slice(col)
    return true
  }
  const tryRewrite = (it, s) => {
    const { section, helper, after } = it.anchor
    const f = helper ? s.fences.find((x) => x.helper === helper) : null
    const sec = f ? { start: f.open + 1, end: f.close - 1 } : findSection(s, section)
    if (!sec) return false
    let cands = []
    for (let k = sec.start; k <= sec.end; k++) if (out[k] === it.to) cands.push(k)
    const exact = cands.filter((k) => prevNonBlankAt(k) === after)
    if (exact.length) cands = exact
    if (!cands.length) return false
    out[nearest(it, cands, it.start)] = it.text
    return true
  }
  const descriptionLines = (s) => {
    const desc = s.fm.present ? getField(s.fm.fields, "description") : null
    if (!desc) return null
    const first = desc.line - 1
    let last = first
    if (desc.block) while (last + 1 < s.fm.closeLine && (isBlank(out[last + 1]) || /^\s+/.test(out[last + 1]))) last++
    return { first, last }
  }
  const tryDescription = (it, s) => {
    const d = descriptionLines(s)
    if (!d) return false
    if (it.anchor.after === null) {
      const m = /^(description:\s*["']?)/.exec(out[d.first])
      if (!m || d.first !== d.last) return false
      out[d.first] = m[1] + it.text + " " + out[d.first].slice(m[1].length)
      return true
    }
    for (let k = d.first; k <= d.last; k++) {
      const p = out[k].indexOf(it.anchor.after)
      if (p === -1) continue
      const col = p + it.anchor.after.length
      out[k] = out[k].slice(0, col) + " " + it.text + out[k].slice(col)
      return true
    }
    return false
  }
  const tagLine = (s) => {
    const meta = s.fm.present ? getField(s.fm.fields, "metadata") : null
    const f = meta?.children?.find((c) => c.key === "tags")
    const k = f ? f.line - 1 : -1
    const m = k >= 0 ? /^(\s*tags:\s*)(["']?)(.*?)\2\s*$/.exec(out[k]) : null
    return m ? { k, m, items: m[3].split(",").map((t) => t.trim()).filter(Boolean) } : null
  }
  const tryTag = (it, s) => {
    const t = tagLine(s)
    if (!t) return false
    if (t.items.includes(it.text)) return true
    const at = it.anchor.after === null ? 0 : t.items.indexOf(it.anchor.after) + 1
    if (at === 0 && it.anchor.after !== null) return false
    t.items.splice(at, 0, it.text)
    out[t.k] = t.m[1] + t.m[2] + t.items.join(", ") + t.m[2]
    return true
  }
  const attempt = (it) => {
    if (!usable(it)) return false
    const s = scan()
    if (LINE_KINDS.includes(it.kind)) return tryLine(it, s)
    if (it.kind === "sentence" || it.kind === "prose-sentence") return tryInline(it, s)
    if (it.kind === "line-rewrite") return tryRewrite(it, s)
    if (it.kind === "description-sentence") return tryDescription(it, s)
    if (it.kind === "tag") return tryTag(it, s)
    return false
  }

  // Passes in recorded order until nothing more goes in at an anchor: a unit whose anchor is another
  // pack's unit waits for that unit.
  for (let progress = true; progress && pending.size;) {
    progress = false
    for (const it of items) if (pending.has(it) && attempt(it)) { pending.delete(it); progress = true }
  }

  // Fallbacks (rule h), in recorded order.
  const orphans = new Map()
  for (const it of items) {
    if (!pending.has(it)) continue
    pending.delete(it)
    const s = scan()
    if (it.kind === "code-region") {
      const key = `${it.pack ?? "pack"}\u0000${it.anchor.helper}`
      if (!orphans.has(key)) orphans.set(key, { pack: it.pack ?? "pack", helper: it.anchor.helper, section: it.anchor.section, regions: [] })
      orphans.get(key).regions.push(it.lines)
      warn(`${label(it)} has no anchor in helper "${it.anchor.helper}"; put in the fence "// ${it.pack ?? "pack"} regions for ${it.anchor.helper}: place by hand"`)
    } else if (it.kind === "line-rewrite") {
      warn(`${label(it)}: no line reads ${JSON.stringify(it.to)} in ${it.anchor.helper ? `helper "${it.anchor.helper}"` : `section "${it.anchor.section}"`}; not applied`)
    } else if (it.kind === "description-sentence") {
      const d = descriptionLines(s)
      if (!d) { warn(`${label(it)}: the master has no description; not restored`); continue }
      const l = out[d.last], q = /["']$/.test(l) && d.first === d.last ? 1 : 0
      out[d.last] = l.slice(0, l.length - q) + " " + it.text + l.slice(l.length - q)
      warn(`${label(it)} has no anchor in the description; appended to its end`)
    } else if (it.kind === "tag") {
      const t = tagLine(s)
      if (!t) { warn(`${label(it)}: the master has no one-line metadata.tags; "${it.text}" not restored`); continue }
      t.items.push(it.text)
      out[t.k] = t.m[1] + t.m[2] + t.items.join(", ") + t.m[2]
      warn(`${label(it)}: tag "${it.anchor.after}" not in metadata.tags; "${it.text}" appended to the list`)
    } else if (it.kind === "template-line") {
      const sec = findSection(s, it.anchor.section)
      const f = sec && s.fences.filter((x) => !x.helper && x.close !== -1 && x.open >= sec.start && x.close <= sec.end).pop()
      if (f) out.splice(f.close, 0, ...it.lines)
      else { const e = sectionEnd(s, it.anchor.section); place(e.at, it.lines, { kind: it.kind, forceRule: true }) }
      warn(`${label(it)} has no anchor in section "${it.anchor.section}"; put at the end of ${f ? "its report fence" : "the section"}`)
    } else {
      const e = sectionEnd(s, it.anchor.section)
      place(e.at, it.lines, { kind: it.kind === "fence" ? "fence" : "block", forceRule: true })
      warn(`${label(it)} has no anchor in section "${it.anchor.section}"; put at the end of ${e.found ? "the section" : "the body (no such section)"}`)
    }
  }
  for (const o of orphans.values()) {
    const body = ["```javascript", `// ${o.pack} regions for ${o.helper}: place by hand`, ...o.regions.flatMap((r, i) => (i ? ["", ...r] : r)), "```"]
    const s = scan()
    const host = s.fences.find((x) => x.helper === o.helper && x.close !== -1)
    place(host ? host.close : sectionEnd(s, o.section).at, body, { kind: "fence", forceRule: true })
  }
  return out
}
