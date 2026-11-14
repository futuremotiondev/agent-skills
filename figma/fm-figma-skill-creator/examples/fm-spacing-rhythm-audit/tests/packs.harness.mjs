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
import { dirname, join, basename } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize } from "../../../scripts/lib/skill-md.mjs"
import { loadPack, findUnits, stripUnits } from "../../../scripts/lib/enhancements.mjs"
import * as enhancements from "../../../scripts/lib/enhancements.mjs"

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
/** A line that makes a small master carry the test pack P (and token-conformance): one phrase unit. */
const CARRIED = "Token mode: the pack is carried."

/** Run the CLI; returns { status, out }. */
const cli = (...args) => { const r = spawnSync(process.execPath, [CLI, ...args], { encoding: "utf8" }); return { status: r.status, out: r.stdout + r.stderr } }

/** The last line of a command's output, for failure messages. */
const tail = (out) => out.trim().split("\n").pop()

/** The output's warnings are exactly one line saying the pack is not present in this master. */
const notPresentOnly = (out, name) => {
  const warns = out.split("\n").filter((l) => l.startsWith("warning:"))
  return warns.length === 1 && warns[0].includes(`${name}: not present in this master`)
}

/** The four pack selections the round trip is proven on: each pack, and both in either order. */
const SELECTIONS = [["token-conformance"], ["revert"], ["token-conformance", "revert"], ["revert", "token-conformance"]]

/** Run the validator with --json on lines written to a temporary master; returns its findings for one rule (all when rule is null). */
function findingsFor(name, lines, rule, ...flags) {
  const r = spawnSync(process.execPath, [VALIDATOR, writeMaster(name, lines), "--edition", "master", "--json", ...flags], { encoding: "utf8" })
  return JSON.parse(r.stdout).findings.filter((f) => rule === null || f.rule === rule)
}

/** A small master with chosen tags, runtimes, and body, for the validator's pack rules. */
const packMaster = (tags, runtimes, ...body) => ["---", "name: fm-x", "description: Audits a thing. Use whenever asked. Not for other things.", "metadata:",
  `  tags: "${tags}"`, `  runtimes: "${runtimes}"`, "---", "", "# T", "", "## Helper scripts", "", ...body]

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
  // Declared items count only in a master that carries the pack, so these masters end with one phrase line.
  "an ambiguous template line is an error": () => throwsWith(tiny("```markdown", "- Bound: <n>", "- Bound: <n>", "```", "", CARRIED), { ...P, templateLines: ["- Bound: <n>"] }, /exactly one/),
  "an ambiguous line rewrite is an error": () => throwsWith(tiny(...helper("let M = 1;", "let M = 1;"), "", CARRIED), { ...P, lineRewrites: [{ from: "let M = 1;", to: "let M = 2;" }] }, /matches 2 lines/),
  "a missing declared prose sentence is a warning that names it": () => {
    const warns = []
    let units = null
    try { units = findUnits(tiny("Some prose.", "", CARRIED), { ...P, proseSentences: ["Token mode adds lines."] }, { warn: (m) => warns.push(m) }) } catch (e) { return [`threw: ${e.message}`] }
    return check([[!units.some((u) => u.kind === "prose-sentence"), `${units.length} units`], [warns.length === 1 && warns[0].includes("Token mode adds lines."), `warnings: ${JSON.stringify(warns)}`]])
  },
  "an ambiguous declared prose sentence is an error": () => throwsWith(tiny("Token mode adds lines. Token mode adds lines.", "", CARRIED), { ...P, proseSentences: ["Token mode adds lines."] }, /prose sentence.*2 times.*line 12/),
  "a declared prose sentence overlapping a phrase-tagged unit is an error": () =>
    throwsWith(tiny("Intro. Token mode: adds lines here."), { ...P, proseSentences: ["Token mode: adds lines here."] }, /line 12: declared prose sentence overlaps a unit/),
  "an ambiguous declared description sentence is an error": () =>
    throwsWith(["---", "name: fm-x", "description: Does a thing. Does a thing. Use whenever asked.", "---", "", "# T", "", CARRIED], { ...P, descriptionSentences: ["Does a thing."] }, /description sentence occurs twice on line 3/),
  "a missing template line, rewrite, description sentence, or tag is a warning": () => {
    const warns = []
    findUnits(tiny(CARRIED), { ...P, templateLines: ["- gone"], lineRewrites: [{ from: "zz", to: "y" }], descriptionSentences: ["Nope."], tags: ["c"] }, { warn: (m) => warns.push(m) })
    return check([[warns.length === 4, `${warns.length} warnings`]])
  },
  "a phrase inside a table row is an error": () => throwsWith(masterWith("| Mode | Token mode: binds | Rhythm mode: sets |"), TOKENS, /line \d+: .*table row/),

  // A master the pack is absent from passes through strip: exit 0, unchanged, with one not-present line.
  "stripping a pack a second time exits 0, changes nothing, and says the pack is not present": () => {
    const problems = []
    for (const name of ["token-conformance", "revert"]) {
      const once = join(tmp, `once-${name}.md`), twice = join(tmp, `twice-${name}.md`)
      const r1 = cli("strip", MASTER, "--pack", name, "--out", once)
      const r2 = cli("strip", once, "--pack", name, "--out", twice)
      problems.push(...check([[r1.status === 0, `${name}: first strip exit ${r1.status}`], [r2.status === 0, `${name}: second strip exit ${r2.status}: ${r2.out.trim().split("\n").pop()}`],
        [r2.status !== 0 || readFileSync(twice, "utf8") === readFileSync(once, "utf8"), `${name}: second strip changed the file`],
        [notPresentOnly(r2.out, name), `${name}: second strip output: ${JSON.stringify(r2.out.split("\n").filter((l) => l.startsWith("warning:")))}`]]))
    }
    return problems
  },
  "stripping token-conformance from the probe leaves it byte-identical and says the pack is not present": () => {
    const probe = join(creator, "examples", "fm-figma-capability-probe", "SKILL.md")
    const out = join(tmp, "probe-stripped.md")
    const r = cli("strip", probe, "--pack", "token-conformance", "--out", out)
    return check([[r.status === 0, `exit ${r.status}: ${tail(r.out)}`], [r.status !== 0 || readFileSync(out).equals(readFileSync(probe)), "the probe changed"],
      [notPresentOnly(r.out, "token-conformance"), `output: ${JSON.stringify(r.out.split("\n").filter((l) => l.startsWith("warning:")))}`]])
  },
  "every template and example master a pack is absent from passes through strip byte-identical": () => {
    const files = [...readdirSync(join(creator, "templates")).filter((f) => f.endsWith(".md")).map((f) => join(creator, "templates", f)),
      join(creator, "examples", "fm-spacing-rhythm-audit", "SKILL.md"), join(creator, "examples", "fm-figma-capability-probe", "SKILL.md")]
    const problems = []
    let runs = 0
    for (const file of files) {
      const text = readFileSync(file, "utf8")
      for (const p of [TOKENS, REVERT]) {
        if (text.includes(p.phrase) || text.includes(`// enhancement: ${p.codeRegion} begin`)) continue
        runs++
        const out = join(tmp, `absent-${p.name}-${basename(file)}`)
        const r = cli("strip", file, "--pack", p.name, "--out", out)
        if (r.status !== 0 || !readFileSync(out).equals(readFileSync(file)) || !notPresentOnly(r.out, p.name)) problems.push(`${p.name} from ${basename(file)}: exit ${r.status}, ${tail(r.out)}`)
      }
    }
    return [...problems, ...check([[runs >= 26, `only ${runs} absent pairs checked`]])]
  },
  "a master with the tokens tag but no pack keeps its tag through a token-conformance strip": () => {
    const path = writeMaster("tag-only.md", ["---", "name: fm-x", "description: Audits a thing. Use whenever asked. Not for other things.", "metadata:",
      '  tags: "spacing, tokens, variables"', "---", "", "# T", "", "Design tokens are named values."])
    const out = join(tmp, "tag-only-stripped.md")
    const r = cli("strip", path, "--pack", "token-conformance", "--out", out)
    return check([[r.status === 0, `exit ${r.status}: ${tail(r.out)}`], [r.status !== 0 || readFileSync(out).equals(readFileSync(path)), "the master changed"],
      [r.status !== 0 || readFileSync(out, "utf8").includes('tags: "spacing, tokens, variables"'), "the tokens tag was removed"]])
  },
  "a master that carries the pack but lacks one declared line still warns for that line": () => {
    const gone = "- Bound values: <n> passed"
    const path = writeMaster("one-missing.md", masterLines.filter((l) => l !== gone))
    const r = cli("strip", path, "--pack", "token-conformance", "--out", join(tmp, "one-missing-stripped.md"))
    const warns = r.out.split("\n").filter((l) => l.startsWith("warning:"))
    return check([[r.status === 0, `exit ${r.status}: ${tail(r.out)}`], [warns.length === 1 && warns[0].includes("template line not found: " + gone), `warnings: ${JSON.stringify(warns)}`]])
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

  // Expand and the round trip (Task 6).
  "the committed enhancement.md files read back as the units findUnits finds": () => {
    const problems = []
    for (const p of [TOKENS, REVERT]) {
      const { units } = enhancements.readUnits(readFileSync(join(PACKS, p.name, "enhancement.md"), "utf8"))
      const want = findUnits(masterLines, p)
      const strip = (u) => JSON.stringify({ kind: u.kind, start: u.start, end: u.end, col: u.col, text: u.text, anchor: u.anchor, to: u.to })
      if (units.length !== want.length) problems.push(`${p.name}: read ${units.length} units, found ${want.length}`)
      else units.forEach((u, i) => { if (strip(u) !== strip(want[i])) problems.push(`${p.name}: unit ${i + 1} differs: ${strip(u).slice(0, 120)}`) })
    }
    return problems
  },
  "roundtrip exits 0 for each pack and for both in either order, with no expand warning": () => {
    const problems = []
    for (const sel of SELECTIONS) {
      const r = cli("roundtrip", MASTER, "--pack", sel.join(","))
      problems.push(...check([[r.status === 0, `${sel}: exit ${r.status}: ${tail(r.out)}`], [!r.out.includes("expand warning"), `${sel}: printed an expand warning`]]))
    }
    return problems
  },
  "strip then expand from the pack records gives back the master byte for byte": () => {
    const problems = []
    for (const sel of SELECTIONS) {
      const stripped = join(tmp, `rt-stripped-${sel.join("-")}.md`), back = join(tmp, `rt-back-${sel.join("-")}.md`)
      const s = cli("strip", MASTER, ...sel.flatMap((n) => ["--pack", n]), "--out", stripped)
      const e = cli("expand", stripped, ...sel.flatMap((n) => ["--pack", n]), "--out", back)
      problems.push(...check([[s.status === 0 && e.status === 0, `${sel}: exit ${s.status}, ${e.status}: ${tail(e.out)}`],
        [e.status !== 0 || readFileSync(back).equals(readFileSync(MASTER)), `${sel}: the expanded file differs from the master`],
        [!e.out.includes("expand warning"), `${sel}: printed an expand warning`]]))
    }
    return problems
  },
  "roundtrip exits 1 when the result differs, and names the first differing line": () => {
    // A tagged block glued to the next paragraph: strip leaves one blank line, and expand cannot know there was none.
    const path = writeMaster("glued.md", masterWith("Token mode: tokens are matched per mode.\nThis core sentence follows on the next line and must stay."))
    const r = cli("roundtrip", path, "--pack", "token-conformance")
    return check([[r.status === 1, `exit ${r.status}`], [/differs from the input at line \d+/.test(r.out), `output: ${tail(r.out)}`]])
  },
  "roundtrip exits 1 on a reworded declared prose sentence, and names the sentence": () => {
    const s = TOKENS.proseSentences[0]
    const path = writeMaster("drifted.md", masterText.replace(s, s.replace("Token mode adds these lines:", "Token mode adds the following lines:")).replace(/\n$/, "").split("\n"))
    const r = cli("roundtrip", path, "--pack", "token-conformance")
    return check([[r.status === 1, `exit ${r.status}`], [r.out.includes("declared prose sentence not found: " + s.slice(0, 60)), `output: ${tail(r.out)}`]])
  },
  "expand refuses a master that already carries the pack": () => {
    const r = cli("expand", MASTER, "--pack", "revert", "--out", join(tmp, "twice-expanded.md"))
    return check([[r.status === 1 && /already carries/.test(r.out), `exit ${r.status}: ${tail(r.out)}`]])
  },
  "a declared line alone does not make a master carry the pack": () => {
    // The probe's report table has the separator "| --- | --- | --- |", which token-conformance also declares.
    const probe = join(creator, "examples", "fm-figma-capability-probe", "SKILL.md")
    const surfaces = findingsFor("probe-copy.md", normalize(readFileSync(probe, "utf8")).replace(/\n$/, "").split("\n"), "enhancement-surfaces")
    const r = cli("expand", probe, "--pack", "token-conformance", "--out", join(tmp, "probe-with-tokens.md"))
    return check([[surfaces.length === 0, `validator: ${JSON.stringify(surfaces)}`], [r.status === 0, `expand exit ${r.status}: ${tail(r.out)}`]])
  },
  "expand into the untagged QA template: a warning per orphan code region, unmarked fences, validates, builds": () => {
    const out = join(tmp, "qa-with-tokens.md")
    const r = cli("expand", join(creator, "templates", "type-standards-qa-audit.md"), "--pack", "token-conformance", "--out", out)
    if (r.status !== 0) return [`expand exit ${r.status}: ${tail(r.out)}`]
    const warns = r.out.split("\n").filter((l) => l.startsWith("expand warning:"))
    const lines = normalize(readFileSync(out, "utf8")).split("\n")
    const fences = lines.map((l) => /^\/\/ token-conformance regions for ([a-z-]+): place by hand$/.exec(l)).filter(Boolean).map((m) => m[1])
    const units = byKind(findUnits(lines, TOKENS))
    const v = findingsFor("qa-with-tokens-check.md", lines, null, "--allow-placeholders")
    const named = writeMaster("qa-named.md", lines.map((l) => (l.startsWith("name: ") ? "name: fm-qa-with-tokens" : l)))
    const b = spawnSync(process.execPath, [BUILDER, named, "--out", join(tmp, "dist-qa"), "--dry-run"], { encoding: "utf8" })
    // Every unit lands somewhere except the rewrite, whose rhythm line the template lacks. The nine sentence
    // units have no anchor here, so each lands on its own line at its section's end and reads back as a block.
    const regionWarnings = warns.filter((l) => /code-region .* has no anchor in helper/.test(l)).length
    return check([
      [regionWarnings === 6, `${regionWarnings} code-region warnings, expected 6`],
      [JSON.stringify(fences) === JSON.stringify(["collect", "apply", "verify"]), `orphan fences: ${JSON.stringify(fences)}`],
      [!lines.some((l) => /^\/\/ helper: (apply|verify)$/.test(l)), "an orphan fence carries a helper marker"],
      [sameCounts(units, { "code-region": 6, block: 17, "description-sentence": 1, "heading-block": 1, "prose-sentence": 1, tag: 2, "template-line": 10 }), `units after expand: ${JSON.stringify(units)}`],
      [v.length === 2 && v.every((f) => ["name-format", "description-angle"].includes(f.rule) && f.severity === "warn"), `validator: ${JSON.stringify(v.map((f) => `${f.severity} ${f.rule} ${f.message}`))}`],
      [b.status === 0 && b.stdout.includes("helpers: 1 scripts (collect)"), `builder: ${(b.stdout + b.stderr).match(/helpers:.*|build error.*/)?.[0]}`],
    ])
  },

  // The validator's pack rules, each on a failing input.
  "validator enhancement-regions: an unended begin, nested regions, and an unknown pack are errors": () => {
    const unended = findingsFor("v-unended.md", packMaster("a", "figma-design", ...helper("// enhancement: revert begin", "x", "return 1")), "enhancement-regions")
    const nested = findingsFor("v-nested.md", packMaster("a", "figma-design", ...helper("// enhancement: revert begin", "// enhancement: token-conformance begin", "x",
      "// enhancement: token-conformance end", "// enhancement: revert end", "return 1")), "enhancement-regions")
    const unknown = findingsFor("v-unknown.md", packMaster("a", "figma-design", ...helper("// enhancement: no-such-pack begin", "x", "// enhancement: no-such-pack end", "return 1")), "enhancement-regions")
    return check([[unended.length === 1 && unended[0].severity === "error" && /no end/.test(unended[0].message), `unended: ${JSON.stringify(unended)}`],
      [nested.length >= 1 && nested.every((f) => f.severity === "error") && nested.some((f) => /nest/.test(f.message)), `nested: ${JSON.stringify(nested)}`],
      [unknown.length === 1 && unknown[0].severity === "error" && /no-such-pack/.test(unknown[0].message), `unknown: ${JSON.stringify(unknown)}`]])
  },
  "validator enhancement-tags: a pack phrase without its code region warns, gated by the tags or, for revert, by either side": () => {
    const tokens = findingsFor("v-tags.md", packMaster("audit, tokens", "figma-design", "Token mode: bind the value to the matching token.", "", ...helper("return 1")), "enhancement-tags")
    const untagged = findingsFor("v-tags-off.md", packMaster("audit", "figma-design", "Token mode: bind the value to the matching token.", "", ...helper("return 1")), "enhancement-tags")
    const revert = findingsFor("v-revert.md", packMaster("audit", "figma-design", ...helper("// enhancement: revert begin", "return 1", "// enhancement: revert end")), "enhancement-tags")
    return check([[tokens.length === 1 && tokens[0].severity === "warn" && /token-conformance/.test(tokens[0].message), `tokens: ${JSON.stringify(tokens)}`],
      [untagged.length === 0, `untagged master warned: ${JSON.stringify(untagged)}`],
      [revert.length === 1 && revert[0].severity === "warn" && /revert/.test(revert[0].message), `revert: ${JSON.stringify(revert)}`]])
  },
  "validator enhancement-surfaces: a pack that does not cover a skill surface warns without a surface guard": () => {
    const region = (...guard) => helper("// enhancement: token-conformance begin", ...guard, "const t = 1;", "// enhancement: token-conformance end", "return 1")
    const bare = findingsFor("v-surf.md", packMaster("audit", "figma-design, figma-spec, mcp", ...region()), "enhancement-surfaces")
    const guarded = findingsFor("v-surf-guard.md", packMaster("audit", "figma-design, figma-spec, mcp",
      ...region('if (figma.editorType === "figspec") return { skipped: "skipped in a Spec file" };')), "enhancement-surfaces")
    const covered = findingsFor("v-surf-ok.md", packMaster("audit", "figma-design, figma-make, mcp", ...region()), "enhancement-surfaces")
    return check([[bare.length === 1 && bare[0].severity === "warn" && /figma-spec/.test(bare[0].message), `bare: ${JSON.stringify(bare)}`],
      [guarded.length === 0, `guarded: ${JSON.stringify(guarded)}`], [covered.length === 0, `covered: ${JSON.stringify(covered)}`]])
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
