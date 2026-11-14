// compare.harness.mjs: runs scripts/oracle-compare.mjs against the committed report fixtures and
// in-memory variants of them, and checks each exit code and each missing, extra, and mismatched count.
//
// Usage, from figma/fm-figma-skill-creator:
//   node examples/fm-spacing-rhythm-audit/tests/compare.harness.mjs
//
// Variants are written to a folder under the operating system's temporary folder and removed at the
// end: short rows, empty cells, numeric cells that are not a whole number, near-equal numbers, an
// oracle-shaped run built from expected.json, and copies of the script with one normalisation
// disabled (each must stop the clean report comparing clean). It exports nothing and exits 1 when
// any case fails.

import { readFileSync, writeFileSync, mkdtempSync, mkdirSync, copyFileSync, rmSync } from "node:fs"
import { spawnSync } from "node:child_process"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const creator = join(here, "..", "..", "..")
const SCRIPT = join(creator, "scripts", "oracle-compare.mjs")
const EXPECTED = join(here, "expected.json")
const SCHEMA = join(here, "schema.spacing.json")
const fixture = (name) => join(here, "fixtures", name)
const tmp = mkdtempSync(join(tmpdir(), "oracle-compare-harness-"))

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Run the compare and read its exit code and Result line; `expected` and `schema` replace the committed files. */
function compare(args, script = SCRIPT, { expected = EXPECTED, schema = SCHEMA } = {}) {
  const r = spawnSync(process.execPath, [script, "--expected", expected, "--schema", schema, ...args], { cwd: creator, encoding: "utf8" })
  const out = r.stdout + r.stderr
  const m = out.match(/Result: (\d+) missing, (\d+) extra, (\d+) mismatched/)
  return { exit: r.status, out, stderr: r.stderr, missing: m ? +m[1] : null, extra: m ? +m[2] : null, mismatched: m ? +m[3] : null }
}

/** A copy of the committed schema with `edit` applied, written to the temporary folder. */
function schemaVariant(name, edit) {
  return variant(name, JSON.stringify(edit(JSON.parse(readFileSync(SCHEMA, "utf8")))))
}

/** A copy of expected.json with `edit` applied, written to the temporary folder. */
function expectedVariant(name, edit) {
  return variant(name, JSON.stringify(edit(JSON.parse(readFileSync(EXPECTED, "utf8")))))
}

/** An input the tool cannot use stops it with one message and exit 2, never a stack trace. */
const oneMessage = (r, re) => check([[r.exit === 2, `exit 2, got ${r.exit}`], [re.test(r.stderr), `message ${re}, got ${JSON.stringify(r.stderr.trim())}`],
  [!/^\s+at /m.test(r.stderr), "a stack trace was printed"]])

/** Write a variant to the temporary folder and return its path. */
function variant(name, text) {
  const path = join(tmp, name)
  writeFileSync(path, text)
  return path
}

/** Turn [condition, message] pairs into the list of failed messages. */
const check = (pairs) => pairs.filter(([ok]) => !ok).map(([, msg]) => msg)

/** The usual assertions: exit code, the three row counts, and text the output must contain. */
function expectResult(r, { exit, missing, extra, mismatched, contains = [] }) {
  return check([
    [r.exit === exit, `exit ${exit}, got ${r.exit}`],
    ...(missing === undefined ? [] : [[r.missing === missing, `${missing} missing, got ${r.missing}`]]),
    ...(extra === undefined ? [] : [[r.extra === extra, `${extra} extra, got ${r.extra}`]]),
    ...(mismatched === undefined ? [] : [[r.mismatched === mismatched, `${mismatched} mismatched, got ${r.mismatched}`]]),
    ...contains.map((t) => [r.out.includes(t), `output contains "${t}"`]),
  ])
}

const SCOPE2 = readFileSync(fixture("report-scope2.md"), "utf8")
const HERO_ROW = /^\| 3 \| P1 \|.*$/m
const heroRow = SCOPE2.match(HERO_ROW)[0]
if (!heroRow.includes("| Gap | 14 | 16 | bind Space/400 | +2 |")) throw new Error("report-scope2.md row 3 is not the Hero gap row")
/** report-scope2.md with row 3 (Hero · Gap · 14) replaced. */
const withHeroRow = (row) => SCOPE2.replace(HERO_ROW, row)

/** A copy of the script with one source fragment replaced; throws when the fragment is gone. */
function mutant(name, from, to) {
  const src = readFileSync(SCRIPT, "utf8")
  if (!src.includes(from)) throw new Error(`mutation anchor not found in oracle-compare.mjs: ${from}`)
  const dir = join(tmp, "mutant-" + name, "scripts")
  mkdirSync(join(dir, "lib"), { recursive: true })
  copyFileSync(join(creator, "scripts", "lib", "skill-md.mjs"), join(dir, "lib", "skill-md.mjs"))
  writeFileSync(join(dir, "oracle-compare.mjs"), src.replace(from, to))
  return join(dir, "oracle-compare.mjs")
}

/** An oracle-shaped run (counts as top-level fields, as use_figma returns them) built from one scope. */
function runOf(scopeNumber, edit = (x) => x) {
  const scope = JSON.parse(readFileSync(EXPECTED, "utf8")).scopes.find((s) => s.scope === scopeNumber)
  const run = { ...scope, ...scope.counts }
  delete run.counts
  return variant(`run-scope${scopeNumber}-${Math.random().toString(36).slice(2)}.json`, JSON.stringify(edit(run)))
}

// The schema's token-only header lines (modes ["tokens"]) and their fields, in schema order.
const TOKEN_ONLY = Object.entries(JSON.parse(readFileSync(SCHEMA, "utf8")).headerLines)
  .filter(([, v]) => v && typeof v === "object" && Array.isArray(v.modes) && !v.modes.includes("rhythm"))
const TOKEN_ONLY_LINES = TOKEN_ONLY.map(([label]) => label)
if (TOKEN_ONLY_LINES.length !== 3) throw new Error(`expected three token-only header lines in the schema, found ${TOKEN_ONLY_LINES.length}`)
/** A run edit that drops the token-only count fields, as a helper without the token-conformance pack returns. */
const withoutTokenCounts = (r) => { for (const [, v] of TOKEN_ONLY) delete r[v.field.split(".").pop()]; return r }

// ---------------------------------------------------------------------------
// Cases: each returns the failed messages
// ---------------------------------------------------------------------------

const cases = {
  // The committed fixtures, as the brief and the follow-up state them.
  "report-scope2.md compares clean": () =>
    expectResult(compare(["--scope", "2", "--report", fixture("report-scope2.md")]), { exit: 0, missing: 0, extra: 0, mismatched: 0 }),
  "report-scope2-altered.md is flagged": () =>
    expectResult(compare(["--scope", "2", "--report", fixture("report-scope2-altered.md")]), {
      exit: 1, missing: 1, extra: 0, mismatched: 1,
      contains: ["Fractional \u00b7 Padding right \u00b7 15.5 (P3)", "Hero \u00b7 Gap \u00b7 14: nearest 16 vs 12; fix bind Space/400 vs bind Space/300"],
    }),
  "report-scope1.md (rhythm) compares clean": () =>
    expectResult(compare(["--scope", "1", "--report", fixture("report-scope1.md")]), {
      exit: 0, missing: 0, extra: 0, mismatched: 0, contains: ["Not printed in rhythm mode, not compared"],
    }),
  "report-scope1-altered.md (rhythm) is flagged": () =>
    expectResult(compare(["--scope", "1", "--report", fixture("report-scope1-altered.md")]), {
      exit: 1, missing: 1, extra: 0, mismatched: 1,
      contains: ["Bound padding \u00b7 Padding left \u00b7 18 (P2)", "Card \u00b7 Padding right \u00b7 19: nearest 20 vs 16; fix set 20 vs set 16", "every count within tolerance"],
    }),
  "report-scope2-alt-headers.md compares clean": () =>
    expectResult(compare(["--scope", "2", "--report", fixture("report-scope2-alt-headers.md")]), { exit: 0, missing: 0, extra: 0, mismatched: 0 }),
  "report-scope2-unknown-header.md exits 2 and lists the header rows": () =>
    expectResult(compare(["--scope", "2", "--report", fixture("report-scope2-unknown-header.md")]), {
      exit: 2, contains: ["Header rows found in the report:", "| # | Priority | Node | Property |"],
    }),
  // The Round 4 in-app capture (2026-11-13), compared with the committed schema unchanged (no alias for
  // "Ranked values"): the missing priority line is a difference, and the rows and the other counts are
  // still compared, so the shortened layer paths of rows 1 to 5 show as 5 missing and 5 extra.
  "round4-sections-audit.md (in-app capture) exits 1 and still lists its row differences": () =>
    expectResult(compare(["--scope", "3", "--report", fixture("round4-sections-audit.md"), "--frame-tolerance", "4"]), {
      exit: 1, missing: 5, extra: 5, mismatched: 0,
      contains: ['No "Off-grid values:" line in the report', "AI Sidebar / Block / Block / Block (page: AI Chat) (main component) · Gap · 10 (P1)",
        "Extra in the report (5)\n  Hero (Slot) / Desktop / Slot · Gap · 10", '5 counts outside tolerance; no "Off-grid values:" line; exit 1'],
    }),
  // The Round 5 in-app capture (2026-11-14, audit 2.3), compared with the committed schema unchanged:
  // every row, count and priority count matches oracle scope 3.
  "round5-sections-audit.md (in-app capture, audit 2.3) compares clean": () =>
    expectResult(compare(["--scope", "3", "--report", fixture("round5-sections-audit.md"), "--frame-tolerance", "4"]), {
      exit: 0, missing: 0, extra: 0, mismatched: 0,
      contains: ["Result: 0 missing, 0 extra, 0 mismatched; every count within tolerance; exit 0"],
    }),
  // The priority line is optional in a schema: an inventory-shaped schema with none compares a perfect report clean.
  "a schema with no priority line compares a report with no priority line clean": () => {
    const schema = schemaVariant("schema-no-priority.json", (s) => { delete s.priorityLine; return s })
    const report = variant("no-priority-line.md", SCOPE2.replace(/^- \*\*Off-grid values:\*\*.*\n/m, ""))
    const r = compare(["--scope", "2", "--report", report], SCRIPT, { schema })
    return [...expectResult(r, { exit: 0, missing: 0, extra: 0, mismatched: 0, contains: ["Priority counts: not compared (the schema declares no priority line)", "every count within tolerance; exit 0"] }),
      ...check([[SCOPE2.includes("**Off-grid values:**") && !readFileSync(report, "utf8").includes("Off-grid values"), "the variant still holds the Off-grid values line"]])]
  },
  "a schema that declares the priority line flags a report without it and still compares the rows": () => {
    const report = variant("no-priority-line-declared.md", SCOPE2.replace(/^- \*\*Off-grid values:\*\*.*\n/m, ""))
    return expectResult(compare(["--scope", "2", "--report", report]), {
      exit: 1, missing: 0, extra: 0, mismatched: 0, contains: ['No "Off-grid values:" line in the report', '4 counts outside tolerance; no "Off-grid values:" line; exit 1'],
    })
  },
  "a declared priority line missing from a report fails even when the scope has no priority counts": () => {
    const expected = expectedVariant("expected-no-priority-report.json", (e) => { for (const s of e.scopes) delete s.counts.byPriority; return e })
    const report = variant("no-priority-line-no-counts.md", SCOPE2.replace(/^- \*\*Off-grid values:\*\*.*\n/m, ""))
    const r = compare(["--scope", "2", "--report", report], SCRIPT, { expected })
    return expectResult(r, { exit: 1, missing: 0, extra: 0, mismatched: 0, contains: ['No "Off-grid values:" line in the report',
      'Result: 0 missing, 0 extra, 0 mismatched; every count within tolerance; no "Off-grid values:" line; exit 1'] })
  },
  "priority counts absent on both sides are equal": () => {
    const expected = expectedVariant("expected-no-priority.json", (e) => { for (const s of e.scopes) delete s.counts.byPriority; return e })
    const run = variant("run-no-priority.json", JSON.stringify((() => { const s = JSON.parse(readFileSync(expected, "utf8")).scopes.find((x) => x.scope === 3); const r = { ...s, ...s.counts }; delete r.counts; return r })()))
    return expectResult(compare(["--scope", "3", "--run", run], SCRIPT, { expected }), { exit: 0, missing: 0, extra: 0, mismatched: 0, contains: ["every count within tolerance; exit 0"] })
  },

  // --frame-tolerance applies to frames measured and bound values only, and only up to its value.
  "frames measured off by 2 passes at tolerance 2": () =>
    expectResult(compare(["--scope", "2", "--report", variant("frames-13.md", SCOPE2.replace("**Frames measured:** 11 ·", "**Frames measured:** 13 ·")), "--frame-tolerance", "2"]), {
      exit: 0, missing: 0, extra: 0, mismatched: 0, contains: ["every count within tolerance"],
    }),
  "frames measured off by 2 fails at tolerance 1": () =>
    expectResult(compare(["--scope", "2", "--report", variant("frames-13b.md", SCOPE2.replace("**Frames measured:** 11 ·", "**Frames measured:** 13 ·")), "--frame-tolerance", "1"]), {
      exit: 1, missing: 0, extra: 0, mismatched: 0, contains: ["1 counts outside tolerance"],
    }),
  "hidden skipped off by 1 fails even at tolerance 5": () =>
    expectResult(compare(["--scope", "2", "--report", variant("hidden-2.md", SCOPE2.replace("Hidden skipped: 1 ·", "Hidden skipped: 2 ·")), "--frame-tolerance", "5"]), {
      exit: 1, missing: 0, extra: 0, mismatched: 0, contains: ["1 counts outside tolerance"],
    }),

  // Inputs the compare cannot use: a folder, or a JSON file that holds no object.
  "a folder or a JSON null as an input stops with one message and exit 2": () => {
    const nul = variant("null.json", "null")
    return [
      ...oneMessage(compare(["--scope", "2", "--report", tmp]), /report is not a file/),
      ...oneMessage(compare(["--scope", "2", "--report", fixture("report-scope2.md")], SCRIPT, { expected: tmp }), /expected file is not a file/),
      ...oneMessage(compare(["--scope", "2", "--report", fixture("report-scope2.md")], SCRIPT, { expected: nul }), /expected file does not hold a JSON object/),
      ...oneMessage(compare(["--scope", "2", "--report", fixture("report-scope2.md")], SCRIPT, { schema: nul }), /schema does not hold a JSON object/),
      ...oneMessage(compare(["--scope", "3", "--run", nul]), /run file does not hold a JSON object/),
    ]
  },
  "--run on an oracle-shaped scope 3 compares clean": () =>
    expectResult(compare(["--scope", "3", "--run", runOf(3)]), { exit: 0, missing: 0, extra: 0, mismatched: 0 }),
  "--run with one changed fix is flagged": () =>
    expectResult(compare(["--scope", "3", "--run", runOf(3, (r) => { r.rows[5].fix.name = "Space/600"; return r })]), {
      exit: 1, missing: 0, extra: 0, mismatched: 1, contains: ["fix bind Space/400 vs bind Space/600"],
    }),

  // Token-only counts in --run: a rhythm-mode run that does not carry them (a helper with the
  // token-conformance pack stripped) sets them aside; any other absence, or a present wrong value, differs.
  "--run in rhythm mode without the token-only counts compares clean": () =>
    expectResult(compare(["--scope", "5", "--run", runOf(5, withoutTokenCounts)]), {
      exit: 0, missing: 0, extra: 0, mismatched: 0,
      contains: [`not compared: ${TOKEN_ONLY_LINES.join(", ")}`, "every count within tolerance"],
    }),
  "--run in tokens mode without the token-only counts is flagged": () =>
    expectResult(compare(["--scope", "2", "--run", runOf(2, withoutTokenCounts)]), {
      exit: 1, missing: 0, extra: 0, mismatched: 0, contains: ["3 counts outside tolerance"],
    }),
  "--run in rhythm mode with a wrong token-only count is flagged": () =>
    expectResult(compare(["--scope", "5", "--run", runOf(5, (r) => { r = withoutTokenCounts(r); r.aliasMatched = 2; return r })]), {
      exit: 1, missing: 0, extra: 0, mismatched: 0, contains: ["1 counts outside tolerance", `not compared: ${TOKEN_ONLY_LINES.filter((l) => l !== "Matches an alias").join(", ")}`],
    }),
  // The shape the token-stripped helper really returns: no `mode` and no token-only counts, on a rhythm scope.
  "--run with no mode and no token-only counts on a rhythm scope compares clean": () => {
    const r = compare(["--scope", "5", "--run", runOf(5, (x) => { x = withoutTokenCounts(x); delete x.mode; return x })])
    return [...expectResult(r, { exit: 0, missing: 0, extra: 0, mismatched: 0, contains: [`not compared: ${TOKEN_ONLY_LINES.join(", ")}`, "every count within tolerance; exit 0"] }),
      ...check([[!r.out.includes("Mode (expected, observed)"), "a Mode line was printed for a run with no mode"]])]
  },
  // The set-aside is judged against the scope's mode only; a run's own `mode` never widens it.
  "--run claiming rhythm on a tokens scope, without the token-only counts, is flagged": () =>
    expectResult(compare(["--scope", "2", "--run", runOf(2, (r) => { r = withoutTokenCounts(r); r.mode = "rhythm"; return r })]), {
      exit: 1, missing: 0, extra: 0, mismatched: 0,
      contains: ["3 counts outside tolerance; mode differs (expected tokens, observed rhythm); exit 1", "Mode (expected, observed): tokens, rhythm  <-- differs"],
    }),
  "--run whose mode differs from the scope's is flagged even with every count present": () =>
    expectResult(compare(["--scope", "3", "--run", runOf(3, (r) => { r.mode = "rhythm"; return r })]), {
      exit: 1, missing: 0, extra: 0, mismatched: 0,
      contains: ["Mode (expected, observed): tokens, rhythm  <-- differs", "every count within tolerance; mode differs (expected tokens, observed rhythm); exit 1"],
    }),

  // Rows and cells.
  "a row that ends early is a mismatch": () =>
    expectResult(compare(["--scope", "2", "--report", variant("short-row.md", withHeroRow(heroRow.replace(/ bind Space\/400 \|.*$/, "")))]), {
      exit: 1, missing: 0, extra: 0, mismatched: 1, contains: ["Hero \u00b7 Gap \u00b7 14: fix bind Space/400 vs absent; delta 2 vs absent"],
    }),
  "an empty Fix cell is a mismatch": () =>
    expectResult(compare(["--scope", "2", "--report", variant("empty-fix.md", withHeroRow(heroRow.replace("| bind Space/400 |", "|  |")))]), {
      exit: 1, missing: 0, extra: 0, mismatched: 1, contains: ["Hero \u00b7 Gap \u00b7 14: fix bind Space/400 vs none"],
    }),
  "an empty Nearest cell is a mismatch": () =>
    expectResult(compare(["--scope", "2", "--report", variant("empty-nearest.md", withHeroRow(heroRow.replace("| 14 | 16 |", "| 14 |  |")))]), {
      exit: 1, missing: 0, extra: 0, mismatched: 1, contains: ["Hero \u00b7 Gap \u00b7 14: nearest 16 vs none"],
    }),

  // Numbers: the whole cell must be a number, compared exactly.
  "a Nearest cell of \"16 or 12\" is a mismatch": () =>
    expectResult(compare(["--scope", "2", "--report", variant("nearest-or.md", withHeroRow(heroRow.replace("| 14 | 16 |", "| 14 | 16 or 12 |")))]), {
      exit: 1, mismatched: 1, contains: ["Hero \u00b7 Gap \u00b7 14: nearest 16 vs 16 or 12"],
    }),
  "a Nearest cell of 16.004 is a mismatch (no epsilon)": () =>
    expectResult(compare(["--scope", "2", "--report", variant("nearest-near.md", withHeroRow(heroRow.replace("| 14 | 16 |", "| 14 | 16.004 |")))]), {
      exit: 1, mismatched: 1, contains: ["Hero \u00b7 Gap \u00b7 14: nearest 16 vs 16.004"],
    }),
  "a Delta cell of +2.004 is a mismatch (no epsilon)": () =>
    expectResult(compare(["--scope", "2", "--report", variant("delta-near.md", withHeroRow(heroRow.replace("| +2 |", "| +2.004 |")))]), {
      exit: 1, mismatched: 1, contains: ["Hero \u00b7 Gap \u00b7 14: delta 2 vs 2.004"],
    }),
  "a Delta cell of \"+2 pt\" is a mismatch": () =>
    expectResult(compare(["--scope", "2", "--report", variant("delta-unit.md", withHeroRow(heroRow.replace("| +2 |", "| +2 pt |")))]), {
      exit: 1, mismatched: 1, contains: ["Hero \u00b7 Gap \u00b7 14: delta 2 vs +2 pt"],
    }),

  // Each normalisation is load-bearing: disabled, the clean report stops comparing clean.
  "en-dash fold disabled: the clean report is flagged": () =>
    expectResult(compare(["--scope", "2", "--report", fixture("report-scope2.md")],
      mutant("en-dash", ".replace(/[\\u2013\\u2014\\u2212]/g, \"-\")", ".replace(/[\\u2014\\u2212]/g, \"-\")")), { exit: 1, mismatched: 2 }),
  "leading ellipsis kept: the clean report is flagged": () =>
    expectResult(compare(["--scope", "2", "--report", fixture("report-scope2.md")],
      mutant("ellipsis", ".replace(/^\\s*(?:\\u2026|\\.\\.\\.)\\s*\\/\\s*/, \"\")", "")), { exit: 1, missing: 1, extra: 1 }),
  "node-link markup kept: the clean report is flagged": () =>
    expectResult(compare(["--scope", "2", "--report", fixture("report-scope2.md")],
      mutant("node-link", ".replace(/<figma-node(?:-group)?-link\\b[^>]*>(.*?)<\\/figma-node(?:-group)?-link>/g, \"$1\")", "")), { exit: 1, missing: 21, extra: 21 }),
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

let failed = 0
try {
  for (const [name, run] of Object.entries(cases)) {
    let problems
    try {
      problems = run()
    } catch (e) {
      problems = ["threw: " + (e && e.message ? e.message : String(e))]
    }
    if (problems.length) failed++
    console.log((problems.length ? "FAIL " : "PASS ") + name + (problems.length ? "\n  - " + problems.join("\n  - ") : ""))
  }
} finally {
  rmSync(tmp, { recursive: true, force: true })
}
const total = Object.keys(cases).length
console.log(`${total} cases, ${failed} failed`)
process.exit(failed ? 1 : 0)
