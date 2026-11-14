#!/usr/bin/env node
// build-skill-editions.mjs — build the three shipping editions of a Figma skill from one master,
// or flatten a multi-file coding-agent skill into one file for the reverse direction.
//
// Usage:
//   node build-skill-editions.mjs <SKILL.md> [--out dist/] [--overlay overlay.claude.yaml] [--validate] [--dry-run]
//   node build-skill-editions.mjs --flatten <skill-dir> [--out dist/] [--dry-run]
//
// Editions written (first form), where <name> is the master's frontmatter name:
//   <out>/<name>.figma.md            upload edition: figma-app sections kept, mcp sections and all
//                                    markers removed, frontmatter reduced to name + description
//   <out>/<name>.paste.md            Start-from-scratch edition: same body, no frontmatter
//   <out>/<name>.paste.fields.txt    the name and description to type into the Start-from-scratch form
//   <out>/claude/<name>/SKILL.md     coding-agent edition: mcp sections kept, figma-app removed,
//                                    overlay merged into the frontmatter; references/ copied beside it
//   <out>/claude/<name>/scripts/<helper>.js
//                                    one file per core `## Helper scripts` fence whose first line is
//                                    `// helper: <helper>`; the fence becomes a one-line pointer in
//                                    the coding-agent SKILL.md. The Figma editions keep every fence.
//                                    The build owns that scripts/ folder: stale *.js files are pruned.
//                                    Each helper must parse (checked with new Function before any write).
//   <out>/<name>.manifest.json       derived record: the master's metadata, each edition's path, body
//                                    lines and estimated tokens, the helpers, the enhancement regions in
//                                    core helpers, metadata.cost, the newest EVAL-LOG.md entry, and the
//                                    master's path relative to <out>. No timestamp, commit, or absolute
//                                    path, so a rebuild is byte-identical. Nothing at runtime reads it.
//   history/<metadata.version>/SKILL.md (and overlay.claude.yaml when the overlay exists), beside the
//                                    master: byte copies, so a folder outside any repository keeps every
//                                    version built. A rebuild at the same version overwrites that
//                                    snapshot; the build never reads, lists, or deletes other history folders.
// The manifest is written with the editions; the history snapshot only by a build that exits 0. A dry
// run writes neither. Neither starts a process; --validate runs the validator as a child process.
//
// Flatten (second form) reads <skill-dir>/SKILL.md plus references/*.md and writes
// <out>/<name>.flat.md with every referenced Markdown file appended as a section and links
// rewritten to point at those sections. scripts/ and assets/ are listed for manual conversion.
//
// Dependency-free. Markers: <!-- target:figma-app --> ... <!-- /target --> and <!-- target:mcp -->.
// Helper fences are found by the shared rule (helperFences in lib/enhancements.mjs): a ``` or ~~~ fence
// whose info string's first word is javascript or js, so "```javascript linenums" counts.
//
// Exit 1 on a build error, before anything is written: unbalanced target markers, a malformed
// enhancement region marker (a begin with no end, nested or interleaved regions), a missing
// name/description, a master or overlay that is missing or not a file, or an unreadable overlay.

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, copyFileSync, statSync, unlinkSync, rmdirSync } from "node:fs"
import { join, dirname, basename, resolve, relative, extname, isAbsolute } from "node:path"
import { spawnSync } from "node:child_process"
import { fileURLToPath } from "node:url"
import {
  normalize, parseFrontmatter, parseYamlSubset, getField, scanRegions, selectTarget,
  serializeFrontmatter, mergeFields, collapseBlankRuns, wordCount, estimateTokens, scanFences,
  HELPER_FENCE_LANG, HELPER_MARKER,
} from "./lib/skill-md.mjs"
import { scanCodeRegions, helperFences } from "./lib/enhancements.mjs"

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const args = process.argv.slice(2)
function opt(name, fallback = null) {
  const i = args.indexOf(name)
  return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback
}
const flattenDir = opt("--flatten")
const outDir = opt("--out", "dist")
const overlayArg = opt("--overlay")
const dryRun = args.includes("--dry-run")
const doValidate = args.includes("--validate")
const consumed = new Set([flattenDir, outDir, overlayArg].filter(Boolean))
const masterPath = args.find((a) => !a.startsWith("--") && !consumed.has(a))

if (args.includes("--help") || args.includes("-h") || (!masterPath && !flattenDir)) {
  console.log(`Usage: node build-skill-editions.mjs <SKILL.md> [--out dist/] [--overlay overlay.claude.yaml] [--validate] [--dry-run]
       node build-skill-editions.mjs --flatten <skill-dir> [--out dist/] [--dry-run]`)
  process.exit(masterPath || flattenDir ? 0 : 1)
}

const here = dirname(fileURLToPath(import.meta.url))
const validatorPath = join(here, "validate-figma-skill.mjs")
const written = []

function fail(msg) { console.error(`build error: ${msg}`); process.exit(1) }

function emit(path, lines) {
  const text = lines.join("\n") + "\n"
  written.push({ path, lines: lines.length, words: wordCount(lines) })
  if (dryRun) return text
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, text, "utf8")
  return text
}

// ---------------------------------------------------------------------------
// Helper extraction (coding-agent edition only)
// ---------------------------------------------------------------------------

const HELPER_HEADING = /^##\s+Helper scripts\s*$/i
const helperPointer = (name) => `The ${name} helper is \`scripts/${name}.js\` in this folder.`

/**
 * Inside the core `## Helper scripts` section only, replace each javascript fence (``` or ~~~,
 * info string starting with `javascript` or `js`, as the validator accepts) whose first body line is
 * `// helper: <name>` with a one-line pointer. Fences without the marker stay inline.
 * Returns { lines, helpers: [{ name, code, open }] } where code is the fence body minus the marker line
 * and open is the body index of the fence's opening line.
 */
function extractHelpers(body) {
  const fence = scanFences(body)
  const { regionAt } = scanRegions(body)
  // Fences by the shared rule (helperFences, over fenceBlocks): the language is the first word of the
  // info string, so "```javascript linenums" is a javascript fence here as in the validator and the packs.
  const fenceAt = new Map(helperFences(body).map((f) => [f.open, f]))
  const out = []
  const helpers = []
  let inSection = false
  for (let i = 0; i < body.length; i++) {
    const line = body[i]
    // Section bounds: the core heading opens it; the next H1 or H2 outside a fence closes it.
    if (!fence[i] && /^#{1,2}\s/.test(line)) inSection = HELPER_HEADING.test(line) && regionAt(i) === "core"
    const f = inSection && regionAt(i) === "core" ? fenceAt.get(i) : undefined
    const open = f && HELPER_FENCE_LANG.test(f.lang) ? f : null
    const marker = open && i + 1 < body.length ? HELPER_MARKER.exec(body[i + 1]) : null
    // Near miss: starts like a marker but fails the strict form; warn and keep the fence inline.
    if (open && !marker && i + 1 < body.length && body[i + 1].startsWith("// helper:")) {
      console.warn(`build warning: body line ${i + 2}: "${body[i + 1]}" is not a valid helper marker (// helper: <lowercase-name>); fence left inline`)
    }
    if (!marker) { out.push(line); continue }
    if (open.close === -1) fail(`helper fence "${marker[1]}" at body line ${i + 1} is never closed`)
    const close = open.close
    if (helpers.some((h) => h.name === marker[1])) fail(`duplicate helper name "${marker[1]}" at body line ${i + 2}`)
    const code = body.slice(i + 2, close)
    if (!code.some((l) => l.trim() !== "")) fail(`helper "${marker[1]}" has no code`)
    // Parse check (never run). The top-level form (top-level `await`, a final `return`, no wrapper) is
    // canonical and parses as an async function body; the old wrapped form is only tolerated, and it
    // parses as a plain function body. A clean parse proves syntax, not the form.
    const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
    try { new Function(code.join("\n")) } catch (e1) {
      try { new AsyncFunction(code.join("\n")) } catch (e2) { fail(`helper "${marker[1]}" does not parse: ${e2.message}`) }
    }
    helpers.push({ name: marker[1], code, open: i })
    out.push(helperPointer(marker[1]))
    i = close
  }
  return { lines: out, helpers }
}

/**
 * The build owns dist/claude/<name>/scripts/: delete every *.js there that this build did not
 * write, then remove the folder when no helpers were written and it is empty. Returns the number
 * of stale files removed (counted, not deleted, on --dry-run).
 */
function pruneStaleScripts(scriptsDir, helpers) {
  if (!existsSync(scriptsDir) || !statSync(scriptsDir).isDirectory()) return 0
  const keep = new Set(helpers.map((h) => `${h.name}.js`))
  const stale = readdirSync(scriptsDir).filter((f) => f.endsWith(".js") && !keep.has(f) && statSync(join(scriptsDir, f)).isFile())
  if (dryRun) return stale.length
  for (const f of stale) unlinkSync(join(scriptsDir, f))
  if (helpers.length === 0 && readdirSync(scriptsDir).length === 0) rmdirSync(scriptsDir)
  return stale.length
}

// ---------------------------------------------------------------------------
// Manifest and history (derived only; nothing at runtime reads either)
// ---------------------------------------------------------------------------

/** A path from `from` to `to` with forward slashes; null, with a warning, when no relative path exists. */
function relPosix(from, to) {
  const r = relative(from, to)
  if (isAbsolute(r)) { console.warn(`build warning: ${basename(to)} has no path relative to ${basename(from)} (another drive); the manifest records null`); return null }
  return r.replace(/\\/g, "/")
}

/**
 * Body lines and estimated tokens of an edition's text, counted as the validator counts them: the text
 * split on newlines, the lines after the frontmatter block when there is one, wordCount, estimateTokens.
 */
function editionSize(text) {
  const all = text.split("\n")
  const fm = parseFrontmatter(all)
  const body = all.slice(fm.present ? fm.closeLine + 1 : 0)
  return { bodyLines: body.length, approxTokens: estimateTokens(wordCount(body)) }
}

/**
 * The newest entry of an eval log: the first level-three heading under its `## Entries` heading, and a
 * YYYY-MM-DD found in that heading. A heading that still holds an unfilled <...> placeholder (the
 * template's) is skipped. Nulls when the file, the section, or an entry is missing.
 */
function readEvalStatus(path) {
  const none = { lastEntry: null, date: null }
  if (!existsSync(path)) return none
  const lines = normalize(readFileSync(path, "utf8")).split("\n")
  const fence = scanFences(lines)
  let inEntries = false
  for (let i = 0; i < lines.length; i++) {
    const h = !fence[i] && /^(#{1,6})\s+(.*?)\s*$/.exec(lines[i])
    if (!h) continue
    if (h[1].length <= 2) {
      if (inEntries) return none
      inEntries = h[1].length === 2 && /^entries$/i.test(h[2])
    } else if (inEntries && h[1].length === 3) {
      // An entry heading still holding an unfilled <...> placeholder is the template's, not an entry.
      if (/<[^>]+>/.test(h[2])) continue
      const date = /\d{4}-\d{2}-\d{2}/.exec(h[2])
      return { lastEntry: h[2], date: date ? date[0] : null }
    }
  }
  return none
}

/**
 * Copy the master, and the overlay when there is one, to history/<version>/ beside the master, where
 * <version> is metadata.version verbatim. Returns the folder and the files copied, or null (with a
 * warning) when the version is missing or cannot be a folder name.
 */
function writeHistory(masterAbs, overlayPath, version) {
  if (version === null || version === "" || version === "." || version === ".." || /[\\/:*?"<>|\x00-\x1f]/.test(version)) {
    console.warn(`build warning: metadata.version ${version === null ? "is missing" : `"${version}" cannot be a folder name`}; no history snapshot written`)
    return null
  }
  const dir = join(dirname(masterAbs), "history", version)
  mkdirSync(dir, { recursive: true })
  copyFileSync(masterAbs, join(dir, "SKILL.md"))
  const files = ["SKILL.md"]
  if (overlayPath && existsSync(overlayPath)) { copyFileSync(overlayPath, join(dir, "overlay.claude.yaml")); files.push("overlay.claude.yaml") }
  return { dir, files }
}

// ---------------------------------------------------------------------------
// Build editions from a master
// ---------------------------------------------------------------------------

function buildEditions(master) {
  const masterAbs = resolve(master)
  if (!existsSync(masterAbs)) fail(`master not found: ${master}`)
  if (!statSync(masterAbs).isFile()) fail(`master is not a file: ${master}`)
  const lines = normalize(readFileSync(masterAbs, "utf8")).split("\n")
  const fm = parseFrontmatter(lines)
  if (!fm.present) fail("master has no frontmatter block on line 1")
  for (const iss of fm.issues) fail(`frontmatter line ${iss.line}: ${iss.message}`)
  const nameF = getField(fm.fields, "name")
  const descF = getField(fm.fields, "description")
  if (!nameF || !nameF.value) fail("frontmatter has no name")
  if (!descF || !descF.value) fail("frontmatter has no description")
  const name = String(nameF.value).trim()
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name) || name.length > 64) {
    fail(`name "${name}" is not a valid skill name (lowercase letters, digits, single hyphens, 1-64 chars); replace template placeholders first`)
  }

  const body = lines.slice(fm.closeLine + 1)
  const { issues, regions } = scanRegions(body)
  for (const iss of issues) fail(`marker problem at body line ${iss.line}: ${iss.message}`)
  for (const r of regions) if (!["figma-app", "mcp"].includes(r.target)) fail(`unknown target "${r.target}" at body line ${r.open + 1}`)

  // Overlay: explicit path, else overlay.claude.yaml beside the master, else none.
  let overlayFields = []
  const overlayPath = overlayArg ? resolve(overlayArg) : join(dirname(masterAbs), "overlay.claude.yaml")
  if (existsSync(overlayPath)) {
    if (!statSync(overlayPath).isFile()) fail(`overlay is not a file: ${overlayArg ?? basename(overlayPath)}`)
    const oIssues = []
    overlayFields = parseYamlSubset(normalize(readFileSync(overlayPath, "utf8")).split("\n"), 0, oIssues)
    for (const iss of oIssues) fail(`overlay ${basename(overlayPath)} line ${iss.line}: ${iss.message}`)
    // The overlay may never rename the skill or rewrite its description.
    overlayFields = overlayFields.filter((f) => !["name", "description"].includes(f.key))
  } else if (overlayArg) {
    fail(`overlay not found: ${overlayArg}`)
  }

  const figmaBody = selectTarget(body, ["figma-app"])
  // Coding-agent body: core helper fences move to scripts/<helper>.js before target selection.
  const { lines: agentBody, helpers } = extractHelpers(body)
  const mcpBody = selectTarget(agentBody, ["mcp"])

  // Enhancement regions in core helpers, for the manifest, read through the pack library's one scan.
  // A region contract error stops the build before anything is written.
  let codeRegions
  try { codeRegions = scanCodeRegions(lines) } catch (e) { fail(`enhancement region problem at master ${e.message}`) }
  const coreHelperOpens = new Set(helpers.map((h) => h.open + fm.closeLine + 1))
  const enhancements = [...new Set(codeRegions.filter((r) => r.fence && coreHelperOpens.has(r.fence.open)).map((r) => r.name))].sort()

  // Upload edition: name + description only. Figma's tolerance for other keys is unverified.
  const uploadFm = serializeFrontmatter([
    { key: "name", value: name, quoted: false },
    { key: "description", value: String(descF.value).trim(), quoted: descF.quoted },
  ])
  const uploadPath = join(outDir, `${name}.figma.md`)
  const uploadText = emit(uploadPath, [...uploadFm, "", ...figmaBody])

  // Paste edition: body only, plus a fields file holding what the Start-from-scratch form asks for.
  const pastePath = join(outDir, `${name}.paste.md`)
  const pasteText = emit(pastePath, figmaBody)
  emit(join(outDir, `${name}.paste.fields.txt`), [
    "Start from scratch: type these into the form. Paste only the .paste.md body into Instructions.",
    "",
    `name: ${name}`,
    "",
    "description (max 1024 chars):",
    String(descF.value).trim(),
  ])

  // Coding-agent edition: full frontmatter merged with the overlay, folder named after the skill.
  const claudeFm = serializeFrontmatter(mergeFields(fm.fields, overlayFields))
  const claudeDir = join(outDir, "claude", name)
  const agentPath = join(claudeDir, "SKILL.md")
  const agentText = emit(agentPath, [...claudeFm, "", ...mcpBody])
  for (const h of helpers) emit(join(claudeDir, "scripts", `${h.name}.js`), h.code)
  const pruned = pruneStaleScripts(join(claudeDir, "scripts"), helpers)

  // Copy references/ (coding-agent only) when the master has one.
  const refDir = join(dirname(masterAbs), "references")
  if (existsSync(refDir) && statSync(refDir).isDirectory()) {
    for (const f of readdirSync(refDir)) {
      const src = join(refDir, f)
      if (!statSync(src).isFile()) continue
      written.push({ path: join(claudeDir, "references", f), copied: true })
      if (!dryRun) { mkdirSync(join(claudeDir, "references"), { recursive: true }); copyFileSync(src, join(claudeDir, "references", f)) }
    }
  }

  // Summary for the operator.
  console.log(`built ${name} from ${relative(process.cwd(), masterAbs) || masterAbs}${dryRun ? " (dry run)" : ""}`)
  for (const w of written) {
    console.log(`  ${relative(process.cwd(), w.path) || w.path}${w.copied ? "  (copied)" : `  ${w.lines} lines, ${w.words} words`}`)
  }
  console.log(`  helpers: ${helpers.length} scripts${helpers.length ? ` (${helpers.map((h) => h.name).join(", ")})` : ""}${pruned ? `; pruned ${pruned} stale` : ""}`)
  console.log(`\nStart-from-scratch fields (type these into Figma's form for the paste edition):`)
  console.log(`  name:        ${name}`)
  console.log(`  description: ${String(descF.value).trim()}`)

  // Manifest: every value derived from the master, its editions, or the eval log beside it.
  const meta = getField(fm.fields, "metadata")
  const metaValue = (key) => { const c = meta?.children?.find((x) => x.key === key); return c ? String(c.value) : null }
  const metaList = (key) => (metaValue(key) ?? "").split(",").map((s) => s.trim()).filter(Boolean)
  const outAbs = resolve(outDir)
  const manifest = {
    schemaVersion: "1",
    type: "skill",
    name,
    description: String(descF.value).trim(),
    version: metaValue("version"),
    author: metaValue("author"),
    category: metaValue("category"),
    tags: metaList("tags"),
    appliesTo: metaList("applies-to"),
    runtimes: metaList("runtimes"),
    editions: {
      upload: { path: relPosix(outAbs, resolve(uploadPath)), ...editionSize(uploadText) },
      paste: { path: relPosix(outAbs, resolve(pastePath)), ...editionSize(pasteText) },
      codingAgent: { path: relPosix(outAbs, resolve(agentPath)), ...editionSize(agentText), helpers: helpers.map((h) => h.name).sort() },
    },
    enhancements,
    cost: metaValue("cost"),
    evalStatus: readEvalStatus(join(dirname(masterAbs), "EVAL-LOG.md")),
    source: { master: relPosix(outAbs, masterAbs) },
  }
  const manifestPath = join(outDir, `${name}.manifest.json`)
  if (dryRun) {
    console.log(`  manifest and history: not written (dry run)`)
    return
  }
  // The manifest goes with the editions, so it is written before --validate runs.
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8")
  console.log(`\nmanifest: ${relative(process.cwd(), manifestPath) || manifestPath}`)

  if (doValidate && !dryRun) {
    const runs = [
      [join(outDir, `${name}.figma.md`), "upload"],
      [join(outDir, `${name}.paste.md`), "paste"],
      [join(claudeDir, "SKILL.md"), "coding-agent"],
    ]
    let failed = false
    console.log("")
    for (const [p, ed] of runs) {
      const r = spawnSync(process.execPath, [validatorPath, p, "--edition", ed], { encoding: "utf8" })
      process.stdout.write(r.stdout)
      if (r.status !== 0) failed = true
    }
    // A failed validation exits 1 before the history snapshot.
    if (failed) process.exit(1)
  } else if (!dryRun) {
    console.log(`\nNext: node ${relative(process.cwd(), validatorPath)} <edition> --edition upload|paste|coding-agent  (or rerun with --validate)`)
  }

  // The build exits 0 from here: write the history snapshot.
  const snap = writeHistory(masterAbs, existsSync(overlayPath) ? overlayPath : null, manifest.version)
  if (snap) console.log(`\nhistory: ${relative(process.cwd(), snap.dir) || snap.dir}  (${snap.files.join(", ")})`)
}

// ---------------------------------------------------------------------------
// Flatten a multi-file skill into one file
// ---------------------------------------------------------------------------

function flatten(dir) {
  const dirAbs = resolve(dir)
  const skillPath = join(dirAbs, "SKILL.md")
  if (!existsSync(skillPath)) fail(`no SKILL.md in ${dir}`)
  const lines = normalize(readFileSync(skillPath, "utf8")).split("\n")
  const fm = parseFrontmatter(lines)
  if (!fm.present) fail("SKILL.md has no frontmatter")
  const nameF = getField(fm.fields, "name")
  const descF = getField(fm.fields, "description")
  if (!nameF || !descF) fail("SKILL.md frontmatter needs name and description")
  const name = String(nameF.value).trim()
  let body = lines.slice(fm.closeLine + 1)

  // Collect Markdown files under references/ (one level) in a stable order.
  const refDir = join(dirAbs, "references")
  const refs = existsSync(refDir)
    ? readdirSync(refDir).filter((f) => extname(f).toLowerCase() === ".md").sort().map((f) => ({ file: f, rel: `references/${f}` }))
    : []
  const sectionTitle = (f) => `Reference: ${basename(f, ".md").replace(/[-_]+/g, " ")}`

  // Rewrite links and bare mentions to the appended sections.
  const fence = scanFences(body)
  body = body.map((line, i) => {
    if (fence[i]) return line
    let out = line
    for (const r of refs) {
      const esc = r.rel.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
      out = out.replace(new RegExp(`\\[([^\\]]*)\\]\\((?:\\./)?${esc}(#[^)]*)?\\)`, "g"), (_, text) => `${text} (see "${sectionTitle(r.file)}" below)`)
      out = out.replace(new RegExp(`(?<![\\w/])(?:\\./)?${esc}`, "g"), `the "${sectionTitle(r.file)}" section below`)
    }
    return out
  })

  // Append each reference with headings demoted one level, fenced code left intact.
  const appended = []
  for (const r of refs) {
    const refLines = normalize(readFileSync(join(refDir, r.file), "utf8")).split("\n")
    const rfm = parseFrontmatter(refLines)
    const content = rfm.present ? refLines.slice(rfm.closeLine + 1) : refLines
    const rfence = scanFences(content)
    appended.push("", `## ${sectionTitle(r.file)}`, "")
    content.forEach((l, i) => {
      if (!rfence[i] && /^#{1,5}\s/.test(l)) appended.push("#" + l)
      else appended.push(l)
    })
  }

  const manual = []
  for (const sub of ["scripts", "assets", "templates", "examples"]) {
    const p = join(dirAbs, sub)
    if (existsSync(p) && statSync(p).isDirectory()) {
      for (const f of readdirSync(p)) manual.push(`${sub}/${f}`)
    }
  }
  for (const f of existsSync(refDir) ? readdirSync(refDir).filter((f) => extname(f).toLowerCase() !== ".md") : []) manual.push(`references/${f}`)

  const flatFm = serializeFrontmatter([
    { key: "name", value: name, quoted: false },
    { key: "description", value: String(descF.value).trim(), quoted: descF.quoted },
  ])
  const outLines = [...flatFm, "", ...collapseBlankRuns([...body, ...appended])]
  emit(join(outDir, `${name}.flat.md`), outLines)

  console.log(`flattened ${name}${dryRun ? " (dry run)" : ""}`)
  for (const w of written) console.log(`  ${relative(process.cwd(), w.path) || w.path}  ${w.lines} lines, ${w.words} words`)
  console.log(`  inlined ${refs.length} reference file${refs.length === 1 ? "" : "s"}`)
  if (manual.length) {
    console.log(`\nNeeds manual conversion (no folders in a Figma skill):`)
    for (const m of manual) console.log(`  - ${m}`)
    console.log(`  scripts -> ordered natural-language steps, or a core "## Helper scripts" fence whose first line is "// helper: <name>", run from both target sections`)
    console.log(`  assets  -> fenced blocks or tables; drop binaries`)
  }
  console.log(`\nNext: mark tool-specific sections with <!-- target:figma-app --> / <!-- target:mcp -->, then build editions from the flat file.`)
}

if (flattenDir) flatten(flattenDir)
else buildEditions(masterPath)
