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
//
// Flatten (second form) reads <skill-dir>/SKILL.md plus references/*.md and writes
// <out>/<name>.flat.md with every referenced Markdown file appended as a section and links
// rewritten to point at those sections. scripts/ and assets/ are listed for manual conversion.
//
// Dependency-free. Markers: <!-- target:figma-app --> ... <!-- /target --> and <!-- target:mcp -->.
// Exit 1 on a build error (unbalanced markers, missing name/description, unreadable overlay).

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, copyFileSync, statSync } from "node:fs"
import { join, dirname, basename, resolve, relative, extname } from "node:path"
import { spawnSync } from "node:child_process"
import { fileURLToPath } from "node:url"
import {
  normalize, parseFrontmatter, parseYamlSubset, getField, scanRegions, selectTarget,
  serializeFrontmatter, mergeFields, collapseBlankRuns, wordCount, scanFences,
} from "./lib/skill-md.mjs"

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
  if (dryRun) return
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, text, "utf8")
}

// ---------------------------------------------------------------------------
// Build editions from a master
// ---------------------------------------------------------------------------

function buildEditions(master) {
  const masterAbs = resolve(master)
  if (!existsSync(masterAbs)) fail(`master not found: ${master}`)
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
    const oIssues = []
    overlayFields = parseYamlSubset(normalize(readFileSync(overlayPath, "utf8")).split("\n"), 0, oIssues)
    for (const iss of oIssues) fail(`overlay ${basename(overlayPath)} line ${iss.line}: ${iss.message}`)
    // The overlay may never rename the skill or rewrite its description.
    overlayFields = overlayFields.filter((f) => !["name", "description"].includes(f.key))
  } else if (overlayArg) {
    fail(`overlay not found: ${overlayArg}`)
  }

  const figmaBody = selectTarget(body, ["figma-app"])
  const mcpBody = selectTarget(body, ["mcp"])

  // Upload edition: name + description only. Figma's tolerance for other keys is unverified.
  const uploadFm = serializeFrontmatter([
    { key: "name", value: name, quoted: false },
    { key: "description", value: String(descF.value).trim(), quoted: descF.quoted },
  ])
  emit(join(outDir, `${name}.figma.md`), [...uploadFm, "", ...figmaBody])

  // Paste edition: body only, plus a fields file holding what the Start-from-scratch form asks for.
  emit(join(outDir, `${name}.paste.md`), figmaBody)
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
  emit(join(claudeDir, "SKILL.md"), [...claudeFm, "", ...mcpBody])

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
  console.log(`\nStart-from-scratch fields (type these into Figma's form for the paste edition):`)
  console.log(`  name:        ${name}`)
  console.log(`  description: ${String(descF.value).trim()}`)

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
    if (failed) process.exit(1)
  } else if (!dryRun) {
    console.log(`\nNext: node ${relative(process.cwd(), validatorPath)} <edition> --edition upload|paste|coding-agent  (or rerun with --validate)`)
  }
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
    console.log(`  scripts -> ordered natural-language steps or a feature-checked evaluate_script block inside <!-- target:figma-app -->`)
    console.log(`  assets  -> fenced blocks or tables; drop binaries`)
  }
  console.log(`\nNext: mark tool-specific sections with <!-- target:figma-app --> / <!-- target:mcp -->, then build editions from the flat file.`)
}

if (flattenDir) flatten(flattenDir)
else buildEditions(masterPath)
