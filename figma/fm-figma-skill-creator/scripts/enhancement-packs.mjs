#!/usr/bin/env node
// enhancement-packs.mjs — list, strip, extract, expand, and round-trip the enhancement packs of a Figma skill master.
//
// Usage:
//   node enhancement-packs.mjs list <SKILL.md> [--pack <name>]... [--enhancements <dir>]
//   node enhancement-packs.mjs strip <SKILL.md> --pack <name> [--pack <name>]... [--out <file>] [--enhancements <dir>]
//   node enhancement-packs.mjs extract <SKILL.md> [--pack <name>]... [--phrase "<Phrase:>"] [--enhancements <dir>]
//   node enhancement-packs.mjs expand <SKILL.md> --pack <name> [--pack <name>]... [--out <file>] [--enhancements <dir>]
//   node enhancement-packs.mjs roundtrip <SKILL.md> --pack <name>[,<name>]... [--enhancements <dir>]
//
// list       prints each pack's units: kind, section, helper, start line, and the first 60 characters,
//            then the count per kind.
// strip      removes every unit of each --pack (in the order given), applies its line rewrites, drops its
//            description sentences and metadata tags, collapses blank runs, and writes --out (standard
//            output when --out is absent).
// extract    writes enhancements/<name>/enhancement.md from the master: a header, then one level-three
//            heading per unit with its anchor and text. pack.json is hand-maintained and written only
//            when absent, as a skeleton that needs --phrase (with exactly one --pack).
// expand     inserts the units each pack's enhancement.md records, each after its anchor, all packs in one
//            pass; a unit with no anchor falls back per rule (h) with one "expand warning:" line on
//            standard error. Refuses a master that already carries units of a named pack.
// roundtrip  strips the packs from the master in the order given, inserts the stripped units again in
//            reverse order, and compares with the input (LF-normalised). Exit 0 only when the result is
//            byte-identical and every item the packs declare was found; otherwise it names the first
//            differing line or the declared item that is missing, and exits 1.
//
// --pack takes one name or a comma-separated list, and repeats. Packs resolve from
// enhancements/<name>/pack.json beside this scripts folder, or from --enhancements. Without --pack,
// list and extract use every pack folder there, in name order. Output carries no timestamp, so a
// second extract changes nothing. The rules are in references/enhancement-packs.md.
//
// Exit 0 on success, 1 on a contract error (nested regions, an ambiguous declared line, a pack.json
// problem), a master that already carries the pack (expand), or a failed round trip, 2 on bad
// arguments or an unreadable master or enhancement.md. Declared items the master lacks are warnings
// on standard error. Dependency-free, Node 18+.

import { readFileSync, writeFileSync, existsSync, readdirSync, mkdirSync, statSync } from "node:fs"
import { join, dirname, resolve, relative, basename, sep } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize, parseFrontmatter, getField } from "./lib/skill-md.mjs"
import { loadPack, findUnits, stripUnits, readUnits, insertUnits, UNIT_KINDS } from "./lib/enhancements.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const args = process.argv.slice(2)
const command = args[0]

function usage(code) {
  console.log(`Usage: node enhancement-packs.mjs list <SKILL.md> [--pack <name>]... [--enhancements <dir>]
       node enhancement-packs.mjs strip <SKILL.md> --pack <name> [--pack <name>]... [--out <file>] [--enhancements <dir>]
       node enhancement-packs.mjs extract <SKILL.md> [--pack <name>]... [--phrase "<Phrase:>"] [--enhancements <dir>]
       node enhancement-packs.mjs expand <SKILL.md> --pack <name> [--pack <name>]... [--out <file>] [--enhancements <dir>]
       node enhancement-packs.mjs roundtrip <SKILL.md> --pack <name>[,<name>]... [--enhancements <dir>]`)
  process.exit(code)
}
function die(code, msg) { console.error(`enhancement-packs: ${msg}`); process.exit(code) }

const COMMANDS = ["list", "strip", "extract", "expand", "roundtrip"]
if (!command || args.includes("--help") || args.includes("-h")) usage(command ? 0 : 2)
if (!COMMANDS.includes(command)) die(2, `unknown command "${command}"; expected list, strip, extract, expand, or roundtrip`)

// Flags: --pack repeats and takes a comma-separated list; the others take one value.
const packNames = []
const flags = {}
let masterArg = null
for (let i = 1; i < args.length; i++) {
  const a = args[i]
  if (["--pack", "--out", "--enhancements", "--phrase"].includes(a)) {
    if (i + 1 >= args.length) die(2, `${a} needs a value`)
    if (a === "--pack") packNames.push(...args[++i].split(",").map((n) => n.trim()).filter(Boolean)); else flags[a] = args[++i]
  } else if (a.startsWith("--")) die(2, `unknown flag ${a}`)
  else if (masterArg === null) masterArg = a
  else die(2, `unexpected argument ${a}`)
}
if (!masterArg) die(2, "missing the master path")
const masterAbs = resolve(masterArg)
if (!existsSync(masterAbs)) die(2, `master not found: ${masterArg}`)
const enhancementsDir = resolve(flags["--enhancements"] ?? join(here, "..", "enhancements"))
const warn = (m) => console.error(`warning: ${m}`)

function main() {
  const master = normalize(readFileSync(masterAbs, "utf8")).split("\n")
  if (["strip", "expand", "roundtrip"].includes(command) && packNames.length === 0) die(2, `${command} needs at least one --pack`)
  if (command === "extract") prepareSkeleton()
  const names = packNames.length ? packNames : listPackFolders()
  if (names.length === 0) die(2, `no packs in ${enhancementsDir}`)
  const packs = names.map((n) => {
    const dir = join(enhancementsDir, n)
    if (!existsSync(join(dir, "pack.json"))) die(2, `no pack "${n}" (missing ${join(dir, "pack.json")})`)
    return loadPack(dir)
  })
  if (command === "list") list(master, packs)
  else if (command === "strip") strip(master, packs)
  else if (command === "expand") expand(master, packs)
  else if (command === "roundtrip") roundtrip(master, packs)
  else extract(master, packs)
}

// ---------------------------------------------------------------------------

function listPackFolders() {
  if (!existsSync(enhancementsDir)) return []
  return readdirSync(enhancementsDir)
    .filter((n) => statSync(join(enhancementsDir, n)).isDirectory() && existsSync(join(enhancementsDir, n, "pack.json")))
    .sort()
}

const oneLine = (s, n) => s.replace(/\s+/g, " ").trim().slice(0, n)
const byKind = (units) => UNIT_KINDS.map((k) => [k, units.filter((u) => u.kind === k).length]).filter(([, c]) => c > 0)
const kindSummary = (units) => byKind(units).map(([k, c]) => `${k} ${c}`).join(", ")

function list(master, packs) {
  for (const pack of packs) {
    const units = findUnits(master, pack, { warn })
    console.log(`${pack.name}: ${units.length} units (${kindSummary(units) || "none"})`)
    console.log(`| # | Kind | Section | Helper | Line | Text |`)
    console.log(`| --- | --- | --- | --- | --- | --- |`)
    units.forEach((u, i) => {
      const text = oneLine(u.text, 60).replace(/\|/g, "\\|")
      console.log(`| ${i + 1} | ${u.kind} | ${u.anchor.section || "-"} | ${u.anchor.helper ?? "-"} | ${u.start + 1} | ${text} |`)
    })
    console.log("")
  }
}

function strip(master, packs) {
  let lines = master
  for (const pack of packs) {
    const units = findUnits(lines, pack, { warn })
    lines = stripUnits(lines, units)
    console.error(`stripped ${pack.name}: ${units.length} units (${kindSummary(units) || "none"})`)
  }
  emit(lines)
}

/** Write the lines to --out, or to standard output when --out is absent. */
function emit(lines) {
  const text = lines.join("\n") + "\n"
  if (flags["--out"]) {
    mkdirSync(dirname(resolve(flags["--out"])), { recursive: true })
    writeFileSync(resolve(flags["--out"]), text, "utf8")
    console.error(`wrote ${flags["--out"]}`)
  } else process.stdout.write(text)
}

/** The master's frontmatter name, or null. */
function skillName(lines) {
  const fm = parseFrontmatter(lines)
  const f = fm.present ? getField(fm.fields, "name") : null
  return f && typeof f.value === "string" ? f.value.trim() : null
}

function expand(master, packs) {
  const units = []
  for (const pack of packs) {
    // Carrying the pack means its phrase or its code region; a declared line alone (a bare table
    // separator, say) can occur in any master.
    const present = findUnits(master, pack).filter((u) => ["code-region", "fence", "block", "heading-block", "sentence"].includes(u.kind))
    if (present.length) die(1, `the master already carries ${present.length} units of ${pack.name} (${kindSummary(present)}); strip it first`)
    const file = join(enhancementsDir, pack.name, "enhancement.md")
    if (!existsSync(file)) die(2, `no ${file}; run extract first`)
    const read = readUnits(readFileSync(file, "utf8"))
    // The skill the pack was extracted from: the folder of the master its enhancement.md names.
    const source = read.source ? basename(dirname(read.source)) : ""
    for (const u of read.units) units.push({ ...u, pack: pack.name, source })
  }
  // The split of a file that ends in a newline ends in one empty element; emit() writes that newline back.
  const body = master[master.length - 1] === "" ? master.slice(0, -1) : master
  const lines = insertUnits(body, units, { warn: (m) => console.error(`expand warning: ${m}`), skill: skillName(master) })
  console.error(`expanded ${packs.map((p) => p.name).join(", ")}: ${units.length} units (${kindSummary(units) || "none"})`)
  emit(lines)
}

function roundtrip(master, packs) {
  const names = packs.map((p) => p.name).join(",")
  let lines = master
  let missing = 0
  const steps = []
  for (const pack of packs) {
    const units = findUnits(lines, pack, { warn: (m) => { missing++; console.error(`roundtrip: ${m}`) } })
    steps.push({ pack, units })
    lines = stripUnits(lines, units)
  }
  // Each pack's units were found on the master as it stood before that pack was stripped, so they go
  // back in the reverse order.
  for (const { pack, units } of steps.slice().reverse()) {
    lines = insertUnits(lines, units.map((u) => ({ ...u, pack: pack.name })), { warn: (m) => console.error(`expand warning: ${m}`) })
  }
  const input = master.join("\n").split("\n"), output = (lines.join("\n") + "\n").split("\n")
  let at = 0
  while (at < input.length && at < output.length && input[at] === output[at]) at++
  const same = at === input.length && at === output.length
  const count = steps.map((s) => `${s.pack.name} ${s.units.length}`).join(", ")
  if (!same) {
    const show = (l) => (l === undefined ? "<end of file>" : JSON.stringify(l).slice(0, 160))
    console.error(`roundtrip ${names}: differs from the input at line ${at + 1}`)
    console.error(`  input:  ${show(input[at])}`)
    console.error(`  output: ${show(output[at])}`)
  }
  if (missing) console.error(`roundtrip ${names}: ${missing} declared item${missing === 1 ? "" : "s"} not found in the master (listed above); the pack declarations no longer match it`)
  if (!same || missing) process.exit(1)
  console.log(`roundtrip ${names}: byte-identical; units stripped and restored: ${count}`)
}

/** extract with --phrase: write a skeleton pack.json for the one named pack when it has none. */
function prepareSkeleton() {
  const phrase = flags["--phrase"]
  if (phrase === undefined) return
  if (packNames.length !== 1) die(2, "--phrase needs exactly one --pack")
  const dir = join(enhancementsDir, packNames[0])
  if (existsSync(join(dir, "pack.json"))) { warn(`${packNames[0]}/pack.json exists and is hand-maintained; --phrase ignored`); return }
  const skeleton = {
    name: packNames[0], phrase, codeRegion: packNames[0], templateLines: [], lineRewrites: [], descriptionSentences: [], tags: [],
    requires: [], conflicts: [], cost: "", seedCase: { file: "", nodes: [], expectedScope: null },
  }
  mkdirSync(dir, { recursive: true })
  writeFileSync(join(dir, "pack.json"), JSON.stringify(skeleton, null, 2) + "\n", "utf8")
  console.error(`wrote ${relative(process.cwd(), join(dir, "pack.json"))} (skeleton; fill in the declarations by hand)`)
}

function extract(master, packs) {
  // The master's path as the skill folder sees it (forward slashes), never an absolute path.
  const rel = relative(dirname(enhancementsDir), masterAbs)
  const source = (rel.startsWith("..") || resolve(rel) === rel ? join(basename(dirname(masterAbs)), basename(masterAbs)) : rel).split(sep).join("/")
  for (const pack of packs) {
    const units = findUnits(master, pack, { warn })
    const out = renderPack(pack, units, source)
    const file = join(enhancementsDir, pack.name, "enhancement.md")
    writeFileSync(file, out.join("\n") + "\n", "utf8")
    console.error(`wrote ${relative(process.cwd(), file) || file}: ${units.length} units (${kindSummary(units) || "none"})`)
  }
}

// ---------------------------------------------------------------------------
// enhancement.md
// ---------------------------------------------------------------------------

/** A fence around `text`, longer than any backtick run inside it. */
function fenced(lang, text) {
  const longest = Math.max(0, ...(text.match(/`+/g) || []).map((r) => r.length))
  const bar = "`".repeat(Math.max(3, longest + 1))
  return [bar + lang, ...text.split("\n"), bar]
}

const LANG = {
  "code-region": "javascript", fence: "markdown", "line-rewrite": "javascript",
  block: "markdown", "heading-block": "markdown", sentence: "markdown", "prose-sentence": "markdown", "template-line": "markdown",
  "description-sentence": "text", tag: "text",
}
const code = (s) => (s.includes("`") ? `"${s}"` : `\`${s}\``)
const listOf = (a) => (a.length ? a.map(code).join(", ") : "none")

function renderPack(pack, units, source) {
  const seed = pack.seedCase
  const seedLine = seed && seed.file
    ? `${code(seed.file)}, nodes ${seed.nodes.join(", ")}; expected scope ${seed.expectedScope}${seed.proofs?.length ? `; proofs ${seed.proofs.map(code).join(", ")}` : ""}`
    : "none yet"
  const out = [
    `# Enhancement pack: ${pack.name}`,
    "",
    `Generated by \`scripts/enhancement-packs.mjs extract\` from \`${source}\`. Do not edit it by hand: change the master and run \`extract\` again. The tag rules are in \`references/enhancement-packs.md\`; the declarations are in \`pack.json\` beside this file.`,
    "",
    `- Name: ${code(pack.name)}`,
    `- Phrase: ${code(pack.phrase)}`,
    `- Code region: ${code(pack.codeRegion)}`,
    `- Cost: ${pack.cost || "not stated"}`,
    `- Requires: ${listOf(pack.requires)}`,
    `- Conflicts: ${listOf(pack.conflicts)}`,
    `- Surfaces: ${pack.surfaces.map(code).join(", ")}${pack.surfacesDeclared ? "" : " (the default)"}`,
    `- Seed case: ${seedLine}`,
    `- Units: ${units.length} (${kindSummary(units) || "none"})`,
    "",
    "## Units",
  ]
  units.forEach((u, i) => {
    const lines = u.start === u.end ? `Master line ${u.start + 1}` : `Master lines ${u.start + 1} to ${u.end + 1}`
    out.push("", `### Unit ${i + 1}: ${u.kind} in ${u.anchor.section || "the preamble"}`, "", `${lines}${u.col ? `, column ${u.col + 1}` : ""}. Anchor:`, "")
    out.push(...fenced("json", JSON.stringify(u.anchor, null, 2)), "")
    if (u.kind === "line-rewrite") {
      out.push("With the pack:", "", ...fenced(LANG[u.kind], u.text), "", "Without the pack:", "", ...fenced(LANG[u.kind], u.to))
    } else {
      out.push("Text:", "", ...fenced(LANG[u.kind], u.text))
    }
  })
  return out
}

// Run last, after every declaration above is initialised.
try { main() } catch (e) { die(1, e.message) }
