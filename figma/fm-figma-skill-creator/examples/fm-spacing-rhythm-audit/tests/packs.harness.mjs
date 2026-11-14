// packs.harness.mjs: tests the enhancement-pack contract (references/enhancement-packs.md) as
// scripts/lib/enhancements.mjs and scripts/enhancement-packs.mjs implement it, on this example's
// master and on copies of it with test text inserted.
//
// Usage, from figma/fm-figma-skill-creator:
//   node examples/fm-spacing-rhythm-audit/tests/packs.harness.mjs
//
// Variants and command outputs are written to a folder under the operating system's temporary
// folder and removed at the end. The master and the committed packs are only read. It exports
// nothing and exits 1 when any case fails.

import { readFileSync, writeFileSync, mkdtempSync, mkdirSync, copyFileSync, rmSync, readdirSync } from "node:fs"
import { spawnSync } from "node:child_process"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize } from "../../../scripts/lib/skill-md.mjs"
import { loadPack, findUnits, stripUnits } from "../../../scripts/lib/enhancements.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const creator = join(here, "..", "..", "..")
const MASTER = join(here, "..", "SKILL.md")
const PACKS = join(creator, "enhancements")
const CLI = join(creator, "scripts", "enhancement-packs.mjs")
const VALIDATOR = join(creator, "scripts", "validate-figma-skill.mjs")
const BUILDER = join(creator, "scripts", "build-skill-editions.mjs")
const tmp = mkdtempSync(join(tmpdir(), "packs-harness-"))

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const masterText = normalize(readFileSync(MASTER, "utf8"))
const masterLines = masterText.split("\n")
const pack = (name) => loadPack(join(PACKS, name))
const TOKENS = pack("token-conformance")
const REVERT = pack("revert")

/** Turn [condition, message] pairs into the list of failed messages. */
const check = (pairs) => pairs.filter(([ok]) => !ok).map(([, msg]) => msg)

/** Count units by kind, as "kind n" pairs in a stable order. */
const byKind = (units) => {
  const m = new Map()
  for (const u of units) m.set(u.kind, (m.get(u.kind) || 0) + 1)
  return Object.fromEntries([...m].sort())
}

/** Two kind-count maps hold the same counts, whatever their key order. */
const sameCounts = (a, b) => JSON.stringify(Object.entries(a).sort()) === JSON.stringify(Object.entries(b).sort())

/** Strip packs in order from lines, re-finding units each time; returns { lines, units: [per pack] }. */
function stripAll(lines, packs) {
  const all = []
  for (const p of packs) {
    const units = findUnits(lines, p)
    all.push({ pack: p, before: lines, units })
    lines = stripUnits(lines, units)
  }
  return { lines, steps: all }
}

/**
 * Every changed line belongs to a listed unit: walk the input and the output together. A line inside
 * a removed unit is skipped; a line holding an in-line unit (sentence, rewrite, description sentence,
 * tag) must have changed; a blank line may disappear (blank runs collapse); any other line must be
 * carried over unchanged and in order. Returns the problems found.
 */
function onlyUnitsChanged(input, output, units) {
  const removed = new Set(), edited = new Set()
  for (const u of units) {
    if (["code-region", "fence", "block", "heading-block", "template-line"].includes(u.kind)) {
      for (let k = u.start; k <= u.end; k++) removed.add(k)
      if (u.kind === "fence" && u.start > 0 && input[u.start - 1].trim() === "") removed.add(u.start - 1)
    } else edited.add(u.start)
  }
  const problems = []
  let j = 0
  for (let i = 0; i < input.length; i++) {
    if (removed.has(i)) continue
    if (edited.has(i)) {
      if (output[j] === input[i]) problems.push(`line ${i + 1} holds a unit but did not change`)
      j++
      continue
    }
    if (input[i].trim() === "") { if (j < output.length && output[j].trim() === "") j++; continue }
    if (output[j] !== input[i]) { problems.push(`line ${i + 1} changed outside any unit: ${JSON.stringify(input[i]).slice(0, 80)} -> ${JSON.stringify(output[j] ?? "<end>").slice(0, 80)}`); break }
    j++
  }
  while (j < output.length && output[j].trim() === "") j++
  if (!problems.length && j !== output.length) problems.push(`output has ${output.length - j} extra lines at the end`)
  return problems
}

/** Write lines as a master file in the temporary folder and return its path. */
function writeMaster(name, lines) {
  const path = join(tmp, name)
  writeFileSync(path, lines.join("\n") + "\n")
  return path
}

/** The master validates at 0 errors, 0 warnings, and its helpers parse (builder dry run). */
function validates(name, lines, helpers) {
  const path = writeMaster(name, lines)
  const v = spawnSync(process.execPath, [VALIDATOR, path, "--edition", "master"], { encoding: "utf8" })
  const b = spawnSync(process.execPath, [BUILDER, path, "--out", join(tmp, name + "-dist"), "--dry-run"], { encoding: "utf8" })
  return check([
    [v.status === 0 && /0 errors, 0 warnings/.test(v.stdout), `validator: ${v.stdout.trim().split("\n").pop()}`],
    [b.status === 0 && b.stdout.includes(`helpers: ${helpers} scripts`), `builder: ${(b.stdout + b.stderr).match(/helpers:.*|build error.*/)?.[0]}`],
  ])
}

/** The master with `text` inserted as its own paragraph just before "## Output contract". */
function masterWith(text) {
  const anchor = "\n## Output contract\n"
  if (!masterText.includes(anchor)) throw new Error("the master has no Output contract heading")
  return masterText.replace(anchor, `\n${text}\n${anchor}`).replace(/\n$/, "").split("\n")
}

/** Does findUnits throw, with a message matching re? */
function throwsWith(lines, p, re) {
  try { findUnits(lines, p); return [`did not throw (expected ${re})`] } catch (e) { return re.test(e.message) ? [] : [`threw "${e.message}", expected ${re}`] }
}

/** A small master around helper and template fences, for the contract's error cases. */
const tiny = (...body) => ["---", "name: fm-x", "description: Does a thing.", "metadata:", '  tags: "a, b"', "---", "", "# T", "", "## Helper scripts", "", ...body]
const helper = (...code) => ["```javascript", "// helper: h", ...code, "```"]
const P = { name: "p", phrase: "Token mode:", codeRegion: "p", templateLines: [], lineRewrites: [], proseSentences: [], descriptionSentences: [], tags: [] }

/** Run the CLI; returns { status, out }. */
const cli = (...args) => { const r = spawnSync(process.execPath, [CLI, ...args], { encoding: "utf8" }); return { status: r.status, out: r.stdout + r.stderr } }

// The reviewer's ordinary sentences: none carries a tag, so each must survive a strip untouched.
const ORDINARY = [
  "Revert the last change by hand if the script stops.",
  "- Revert the last change by hand if the script stops.",
  "Revert history in Figma is kept per file; Cmd+Z undoes one snap at a time.",
  "Snaps are applied one row at a time. Use Cmd+Z, e.g. Revert is not needed for a single row.",
  "- Token mode is chosen once per run and never changes mid-run.",
]

// ---------------------------------------------------------------------------
// Cases: each returns the failed messages
// ---------------------------------------------------------------------------

const cases = {
  // The audit master's units.
  "token-conformance: 39 units by kind": () => {
    const k = byKind(findUnits(masterLines, TOKENS))
    const want = { "code-region": 6, block: 8, "description-sentence": 1, "heading-block": 1, "line-rewrite": 1, "prose-sentence": 1, sentence: 9, tag: 2, "template-line": 10 }
    return check([[sameCounts(k, want), `got ${JSON.stringify(k)}`]])
  },
  "revert: 8 units by kind": () => {
    const k = byKind(findUnits(masterLines, REVERT))
    const want = { block: 3, fence: 1, "prose-sentence": 1, sentence: 2, "template-line": 1 }
    return check([[sameCounts(k, want), `got ${JSON.stringify(k)}`]])
  },

  // Strip on the real master.
  "strip token-conformance: only units change, validates, 4 helpers": () => {
    const s = stripAll(masterLines, [TOKENS])
    return [...onlyUnitsChanged(masterLines, s.lines, s.steps[0].units), ...validates("no-tokens.md", s.lines, 4),
      ...check([[!s.lines.some((l) => l.includes("Token mode")), "a Token mode mention survived"]])]
  },
  "strip revert: only units change, validates, 3 helpers": () => {
    const s = stripAll(masterLines, [REVERT])
    return [...onlyUnitsChanged(masterLines, s.lines, s.steps[0].units), ...validates("no-revert.md", s.lines, 3),
      ...check([[!s.lines.some((l) => l.includes("Revert")), "a Revert mention survived"]])]
  },
  "strip both, either order: same result, only units change, validates": () => {
    const a = stripAll(masterLines, [TOKENS, REVERT]), b = stripAll(masterLines, [REVERT, TOKENS])
    return [...check([[a.lines.join("\n") === b.lines.join("\n"), "the two orders differ"]]),
      ...onlyUnitsChanged(a.steps[1].before, a.lines, a.steps[1].units), ...onlyUnitsChanged(masterLines, a.steps[1].before, a.steps[0].units),
      ...validates("no-packs.md", a.lines, 3)]
  },
  "the strip command writes what the library strips": () => {
    const out = join(tmp, "cli-no-tokens.md")
    const r = cli("strip", MASTER, "--pack", "token-conformance", "--out", out)
    return check([[r.status === 0, `exit ${r.status}`], [readFileSync(out, "utf8") === stripAll(masterLines, [TOKENS]).lines.join("\n") + "\n", "CLI output differs from stripUnits"]])
  },

  // Extract: the committed enhancement.md files are current, and a second run changes nothing.
  "extract reproduces the committed files and is idempotent": () => {
    const root = join(tmp, "extract-root")
    mkdirSync(join(root, "examples", "fm-spacing-rhythm-audit"), { recursive: true })
    copyFileSync(MASTER, join(root, "examples", "fm-spacing-rhythm-audit", "SKILL.md"))
    for (const n of readdirSync(PACKS)) {
      mkdirSync(join(root, "enhancements", n), { recursive: true })
      copyFileSync(join(PACKS, n, "pack.json"), join(root, "enhancements", n, "pack.json"))
    }
    const run = () => cli("extract", join(root, "examples", "fm-spacing-rhythm-audit", "SKILL.md"), "--enhancements", join(root, "enhancements"))
    const r1 = run()
    const first = readdirSync(PACKS).map((n) => readFileSync(join(root, "enhancements", n, "enhancement.md"), "utf8"))
    const r2 = run()
    const second = readdirSync(PACKS).map((n) => readFileSync(join(root, "enhancements", n, "enhancement.md"), "utf8"))
    const committed = readdirSync(PACKS).map((n) => readFileSync(join(PACKS, n, "enhancement.md"), "utf8"))
    return check([[r1.status === 0 && r2.status === 0, `exit ${r1.status}, ${r2.status}`], [first.join() === second.join(), "a second extract changed the files"],
      [first.join() === committed.join(), "the committed enhancement.md files are not what extract writes; run extract"]])
  },

  // The contract's error cases.
  "nested regions are an error": () => throwsWith(tiny(...helper("// enhancement: p begin", "// enhancement: q begin", "x", "// enhancement: q end", "// enhancement: p end", "return 1")), P, /never nest/),
  "interleaved regions are an error": () => throwsWith(tiny(...helper("// enhancement: p begin", "x", "// enhancement: q end", "return 1")), P, /closed by an end/),
  "a region spanning two fences is an error": () => throwsWith(tiny(...helper("// enhancement: p begin", "x"), "", ...helper("y", "// enhancement: p end")), P, /different fence/),
  "an end without a begin is an error": () => throwsWith(tiny(...helper("x", "// enhancement: p end")), P, /has no begin/),
  "a region that never ends is an error": () => throwsWith(tiny(...helper("// enhancement: p begin", "x")), P, /never ends/),
  "an ambiguous template line is an error": () => throwsWith(tiny("```markdown", "- Bound: <n>", "- Bound: <n>", "```"), { ...P, templateLines: ["- Bound: <n>"] }, /exactly one/),
  "an ambiguous line rewrite is an error": () => throwsWith(tiny(...helper("let M = 1;", "let M = 1;")), { ...P, lineRewrites: [{ from: "let M = 1;", to: "let M = 2;" }] }, /matches 2 lines/),
  "a missing declared prose sentence is a warning that names it": () => {
    const warns = []
    let units = null
    try { units = findUnits(tiny("Some prose."), { ...P, proseSentences: ["Token mode adds lines."] }, { warn: (m) => warns.push(m) }) } catch (e) { return [`threw: ${e.message}`] }
    return check([[units.length === 0, `${units.length} units`], [warns.length === 1 && warns[0].includes("Token mode adds lines."), `warnings: ${JSON.stringify(warns)}`]])
  },
  "an ambiguous declared prose sentence is an error": () => throwsWith(tiny("Token mode adds lines. Token mode adds lines."), { ...P, proseSentences: ["Token mode adds lines."] }, /prose sentence.*2 times.*line 12/),
  "a declared prose sentence overlapping a phrase-tagged unit is an error": () =>
    throwsWith(tiny("Intro. Token mode: adds lines here."), { ...P, proseSentences: ["Token mode: adds lines here."] }, /line 12: declared prose sentence overlaps a unit/),
  "an ambiguous declared description sentence is an error": () =>
    throwsWith(["---", "name: fm-x", "description: Does a thing. Does a thing. Use whenever asked.", "---", "", "# T"], { ...P, descriptionSentences: ["Does a thing."] }, /description sentence occurs twice on line 3/),
  "a missing template line, rewrite, description sentence, or tag is a warning": () => {
    const warns = []
    findUnits(tiny(), { ...P, templateLines: ["- gone"], lineRewrites: [{ from: "zz", to: "y" }], descriptionSentences: ["Nope."], tags: ["c"] }, { warn: (m) => warns.push(m) })
    return check([[warns.length === 4, `${warns.length} warnings`]])
  },
  "a phrase inside a table row is an error": () => throwsWith(masterWith("| Mode | Token mode: binds | Rhythm mode: sets |"), TOKENS, /line \d+: .*table row/),

  // A master the pack is absent from passes through strip: exit 0, unchanged, with warnings.
  "stripping a pack a second time exits 0, changes nothing, and warns": () => {
    const problems = []
    for (const name of ["token-conformance", "revert"]) {
      const once = join(tmp, `once-${name}.md`), twice = join(tmp, `twice-${name}.md`)
      const r1 = cli("strip", MASTER, "--pack", name, "--out", once)
      const r2 = cli("strip", once, "--pack", name, "--out", twice)
      problems.push(...check([[r1.status === 0, `${name}: first strip exit ${r1.status}`], [r2.status === 0, `${name}: second strip exit ${r2.status}: ${r2.out.trim().split("\n").pop()}`],
        [r2.status !== 0 || readFileSync(twice, "utf8") === readFileSync(once, "utf8"), `${name}: second strip changed the file`],
        [/warning: .*not found/.test(r2.out), `${name}: second strip printed no warning`]]))
    }
    return problems
  },
  "stripping each pack from a master with no pack tags leaves it byte-identical": () => {
    const src = join(creator, "templates", "type-standards-qa-audit.md")
    const copy = join(tmp, "untagged.md")
    copyFileSync(src, copy)
    const problems = []
    for (const name of ["token-conformance", "revert"]) {
      const out = join(tmp, `untagged-no-${name}.md`)
      const r = cli("strip", copy, "--pack", name, "--out", out)
      problems.push(...check([[r.status === 0, `${name}: exit ${r.status}: ${r.out.trim().split("\n").pop()}`],
        [r.status !== 0 || readFileSync(out).equals(readFileSync(src)), `${name}: output differs from the template`]]))
    }
    return problems
  },

  // Finding 1: ordinary sentences that merely start with the phrase's words are not units.
  "ordinary sentences survive a strip of each pack untouched": () => {
    const lines = masterWith(ORDINARY.join("\n\n"))
    const problems = []
    for (const p of [TOKENS, REVERT]) {
      const out = stripAll(lines, [p]).lines
      for (const s of ORDINARY) if (!out.includes(s)) problems.push(`${p.name} strip changed: ${s}`)
    }
    return problems
  },
  // Finding 2: a sentence unit ends at an unmatched closing parenthesis.
  "a phrase in parentheses leaves the host sentence whole": () => {
    const out = stripAll(masterWith("Bind the value (Token mode: only unbound rows) and report it. Then continue."), [TOKENS]).lines
    return check([[out.includes("Bind the value () and report it. Then continue."), `got ${JSON.stringify(out.find((l) => l.startsWith("Bind the value")))}`]])
  },
  // Finding 3: a block is its first line plus the continuation lines the contract defines.
  "a line at the same indent after a block stays": () => {
    const out = stripAll(masterWith("Token mode: tokens are matched per mode.\nThis core sentence follows on the next line and must stay."), [TOKENS]).lines
    return check([[out.includes("This core sentence follows on the next line and must stay."), "the same-indent line was removed"],
      [!out.includes("Token mode: tokens are matched per mode."), "the tagged line survived"]])
  },
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
