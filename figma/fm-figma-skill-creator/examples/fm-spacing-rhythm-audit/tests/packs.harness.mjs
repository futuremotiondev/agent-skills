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

import { readFileSync, writeFileSync, mkdtempSync, mkdirSync, copyFileSync, rmSync, readdirSync, existsSync } from "node:fs"
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

/** Lines with `extra` inserted after the first line equal to `at`. */
function insertAfterLine(lines, at, extra) {
  const i = lines.indexOf(at)
  if (i === -1) throw new Error(`no line reads ${JSON.stringify(at)}`)
  return [...lines.slice(0, i + 1), ...extra, ...lines.slice(i + 1)]
}

/** The reviewer's edits that touch no anchor: prose under When to use, code at the top of collect, and a decoy `};`. */
const EDITS = {
  "prose-15": (l) => insertAfterLine(l, "## When to use", ["", ...Array.from({ length: 15 }, (_, i) => `Extra line ${i}.`)]),
  "code-30": (l) => insertAfterLine(l, "// helper: collect", Array.from({ length: 30 }, (_, i) => `const extra${i} = ${i};`)),
  "arrow-6": (l) => insertAfterLine(l, "// helper: collect", ["const decoyA = () => {", "  return 1;", "};", "const decoyB = () => {", "  return 2;", "};"]),
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

  // Fix round 1, ruling 1: expand places a unit only where it can verify the place.
  "expand commutes with edits that touch no anchor, for each pack and both": () => {
    const problems = []
    for (const sel of [[TOKENS], [REVERT], [TOKENS, REVERT]]) {
      const names = sel.map((p) => p.name)
      const stripped = stripAll(masterLines, sel).lines
      for (const [label, edit] of Object.entries(EDITS)) {
        const input = writeMaster(`commute-${names.join("-")}-${label}.md`, edit(stripped))
        const out = join(tmp, `commute-${names.join("-")}-${label}-back.md`)
        const r = cli("expand", input, ...names.flatMap((n) => ["--pack", n]), "--out", out)
        const want = edit(masterLines.slice(0, -1)).join("\n") + "\n"
        const got = r.status === 0 ? readFileSync(out, "utf8") : ""
        const at = want.split("\n").findIndex((l, i) => l !== got.split("\n")[i])
        problems.push(...check([[r.status === 0, `${names} ${label}: exit ${r.status}: ${tail(r.out)}`], [!r.out.includes("expand warning"), `${names} ${label}: warned: ${r.out.split("\n").find((l) => l.startsWith("expand warning"))}`],
          [r.status !== 0 || got === want, `${names} ${label}: differs at line ${at + 1}: ${JSON.stringify(got.split("\n")[at] ?? "").slice(0, 80)}`]]))
      }
    }
    return problems
  },
  "expand warns and falls back when an anchor is missing or ambiguous, and places nothing silently": () => {
    const run = (name, lines, pack) => {
      const out = join(tmp, `${name}-back.md`)
      const r = cli("expand", writeMaster(`${name}.md`, lines), "--pack", pack, "--out", out)
      return { r, warns: r.out.split("\n").filter((l) => l.startsWith("expand warning:")), lines: r.status === 0 ? normalize(readFileSync(out, "utf8")).split("\n") : [] }
    }
    // The revert helper fence anchors on the helper before it, by name: renamed, it falls back.
    const noRevert = stripAll(masterLines, [REVERT]).lines
    const renamed = run("renamed-verify", noRevert.map((l) => (l === "// helper: verify" ? "// helper: check" : l)), "revert")
    // The Discovery region's anchor `};` is located by the line above it; a second copy of that line makes it ambiguous.
    const noTokens = stripAll(masterLines, [TOKENS]).lines
    const keyLine = "  return hi % 8 === 0 && lo % 8 !== 0 ? hi : lo;"
    const decoy = run("decoy-key", insertAfterLine(noTokens, "// helper: collect", ["const decoy = (lo, hi) => {", keyLine, "};"]), "token-conformance")
    // A prose anchor that occurs twice in its section is ambiguous.
    const verifyLine = noRevert.find((l) => l.startsWith("7. **Verify.**"))
    const twice = run("twice-verify", insertAfterLine(noRevert, "## Instructions", ["", verifyLine]), "revert")
    const at = (r, re) => r.lines.findIndex((l) => re.test(l))
    return check([
      [renamed.r.status === 0 && renamed.warns.length === 1 && /fence \(master lines 441 to \d+\).*helper "verify"/.test(renamed.warns[0]), `renamed: ${JSON.stringify(renamed.warns)}`],
      [at(renamed, /^\/\/ helper: revert$/) > at(renamed, /^\/\/ helper: check$/), "renamed: the revert fence is not after the renamed helper"],
      [decoy.r.status === 0 && decoy.warns.length === 1 && /code-region \(master lines 162 to 238\)/.test(decoy.warns[0]), `decoy: ${JSON.stringify(decoy.warns)}`],
      [at(decoy, /^\/\/ Discovery: /) > at(decoy, /^\/\/ token-conformance regions for collect: place by hand$/) && at(decoy, /regions for collect/) > 0, "decoy: the Discovery region is not in the orphan fence"],
      [twice.r.status === 0 && twice.warns.length === 1 && /block \(master line 55\).*2 lines/.test(twice.warns[0]), `twice: ${JSON.stringify(twice.warns)}`],
    ])
  },
  "a skill that takes the flagship's name still gets the Discovery region as an orphan": () => {
    const qa = normalize(readFileSync(join(creator, "templates", "type-standards-qa-audit.md"), "utf8")).replace(/\n$/, "").split("\n").map((l) => (l.startsWith("name: ") ? "name: fm-spacing-rhythm-audit" : l))
    const r = cli("expand", writeMaster("qa-as-audit.md", qa), "--pack", "token-conformance", "--out", join(tmp, "qa-as-audit-back.md"))
    const regions = r.out.split("\n").filter((l) => /^expand warning: .*code-region .* has no anchor in helper/.test(l)).length
    return check([[r.status === 0 && regions === 6, `exit ${r.status}, ${regions} code-region warnings`]])
  },

  // Ruling 2: a separator has no identity of its own; library errors reach the validator; expand checks its result.
  "a separator-only template line matches only below another declared template line": () => {
    const lines = masterWith("```markdown\n| A | B | C |\n| --- | --- | --- |\n```")
    let units
    try { units = findUnits(lines, TOKENS) } catch (e) { return [`threw: ${e.message}`] }
    const out = stripAll(lines, [TOKENS]).lines
    const k = out.indexOf("| A | B | C |")
    return check([[units.filter((u) => u.kind === "template-line").length === 10, "template-line count changed"], [k !== -1 && out[k + 1] === "| --- | --- | --- |", "the other table lost its separator"]])
  },
  "expand into the probe writes a master the tools accept, and the validator sees the uncovered surface": () => {
    const out = join(tmp, "probe-tok.md")
    const e = cli("expand", join(creator, "examples", "fm-figma-capability-probe", "SKILL.md"), "--pack", "token-conformance", "--out", out)
    if (e.status !== 0) return [`expand exit ${e.status}: ${tail(e.out)}`]
    const s = cli("strip", out, "--pack", "token-conformance", "--out", join(tmp, "probe-tok-stripped.md"))
    const surfaces = findingsFor("probe-tok-check.md", normalize(readFileSync(out, "utf8")).replace(/\n$/, "").split("\n"), "enhancement-surfaces")
    return check([[s.status === 0, `strip exit ${s.status}: ${tail(s.out)}`], [surfaces.length === 1, `surfaces: ${JSON.stringify(surfaces)}`]])
  },
  "the validator reports a pack library error under enhancement-regions": () => {
    const gone = "- Bound values: <n> passed"
    const lines = masterLines.slice(0, -1).flatMap((l) => (l === gone ? [l, l] : [l]))
    const f = findingsFor("lib-error.md", lines, "enhancement-regions")
    return check([[f.length === 1 && f[0].severity === "error" && /matches 2 lines/.test(f[0].message) && f[0].line, `findings: ${JSON.stringify(f)}`]])
  },
  "expand writes nothing and exits 1 when the pack tools would refuse its result": () => {
    const qa = normalize(readFileSync(join(creator, "templates", "type-standards-qa-audit.md"), "utf8")).replace(/\n$/, "").split("\n")
    const out = join(tmp, "refused.md")
    const r = cli("expand", writeMaster("qa-own-bound.md", insertAfterLine(qa, "- Violations: P0 <n> · P1 <n> · P2 <n> · P3 <n>", ["- Bound values: <n> passed"])), "--pack", "token-conformance", "--out", out)
    return check([[r.status === 1, `exit ${r.status}`], [!existsSync(out), "a file was written"], [/matches 2 lines \(\d+, \d+\)/.test(r.out), `output: ${tail(r.out)}`]])
  },

  // Rulings 4 to 8.
  "enhancement-surfaces: a guard anywhere in the helper counts, and no overlap says so": () => {
    const region = ["// enhancement: token-conformance begin", "const t = 1;", "// enhancement: token-conformance end"]
    const guarded = findingsFor("v-surf-helper-guard.md", packMaster("audit", "figma-design, figma-spec, mcp",
      ...helper('if (figma.editorType === "figspec") return { skipped: "skipped in a Spec file" };', ...region, "return 1")), "enhancement-surfaces")
    const none = findingsFor("v-surf-none.md", packMaster("audit", "figma-spec, mcp", ...helper(...region, "return 1")), "enhancement-surfaces")
    return check([[guarded.length === 0, `guarded in helper: ${JSON.stringify(guarded)}`],
      [none.length === 1 && /none of the skill's surfaces/.test(none[0].message) && /remove/.test(none[0].message), `no overlap: ${JSON.stringify(none)}`]])
  },
  "a pack phrase in a table row of a pack-free master is ordinary text for strip and the validator": () => {
    const lines = packMaster("audit", "figma-design", "| Row | Note |", "| --- | --- |", "| R | Revert: undo the last snap |", "", ...helper("return 1"))
    const path = writeMaster("table-row-free.md", lines), out = join(tmp, "table-row-free-stripped.md")
    const r = cli("strip", path, "--pack", "revert", "--out", out)
    const all = findingsFor("table-row-free-check.md", lines, null)
    return check([[r.status === 0 && readFileSync(out).equals(readFileSync(path)), `strip exit ${r.status}: ${tail(r.out)}`],
      [!all.some((f) => f.severity === "error" || f.rule.startsWith("enhancement-")), `validator: ${JSON.stringify(all.filter((f) => f.severity === "error" || f.rule.startsWith("enhancement-")))}`]])
  },
  "strip of a pack-free master writes the input bytes, CRLF or no final newline": () => {
    const text = readFileSync(join(creator, "templates", "type-standards-qa-audit.md"), "utf8")
    const problems = []
    for (const [label, bytes] of [["crlf", text.replace(/\n/g, "\r\n")], ["no-final-newline", text.replace(/\n$/, "")]]) {
      const path = join(tmp, `${label}.md`), out = join(tmp, `${label}-out.md`)
      writeFileSync(path, bytes)
      const r = cli("strip", path, "--pack", "token-conformance", "--out", out)
      problems.push(...check([[r.status === 0 && readFileSync(out).equals(readFileSync(path)), `${label}: exit ${r.status}, bytes ${r.status === 0 ? "differ" : "-"}`]]))
    }
    return problems
  },
  "roundtrip on a master without the pack exits 1 and says the pack is not present": () => {
    const r = cli("roundtrip", join(creator, "templates", "type-standards-qa-audit.md"), "--pack", "revert")
    return check([[r.status === 1, `exit ${r.status}`], [/not present in this master/.test(tail(r.out)) && !/declared item/.test(r.out), `output: ${JSON.stringify(r.out.trim().split("\n"))}`]])
  },
  "a unit whose section is missing goes at the end of the last core section, with a warning naming the section": () => {
    const qa = normalize(readFileSync(join(creator, "templates", "type-standards-qa-audit.md"), "utf8")).replace(/\n$/, "").split("\n").map((l) => (l === "## Common edge cases" ? "## Gotchas" : l))
    const out = join(tmp, "missing-section-back.md")
    const r = cli("expand", writeMaster("missing-section.md", qa), "--pack", "token-conformance", "--out", out)
    if (r.status !== 0) return [`exit ${r.status}: ${tail(r.out)}`]
    const lines = normalize(readFileSync(out, "utf8")).split("\n")
    const unit = lines.findIndex((l) => l.startsWith("- **Token mode: alias tokens.**"))
    return check([[r.out.split("\n").some((l) => l.startsWith("expand warning:") && l.includes('section "Common edge cases" not found')), "no warning names the missing section"],
      [unit > lines.findIndex((l) => l.startsWith("## Final gate")) && unit < lines.indexOf("<!-- target:figma-app -->"), `the unit is at line ${unit + 1}, not in the last core section`]])
  },

  // Task 8, carried items.
  "a section name that two sections carry is a fallback with a warning, never a silent placement": () => {
    // Strip revert, then add a second "## Instructions" before the real one, holding a copy of the Verify line the revert block anchors on.
    const noRevert = stripAll(masterLines, [REVERT]).lines
    const verifyLine = noRevert.find((l) => l.startsWith("7. **Verify.**"))
    const at = noRevert.indexOf("## Instructions")
    const lines = [...noRevert.slice(0, at), "## Instructions", "", verifyLine, "", ...noRevert.slice(at)]
    const out = join(tmp, "dup-section-back.md")
    const r = cli("expand", writeMaster("dup-section.md", lines), "--pack", "revert", "--out", out)
    if (r.status !== 0) return [`exit ${r.status}: ${tail(r.out)}`]
    const warns = r.out.split("\n").filter((l) => l.startsWith("expand warning:"))
    const back = normalize(readFileSync(out, "utf8")).split("\n")
    const first = back.indexOf("## Instructions")
    const decoy = back.slice(first, back.indexOf("## Instructions", first + 1))
    return check([[warns.length >= 1 && warns.some((l) => /section "Instructions" matches 2 sections/.test(l)), `warnings: ${JSON.stringify(warns)}`],
      [!decoy.some((l) => l.includes("Revert")), `a revert unit went into the decoy section: ${JSON.stringify(decoy)}`]])
  },
  "the validator does not double the pack name on a library message that starts with it": () => {
    const s = TOKENS.proseSentences[0]
    const host = masterLines.findIndex((l) => l.includes(s))
    const lines = masterLines.slice(0, -1).flatMap((l, i) => (i === host ? [l, "", s] : [l]))
    const f = findingsFor("doubled-prefix.md", lines, "enhancement-regions")
    return check([[f.length === 1 && /^token-conformance: declared prose sentence matches 2 times/.test(f[0].message), `findings: ${JSON.stringify(f)}`],
      [!f.some((x) => x.message.includes("token-conformance: token-conformance:")), "the pack name is doubled"]])
  },
  "a region marker shown in a markdown or ts fence is ordinary text for the library and the validator": () => {
    const lines = masterWith("```markdown\n// enhancement: revert begin\n```\n\n```ts\n// enhancement: token-conformance end\n```")
    const problems = []
    for (const [p, want] of [[TOKENS, 39], [REVERT, 8]]) {
      try { const n = findUnits(lines, p).length; if (n !== want) problems.push(`${p.name}: ${n} units, expected ${want}`) } catch (e) { problems.push(`${p.name}: threw ${e.message}`) }
    }
    const f = findingsFor("shown-markers.md", lines, null).filter((x) => x.severity === "error" || x.rule.startsWith("enhancement-"))
    const r = cli("strip", writeMaster("shown-markers-cli.md", lines), "--pack", "revert", "--out", join(tmp, "shown-markers-stripped.md"))
    return [...problems, ...check([[f.length === 0, `validator: ${JSON.stringify(f)}`], [r.status === 0, `strip exit ${r.status}: ${tail(r.out)}`]])]
  },
  "enhancement-surfaces: a guard in one helper does not cover a region in another": () => {
    const region = ["// enhancement: token-conformance begin", "const t = 1;", "// enhancement: token-conformance end"]
    const guard = 'if (figma.editorType === "figspec") return { skipped: "skipped in a Spec file" };'
    const two = (g1, g2) => packMaster("audit", "figma-design, figma-spec, mcp", "```javascript", "// helper: one", ...g1, ...region, "return 1", "```", "",
      "```javascript", "// helper: two", ...g2, ...region, "return 2", "```")
    const oneGuarded = findingsFor("v-surf-one.md", two([guard], []), "enhancement-surfaces")
    const bothGuarded = findingsFor("v-surf-both.md", two([guard], [guard]), "enhancement-surfaces")
    return check([[oneGuarded.length === 1 && /"two"/.test(oneGuarded[0].message) && oneGuarded[0].line === 24,`one guarded: ${JSON.stringify(oneGuarded)}`],
      [bothGuarded.length === 0, `both guarded: ${JSON.stringify(bothGuarded)}`]])
  },
  "no overlap advises removing the pack, in the validator and in contract rule (i)": () => {
    const region = ["// enhancement: token-conformance begin", "const t = 1;", "// enhancement: token-conformance end"]
    const none = findingsFor("v-surf-none-advice.md", packMaster("audit", "figma-spec, mcp", ...helper(...region, "return 1")), "enhancement-surfaces")
    const contract = readFileSync(join(creator, "references", "enhancement-packs.md"), "utf8").split("\n").find((l) => l.startsWith("- **No overlap**")) || ""
    return check([[none.length === 1 && /remove the pack/.test(none[0].message) && !/or narrow/.test(none[0].message), `message: ${JSON.stringify(none.map((f) => f.message))}`],
      [/remove/.test(contract) && !/offers to narrow/.test(contract), `contract: ${contract}`]])
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
