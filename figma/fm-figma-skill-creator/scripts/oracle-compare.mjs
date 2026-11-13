#!/usr/bin/env node
// oracle-compare.mjs — compare a skill's report, or an oracle-shaped run, with its oracle fixture.
//
// Usage, from figma/fm-figma-skill-creator:
//   node scripts/oracle-compare.mjs --expected <expected.json> --scope <n> --schema <schema.json>
//        (--report <pasted.md> | --run <oracle-shaped.json>) [--frame-tolerance <n>]
//
// --report reads a Markdown report pasted from the in-app agent. --run reads a raw `use_figma`
// return (counts as top-level fields) and compares it over the fields both sides share.
// --frame-tolerance (default 0) is how far `framesMeasured` and `boundPassed` may drift; every
// other count, the priority counts included, must match exactly.
//
// Prints, in order: the header counts (expected, observed, delta), the priority counts, the rows
// missing from the report, the rows extra in the report, the per-row mismatches keyed by the
// schema's key columns, a result line, and an EVAL-LOG entry stub built from the entry template in
// templates/EVAL-LOG.md.
//
// Exit codes: 0 when nothing is missing, extra, or mismatched and every count is within tolerance;
// 1 when anything differs; 2 when an input cannot be read or parsed (bad arguments, unreadable
// JSON, no such scope, no priority line, no main table).
//
// The schema names the report's labels and maps them to collect result fields:
//   keyColumns           fields that identify a row (here path, property, current)
//   columns              main-table header text -> field (null to ignore the column), or
//                        { "field", "aliases": [other header spellings] }
//   headerLines          header label -> field path in the scope object ("counts.framesMeasured"), or
//                        { "field", "aliases": [other labels], "modes": [modes that print the line] };
//                        in a --report compare, a line whose modes leave out the scope's mode is not
//                        read or compared (a --run carries every field and compares them all)
//   priorityLine         label of the "P0 <n> · P1 <n> · P2 <n> · P3 <n>" line
//   optionalHeaderLines  labels a report may omit; an omitted counted line reads as 0
//   fixFormat            how an expected `fix` object prints ("bind {name}", "set {value}")
// Labels and header names match after the same cleaning as cells, ignoring case. When no table holds
// every key column, the exit-2 message lists the header rows the report does have.
//
// The report parser removes the agent's decoration before reading anything: `**` bold, en and em
// dashes and the minus sign (U+2212) become "-", `<figma-node-link …>x</figma-node-link>` (and the
// group-link form) becomes x, a leading "… / " on a path is dropped, "→" reads as "->", and
// thousands separators in numbers are ignored. The same cleaning is applied to expected strings.
// A numeric cell must be a number as a whole and compares exactly; a row that ends before a compared
// column reads as absent there. Both count as mismatches.
//
// Dependency-free, Node 18+.

import { readFileSync, existsSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize, scanFences } from "./lib/skill-md.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const EVAL_LOG_TEMPLATE = join(here, "..", "templates", "EVAL-LOG.md")

/** An input that cannot be read or parsed: exit 2. */
class ParseError extends Error {}
const fail = (message) => { throw new ParseError(message) }

// Fields the frame tolerance applies to; every other count must match exactly.
const TOLERANT_FIELDS = new Set(["framesMeasured", "boundPassed"])
// Row fields never compared: free prose the agent is allowed to rephrase.
const UNCOMPARED_FIELDS = new Set(["note"])
const PRIORITY_LEVELS = ["P0", "P1", "P2", "P3"]

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const FLAGS = ["--expected", "--scope", "--schema", "--report", "--run", "--frame-tolerance"]

function parseArgs(argv) {
  const out = {}
  for (let i = 0; i < argv.length; i += 2) {
    const flag = argv[i]
    if (!FLAGS.includes(flag)) fail(`unknown argument ${flag}; expected ${FLAGS.join(", ")}`)
    if (i + 1 >= argv.length || argv[i + 1].startsWith("--")) fail(`${flag} needs a value`)
    out[flag.slice(2)] = argv[i + 1]
  }
  if (!out.expected || !out.scope || !out.schema) fail("--expected, --scope, and --schema are required")
  if (Boolean(out.report) === Boolean(out.run)) fail("give exactly one of --report and --run")
  const tolerance = out["frame-tolerance"] === undefined ? 0 : Number(out["frame-tolerance"])
  if (!Number.isFinite(tolerance) || tolerance < 0) fail("--frame-tolerance must be a number of 0 or more")
  return { ...out, tolerance }
}

function readText(path, what) {
  if (!existsSync(path)) fail(`${what} not found: ${path}`)
  return normalize(readFileSync(path, "utf8"))
}

function readJson(path, what) {
  const text = readText(path, what)
  try { return JSON.parse(text) } catch (e) { return fail(`${what} is not valid JSON (${path}): ${e.message}`) }
}

/**
 * One `columns` or `headerLines` entry: a field string, null, or { field, aliases, modes }.
 * Returns { name, field, spellings (canonical name first), modes (null for every mode) }.
 */
function schemaEntry(name, value, where) {
  if (value === null || typeof value === "string") return { name, field: value, spellings: [name], modes: null }
  const ok = value && typeof value === "object" && (value.field === null || typeof value.field === "string") &&
    (value.aliases === undefined || (Array.isArray(value.aliases) && value.aliases.every((a) => typeof a === "string"))) &&
    (value.modes === undefined || (Array.isArray(value.modes) && value.modes.every((m) => typeof m === "string")))
  if (!ok) fail(`schema ${where} entry "${name}" must be a field name, null, or { "field", "aliases", "modes" }`)
  return { name, field: value.field, spellings: [name, ...(value.aliases || [])], modes: value.modes || null }
}

/** Read the schema and resolve it for one mode: header lines marked for other modes are set aside. */
function loadSchema(path, mode) {
  const schema = readJson(path, "schema")
  for (const key of ["keyColumns", "columns", "headerLines", "priorityLine"]) {
    if (schema[key] === undefined) fail(`schema has no "${key}": ${path}`)
  }
  schema.columnList = Object.entries(schema.columns).map(([n, v]) => schemaEntry(n, v, "columns"))
  schema.fields = [...new Set(schema.columnList.map((c) => c.field).filter(Boolean))]
  for (const k of schema.keyColumns) if (!schema.fields.includes(k)) fail(`schema key column "${k}" is not mapped in "columns"`)
  const lines = Object.entries(schema.headerLines).map(([n, v]) => schemaEntry(n, v, "headerLines"))
  for (const l of lines) if (!l.field) fail(`schema headerLines entry "${l.name}" has no field`)
  const applies = (l) => !l.modes || !mode || l.modes.includes(mode)
  schema.lines = lines.filter(applies)
  schema.linesNotInMode = lines.filter((l) => !applies(l)).map((l) => l.name)
  schema.optionalHeaderLines = schema.optionalHeaderLines || []
  schema.fixFormat = schema.fixFormat || {}
  return schema
}

// ---------------------------------------------------------------------------
// Normalisation
// ---------------------------------------------------------------------------

/** Remove the agent's decoration from report text (also applied to expected strings). */
function clean(text) {
  return String(text)
    .replace(/\*\*/g, "")
    .replace(/[\u2013\u2014\u2212]/g, "-")
    .replace(/<figma-node(?:-group)?-link\b[^>]*>(.*?)<\/figma-node(?:-group)?-link>/g, "$1")
}

/** A text cell as compared: cleaned, no leading "… / ", arrows as "->", single spaces. */
function text(value) {
  return clean(value)
    .replace(/^\s*(?:\u2026|\.\.\.)\s*\/\s*/, "")
    .replace(/\u2192/g, "->")
    .replace(/\s+/g, " ")
    .trim()
}

/** A header label or column name as matched: normalised like a cell, case ignored. */
const labelKey = (value) => text(value).toLowerCase()

/** The first number in a header-line value ("1,937", "6 passed", "0 (not offered)"), or null. */
function num(value) {
  if (typeof value === "number") return value
  if (value === null || value === undefined) return null
  const m = clean(value).replace(/(\d),(?=\d{3}\b)/g, "$1").match(/[-+]?\d+(?:\.\d+)?/)
  return m ? Number(m[0]) : null
}

/**
 * A numeric table cell as compared: a number only when the whole cleaned cell is one ("−3", "+0.5",
 * "1,024"); otherwise the cleaned text itself ("16 or 12", "+2 pt", ""), which never equals a number.
 */
function cellNum(value) {
  if (typeof value === "number") return value
  const t = text(value).replace(/(\d),(?=\d{3}\b)/g, "$1")
  return /^[-+]?\d+(?:\.\d+)?$/.test(t) ? Number(t) : t
}

/** A fix cell or object as compared; "" for none. */
function fixText(value, format) {
  if (value === null || value === undefined) return ""
  if (typeof value === "object") {
    const template = format[value.kind]
    if (!template) return `${value.kind} ${value.value}`
    return template.replace(/\{(\w+)\}/g, (all, k) => (value[k] === undefined ? all : String(value[k])))
  }
  const t = text(value)
  return t === "-" ? "" : t
}

/** Resolve "a.b" in obj; a run carries counts as top-level fields, so fall back to the last segment. */
function getPath(obj, path) {
  let v = obj
  for (const part of path.split(".")) v = v === null || v === undefined ? undefined : v[part]
  if (v === undefined && path.includes(".")) v = obj[path.split(".").pop()]
  return v
}

// ---------------------------------------------------------------------------
// Sides: the expected scope, a run, or a report, all read into one shape
//   { counts: Map(label -> number|null), omitted: Set(label), priority: {P0..P3}, rows, columnsMissing }
// ---------------------------------------------------------------------------

/** Rows the master prints: on more than 50 frames, token-mode opportunity rows are left out. */
function printedRows(rows, framesMeasured) {
  return rows.filter((r) => !(framesMeasured > 50 && r.priority === "P3" && r.delta === 0))
}

/** Which row fields are numeric, read from the expected rows (a field is numeric where they hold numbers). */
function numericFields(rows, schema) {
  const fields = new Set()
  for (const f of schema.fields) {
    const sample = rows.find((r) => r[f] !== undefined && r[f] !== null)
    if (sample && typeof sample[f] === "number") fields.add(f)
  }
  return fields
}

/**
 * A row as compared: { key, label, values: { field -> comparable } }. A field the source does not
 * carry at all is left out; a field it carries as undefined (a report row that ends before that
 * column) becomes null, shown as "absent", which never equals an expected value.
 */
function rowOf(source, schema, numeric) {
  const values = {}
  for (const f of schema.fields) {
    if (!(f in source)) continue
    const v = source[f]
    if (v === undefined) values[f] = null
    else if (f === "fix") values[f] = fixText(v, schema.fixFormat)
    else if (v === null) values[f] = ""
    else if (f === "priority") values[f] = text(v).toUpperCase()
    else if (numeric.has(f)) values[f] = cellNum(v)
    else values[f] = text(v)
  }
  const keyParts = schema.keyColumns.map((k) => (values[k] === null || values[k] === undefined ? "?" : String(values[k])))
  return { key: keyParts.join("\u0000"), label: keyParts.join(" \u00b7 "), values, source }
}

/** The expected scope, or an oracle-shaped run, as a side. */
function fromOracle(obj, schema, numeric) {
  if (!Array.isArray(obj.rows)) fail("the oracle object has no rows array")
  const counts = new Map()
  for (const line of schema.lines) {
    const v = getPath(obj, line.field)
    counts.set(line.name, typeof v === "number" ? v : null)
  }
  const byPriority = getPath(obj, "counts.byPriority") || {}
  const priority = Object.fromEntries(PRIORITY_LEVELS.map((p) => [p, typeof byPriority[p] === "number" ? byPriority[p] : null]))
  const framesMeasured = getPath(obj, "counts.framesMeasured")
  const rows = printedRows(obj.rows, framesMeasured).map((r) => rowOf(r, schema, numeric))
  return { counts, omitted: new Set(), priority, rows, columnsMissing: [] }
}

/** Split one Markdown table line into trimmed cells (an escaped "\|" stays inside its cell). */
function cells(line) {
  let t = line.trim()
  if (t.startsWith("|")) t = t.slice(1)
  if (t.endsWith("|") && !t.endsWith("\\|")) t = t.slice(0, -1)
  return t.split(/(?<!\\)\|/).map((c) => c.replace(/\\\|/g, "|").trim())
}

const SEPARATOR = /^\s*:?-{3,}:?\s*$/

/** Every Markdown table outside code fences: [{ header: [cells], rows: [[cells]] }]. */
function tables(lines) {
  const inFence = scanFences(lines)
  const out = []
  for (let i = 0; i < lines.length; i++) {
    if (inFence[i] || !lines[i].trim().startsWith("|")) continue
    const block = []
    while (i < lines.length && !inFence[i] && lines[i].trim().startsWith("|")) block.push(lines[i++])
    if (block.length >= 2 && cells(block[1]).every((c) => SEPARATOR.test(c))) {
      out.push({ header: cells(block[0]).map(text), rows: block.slice(2).map(cells) })
    }
  }
  return out
}

/** Header lines: { label (lower case) -> rest of the part after its colon }, first occurrence wins. */
function headerParts(lines, schema) {
  const inFence = scanFences(lines)
  const parts = new Map()
  const priorityLabel = labelKey(schema.priorityLine)
  const add = (part) => {
    const colon = part.indexOf(":")
    if (colon < 0) return
    const key = labelKey(part.slice(0, colon))
    if (!parts.has(key)) parts.set(key, part.slice(colon + 1))
  }
  for (let i = 0; i < lines.length; i++) {
    if (inFence[i] || lines[i].trim().startsWith("|")) continue
    const line = clean(lines[i]).trim().replace(/^[-*+]\s+/, "")
    const colon = line.indexOf(":")
    // The priority line holds " · " itself, so it is read whole before any split.
    if (colon >= 0 && labelKey(line.slice(0, colon)) === priorityLabel) { add(line); continue }
    for (const part of line.split(/\s+\u00b7\s+/)) add(part)
  }
  return parts
}

/** A pasted report as a side. */
function fromReport(reportText, schema, numeric, expectedRowCount) {
  const lines = reportText.split("\n")
  const parts = headerParts(lines, schema)

  const counts = new Map()
  const omitted = new Set()
  const optional = new Set(schema.optionalHeaderLines.map((l) => l.toLowerCase()))
  for (const line of schema.lines) {
    // The first spelling the report uses wins: the canonical label, then each alias.
    const spelling = line.spellings.find((s) => parts.has(labelKey(s)))
    if (spelling !== undefined) counts.set(line.name, num(parts.get(labelKey(spelling))))
    else if (optional.has(line.name.toLowerCase())) { counts.set(line.name, 0); omitted.add(line.name) }
    else counts.set(line.name, null)
  }

  const priorityRest = parts.get(labelKey(schema.priorityLine))
  if (priorityRest === undefined) fail(`no "${schema.priorityLine}:" line in the report`)
  const priority = {}
  for (const p of PRIORITY_LEVELS) {
    const m = priorityRest.match(new RegExp(`\\b${p}\\b\\s*:?\\s*(-?\\d[\\d,]*)`))
    priority[p] = m ? num(m[1]) : null
  }

  // The main table is the first table whose header holds every key column, under any of its spellings.
  const columnNames = new Map()
  for (const c of schema.columnList) for (const s of c.spellings) if (!columnNames.has(labelKey(s))) columnNames.set(labelKey(s), c.field)
  let main = null
  let fieldAt = null
  const found = tables(lines)
  for (const t of found) {
    const fields = t.header.map((h) => columnNames.get(h.toLowerCase()) ?? null)
    if (schema.keyColumns.every((k) => fields.includes(k))) { main = t; fieldAt = fields; break }
  }
  // "No off-grid values in N frames" replaces an empty table, so no table is only an error when rows are expected.
  if (!main && expectedRowCount > 0) {
    const headers = found.length
      ? found.map((t, i) => `  ${i + 1}. | ${t.header.join(" | ")} |`).join("\n")
      : "  (no Markdown tables found)"
    fail(`no table in the report has every key column (${schema.keyColumns.join(", ")}).\n` +
      `Header rows found in the report:\n${headers}\n` +
      `If one of them is the main table, add its spelling of the missing column to that column's "aliases" in the schema.`)
  }

  const rows = []
  const columnsMissing = []
  if (main) {
    for (const f of schema.fields) {
      if (!fieldAt.includes(f) && !schema.keyColumns.includes(f) && !UNCOMPARED_FIELDS.has(f)) columnsMissing.push(f)
    }
    for (const r of main.rows) {
      if (r.every((c) => c === "")) continue
      const source = {}
      // Every column in the header is carried, so a row that ends early reads as absent there.
      fieldAt.forEach((f, i) => { if (f) source[f] = r[i] })
      rows.push(rowOf(source, schema, numeric))
    }
  }
  return { counts, omitted, priority, rows, columnsMissing }
}

// ---------------------------------------------------------------------------
// Compare
// ---------------------------------------------------------------------------

// Exact: the helper rounds every number to two decimals and the report prints that same number.
const same = (a, b) => a === b
const show = (v) => (v === null || v === undefined ? "absent" : v === "" ? "none" : String(v))

function compare(exp, obs, schema, tolerance) {
  const counts = []
  for (const { name: label, field } of schema.lines) {
    const e = exp.counts.get(label)
    const o = obs.counts.get(label)
    const tol = TOLERANT_FIELDS.has(field.split(".").pop()) ? tolerance : 0
    const delta = e !== null && o !== null ? o - e : null
    counts.push({ label, e, o, delta, ok: delta !== null && Math.abs(delta) <= tol, omitted: obs.omitted.has(label) })
  }
  const priority = PRIORITY_LEVELS.map((p) => {
    const e = exp.priority[p]
    const o = obs.priority[p]
    const delta = e !== null && o !== null ? o - e : null
    return { label: p, e, o, delta, ok: delta === 0 }
  })

  // Rows pair by key in order, so two rows with the same key pair first to first.
  const pending = new Map()
  for (const r of exp.rows) {
    if (!pending.has(r.key)) pending.set(r.key, [])
    pending.get(r.key).push(r)
  }
  const extra = []
  const mismatched = []
  const compared = schema.fields.filter((f) => !schema.keyColumns.includes(f) && !UNCOMPARED_FIELDS.has(f))
  for (const o of obs.rows) {
    const e = pending.get(o.key)?.shift()
    if (!e) { extra.push(o); continue }
    const diffs = []
    for (const f of compared) {
      if (!(f in o.values)) continue
      const ev = e.values[f]
      const ov = o.values[f]
      // A report may name the mode after a bound token: "bind Space/300 (Compact)".
      const modeName = f === "fix" && e.source.fix && e.source.fix.modeName
      if (same(ev, ov) || (modeName && ov === `${ev} (${modeName})`)) continue
      diffs.push(`${f} ${show(ev)} vs ${show(ov)}`)
    }
    if (diffs.length) mismatched.push({ label: e.label, diffs })
  }
  const missing = [...pending.values()].flat()
  const allMatch = counts.every((c) => c.ok) && priority.every((p) => p.ok) &&
    !missing.length && !extra.length && !mismatched.length && !obs.columnsMissing.length
  return { counts, priority, missing, extra, mismatched, allMatch }
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

function countTable(title, entries) {
  const width = Math.max(...entries.map((c) => c.label.length))
  const out = [`${title} (expected, observed, delta)`]
  for (const c of entries) {
    const d = c.delta === null ? "n/a" : (c.delta > 0 ? "+" : "") + c.delta
    const flags = (c.omitted ? "  (line omitted, read as 0)" : "") + (c.ok ? "" : "  <-- differs")
    out.push(`  ${c.label.padEnd(width)}  ${show(c.e).padStart(6)}  ${show(c.o).padStart(6)}  ${d.padStart(4)}${flags}`)
  }
  return out
}

function listBlock(title, items) {
  return [`${title} (${items.length})`, ...items.map((i) => "  " + i)]
}

/** The EVAL-LOG entry template's heading and bullets, from templates/EVAL-LOG.md. */
function entryTemplate() {
  const fallback = ["### <YYYY-MM-DD> \u00b7 v<description version> \u00b7 <surface: Figma Design | Figma Make | Claude Code>",
    ...["Edition tested", "File and selection", "Prompt", "Triggered", "What the agent did", "What it should have done",
      "Output contract met", "Source changed", "Credits consumed (if visible)", "Defects", "Change made", "Re-test needed"]
      .map((l) => `- **${l}:** <fill in>`)]
  if (!existsSync(EVAL_LOG_TEMPLATE)) return fallback
  const lines = normalize(readFileSync(EVAL_LOG_TEMPLATE, "utf8")).split("\n")
  const start = lines.findIndex((l) => /^## Entry template\b/.test(l))
  if (start < 0) return fallback
  const out = []
  for (let i = start + 1; i < lines.length && !/^## /.test(lines[i]); i++) {
    if (/^### /.test(lines[i]) || /^- \*\*/.test(lines[i])) out.push(lines[i])
  }
  return out.length ? out : fallback
}

function evalLogStub(ctx) {
  const { expected, scope, obs, result, mode, exitCode } = ctx
  const countsLine = [...obs.counts.entries()].filter(([l]) => !obs.omitted.has(l)).map(([l, v]) => `${l} ${show(v)}`).join(" \u00b7 ")
  const prio = PRIORITY_LEVELS.map((p) => `${p} ${show(obs.priority[p])}`).join(" \u00b7 ")
  const selection = Array.isArray(scope.selection) ? `${scope.selection.length} named top-level nodes`
    : scope.selection === "page" ? "every top-level node" : String(scope.selection)
  const defects = []
  for (const c of [...result.counts, ...result.priority]) if (!c.ok) defects.push(`${c.label}: expected ${show(c.e)}, observed ${show(c.o)}`)
  for (const r of result.missing) defects.push(`missing row ${r.label}`)
  for (const r of result.extra) defects.push(`extra row ${r.label}`)
  for (const m of result.mismatched) defects.push(`${m.label}: ${m.diffs.join("; ")}`)
  for (const f of obs.columnsMissing) defects.push(`no ${f} column in the report table`)
  const fill = {
    "File and selection": `${scope.fileKey || "<file>"}, page ${scope.page || "<page>"}, ${selection} (oracle scope ${scope.scope}, ${scope.mode || "mode not recorded"})`,
    "What the agent did": `${mode === "run" ? "returned" : "reported"} ${countsLine}; ${ctx.schema.priorityLine} ${prio}; ${obs.rows.length} rows`,
    "What it should have done": result.allMatch ? "nothing different from the oracle" : `match oracle scope ${scope.scope}; see Defects`,
    "Defects": defects.length ? defects.map((d, i) => `${i + 1}. ${d}`).join(" ") : `none against oracle scope ${scope.scope} (oracle-compare exit ${exitCode})`,
  }
  return entryTemplate().flatMap((line) => {
    // A blank line after the heading keeps the pasted entry lint-clean.
    if (line.startsWith("### ")) return [expected.masterVersion ? line.replace(/v<[^>]*>/, `v${expected.masterVersion}`) : line, ""]
    const m = line.match(/^- \*\*(.+?):\*\*/)
    return m && fill[m[1]] !== undefined ? `- **${m[1]}:** ${fill[m[1]]}` : line
  })
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const opts = parseArgs(process.argv.slice(2))
  const expected = readJson(opts.expected, "expected file")
  const scope = (expected.scopes || []).find((s) => String(s.scope) === String(opts.scope))
  if (!scope) fail(`no scope ${opts.scope} in ${opts.expected}`)
  // Mode-only header lines are a report matter; a run carries every field, so it compares them all.
  const schema = loadSchema(opts.schema, opts.report ? scope.mode : null)
  const numeric = numericFields(scope.rows || [], schema)

  const exp = fromOracle(scope, schema, numeric)
  const mode = opts.report ? "report" : "run"
  const obs = opts.report
    ? fromReport(readText(opts.report, "report"), schema, numeric, exp.rows.length)
    : fromOracle(readJson(opts.run, "run file"), schema, numeric)
  const result = compare(exp, obs, schema, opts.tolerance)
  const exitCode = result.allMatch ? 0 : 1

  const out = []
  out.push(`oracle-compare: scope ${scope.scope} (${scope.mode || "mode not recorded"}), ${mode} ${opts[mode]}, frame tolerance ${opts.tolerance}`)
  out.push("")
  out.push(...countTable("Counts", result.counts))
  if (schema.linesNotInMode.length) out.push(`  Not printed in ${scope.mode} mode, not compared: ${schema.linesNotInMode.join(", ")}`)
  out.push("")
  out.push(...countTable(`Priority counts, ${schema.priorityLine}`, result.priority))
  out.push("")
  out.push(...listBlock(`Missing from the ${mode}`, result.missing.map((r) => `${r.label} (${r.values.priority ?? "no priority"})`)))
  out.push(...listBlock(`Extra in the ${mode}`, result.extra.map((r) => r.label)))
  out.push(...listBlock("Mismatched", result.mismatched.map((m) => `${m.label}: ${m.diffs.join("; ")}`)))
  if (obs.columnsMissing.length) out.push(`Columns missing from the report table (${obs.columnsMissing.length}): ${obs.columnsMissing.join(", ")}`)
  out.push("")
  const countsOff = [...result.counts, ...result.priority].filter((c) => !c.ok).length
  out.push(`Result: ${result.missing.length} missing, ${result.extra.length} extra, ${result.mismatched.length} mismatched; ` +
    (countsOff ? `${countsOff} counts outside tolerance` : "every count within tolerance") + `; exit ${exitCode}`)
  out.push("")
  out.push("EVAL-LOG entry stub:")
  out.push("")
  out.push(...evalLogStub({ expected, scope, obs, result, mode, exitCode, schema }))
  console.log(out.join("\n"))
  return exitCode
}

try {
  process.exitCode = main()
} catch (e) {
  if (!(e instanceof ParseError)) console.error(e.stack)
  console.error(`oracle-compare: ${e.message}`)
  process.exitCode = 2
}
