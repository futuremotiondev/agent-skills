// checks.harness.mjs: tests the validator rules that are not pack rules (the description boundary and
// voice, gate-tool, helper-form, capability-gates, and the helper-fence language the validator shares
// with the libraries), and scripts/check-all.mjs (its check list, the changelog checks, and that it
// never reads a history/ folder). The pack rules are tested in packs.harness.mjs.
//
// Usage, from figma/fm-figma-skill-creator:
//   node examples/fm-spacing-rhythm-audit/tests/checks.harness.mjs
//
// Variants, scratch copies of the creator, and command outputs are written to a folder under the
// operating system's temporary folder and removed at the end. The creator's files are only read. It
// exports nothing and exits 1 when any case fails. It runs check-all.mjs only with --list and --only
// groups that start no harness, so check-all running this harness never recurses.

import { readFileSync, writeFileSync, mkdtempSync, mkdirSync, cpSync, rmSync, existsSync } from "node:fs"
import { spawnSync } from "node:child_process"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize } from "../../../scripts/lib/skill-md.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const creator = join(here, "..", "..", "..")
const MASTER = join(here, "..", "SKILL.md")
const VALIDATOR = join(creator, "scripts", "validate-figma-skill.mjs")
const CHECK_ALL = join(creator, "scripts", "check-all.mjs")
const tmp = mkdtempSync(join(tmpdir(), "checks-harness-"))

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Turn [condition, message] pairs into the list of failed messages. */
const check = (pairs) => pairs.filter(([ok]) => !ok).map(([, msg]) => msg)

const masterLines = normalize(readFileSync(MASTER, "utf8")).replace(/\n$/, "").split("\n")

/** Run the validator with --json; returns its parsed result. */
const validate = (...args) => {
  const r = spawnSync(process.execPath, [VALIDATOR, ...args, "--json"], { encoding: "utf8" })
  return { status: r.status, ...JSON.parse(r.stdout) }
}

/** The findings of one rule for a description string. */
const descFindings = (text, rule) => validate("--description", text).findings.filter((f) => f.rule === rule)

/** Write lines as a file in the temporary folder, validate it as `edition`, and return the findings of one rule (all when null). */
const fileFindings = (name, lines, edition, rule) => {
  const path = join(tmp, name)
  writeFileSync(path, lines.join("\n") + "\n")
  return validate(path, "--edition", edition).findings.filter((f) => rule === null || f.rule === rule)
}

/** A small master: frontmatter, the four required sections, and `body` in Instructions, with optional extra sections. */
const skill = (body, extra = []) => ["---", "name: fm-gate-test", 'description: "Audits X. Use whenever the user asks to audit X. Not for Y."', "metadata:", '  version: "1.0"', "---", "",
  "# Gate test", "", "## When to use", "", "- x", "", "## Instructions", "", ...body, "", "## Common edge cases", "", "- x", "", "## Final gate", "", "- [ ] x", ...extra]

/** The same body with no frontmatter, for the paste edition. */
const pasteOf = (lines) => lines.slice(lines.indexOf("---", 1) + 2)

/** The figma-app section that names the structured question tool. */
const APP_TOOL = ["", "<!-- target:figma-app -->", "## In-app execution", "", "If a structured question tool such as `ask_user_question` is available, ask every numbered question through it.", "<!-- /target -->"]

/** A helper section holding one helper fence. */
const helperSection = (...code) => ["", "## Helper scripts", "", "```javascript", "// helper: h", ...code, "```"]

/** Run check-all.mjs from `root` (a creator folder) with args; returns { status, lines }. */
const checkAll = (root, ...args) => {
  const r = spawnSync(process.execPath, [join(root, "scripts", "check-all.mjs"), ...args], { encoding: "utf8", cwd: root })
  return { status: r.status, lines: (r.stdout + r.stderr).trim().split("\n") }
}

/** Parse JSONC: line and block comments outside strings, and trailing commas, are removed before JSON.parse. */
function parseJsonc(text) {
  let out = "", inString = false
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (inString) { out += c; if (c === "\\") out += text[++i] ?? ""; else if (c === "\"") inString = false; continue }
    if (c === "\"") { inString = true; out += c; continue }
    if (c === "/" && text[i + 1] === "/") { while (i < text.length && text[i] !== "\n") i++; out += "\n"; continue }
    if (c === "/" && text[i + 1] === "*") { i = text.indexOf("*/", i + 2); if (i === -1) throw new Error("unclosed block comment"); i++; continue }
    out += c
  }
  return JSON.parse(out.replace(/,(\s*[\]}])/g, "$1"))
}

/** A scratch copy of the creator with only the folders a check needs (never a history/ folder). */
const scratchCreator = (name, parts) => {
  const root = join(tmp, name)
  for (const p of parts) cpSync(join(creator, p), join(root, p), { recursive: true, filter: (src) => !/[\\/]history([\\/]|$)/.test(src) })
  return root
}

// ---------------------------------------------------------------------------
// Cases: each returns the failed messages
// ---------------------------------------------------------------------------

const cases = {
  // The boundary: "does not" and "doesn't" describe behaviour; they are no boundary.
  "description-triggers: a bare \"does not\" or \"doesn't\" is no boundary, \"Not for\" is": () => {
    const bare = descFindings("Audits frames and does not need a selection. Use whenever the user asks to audit.", "description-triggers")
    const doesnt = descFindings("Audits frames and doesn't need a selection. Use whenever the user asks to audit.", "description-triggers")
    const ok = descFindings("Audits frames. Use whenever the user asks to audit. Not for layout changes (use /fm-layout).", "description-triggers")
    const skip = descFindings("Audits frames. Use whenever the user asks to audit. Skip it for layout changes.", "description-triggers")
    return check([[bare.length === 1 && /boundary/.test(bare[0].message), `does not: ${JSON.stringify(bare)}`],
      [doesnt.length === 1 && /boundary/.test(doesnt[0].message), `doesn't: ${JSON.stringify(doesnt)}`],
      [ok.length === 0, `Not for: ${JSON.stringify(ok)}`], [skip.length === 0, `Skip it for: ${JSON.stringify(skip)}`]])
  },
  "description-voice: \"Lets designers\", \"helps teams\", and \"allows users to\" warn; a capability-first description does not": () => {
    const texts = [
      "Lets designers quickly audit spacing. Use whenever the user asks to audit spacing. Not for layout changes.",
      "Audits spacing and helps product teams keep the rhythm. Use whenever the user asks to audit spacing. Not for layout changes.",
      "Audits spacing. It allows anyone to fix a frame. Use whenever the user asks to audit spacing. Not for layout changes.",
      "Audits spacing and lets reviewers to sign off. Use whenever the user asks to audit spacing. Not for layout changes.",
    ]
    const flagged = texts.map((t) => descFindings(t, "description-voice").length)
    const clean = descFindings("Audits spacing on the 4/8 pt rhythm and offers snaps. Use whenever the user asks to audit spacing. Not for layout changes.", "description-voice")
    return check([[flagged.every((n) => n === 1), `voice findings per text: ${JSON.stringify(flagged)}`], [clean.length === 0, `clean: ${JSON.stringify(clean)}`]])
  },

  // gate-tool: a numbered question in a blockquote is a gate.
  "gate-tool: a gate without the question-tool clause, in a file that never names ask_user_question, warns twice": () => {
    const f = fileFindings("gate-bare.md", skill(["1. Ask:", "   > Nothing selected. 1. Page, or 2. select?"]), "master", "gate-tool")
    return check([[f.length === 2 && f.every((x) => x.severity === "warn" && x.line === 17), `findings: ${JSON.stringify(f)}`],
      [f.some((x) => /structured question tool/.test(x.message)) && f.some((x) => /ask_user_question/.test(x.message)), `messages: ${JSON.stringify(f.map((x) => x.message))}`]])
  },
  "gate-tool: the clause anywhere in the gate's list item and the tool in target:figma-app pass": () => {
    const listItem = fileFindings("gate-ok.md", skill(["1. **Resolve the scope.** If nothing is selected, ask, verbatim (through a structured question tool when the runtime has one):",
      "   > Nothing selected. 1. Page, or 2. select?", "   Wait for the answer."], APP_TOOL), "master", "gate-tool")
    const paragraph = fileFindings("gate-para.md", skill(["Ask, verbatim, with numbered options (through a structured question tool when the runtime has one; plain text otherwise):",
      "> Which one? 1. A · 2. B", "Wait."], APP_TOOL), "master", "gate-tool")
    // The clause is in an earlier paragraph: this gate's own paragraph lacks it.
    const apart = fileFindings("gate-apart.md", skill(["Every question goes through a structured question tool when the runtime has one.", "", "Ask:", "> Which one? 1. A · 2. B"], APP_TOOL), "master", "gate-tool")
    return check([[listItem.length === 0, `list item: ${JSON.stringify(listItem)}`], [paragraph.length === 0, `paragraph: ${JSON.stringify(paragraph)}`],
      [apart.length === 1 && apart[0].line === 19 &&/structured question tool/.test(apart[0].message), `separate paragraph: ${JSON.stringify(apart)}`]])
  },
  "gate-tool: the two example masters carry no gate-tool warning": () => {
    const probe = join(creator, "examples", "fm-figma-capability-probe", "SKILL.md")
    const found = [MASTER, probe].map((p) => validate(p, "--edition", "master").findings.filter((f) => f.rule === "gate-tool").length)
    return check([[found.every((n) => n === 0), `gate-tool findings: ${JSON.stringify(found)}`]])
  },

  // helper-form: helpers use top-level await and a final return, never a function wrapper.
  "helper-form: a wrapped helper is an error in the master, upload, and paste editions": () => {
    const wrapped = skill([], [...helperSection("(async () => {", "  const n = await figma.getNodeByIdAsync(\"1:2\");", "  return n.name;", "})();"), ...APP_TOOL])
    const problems = []
    for (const [edition, lines] of [["master", wrapped], ["upload", wrapped.filter((l) => !/^(metadata:|  version:)/.test(l))], ["paste", pasteOf(wrapped)]]) {
      const f = fileFindings(`wrapped-${edition}.md`, lines, edition, "helper-form")
      if (!(f.length === 2 && f.every((x) => x.severity === "error" && /top-level await and a final return/.test(x.message)))) problems.push(`${edition}: ${JSON.stringify(f)}`)
    }
    const others = ["(async function main() {", "(() => {"].map((open) => fileFindings("wrapped-other.md", skill([], helperSection(open, "  return 1;", "})();")), "master", "helper-form").length)
    return [...problems, ...check([[others.every((n) => n === 2), `async function and arrow wrappers: ${JSON.stringify(others)}`]])]
  },
  "helper-form: the top-level form passes, and so do an indented inner wrapper and a plain javascript fence": () => {
    const top = fileFindings("top.md", skill([], helperSection("const n = await figma.getNodeByIdAsync(\"1:2\");", "if (!n) return { error: \"not found\" };", "return n.name;")), "master", "helper-form")
    const indented = fileFindings("indented.md", skill([], helperSection("for (const id of ids) {", "  (async () => {", "    await go(id);", "  })();", "}", "return 1;")), "master", "helper-form")
    const plain = fileFindings("plain.md", skill(["```javascript", "(async () => {", "  return 1;", "})();", "```"]), "master", "helper-form")
    const audit = validate(MASTER, "--edition", "master").findings.filter((f) => f.rule === "helper-form")
    return check([[top.length === 0, `top-level: ${JSON.stringify(top)}`], [indented.length === 0, `indented: ${JSON.stringify(indented)}`],
      [plain.length === 0, `plain fence: ${JSON.stringify(plain)}`], [audit.length === 0, `audit master: ${JSON.stringify(audit)}`]])
  },
  "helper-form: a pack's whole-helper fence follows the rule (the audit's revert helper, wrapped)": () => {
    const begin = masterLines.indexOf("// enhancement: revert begin"), end = masterLines.indexOf("// enhancement: revert end")
    const lines = [...masterLines.slice(0, begin + 1), "(async () => {", ...masterLines.slice(begin + 1, end), "})();", ...masterLines.slice(end)]
    const f = fileFindings("revert-wrapped.md", lines, "master", "helper-form")
    return check([[f.length === 2 && f[0].line === begin + 2 && f[1].line === end + 2 && f.every((x) => x.severity === "error"), `findings: ${JSON.stringify(f)}`]])
  },

  // capability-gates: generating vector icons is available; editing existing vector paths is not.
  "capability-gates: generated vector artwork passes, editing existing vector paths without plan-only wording warns": () => {
    const gen = fileFindings("vec-gen.md", skill(["Generate vector icons and illustrations for the empty state in a new frame, then check the strokes against the style."]), "master", "capability-gates")
    const conv = fileFindings("vec-conv.md", skill(["Convert the pasted image to vectors in a new frame."]), "master", "capability-gates")
    const edit = fileFindings("vec-edit.md", skill(["Edit the existing vector paths of the logo so the corners are round."]), "master", "capability-gates")
    const points = fileFindings("vec-points.md", skill(["Move the vector points of the icon onto the pixel grid."]), "master", "capability-gates")
    const planned = fileFindings("vec-plan.md", skill(["Editing existing vector paths is not available in-app; describe the change for the user to make."]), "master", "capability-gates")
    const possessive = ["Edit the logo's vectors.", "Edit the logo’s vectors."].map((t, i) => fileFindings(`vec-poss-${i}.md`, skill([t]), "master", "capability-gates").length)
    const genPossessive = fileFindings("vec-gen-poss.md", skill(["Generate the logo's vector artwork in a new frame."]), "master", "capability-gates")
    return check([[gen.length === 0, `generate: ${JSON.stringify(gen)}`], [conv.length === 0, `convert: ${JSON.stringify(conv)}`],
      [edit.length === 1 && /vector path/.test(edit[0].message), `edit paths: ${JSON.stringify(edit)}`], [points.length === 1, `points: ${JSON.stringify(points)}`],
      [planned.length === 0, `plan-only: ${JSON.stringify(planned)}`], [possessive.every((n) => n === 1), `possessive edit (straight, curly): ${JSON.stringify(possessive)}`],
      [genPossessive.length === 0, `possessive generate: ${JSON.stringify(genPossessive)}`]])
  },
  "capability-gates: the rule's basis names editing existing vector paths, not vectors in general": () => {
    const r = spawnSync(process.execPath, [VALIDATOR, "--rules"], { encoding: "utf8" })
    const row = r.stdout.split("\n").find((l) => l.startsWith("capability-gates")) || ""
    return check([[/editing existing vector paths/.test(row) && /vector icons and illustrations/.test(row), `basis: ${row}`]])
  },

  // The helper-fence language: one definition, shared.
  "the validator decides helper fences only through HELPER_FENCE_LANG": () => {
    const src = readFileSync(VALIDATOR, "utf8")
    const own = src.split("\n").map((l, i) => [i + 1, l]).filter(([, l]) => /javascript\|js/.test(l) && !/^\s*\/\//.test(l))
    const caps = fileFindings("js-in-target.md", skill([], ["", "<!-- target:mcp -->", "## MCP", "", "```JS", "return 1;", "```", "<!-- /target -->"]), "master", "helper-placement")
    return check([[own.length === 0, `own fence-language patterns at ${JSON.stringify(own)}`], [caps.length === 1, `a JS fence in a target region: ${JSON.stringify(caps)}`]])
  },

  // check-all.mjs: what it runs, and that it never reads history/.
  "check-all --list names every check, one line each, and no history path": () => {
    const r = checkAll(creator, "--list")
    const want = ["changelog rows", "changelog cells", "changelog basis", "changelog order", "changelog review block",
      "examples/fm-spacing-rhythm-audit/SKILL.md", "examples/fm-figma-capability-probe/SKILL.md",
      ...["skill-master", "type-critique-review", "type-design-system-conventions", "type-generation-builder", "type-research-synthesis", "type-standards-qa-audit", "type-workflow-process"].map((t) => `templates/${t}.md`),
      ...["collect", "compare", "packs", "build", "checks"].map((h) => `tests/${h}.harness.mjs`),
      "roundtrip token-conformance", "roundtrip revert", "roundtrip token-conformance,revert", "report-scope2.md", "dist/claude/fm-spacing-rhythm-audit/scripts", "dist/claude/fm-figma-capability-probe/scripts"]
    const missing = want.filter((w) => !r.lines.some((l) => l.includes(w)))
    return check([[r.status === 0, `exit ${r.status}`], [missing.length === 0, `not listed: ${JSON.stringify(missing)}`],
      [!r.lines.some((l) => /[\\/]history[\\/]/.test(l)), "a listed check names a history path"]])
  },
  "check-all --only changelog passes on the committed changelog with five lines": () => {
    const r = checkAll(creator, "--only", "changelog")
    const pass = r.lines.filter((l) => /^PASS +changelog /.test(l))
    const one = checkAll(creator, "--only", "description")
    return check([[r.status === 0, `exit ${r.status}: ${r.lines.slice(-2).join(" | ")}`], [pass.length === 5, `${pass.length} changelog PASS lines`],
      [r.lines[r.lines.length - 1] === "check-all: 5 checks passed", `summary: ${r.lines[r.lines.length - 1]}`],
      [one.lines[one.lines.length - 1] === "check-all: 1 check passed", `one-check summary: ${one.lines[one.lines.length - 1]}`]])
  },
  "check-all --only changelog fails at the broken check, for each of the five": () => {
    const text = normalize(readFileSync(join(creator, "references", "figma-changelog.md"), "utf8"))
    const rows = text.split("\n").filter((l) => l.startsWith("| 20"))
    const breaks = {
      "changelog rows": () => text.split("\n").filter((l) => !l.startsWith("| 20") || rows.indexOf(l) < 10).join("\n"),
      "changelog cells": () => text.replace(rows[3], rows[3] + " extra |"),
      "changelog basis": () => text.replace(rows[4], rows[4].replace(/\| (documented|observed|secondary) \|$/, "| confirmed |")),
      "changelog order": () => text.replace(rows[0], "\u0000").replace(rows[rows.length - 1], rows[0]).replace("\u0000", rows[rows.length - 1]),
      "changelog review block": () => text.replace(/^- Last reviewed: .*$/m, (m) => `${m}\n${m}`),
    }
    const problems = []
    for (const [label, broken] of Object.entries(breaks)) {
      const root = scratchCreator(`changelog-${label.replace(/ /g, "-")}`, ["scripts", "references"])
      writeFileSync(join(root, "references", "figma-changelog.md"), broken())
      const r = checkAll(root, "--only", "changelog")
      const fail = r.lines.find((l) => l.startsWith("FAIL"))
      if (r.status !== 1 || !fail || !fail.includes(label)) problems.push(`${label}: exit ${r.status}, ${fail ?? "no FAIL line"}`)
    }
    return problems
  },
  // The committed lint config: history/ snapshots are git-ignored copies of masters, so the lint skips them.
  // Read only, never run: the lint is the separate npx command, and this harness needs Node alone. The
  // config is the repository root's, so a copy of the creator folder elsewhere skips this case.
  "the committed markdownlint config ignores history/ snapshots": () => {
    const path = join(creator, "..", "..", ".markdownlint-cli2.jsonc")
    if (!existsSync(path)) return { skip: `no repository-root .markdownlint-cli2.jsonc beside this creator folder (${path})` }
    const commented = parseJsonc('{\n  // a line comment\n  "ignores": ["a/**", /* a block comment */ "b//c"],\n}\n')
    let config
    try { config = parseJsonc(readFileSync(path, "utf8")) } catch (e) { return [`the committed config does not parse: ${e.message}`] }
    return check([[JSON.stringify(commented.ignores) === JSON.stringify(["a/**", "b//c"]), `the JSONC reader: ${JSON.stringify(commented)}`],
      [Array.isArray(config.ignores) && config.ignores.includes("**/history/**"), `ignores: ${JSON.stringify(config.ignores)}`]])
  },
  "check-all fails a build that rewrites a stale dist/, naming the first file that changed": () => {
    const root = scratchCreator("stale-dist", ["scripts", "enhancements", "references", "examples/fm-spacing-rhythm-audit", "examples/fm-figma-capability-probe"])
    const fresh = checkAll(root, "--only", "builds")
    const stale = join(root, "examples", "fm-spacing-rhythm-audit", "dist", "fm-spacing-rhythm-audit.paste.fields.txt")
    writeFileSync(stale, readFileSync(stale, "utf8") + "stale line\n")
    const r = checkAll(root, "--only", "builds")
    const fail = r.lines.find((l) => l.startsWith("FAIL")) || ""
    return check([[fresh.status === 0, `a current dist/: exit ${fresh.status}: ${fresh.lines.slice(-2).join(" | ")}`],
      [r.status === 1 && fail.includes("build examples/fm-spacing-rhythm-audit/SKILL.md") && /stale/.test(fail) && fail.includes("fm-spacing-rhythm-audit.paste.fields.txt"), `stale dist/: exit ${r.status}: ${fail}`]])
  },
  "check-all never reads a history/ folder: a broken snapshot beside each master changes nothing": () => {
    const root = scratchCreator("history-guard", ["scripts", "enhancements", "references", "examples/fm-spacing-rhythm-audit/SKILL.md", "examples/fm-figma-capability-probe/SKILL.md"])
    for (const ex of ["fm-spacing-rhythm-audit", "fm-figma-capability-probe"]) {
      mkdirSync(join(root, "examples", ex, "history", "0.1"), { recursive: true })
      writeFileSync(join(root, "examples", ex, "history", "0.1", "SKILL.md"), "not a skill: no frontmatter, no sections\n")
    }
    const r = checkAll(root, "--only", "masters")
    const guard = r.lines.find((l) => /history/.test(l)) || ""
    return check([[r.status === 0, `exit ${r.status}: ${r.lines.slice(-2).join(" | ")}`], [r.lines.filter((l) => l.startsWith("PASS")).length === 3, `PASS lines: ${JSON.stringify(r.lines)}`],
      [/no path under a history\/ folder/.test(guard) && r.lines.filter((l) => /history/.test(l)).length === 1, `history lines: ${JSON.stringify(r.lines.filter((l) => /history/.test(l)))}`]])
  },
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

// A case returns its failed messages, or { skip: reason } when what it reads is absent here.
let failed = 0, skipped = 0
try {
  for (const [name, run] of Object.entries(cases)) {
    let problems
    try {
      problems = run()
    } catch (e) {
      problems = ["threw: " + (e && e.message ? e.message : String(e))]
    }
    if (problems && !Array.isArray(problems) && problems.skip) { skipped++; console.log(`SKIP ${name} (${problems.skip})`); continue }
    if (problems.length) failed++
    console.log((problems.length ? "FAIL " : "PASS ") + name + (problems.length ? "\n  - " + problems.join("\n  - ") : ""))
  }
} finally {
  rmSync(tmp, { recursive: true, force: true })
}
const total = Object.keys(cases).length
console.log(`${total} cases, ${skipped ? `${skipped} skipped, ` : ""}${failed} failed`)
process.exit(failed ? 1 : 0)
