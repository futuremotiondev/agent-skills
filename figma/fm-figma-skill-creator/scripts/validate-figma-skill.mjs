#!/usr/bin/env node
// validate-figma-skill.mjs — static checks for a single-file Figma skill (and its editions).
//
// Usage:
//   node validate-figma-skill.mjs <skill.md> --edition master|upload|paste|coding-agent
//                                 [--prefix fm-] [--allow-placeholders] [--strict] [--json]
//   node validate-figma-skill.mjs --description "<text>" [--strict] [--json]
//                                                    # check one description string, no file
//   node validate-figma-skill.mjs --rules            # print the rule table and exit
//
// --description runs only the description rules, with the coding-agent lead check applied,
// because seeds and concept cards target the coding-agent edition first.
//
// Editions:
//   master        the Git source: one frontmatter block, tool-neutral core, target-marked sections
//   upload        dist/<name>.figma.md  — what goes through Figma's "Add skill" upload
//   paste         dist/<name>.paste.md  — what goes into "Start from scratch" (no frontmatter)
//   coding-agent  dist/claude/<name>/SKILL.md — the Agent Skills spec edition for MCP agents
//
// Dependency-free. Encodes the rule table from references/testing-and-maintenance.md; the
// table printed by --rules is the same data the checks run from. Exit code 1 when any error
// is reported (or any warning with --strict), 0 otherwise.

import { readFileSync, existsSync, readdirSync, statSync } from "node:fs"
import { basename, dirname, resolve, join } from "node:path"
import {
  normalize, parseFrontmatter, getField, findFrontmatterLikeBlocks,
  scanFences, scanRegions, wordCount,
} from "./lib/skill-md.mjs"

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const args = process.argv.slice(2)
const EDITIONS = ["master", "upload", "paste", "coding-agent"]

function opt(name, fallback = null) {
  const i = args.indexOf(name)
  return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback
}
const wantRules = args.includes("--rules")
const asJson = args.includes("--json")
const strict = args.includes("--strict")
const allowPlaceholders = args.includes("--allow-placeholders")
const prefix = opt("--prefix", "fm-")
const descriptionText = opt("--description")
const descriptionMode = args.includes("--description")
// Description mode checks a bare string; applicability follows the coding-agent edition.
const edition = descriptionMode ? "coding-agent" : opt("--edition", "master")
const file = args.find((a) => !a.startsWith("--") && a !== prefix && a !== edition && a !== descriptionText)


// ---------------------------------------------------------------------------
// Rule table (data). `editions` is where the rule applies; checks consult it via report().
// ---------------------------------------------------------------------------

const ALL = EDITIONS
const FIGMA = ["upload", "paste"]
const WITH_FM = ["master", "upload", "coding-agent"]

const RULES = [
  { id: "name-format", editions: ALL, severity: "error", basis: "agentskills.io: ^[a-z0-9]+(-[a-z0-9]+)*$, 1-64 chars; matches every Figma slash example" },
  { id: "name-reserved", editions: ALL, severity: "error", basis: "Claude platform docs: no `anthropic` or `claude` in skill names" },
  { id: "name-prefix", editions: ALL, severity: "warn", basis: "Figma: avoid generic names like design-critique; add a name, team, or company prefix" },
  { id: "name-not-figma", editions: ALL, severity: "warn", basis: "figma/community-resources CONTRIBUTING: public names must not start with figma" },
  { id: "name-folder", editions: ["coding-agent"], severity: "error", basis: "agentskills.io and Figma dev docs: name equals the directory name" },
  { id: "description-length", editions: ALL, severity: "error", basis: "spec: description required, 1-1024 chars" },
  { id: "description-angle", editions: ALL, severity: "error", basis: "Claude platform docs: no < or > in description (tag injection)" },
  { id: "description-voice", editions: ALL, severity: "warn", basis: "spec and Figma examples: third person, names the capability" },
  { id: "description-triggers", editions: ALL, severity: "warn", basis: "Figma dev docs: say when to use it and when not to; spec" },
  { id: "description-restrictive", editions: ALL, severity: "warn", basis: "Figma help: phrase triggers as requirements, not restrictions (only when / unless)" },
  { id: "description-lead", editions: ["coding-agent"], severity: "warn", basis: "Claude Code listing truncation: key use case in the first 250 chars" },
  { id: "frontmatter-present", editions: WITH_FM, severity: "error", basis: "spec: SKILL.md starts with a --- block; Figma upload reads name and description from it" },
  { id: "frontmatter-single", editions: WITH_FM, severity: "error", basis: "hifi-mockup-presenter shipped two blocks; only the first is read" },
  { id: "frontmatter-none", editions: ["paste"], severity: "error", basis: "Start from scratch keeps a pasted --- block as literal instruction text" },
  { id: "frontmatter-keys", editions: WITH_FM, severity: "warn", basis: "Figma: extra keys unverified on upload; spec: name, description, license, compatibility, metadata, allowed-tools" },
  { id: "metadata-strings", editions: ALL, severity: "error", basis: "spec: metadata is a string-to-string map; `version: 1.0` is a float, quote it" },
  { id: "relative-links", editions: ["master", ...FIGMA], severity: "error", basis: "Figma: single file, no folders; references/, scripts/, assets/ are dead in-app" },
  { id: "mcp-tools", editions: ["master", ...FIGMA], severity: "error", basis: "use_figma, create_session, get_design_context, skillNames, download_assets exist only on the MCP server" },
  { id: "inapp-tools", editions: ["master", "coding-agent"], severity: "error", basis: "evaluate_script, show_widget, sendPrompt, read_me, get_comments, list_shader_fills exist only in-app" },
  { id: "markers-balanced", editions: ["master"], severity: "error", basis: "build convention: every <!-- target:x --> has a <!-- /target -->" },
  { id: "markers-leaked", editions: ["upload", "paste", "coding-agent"], severity: "error", basis: "markers are build-time only; Figma shows HTML comments as text" },
  { id: "html-comments", editions: FIGMA, severity: "warn", basis: "Figma renders HTML comments as visible instruction text" },
  { id: "image-links", editions: FIGMA, severity: "warn", basis: "image rendering in the Figma instructions view is unverified" },
  { id: "headings-required", editions: ALL, severity: "warn", basis: "Figma dev recipe: When to use, Instructions, Common edge cases; first-party final gate or output contract" },
  { id: "body-size", editions: ALL, severity: "warn", basis: "spec: under 500 lines; about 5k tokens is coding-agent context guidance; Figma enforces no body limit and its longest first-party skill is about 12k tokens (calibrated 2026-11-02)" },
  { id: "slash-invocations", editions: ["master", ...FIGMA], severity: "warn", basis: "only the first skill mentioned in a prompt runs; point to others only as Not for X (use /y)" },
  { id: "capability-gates", editions: ["master", ...FIGMA], severity: "warn", basis: "capability table: prototyping, vectors, slots are Coming soon; export and diagrams unsupported in-app" },
  { id: "console-log", editions: ["master", ...FIGMA], severity: "warn", basis: "script contract: results come back through return, not console.log" },
  { id: "helper-placement", editions: ["master"], severity: "warn", basis: "build contract: helpers live in the core `## Helper scripts` section, first line `// helper: <name>`; a fence in a target region ships to one runtime only" },
  { id: "placeholders-frontmatter", editions: ALL, severity: "error", basis: "a name or description still holding <verb> or <object> is an unfinished template" },
  { id: "placeholders-body", editions: ALL, severity: "warn", basis: "authoring placeholders such as <Step name> or <e.g. ...> must be replaced; agent fill-ins such as <n> are fine" },
]
const RULE_BY_ID = new Map(RULES.map((r) => [r.id, r]))

if (wantRules) { printRules(); process.exit(0) }
if (descriptionMode && descriptionText === null) {
  console.error(`--description needs the description text as its value`)
  process.exit(2)
}
if ((!file && !descriptionMode) || args.includes("--help") || args.includes("-h")) {
  console.log(`Usage: node validate-figma-skill.mjs <skill.md> --edition ${EDITIONS.join("|")} [--prefix fm-] [--allow-placeholders] [--strict] [--json]
       node validate-figma-skill.mjs --description "<text>" [--strict] [--json]
       node validate-figma-skill.mjs --rules`)
  process.exit(file || descriptionMode ? 0 : 1)
}
if (!EDITIONS.includes(edition)) {
  console.error(`Unknown --edition "${edition}". Expected one of: ${EDITIONS.join(", ")}`)
  process.exit(2)
}

function printRules() {
  const pad = (s, n) => String(s).padEnd(n)
  console.log(`${pad("Rule", 24)} ${pad("Severity", 9)} ${pad("Editions", 34)} Basis`)
  console.log(`${"-".repeat(24)} ${"-".repeat(9)} ${"-".repeat(34)} ${"-".repeat(60)}`)
  for (const r of RULES) {
    const eds = r.editions.length === EDITIONS.length ? "all" : r.editions.join(", ")
    console.log(`${pad(r.id, 24)} ${pad(r.severity, 9)} ${pad(eds, 34)} ${r.basis}`)
  }
}

// ---------------------------------------------------------------------------
// Findings. finding() applies the rule table (edition applicability, severity) and returns
// null when the rule does not apply; report() pushes into the shared list.
// ---------------------------------------------------------------------------

const findings = []

function finding(id, message, line) {
  const rule = RULE_BY_ID.get(id)
  if (!rule) throw new Error(`unknown rule id ${id}`)
  if (!rule.editions.includes(edition)) return null
  let severity = rule.severity
  if (id === "description-angle" && allowPlaceholders) severity = "warn"
  return { severity, rule: id, message, line: line ?? null }
}

function report(id, message, line) {
  const f = finding(id, message, line)
  if (f) findings.push(f)
}

// ---------------------------------------------------------------------------
// Description rules. Shared by the file path (frontmatter description) and --description.
// Returns the findings; the caller pushes them. `descField.line` is null in --description mode.
// ---------------------------------------------------------------------------

function checkDescription(description, descField) {
  // Third person, capability first. Must catch, anywhere in the text: helps|assists|enables|
  // allows|lets|guides|empowers followed within two words by "you" or "designers to"
  // ("helps you", "guides designers to"); the openers "This skill", "Designed to", "A skill
  // that/to"; and first person ("I ..."/"We ..." openers, "I will", "I'll"), plus a "You" opener.
  const VOICE = /\b(helps|assists|enables|allows|lets|guides|empowers)\s+(?:[\w'-]+\s+)?(you|designers\s+to)\b|^(this skill|designed to|a skill (that|to))\b|^(i|we|you)\b|\b(i will|i'll)\b/i
  // Second-person address in the first sentence: "you" or "your" anywhere in it.
  const VOICE_YOU = /\b(you|your)\b/i
  // A trigger clause. Must catch: "Use when", "Use whenever", "Use this skill when", "Use it
  // when", "Trigger whenever", "Invoke it when", "Activate when", "Run when", "Apply when",
  // "Always use"; or at least two double-quoted phrases (a trigger list without a verb).
  const USE_TRIGGER = /\b(use|trigger|invoke|activate|run|apply)( this( skill)?| it)?\s+(it\s+)?when(ever)?\b|\balways use\b/i
  const QUOTED_PHRASE = /["“][^"”]+["”]/g
  // A boundary. Must catch: "Not for", "Do not use", "Don't use", "Does not", "Doesn't",
  // "Excludes", "outside its/the scope", "Skip (it) for", "leave ... to /other-skill".
  const NOT_FOR = /\bnot for\b|\bdo not use\b|\bdon't use\b|\bdoes not\b|\bdoesn't\b|\bexcludes\b|\boutside (its|the) scope\b|\bskip (it )?for\b|\bleave .{1,40} to \//i
  // Restriction phrasing Figma advises against. Must catch: "only when", "only if", "unless",
  // "exclusively", "solely", "strictly", "limited to", "restricted to", "except when/if".
  const RESTRICTIVE = /\bonly (when|if)\b|\bunless\b|\bexclusively\b|\bsolely\b|\bstrictly\b|\blimited to\b|\brestricted to\b|\bexcept (when|if)\b/i

  const out = []
  const add = (id, message) => { const f = finding(id, message, descField.line); if (f) out.push(f) }
  const firstStop = description.search(/[.!?](\s|$)/)
  const firstSentence = firstStop === -1 ? description : description.slice(0, firstStop + 1)

  if (description.length < 1 || description.length > 1024) {
    add("description-length", `description is ${description.length} chars; must be 1-1024`)
  }
  if (/[<>]/.test(description)) add("description-angle", "description contains < or >")
  if (VOICE.test(description) || VOICE_YOU.test(firstSentence)) {
    add("description-voice", "description should be third person and name the capability (\"Audits...\", not \"Helps you audit...\")")
  }
  const hasUse = USE_TRIGGER.test(description) || (description.match(QUOTED_PHRASE) || []).length >= 2
  if (!hasUse) add("description-triggers", "description has no \"Use when / Use whenever\" trigger clause")
  if (!NOT_FOR.test(description)) add("description-triggers", "description has no \"Not for X (use /y)\" boundary")
  if (RESTRICTIVE.test(description)) {
    add("description-restrictive", "description uses restriction phrasing (only when / unless / solely); phrase triggers as requirements")
  }
  if (description.length > 250 && (firstStop === -1 || firstStop > 250)) {
    add("description-lead", `first sentence runs ${firstStop === -1 ? "to the end" : firstStop + 1 + " chars"}; put the key use case in the first 250`)
  }
  return out
}

// ---------------------------------------------------------------------------
// --description mode: no file; only the description rules, coding-agent applicability.
// ---------------------------------------------------------------------------

if (descriptionMode) {
  const value = descriptionText.trim()
  findings.push(...checkDescription(value, { value, line: null }))
  finish({ file: null, edition: "description", chars: value.length }, "description")
}

// ---------------------------------------------------------------------------
// Load and pre-scan
// ---------------------------------------------------------------------------

if (!existsSync(file)) { console.error(`File not found: ${file}`); process.exit(2) }
const source = normalize(readFileSync(file, "utf8"))
const lines = source.split("\n")

const fm = parseFrontmatter(lines)
const fence = scanFences(lines)
const { regions, regionAt, issues: regionIssues } = scanRegions(lines)
const bodyStart = fm.present ? fm.closeLine + 1 : 0
const bodyLines = lines.slice(bodyStart)
const isFigmaEdition = FIGMA.includes(edition)

// Lines that count as "prose" for text rules: body, outside fences.
const markerLines = new Set()
for (const r of regions) { markerLines.add(r.open); if (r.close !== -1) markerLines.add(r.close) }
const proseLine = (i) => i >= bodyStart && !fence[i] && !markerLines.has(i)

// Region helpers. In non-master editions everything is core.
const inRegion = (i, target) => edition === "master" && regionAt(i) === target

// ---------------------------------------------------------------------------
// Frontmatter rules
// ---------------------------------------------------------------------------

for (const iss of fm.issues) report("frontmatter-present", iss.message, iss.line)

if (edition === "paste") {
  if (fm.present) report("frontmatter-none", "paste edition must not start with a --- frontmatter block; Figma keeps it as literal text", 1)
  for (const b of findFrontmatterLikeBlocks(lines, fm.present ? fm.closeLine + 1 : 0)) {
    report("frontmatter-none", "frontmatter-like --- block found in the body", b.start + 1)
  }
} else {
  if (!fm.present) report("frontmatter-present", "file must start with a --- frontmatter block on line 1", 1)
  for (const b of findFrontmatterLikeBlocks(lines, fm.present ? fm.closeLine + 1 : 1)) {
    report("frontmatter-single", `second frontmatter-like --- block (lines ${b.start + 1}-${b.end + 1}); only the first is read`, b.start + 1)
  }
}

const nameField = getField(fm.fields, "name")
const descField = getField(fm.fields, "description")
const name = nameField && typeof nameField.value === "string" ? nameField.value.trim() : ""
const description = descField && typeof descField.value === "string" ? descField.value.trim() : ""

if (edition !== "paste") {
  // name
  if (!nameField) report("name-format", "frontmatter has no `name`", fm.present ? 1 : null)
  else {
    if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name) || name.length < 1 || name.length > 64) {
      if (allowPlaceholders && /<[^>]+>/.test(name)) {
        findings.push({ severity: "warn", rule: "name-format", message: `name "${name}" still holds a placeholder`, line: nameField.line })
      } else {
        report("name-format", `name "${name}" must match ^[a-z0-9]+(-[a-z0-9]+)*$ and be 1-64 chars`, nameField.line)
      }
    }
    if (/anthropic|claude/i.test(name)) report("name-reserved", `name "${name}" contains a reserved word (anthropic, claude)`, nameField.line)
    if (prefix && !name.startsWith(prefix)) report("name-prefix", `name "${name}" lacks the team prefix "${prefix}"; generic names collide in the slash menu`, nameField.line)
    if (/^figma/i.test(name)) report("name-not-figma", `public skill names should not start with "figma"`, nameField.line)
    if (edition === "coding-agent" && /^skill\.md$/i.test(basename(file))) {
      const folder = basename(dirname(resolve(file)))
      if (folder !== name) report("name-folder", `name "${name}" must equal its folder name "${folder}"`, nameField.line)
    }
  }

  // description
  if (!descField) report("description-length", "frontmatter has no `description`", fm.present ? 1 : null)
  else findings.push(...checkDescription(description, descField))

  // keys
  const specKeys = new Set(["name", "description", "license", "compatibility", "metadata", "allowed-tools"])
  const claudeKeys = new Set(["disable-model-invocation", "argument-hint", "when_to_use", "model", "context", "hooks", "paths", "user-invocable", "effort"])
  for (const f of fm.fields) {
    if (edition === "upload" && !["name", "description"].includes(f.key)) {
      report("frontmatter-keys", `key "${f.key}" is not name or description; Figma's handling of extra keys is unverified (the build strips them)`, f.line)
    } else if (edition === "master" && !specKeys.has(f.key)) {
      const hint = claudeKeys.has(f.key) ? "; move it to overlay.claude.yaml" : ""
      report("frontmatter-keys", `key "${f.key}" is outside the Agent Skills spec set${hint}`, f.line)
    } else if (edition === "coding-agent" && !specKeys.has(f.key) && !claudeKeys.has(f.key)) {
      report("frontmatter-keys", `key "${f.key}" is unknown to the spec and to Claude Code`, f.line)
    }
  }

  // metadata values
  const meta = getField(fm.fields, "metadata")
  if (meta) {
    if (!meta.children) report("metadata-strings", "metadata must be a map of string keys to string values", meta.line)
    else {
      for (const c of meta.children) {
        const looksScalar = /^(true|false|null|~|yes|no|on|off|[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?|0x[0-9a-f]+)$/i.test(c.raw.trim())
        if (!c.quoted && looksScalar) report("metadata-strings", `metadata.${c.key}: ${c.raw.trim()} parses as a non-string; write "${c.raw.trim()}"`, c.line)
        if (c.raw.trim() === "") report("metadata-strings", `metadata.${c.key} is empty`, c.line)
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Markers
// ---------------------------------------------------------------------------

if (edition === "master") {
  for (const iss of regionIssues) report("markers-balanced", iss.message, iss.line)
  for (const r of regions) {
    if (!["figma-app", "mcp"].includes(r.target)) report("markers-balanced", `unknown target "${r.target}"; the build knows figma-app and mcp`, r.open + 1)
  }
} else {
  for (let i = 0; i < lines.length; i++) {
    if (fence[i]) continue
    if (/<!--\s*\/?target/i.test(lines[i])) report("markers-leaked", "target marker left in a built edition; rebuild from the master", i + 1)
  }
}

if (isFigmaEdition) {
  for (let i = 0; i < lines.length; i++) {
    if (fence[i] || /<!--\s*\/?target/i.test(lines[i])) continue
    if (/<!--/.test(lines[i])) report("html-comments", "HTML comment will show as visible text in Figma", i + 1)
    if (/!\[[^\]]*\]\(/.test(lines[i])) report("image-links", "Markdown image; rendering in the Figma instructions view is unverified", i + 1)
  }
}

// ---------------------------------------------------------------------------
// Tool vocabulary and links by region
// ---------------------------------------------------------------------------

const MCP_TOOLS = /\b(use_figma|create_session|get_design_context|get_screenshot|get_metadata|download_assets|upload_assets|search_design_system|get_variable_defs|get_figjam|generate_image|generate_diagram|skillNames|figma-use)\b/g
const INAPP_TOOLS = /\b(evaluate_script|show_widget|sendPrompt|read_me|get_comments|list_shader_fills|get_shader_fill|ask_user_question)\b/g
const REL_LINKS = /\]\(\.\.?\/|(?<![\w/.-])(references|scripts|assets)\/[\w.-]+/g

for (let i = bodyStart; i < lines.length; i++) {
  const line = lines[i]
  // Relative links: forbidden in Figma editions anywhere; in master anywhere outside mcp.
  if (isFigmaEdition || (edition === "master" && !inRegion(i, "mcp"))) {
    for (const m of line.matchAll(REL_LINKS)) report("relative-links", `relative path or folder reference "${m[0]}" cannot resolve in a single-file skill`, i + 1)
  }
  // MCP-only tool names.
  if (isFigmaEdition || (edition === "master" && !inRegion(i, "mcp"))) {
    for (const m of line.matchAll(MCP_TOOLS)) {
      report("mcp-tools", `"${m[1]}" is an MCP-only tool${edition === "master" ? "; move it inside <!-- target:mcp -->" : "; it does not exist inside Figma"}`, i + 1)
    }
  }
  // In-app-only tool names.
  if (edition === "coding-agent" || (edition === "master" && !inRegion(i, "figma-app"))) {
    for (const m of line.matchAll(INAPP_TOOLS)) {
      report("inapp-tools", `"${m[1]}" is an in-app-only tool${edition === "master" ? "; move it inside <!-- target:figma-app -->" : "; MCP agents do not have it"}`, i + 1)
    }
  }
  // console.log inside helper code.
  if (fence[i] && /console\.log\s*\(/.test(line) && (isFigmaEdition || inRegion(i, "figma-app"))) {
    report("console-log", "helper code uses console.log; return a value instead", i + 1)
  }
}

// ---------------------------------------------------------------------------
// Helper placement (master only): the builder extracts helpers only from the core `## Helper scripts`
// section, so a javascript fence inside a target region, or a `// helper:` marker anywhere else,
// would ship to one runtime only. Section bounds match the builder: an H1 or H2 outside a fence.
// ---------------------------------------------------------------------------

if (edition === "master") {
  let inHelpers = false
  let openFence = null
  for (let i = bodyStart; i < lines.length; i++) {
    const line = lines[i]
    if (!fence[i] && /^#{1,2}\s/.test(line)) inHelpers = /^##\s+Helper scripts\s*$/i.test(line) && regionAt(i) === "core"
    const f = /^\s*(`{3,}|~{3,})\s*([\w-]*)\s*$/.exec(line)
    if (f && !openFence) {
      openFence = f[1]
      if (/^(javascript|js)$/i.test(f[2]) && regionAt(i) !== "core") {
        report("helper-placement", `javascript fence inside target:${regionAt(i)}; move it to the core "## Helper scripts" section with "// helper: <name>" as its first line, and reference it from both target sections`, i + 1)
      }
      continue
    }
    if (f && openFence && f[1][0] === openFence[0] && f[1].length >= openFence.length && f[2] === "") { openFence = null; continue }
    if (/^\s*\/\/ helper:/.test(line) && !(inHelpers && regionAt(i) === "core")) {
      report("helper-placement", `"// helper:" marker outside the core "## Helper scripts" section; the build extracts helpers only from there`, i + 1)
    }
  }
}

// ---------------------------------------------------------------------------
// Structure and size
// ---------------------------------------------------------------------------

const headings = []
for (let i = bodyStart; i < lines.length; i++) {
  if (fence[i]) continue
  const m = /^(#{1,6})\s+(.*)$/.exec(lines[i])
  if (m) headings.push({ level: m[1].length, text: m[2].trim(), line: i + 1 })
}
const hasHeading = (re) => headings.some((h) => re.test(h.text))
if (!headings.some((h) => h.level === 1)) report("headings-required", "no H1 title", bodyStart + 1)
if (!hasHeading(/when to use|use (this|it) when|use when|triggers?|purpose|scope|activation|boundary|supported context|when (not )?to/i)) report("headings-required", "no \"When to use\" section (or purpose / activation boundary)", null)
if (!hasHeading(/instructions|workflow|steps|process|procedure|how (to|it works)|method|phases?|stages?/i)) report("headings-required", "no \"Instructions\" or \"Workflow\" section", null)
if (!hasHeading(/edge cases|failure modes|troubleshooting|gotchas|pitfalls|constraints|rules|guardrails|limits|limitations|do not|don't/i)) report("headings-required", "no \"Common edge cases\" section (or guardrails / limits)", null)
if (!hasHeading(/final gate|output contract|output|checklist|done when|completion|criteria|report|deliverable|format|summary/i)) report("headings-required", "no final gate, checklist, or output contract section", null)

const bodyLineCount = bodyLines.filter((l) => l.trim() !== "").length
const words = wordCount(bodyLines)
const approxTokens = Math.round(words * 1.35)
// Lines: the spec's 500 applies everywhere. Tokens: about 5k is coding-agent context guidance;
// Figma enforces no body limit, so its editions warn only past its longest first-party skill (~12k).
if (bodyLines.length > 500) report("body-size", `body is ${bodyLines.length} lines (${bodyLineCount} non-blank); spec recommends under 500`, null)
if (edition === "coding-agent" && approxTokens > 5000) {
  report("body-size", `body is about ${approxTokens} tokens (${words} words); the spec's coding-agent guidance is about 5k`, null)
}
if (edition !== "coding-agent" && approxTokens > 12000) {
  report("body-size", `body is about ${approxTokens} tokens (${words} words), past the longest first-party Figma skill (about 12k); split it`, null)
}

// ---------------------------------------------------------------------------
// Slash invocations, capability gates, placeholders (prose only)
// ---------------------------------------------------------------------------

const POINTER_LINE = /\bnot for\b|\(use \/|\buse \/|\binstead\b|\bhand(s|ed)? (off|over|that|it)\b|\bsee \//i
const SLASH = /(?<=(?:^|[\s(])[`"']?)(\/[a-z][a-z0-9-]{2,})\b/g
for (let i = bodyStart; i < lines.length; i++) {
  if (!proseLine(i)) continue
  if (POINTER_LINE.test(lines[i])) continue
  for (const m of lines[i].matchAll(SLASH)) {
    const token = m[1]
    if (name && token === "/" + name) continue
    if (/^\/(dev|tmp|usr|etc|bin|var|home|mnt|opt|proc|sys)\b/.test(token)) continue
    report("slash-invocations", `"${token}" invoked mid-instruction; only the first skill in a prompt runs. Point to it as "Not for X (use ${token})" instead`, i + 1)
  }
}

const CAPABILITY = /\b([Pp]rototyp\w*|[Ww]ire(?!frame)\w*|[Vv]ector\w*|Slots?|slot (?:component|property|feature)s?|[Ee]xport\w*|[Dd]iagram\w*)\b/g
const PLAN_ONLY = /\b(plan|plan-only|not available|unavailable|cannot|can't|by hand|hand (it|that|them|those|over|off)|skip\w*|unsupported|coming soon|does not|do not|don't|not (possible|supported|yet)|user (must|will|does)|for you to|outside|never|without|no )\b|\bnot\b/i
// Paragraph-level check: a capability word is fine when its paragraph carries plan-only wording.
{
  let para = []
  let paraStart = -1
  const flush = () => {
    if (!para.length) return
    const text = para.join(" ")
    const hits = [...text.matchAll(CAPABILITY)].map((m) => m[1].toLowerCase())
    if (hits.length && !PLAN_ONLY.test(text)) {
      report("capability-gates", `"${[...new Set(hits)].join(", ")}" mentioned without plan-only wording; the agent cannot do this in-app today`, paraStart + 1)
    }
    para = []; paraStart = -1
  }
  for (let i = bodyStart; i < lines.length; i++) {
    if (!proseLine(i) || lines[i].trim() === "" || /^#{1,6}\s/.test(lines[i])) { flush(); continue }
    if (paraStart === -1) paraStart = i
    para.push(lines[i])
  }
  flush()
}

if (!allowPlaceholders) {
  // Lowercase HTML and SVG element names. Skills that discuss markup mention <button> or <a href>;
  // template placeholders are natural-language words (<verb>, <n>, <Title in plain words>).
  // Body placeholders are ambiguous: <n> in an output contract is a fill-in the agent completes at
  // run time, while <Step name> or <e.g. 80 px> is authoring guidance that was never replaced.
  // Only the second kind is reported, and only as a warning. Frontmatter placeholders are always errors.
  const AUTHORING = /^[A-Z][a-z]+\s+\S|e\.g\.|example|placeholder|:\s/
  const HTML_TAGS = new Set("a abbr address article aside audio b bdi bdo blockquote body br button canvas caption cite code col colgroup data datalist dd del details dfn dialog div dl dt em embed fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header hgroup hr html i iframe img input ins kbd label legend li link main map mark menu meta meter nav noscript object ol optgroup option output p param picture pre progress q rp rt ruby s samp script section select slot small source span strong style sub summary sup table tbody td template textarea tfoot th thead time title tr track u ul var video wbr svg path g rect circle ellipse line polyline polygon text tspan defs use symbol clippath mask pattern lineargradient radialgradient stop filter".split(" "))
  const PLACEHOLDER = /<([A-Za-z][A-Za-z0-9 ,.'’/:+-]{0,80})>/g
  let count = 0
  const fmEnd = fm.present ? fm.closeLine : -1
  for (let i = 0; i < lines.length; i++) {
    if (fence[i]) continue
    for (const m of lines[i].matchAll(PLACEHOLDER)) {
      const inner = m[1].trim()
      const firstToken = inner.replace(/^\//, "").split(/[\s/]/)[0]
      if (inner.includes("://") || HTML_TAGS.has(firstToken)) continue
      if (i <= fmEnd) { report("placeholders-frontmatter", `placeholder "<${inner}>" in the frontmatter`, i + 1); continue }
      if (!AUTHORING.test(inner)) continue
      count++
      if (count <= 25) report("placeholders-body", `authoring placeholder "<${inner}>" left in the body`, i + 1)
    }
  }
  if (count > 25) report("placeholders-body", `${count - 25} more authoring placeholders not listed`, null)
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

// Coding-agent edition: helpers ship as scripts/*.js beside SKILL.md, so count the files.
let helperScripts = null
if (edition === "coding-agent") {
  const scriptsDir = join(dirname(resolve(file)), "scripts")
  if (existsSync(scriptsDir) && statSync(scriptsDir).isDirectory()) {
    helperScripts = readdirSync(scriptsDir).filter((f) => f.endsWith(".js") && statSync(join(scriptsDir, f)).isFile()).length
  }
}

const sizeTail = `${bodyLines.length} body lines, ${words} words (~${approxTokens} tokens)${helperScripts === null ? "" : `; helpers: ${helperScripts} scripts`}`
finish(
  { file, edition, name: name || null, lines: lines.length, bodyLines: bodyLines.length, words, approxTokens, ...(helperScripts === null ? {} : { helperScripts }) },
  `${basename(file)} [${edition}]`,
  sizeTail,
)

/** Sort and print the findings, print the verdict line, and exit (1 on errors, or warnings with --strict). */
function finish(summary, label, tail = "") {
  const order = { error: 0, warn: 1, info: 2 }
  findings.sort((a, b) => order[a.severity] - order[b.severity] || (a.line ?? 0) - (b.line ?? 0))
  const errors = findings.filter((f) => f.severity === "error").length
  const warns = findings.filter((f) => f.severity === "warn").length

  if (asJson) {
    console.log(JSON.stringify({ ...summary, errors, warnings: warns, findings }, null, 2))
  } else {
    for (const f of findings) {
      console.log(`${f.severity.toUpperCase().padEnd(5)} ${f.rule.padEnd(24)} ${(f.line ? `L${f.line}` : "").padEnd(6)} ${f.message}`)
    }
    const verdict = errors ? "FAIL" : strict && warns ? "FAIL (strict)" : "OK"
    console.log(`${verdict}: ${label} — ${errors} error${errors === 1 ? "" : "s"}, ${warns} warning${warns === 1 ? "" : "s"}${tail ? `; ${tail}` : ""}`)
  }
  process.exit(errors || (strict && warns) ? 1 : 0)
}
