#!/usr/bin/env node
// check-all.mjs — every validation and build gate for the creator and its examples, in one command.
//
// Usage, from figma/fm-figma-skill-creator (paths resolve from this script's folder, so any cwd works):
//   node scripts/check-all.mjs                        run every check, one line each; exit 1 on the first failure
//   node scripts/check-all.mjs --list                 print the checks in run order without running them
//   node scripts/check-all.mjs --only <group>[,<group>]
//                                                     run only these groups
//
// Groups, in run order:
//   changelog    the five checks on references/figma-changelog.md (Plan 2, Task 0A Step 2)
//   description  the creator's own description, with --description, at 0 errors and 0 warnings
//   masters      the two example masters, --edition master, at 0 errors and 0 warnings
//   templates    the seven skill templates, --allow-placeholders, at 0 errors and exactly the two
//                placeholder warnings (name-format, description-angle)
//   builds       both examples built into their dist/ with --validate, every edition at 0 and 0,
//                and dist/ byte-identical afterwards (a change means the committed dist/ was stale)
//   parse        every helper script a build wrote under dist/claude/<name>/scripts/, parsed with
//                new AsyncFunction(body) as the builder does (node --check rejects top-level await)
//   roundtrips   enhancement-packs roundtrip on the audit master: each pack, and both
//   compare      oracle-compare on fixtures/report-scope2.md against expected.json, scope 2
//   harnesses    the five test harnesses under examples/fm-spacing-rhythm-audit/tests/
//
// Every file is named here. Masters and templates are never found by walking folders; the only
// listings are of the dist/ folders a build writes. Nothing under a history/ folder is ever read: every
// path goes through file(), which refuses one, and the last line reports the count of paths checked.
// The builds write dist/, which must come out byte-identical, and the builder's history snapshot beside
// each master, which this script never reads. Dependency-free: Node 18+ and nothing else (the
// markdownlint run is a separate command).

import { readFileSync, readdirSync, existsSync, statSync } from "node:fs"
import { spawnSync } from "node:child_process"
import { dirname, join, relative } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize, parseFrontmatter, getField } from "./lib/skill-md.mjs"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const args = process.argv.slice(2)
const listOnly = args.includes("--list")
const onlyArg = args.includes("--only") ? args[args.indexOf("--only") + 1] ?? "" : null

// ---------------------------------------------------------------------------
// The files, by name
// ---------------------------------------------------------------------------

const EXAMPLES = ["fm-spacing-rhythm-audit", "fm-figma-capability-probe"]
const TEMPLATES = ["skill-master", "type-critique-review", "type-design-system-conventions", "type-generation-builder",
  "type-research-synthesis", "type-standards-qa-audit", "type-workflow-process"]
const TESTS = "examples/fm-spacing-rhythm-audit/tests"
const HARNESSES = ["collect", "compare", "packs", "build", "checks"]
const ROUNDTRIPS = ["token-conformance", "revert", "token-conformance,revert"]
const GROUPS = ["changelog", "description", "masters", "templates", "builds", "parse", "roundtrips", "compare", "harnesses"]

const seen = new Set()
/** The absolute path of a creator-relative path; refuses any path under a history/ folder. */
function file(rel) {
  if (/(^|[\\/])history([\\/]|$)/.test(rel)) throw new Error(`check-all never reads a history/ folder: ${rel}`)
  seen.add(rel)
  return join(root, rel)
}

/** Run a creator script or harness with node, from the creator folder. */
const node = (...a) => spawnSync(process.execPath, a, { cwd: root, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 })
const lastLine = (text) => text.trim().split("\n").pop() ?? ""
const ok = (detail) => ({ ok: true, detail })
const bad = (detail, more = []) => ({ ok: false, detail, more })

/** Validate with --json; returns { status, errors, warnings, findings }. */
function validate(...a) {
  const r = node(file("scripts/validate-figma-skill.mjs"), ...a, "--json")
  try { return { status: r.status, ...JSON.parse(r.stdout) } } catch { return { status: r.status, errors: -1, warnings: -1, findings: [], raw: r.stdout + r.stderr } }
}
/** "1 error, 2 warnings" for a validator result. */
const counts = (v) => `${v.errors} error${v.errors === 1 ? "" : "s"}, ${v.warnings} warning${v.warnings === 1 ? "" : "s"}`
const findingLines = (v) => v.raw ? [lastLine(v.raw)] : v.findings.map((f) => `${f.severity} ${f.rule}${f.line ? ` L${f.line}` : ""}: ${f.message}`)

// ---------------------------------------------------------------------------
// The checks, in run order
// ---------------------------------------------------------------------------

const checks = []
const add = (group, label, run) => checks.push({ group, label, run })

// changelog: the five checks of Task 0A Step 2, on the dated rows (lines starting "| 20").
const CHANGELOG = "references/figma-changelog.md"
const changelog = () => normalize(readFileSync(file(CHANGELOG), "utf8")).split("\n")
const rows = () => changelog().filter((l) => l.startsWith("| 20"))
add("changelog", "changelog rows: at least 81 dated rows", () => { const n = rows().length; return n >= 81 ? ok(`${n} rows`) : bad(`${n} rows`) })
add("changelog", "changelog cells: six cells in every dated row", () => {
  const off = rows().filter((l) => l.split("|").length !== 8)
  return off.length ? bad(`${off.length} rows`, off.map((l) => l.slice(0, 100))) : ok(`${rows().length} rows`)
})
add("changelog", "changelog basis: documented, observed, or secondary", () => {
  const off = rows().filter((l) => !["documented", "observed", "secondary"].includes((l.split("|")[6] ?? "").trim()))
  return off.length ? bad(`${off.length} rows`, off.map((l) => l.slice(0, 100))) : ok(`${rows().length} rows`)
})
add("changelog", "changelog order: newest first", () => {
  const dates = rows().map((l) => l.slice(2, 12))
  const at = dates.findIndex((d, i) => i > 0 && d > dates[i - 1])
  return at === -1 ? ok(`${dates[0]} to ${dates[dates.length - 1]}`) : bad(`row ${at + 1} (${dates[at]}) is newer than the row above it (${dates[at - 1]})`)
})
add("changelog", "changelog review block: one Last reviewed line", () => {
  const n = changelog().filter((l) => l.startsWith("- Last reviewed: 20")).length
  return n === 1 ? ok(changelog().find((l) => l.startsWith("- Last reviewed: 20")).slice(2)) : bad(`${n} Last reviewed lines`)
})

// description: the creator's own description, checked as text.
add("description", "description SKILL.md (the creator's own, with --description)", () => {
  const fm = parseFrontmatter(normalize(readFileSync(file("SKILL.md"), "utf8")).split("\n"))
  const d = fm.present ? getField(fm.fields, "description") : null
  if (!d || typeof d.value !== "string") return bad("no description in SKILL.md")
  const v = validate("--description", d.value.trim())
  return v.errors === 0 && v.warnings === 0 ? ok("0 errors, 0 warnings") : bad(counts(v), findingLines(v))
})

// masters: the two examples.
for (const ex of EXAMPLES) {
  const rel = `examples/${ex}/SKILL.md`
  add("masters", `master ${rel}`, () => {
    const v = validate(file(rel), "--edition", "master")
    return v.errors === 0 && v.warnings === 0 ? ok("0 errors, 0 warnings") : bad(counts(v), findingLines(v))
  })
}

// templates: exactly the two placeholder warnings.
for (const t of TEMPLATES) {
  const rel = `templates/${t}.md`
  add("templates", `template ${rel}`, () => {
    const v = validate(file(rel), "--edition", "master", "--allow-placeholders")
    const rules = v.findings.map((f) => f.rule).sort().join(",")
    return v.errors === 0 && v.warnings === 2 && rules === "description-angle,name-format" ? ok("0 errors, 2 placeholder warnings") : bad(counts(v), findingLines(v))
  })
}

// builds: into each example's dist/, with --validate; every edition at 0 and 0.
/** Every file under a dist/ folder, as { creator-relative path: bytes }, sorted by path. */
function distBytes(rel) {
  const out = {}
  const walk = (r) => { for (const n of readdirSync(file(r)).sort()) { const p = `${r}/${n}`; if (statSync(file(p)).isDirectory()) walk(p); else out[p] = readFileSync(file(p)) } }
  if (existsSync(file(rel))) walk(rel)
  return out
}
for (const ex of EXAMPLES) {
  const rel = `examples/${ex}/SKILL.md`
  add("builds", `build ${rel} --validate`, () => {
    // A rebuild of a committed dist/ must leave it byte-identical; one that changes a file shows it was stale.
    const dist = `examples/${ex}/dist`
    const before = distBytes(dist)
    const r = node(file("scripts/build-skill-editions.mjs"), file(rel), "--out", file(dist), "--validate")
    const clean = (r.stdout.match(/^OK: .* — 0 errors, 0 warnings/gm) || []).length
    if (r.status !== 0 || clean !== 3) return bad(`exit ${r.status}, ${clean} of 3 editions clean`, (r.stdout + r.stderr).trim().split("\n").filter((l) => /^(ERROR|WARN|FAIL|build error)/.test(l)))
    const after = distBytes(dist)
    // No dist/ before the build is a missing dist/, not a stale one.
    if (!Object.keys(before).length) return bad(`there was no committed dist/ (${dist}); the build wrote one: commit it`)
    const changed = [...new Set([...Object.keys(before), ...Object.keys(after)])].sort().find((p) => !before[p] || !after[p] || !before[p].equals(after[p]))
    return changed ? bad(`the committed dist/ was stale: the build changed ${changed}; commit the rebuilt dist/`) : ok("3 editions at 0 errors, 0 warnings; dist/ byte-identical")
  })
}

// parse: every helper script a build wrote, as the builder parses it.
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
for (const ex of EXAMPLES) {
  const rel = `examples/${ex}/dist/claude/${ex}/scripts`
  add("parse", `parse ${rel}/*.js`, () => {
    const dir = file(rel)
    if (!existsSync(dir)) return bad("no scripts folder; build the example first")
    const scripts = readdirSync(dir).filter((f) => f.endsWith(".js")).sort()
    const broken = []
    for (const s of scripts) { try { new AsyncFunction(readFileSync(file(`${rel}/${s}`), "utf8")) } catch (e) { broken.push(`${s}: ${e.message}`) } }
    return scripts.length && !broken.length ? ok(`${scripts.length} script${scripts.length === 1 ? "" : "s"} parse${scripts.length === 1 ? "s" : ""} (${scripts.join(", ")})`) : bad(scripts.length ? `${broken.length} of ${scripts.length} do not parse` : "no scripts", broken)
  })
}

// roundtrips: strip then expand gives the audit master back byte for byte.
for (const sel of ROUNDTRIPS) {
  add("roundtrips", `roundtrip ${sel} (examples/fm-spacing-rhythm-audit/SKILL.md)`, () => {
    const r = node(file("scripts/enhancement-packs.mjs"), "roundtrip", file("examples/fm-spacing-rhythm-audit/SKILL.md"), "--pack", sel)
    return r.status === 0 && !/expand warning/.test(r.stdout + r.stderr) ? ok(lastLine(r.stdout + r.stderr)) : bad(`exit ${r.status}: ${lastLine(r.stdout + r.stderr)}`)
  })
}

// compare: the injected-markup report compares clean against the oracle.
add("compare", `compare ${TESTS}/fixtures/report-scope2.md (scope 2)`, () => {
  const r = node(file("scripts/oracle-compare.mjs"), "--expected", file(`${TESTS}/expected.json`), "--scope", "2",
    "--schema", file(`${TESTS}/schema.spacing.json`), "--report", file(`${TESTS}/fixtures/report-scope2.md`))
  const result = (r.stdout.match(/^Result: .*$/m) || [lastLine(r.stdout + r.stderr)])[0]
  return r.status === 0 ? ok(result) : bad(`exit ${r.status}: ${result}`)
})

// harnesses: each prints "<n> cases, 0 failed" and exits 0.
for (const h of HARNESSES) {
  const rel = `${TESTS}/${h}.harness.mjs`
  add("harnesses", `harness ${rel}`, () => {
    const r = node(file(rel))
    const out = r.stdout + r.stderr
    return r.status === 0 && / 0 failed$/.test(lastLine(out)) ? ok(lastLine(out)) : bad(`exit ${r.status}: ${lastLine(out)}`, out.split("\n").filter((l) => /^FAIL|^  - /.test(l)))
  })
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

const only = onlyArg === null ? null : onlyArg.split(",").map((g) => g.trim()).filter(Boolean)
const unknown = (only ?? []).filter((g) => !GROUPS.includes(g))
if (onlyArg !== null && (!only.length || unknown.length)) {
  console.error(`--only takes groups from: ${GROUPS.join(", ")}${unknown.length ? ` (unknown: ${unknown.join(", ")})` : ""}`)
  process.exit(2)
}
const run = checks.filter((c) => !only || only.includes(c.group))
const width = Math.max(...run.map((c) => c.label.length))

if (listOnly) {
  for (const c of run) console.log(`${c.group.padEnd(12)} ${c.label}`)
  process.exit(0)
}

for (const c of run) {
  let result
  try { result = c.run() } catch (e) { result = bad(`threw: ${e.message}`) }
  console.log(`${result.ok ? "PASS" : "FAIL"} ${c.label.padEnd(width)}  ${result.detail}`)
  if (!result.ok) {
    for (const m of (result.more ?? []).slice(0, 20)) console.log(`     ${m}`)
    console.log(`check-all: stopped at the first failure (${relative(process.cwd(), root) || "."})`)
    process.exit(1)
  }
}
console.log(`PASS ${"history".padEnd(width)}  no path under a history/ folder was read (${seen.size} paths checked)`)
console.log(`check-all: ${run.length} check${run.length === 1 ? "" : "s"} passed`)
