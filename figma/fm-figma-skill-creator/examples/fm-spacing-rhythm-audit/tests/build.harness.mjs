// build.harness.mjs: tests what scripts/build-skill-editions.mjs writes beside the editions: the
// derived manifest (dist/<name>.manifest.json) and the history snapshot (history/<version>/ beside the
// master). Every build runs on a copy of this example, or of the probe example, in a folder under the
// operating system's temporary folder; the repository is only read.
//
// Usage, from figma/fm-figma-skill-creator:
//   node examples/fm-spacing-rhythm-audit/tests/build.harness.mjs
//
// The temporary folder is removed at the end. It exports nothing and exits 1 when any case fails.

import { readFileSync, writeFileSync, mkdtempSync, mkdirSync, copyFileSync, rmSync, readdirSync, existsSync, statSync, openSync, closeSync } from "node:fs"
import { spawnSync } from "node:child_process"
import { tmpdir } from "node:os"
import { dirname, join, resolve, parse as parsePath } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"
import { normalize, parseFrontmatter, getField } from "../../../scripts/lib/skill-md.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const creator = join(here, "..", "..", "..")
const AUDIT = join(here, "..")
const PROBE = join(creator, "examples", "fm-figma-capability-probe")
const BUILDER = join(creator, "scripts", "build-skill-editions.mjs")
const VALIDATOR = join(creator, "scripts", "validate-figma-skill.mjs")
const tmp = mkdtempSync(join(tmpdir(), "build-harness-"))

// The manifest's keys, in the order the Manifest table of references/format-and-frontmatter.md lists them.
const KEYS = ["schemaVersion", "type", "name", "description", "version", "author", "category", "tags", "appliesTo", "runtimes", "editions", "enhancements", "cost", "evalStatus", "source"]

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Turn [condition, message] pairs into the list of failed messages. */
const check = (pairs) => pairs.filter(([ok]) => !ok).map(([, msg]) => msg)
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const show = (v) => JSON.stringify(v)

/** Copy the named files of an example folder into a new folder under the temporary folder. */
function copyExample(from, to, files = ["SKILL.md", "overlay.claude.yaml", "EVAL-LOG.md"]) {
  const dir = join(tmp, to)
  mkdirSync(dir, { recursive: true })
  for (const f of files) copyFileSync(join(from, f), join(dir, f))
  return dir
}

/**
 * Run the builder in `dir` on its SKILL.md with --out dist, relative paths only, so nothing in the
 * call names the repository. `stderrFile` sends stderr to that file instead of capturing it.
 */
function build(dir, extra = [], { stderrFile = null, nodeArgs = [] } = {}) {
  let fd = null
  if (stderrFile) fd = openSync(stderrFile, "w")
  try {
    const r = spawnSync(process.execPath, [...nodeArgs, BUILDER, "SKILL.md", "--out", "dist", ...extra], {
      cwd: dir, encoding: "utf8", stdio: ["ignore", "pipe", fd ?? "pipe"],
    })
    return { status: r.status, stdout: r.stdout ?? "", stderr: r.stderr ?? "" }
  } finally {
    if (fd !== null) closeSync(fd)
  }
}

const nameOf = (dir) => String(getField(parseFrontmatter(normalize(readFileSync(join(dir, "SKILL.md"), "utf8")).split("\n")).fields, "name").value)
const manifestPath = (dir) => join(dir, "dist", `${nameOf(dir)}.manifest.json`)
const manifestOf = (dir) => (existsSync(manifestPath(dir)) ? JSON.parse(readFileSync(manifestPath(dir), "utf8")) : null)
const list = (dir) => (existsSync(dir) ? readdirSync(dir).sort() : null)

/** Every file under `dir`, as { relative path: bytes }. */
function snapshot(dir, base = dir, out = {}) {
  if (!existsSync(dir)) return out
  for (const f of readdirSync(dir).sort()) {
    const p = join(dir, f)
    if (statSync(p).isDirectory()) snapshot(p, base, out)
    else out[p.slice(base.length + 1).replace(/\\/g, "/")] = readFileSync(p)
  }
  return out
}
const sameTree = (a, b) => same(Object.keys(a), Object.keys(b)) && Object.keys(a).every((k) => a[k].equals(b[k]))
const sameBytes = (p, q) => existsSync(p) && existsSync(q) && readFileSync(p).equals(readFileSync(q))

/** The master's metadata values, read here without the builder. */
function metadataOf(dir) {
  const fm = parseFrontmatter(normalize(readFileSync(join(dir, "SKILL.md"), "utf8")).split("\n"))
  const meta = getField(fm.fields, "metadata")
  const get = (k) => meta?.children?.find((c) => c.key === k)?.value ?? null
  const split = (k) => (get(k) === null ? [] : String(get(k)).split(",").map((s) => s.trim()).filter(Boolean))
  return {
    description: String(getField(fm.fields, "description").value).trim(),
    version: get("version"), author: get("author"), category: get("category"), cost: get("cost"),
    tags: split("tags"), appliesTo: split("applies-to"), runtimes: split("runtimes"),
  }
}

/** The first level-three heading under `## Entries` in an eval log, found here without the builder. */
function firstEntry(path) {
  if (!existsSync(path)) return { lastEntry: null, date: null }
  const lines = normalize(readFileSync(path, "utf8")).split("\n")
  const at = lines.findIndex((l) => /^##\s+Entries\s*$/.test(l))
  if (at === -1) return { lastEntry: null, date: null }
  for (const l of lines.slice(at + 1)) {
    if (/^#{1,2}\s/.test(l)) break
    const m = /^###\s+(.*?)\s*$/.exec(l)
    if (m) return { lastEntry: m[1], date: (/\d{4}-\d{2}-\d{2}/.exec(m[1]) || [null])[0] }
  }
  return { lastEntry: null, date: null }
}

/** The audit, copied and built once with --validate; cases that only read it share this build. */
let auditCache = null
function auditBuild() {
  if (!auditCache) {
    const dir = copyExample(AUDIT, "audit")
    auditCache = { dir, run: build(dir, ["--validate"]) }
  }
  return auditCache
}

/** The probe master alone (no overlay, no eval log), built once. */
let probeCache = null
function probeBuild() {
  if (!probeCache) {
    const dir = copyExample(PROBE, "no-log", ["SKILL.md"])
    probeCache = { dir, run: build(dir) }
  }
  return probeCache
}

/** The nearest folder at or above `dir` that holds a .git entry, or null. */
function gitAncestor(dir) {
  let d = resolve(dir)
  for (;;) {
    if (existsSync(join(d, ".git"))) return d
    const up = dirname(d)
    if (up === d || d === parsePath(d).root) return null
    d = up
  }
}

// ---------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------

const cases = {
  "(a) the audit builds with --validate at exit 0, an empty stderr, and a manifest whose keys follow the documented order": () => {
    const { dir, run } = auditBuild()
    const m = manifestOf(dir)
    if (!m) return [`no manifest (exit ${run.status}): ${run.stderr.trim() || run.stdout.trim().split("\n").pop()}`]
    return check([
      [run.status === 0, `exit ${run.status}`],
      [run.stderr === "", `stderr: ${show(run.stderr)}`],
      [same(Object.keys(m), KEYS), `keys: ${Object.keys(m).join(",")}`],
      [same(Object.keys(m.editions), ["upload", "paste", "codingAgent"]), `editions keys: ${Object.keys(m.editions).join(",")}`],
      [same(Object.keys(m.editions.upload), ["path", "bodyLines", "approxTokens"]), `upload keys: ${Object.keys(m.editions.upload).join(",")}`],
      [same(Object.keys(m.editions.paste), ["path", "bodyLines", "approxTokens"]), `paste keys: ${Object.keys(m.editions.paste).join(",")}`],
      [same(Object.keys(m.editions.codingAgent), ["path", "bodyLines", "approxTokens", "helpers"]), `codingAgent keys: ${Object.keys(m.editions.codingAgent).join(",")}`],
      [same(Object.keys(m.evalStatus), ["lastEntry", "date"]), `evalStatus keys: ${Object.keys(m.evalStatus).join(",")}`],
      [same(Object.keys(m.source), ["master"]), `source keys: ${Object.keys(m.source).join(",")}`],
    ])
  },
  "(a) the audit manifest's values come from the master's metadata, its editions, its packs and its eval log": () => {
    const { dir } = auditBuild()
    const m = manifestOf(dir)
    if (!m) return ["no manifest"]
    const meta = metadataOf(dir)
    const name = nameOf(dir)
    const log = firstEntry(join(dir, "EVAL-LOG.md"))
    return check([
      [m.schemaVersion === "1" && m.type === "skill", `schemaVersion ${show(m.schemaVersion)}, type ${show(m.type)}`],
      [m.name === name && m.description === meta.description, "name or description differs from the master"],
      [m.version === "2.2" && m.version === meta.version, `version ${show(m.version)}`],
      [m.author === meta.author && m.category === meta.category, `author ${show(m.author)}, category ${show(m.category)}`],
      [same(m.tags, meta.tags) && same(m.appliesTo, meta.appliesTo) && same(m.runtimes, meta.runtimes), `tags ${show(m.tags)}, appliesTo ${show(m.appliesTo)}, runtimes ${show(m.runtimes)}`],
      [same(m.enhancements, ["revert", "token-conformance"]), `enhancements ${show(m.enhancements)}`],
      [same(m.editions.codingAgent.helpers, ["apply", "collect", "revert", "verify"]), `helpers ${show(m.editions.codingAgent.helpers)}`],
      [m.cost === meta.cost && m.cost === null, `cost ${show(m.cost)}`],
      [log.lastEntry !== null && same(m.evalStatus, log), `evalStatus ${show(m.evalStatus)}, expected ${show(log)}`],
      [same(m.source, { master: "../SKILL.md" }), `source ${show(m.source)}`],
      [m.editions.upload.path === `${name}.figma.md` && m.editions.paste.path === `${name}.paste.md` && m.editions.codingAgent.path === `claude/${name}/SKILL.md`, `paths ${show([m.editions.upload.path, m.editions.paste.path, m.editions.codingAgent.path])}`],
      [["upload", "paste", "codingAgent"].every((e) => existsSync(join(dir, "dist", m.editions[e].path))), "an edition path does not resolve from the manifest's folder"],
    ])
  },
  "edition sizes in the manifest equal the validator's own body-line and token counts for each edition": () => {
    const { dir } = auditBuild()
    const m = manifestOf(dir)
    if (!m) return ["no manifest"]
    const problems = []
    for (const [key, edition] of [["upload", "upload"], ["paste", "paste"], ["codingAgent", "coding-agent"]]) {
      const r = spawnSync(process.execPath, [VALIDATOR, join(dir, "dist", m.editions[key].path), "--edition", edition, "--json"], { encoding: "utf8" })
      const v = JSON.parse(r.stdout)
      if (v.bodyLines !== m.editions[key].bodyLines || v.approxTokens !== m.editions[key].approxTokens) {
        problems.push(`${key}: manifest ${m.editions[key].bodyLines} lines, ${m.editions[key].approxTokens} tokens; validator ${v.bodyLines} lines, ${v.approxTokens} tokens`)
      }
    }
    return problems
  },
  "the manifest holds no timestamp, no absolute path, no commit hash, and no build-time key": () => {
    const { dir } = auditBuild()
    if (!existsSync(manifestPath(dir))) return ["no manifest"]
    const text = readFileSync(manifestPath(dir), "utf8")
    const strings = []
    const walk = (v) => { if (typeof v === "string") strings.push(v); else if (v && typeof v === "object") for (const x of Object.values(v)) walk(x) }
    walk(JSON.parse(text))
    return check([
      [!/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/.test(text), "a date with a time of day"],
      [!/\b1[0-9]{12}\b/.test(text), "an epoch-millisecond number"],
      [!/"(generated|generatedAt|built|builtAt|buildTime|timestamp|time|commit|hash|sha|head|branch)"\s*:/i.test(text), "a build-time key"],
      [!/\b(?=[0-9a-f]*[a-f])(?=[0-9a-f]*\d)[0-9a-f]{7,40}\b/.test(text), "a hex run shaped like a commit hash"],
      [!strings.some((s) => /^([A-Za-z]:[\\/]|[\\/])/.test(s) || s.includes("\\")), `an absolute or backslash path: ${show(strings.filter((s) => /^([A-Za-z]:[\\/]|[\\/])/.test(s) || s.includes("\\")))}`],
      [!text.includes(tmp.replace(/\\/g, "\\\\")) && !text.includes(tmp.replace(/\\/g, "/")) && !text.includes(resolve(creator).replace(/\\/g, "/")), "the build folder or the repository path"],
    ])
  },
  "the manifest is two-space JSON with one trailing newline and no carriage return": () => {
    const { dir } = auditBuild()
    if (!existsSync(manifestPath(dir))) return ["no manifest"]
    const text = readFileSync(manifestPath(dir), "utf8")
    return check([
      [text === JSON.stringify(JSON.parse(text), null, 2) + "\n", "not JSON.stringify(m, null, 2) plus one newline"],
      [!text.includes("\r"), "carriage return"],
    ])
  },
  "a second build leaves dist byte-identical and history with the same single folder per version": () => {
    const dir = copyExample(AUDIT, "rebuild")
    const first = build(dir, ["--validate"])
    if (first.status !== 0) return [`first build exit ${first.status}`]
    const dist1 = snapshot(join(dir, "dist")), hist1 = snapshot(join(dir, "history"))
    const second = build(dir, ["--validate"])
    const dist2 = snapshot(join(dir, "dist")), hist2 = snapshot(join(dir, "history"))
    return check([
      [second.status === 0, `second build exit ${second.status}`],
      [Object.keys(dist1).some((k) => k.endsWith(".manifest.json")), "the first build wrote no manifest"],
      [sameTree(dist1, dist2), "dist differs after the second build"],
      [sameTree(hist1, hist2), "history differs after the second build"],
      [same(list(join(dir, "history")), ["2.2"]), `history holds ${show(list(join(dir, "history")))}`],
    ])
  },
  "(d) history/2.2 holds byte copies of the master and the overlay, and nothing from dist": () => {
    const { dir, run } = auditBuild()
    const h = join(dir, "history", "2.2")
    return check([
      [run.status === 0, `exit ${run.status}`],
      [sameBytes(join(dir, "SKILL.md"), join(h, "SKILL.md")), "history/2.2/SKILL.md is not a byte copy of the master"],
      [sameBytes(join(dir, "overlay.claude.yaml"), join(h, "overlay.claude.yaml")), "history/2.2/overlay.claude.yaml is not a byte copy of the overlay"],
      [same(list(h), ["SKILL.md", "overlay.claude.yaml"]), `history/2.2 holds ${show(list(h))}`],
      [same(list(join(dir, "history")), ["2.2"]), `history holds ${show(list(join(dir, "history")))}`],
    ])
  },
  "(d) a version bump keeps the old snapshot byte-identical and adds the new one": () => {
    const dir = copyExample(AUDIT, "bump")
    const before = readFileSync(join(dir, "SKILL.md"))
    const r1 = build(dir)
    const text = before.toString("utf8")
    if (!text.includes('  version: "2.2"\n')) return ['the master has no `  version: "2.2"` line to bump']
    writeFileSync(join(dir, "SKILL.md"), text.replace('  version: "2.2"\n', '  version: "2.3"\n'))
    const r2 = build(dir)
    const h = join(dir, "history")
    return check([
      [r1.status === 0 && r2.status === 0, `exits ${r1.status}, ${r2.status}`],
      [same(list(h), ["2.2", "2.3"]), `history holds ${show(list(h))}`],
      [existsSync(join(h, "2.2", "SKILL.md")) && readFileSync(join(h, "2.2", "SKILL.md")).equals(before), "history/2.2/SKILL.md is not the pre-bump master"],
      [sameBytes(join(dir, "SKILL.md"), join(h, "2.3", "SKILL.md")), "history/2.3/SKILL.md is not the bumped master"],
      [sameBytes(join(dir, "overlay.claude.yaml"), join(h, "2.3", "overlay.claude.yaml")), "history/2.3 has no overlay copy"],
      [manifestOf(dir)?.version === "2.3", `manifest version ${show(manifestOf(dir)?.version)}`],
    ])
  },
  "a rebuild at an unchanged version overwrites that version's snapshot": () => {
    const dir = copyExample(AUDIT, "same-version")
    const r1 = build(dir)
    writeFileSync(join(dir, "SKILL.md"), readFileSync(join(dir, "SKILL.md"), "utf8") + "\nAn edit without a version bump.\n")
    const r2 = build(dir)
    return check([
      [r1.status === 0 && r2.status === 0, `exits ${r1.status}, ${r2.status}`],
      [sameBytes(join(dir, "SKILL.md"), join(dir, "history", "2.2", "SKILL.md")), "history/2.2/SKILL.md still holds the earlier master"],
      [same(list(join(dir, "history")), ["2.2"]), `history holds ${show(list(join(dir, "history")))}`],
    ])
  },
  "(b) the probe with no EVAL-LOG.md beside it builds at exit 0, empty stderr, evalStatus nulls, no packs": () => {
    const { dir, run } = probeBuild()
    const m = manifestOf(dir)
    if (!m) return [`no manifest (exit ${run.status}): ${run.stderr.trim()}`]
    return check([
      [run.status === 0, `exit ${run.status}`],
      [run.stderr === "", `stderr: ${show(run.stderr)}`],
      [same(m.evalStatus, { lastEntry: null, date: null }), `evalStatus ${show(m.evalStatus)}`],
      [same(Object.keys(m), KEYS), `keys: ${Object.keys(m).join(",")}`],
      [same(m.enhancements, []), `enhancements ${show(m.enhancements)}`],
      [same(m.editions.codingAgent.helpers, ["probe"]), `helpers ${show(m.editions.codingAgent.helpers)}`],
      [m.version === "1.2" && m.cost === null, `version ${show(m.version)}, cost ${show(m.cost)}`],
    ])
  },
  "an eval log with no Entries heading, or an Entries section with no entry, gives evalStatus nulls": () => {
    const problems = []
    const logs = {
      "no-entries-heading": "# EVAL-LOG: x\n\n## Entry template\n\n### 2026-01-01 · v1.0 · template\n",
      "empty-entries": "# EVAL-LOG: x\n\n## Entries\n\nNone yet.\n\n## Notes\n\n### 2026-01-02 · not an entry\n",
    }
    for (const [name, log] of Object.entries(logs)) {
      const dir = copyExample(PROBE, name, ["SKILL.md"])
      writeFileSync(join(dir, "EVAL-LOG.md"), log)
      const r = build(dir)
      const m = manifestOf(dir)
      if (r.status !== 0 || r.stderr !== "") problems.push(`${name}: exit ${r.status}, stderr ${show(r.stderr)}`)
      if (!m || !same(m.evalStatus, { lastEntry: null, date: null })) problems.push(`${name}: evalStatus ${show(m?.evalStatus)}`)
    }
    return problems
  },
  "(e) a master with no overlay beside it gets history/<version>/ holding SKILL.md alone": () => {
    const { dir, run } = probeBuild()
    return check([
      [run.status === 0 && run.stderr === "", `exit ${run.status}, stderr ${show(run.stderr)}`],
      [same(list(join(dir, "history")), ["1.2"]), `history holds ${show(list(join(dir, "history")))}`],
      [same(list(join(dir, "history", "1.2")), ["SKILL.md"]), `history/1.2 holds ${show(list(join(dir, "history", "1.2")))}`],
      [sameBytes(join(dir, "SKILL.md"), join(dir, "history", "1.2", "SKILL.md")), "history/1.2/SKILL.md is not a byte copy"],
    ])
  },
  "(c) a folder under no git repository builds at exit 0 with stderr, sent to a file, empty": () => {
    const dir = copyExample(AUDIT, "outside-repo")
    const repo = gitAncestor(dir)
    if (repo) console.log(`  note: skipped the "under no git repository" assertion: ${repo} holds a .git entry`)
    const errFile = join(tmp, "outside-repo.stderr.txt")
    const r = build(dir, [], { stderrFile: errFile })
    const m = manifestOf(dir)
    return check([
      [r.status === 0, `exit ${r.status}`],
      [readFileSync(errFile, "utf8") === "", `stderr file: ${show(readFileSync(errFile, "utf8"))}`],
      [m !== null, "no manifest"],
      [same(m?.source, { master: "../SKILL.md" }), `source ${show(m?.source)}`],
      [existsSync(join(dir, "history", "2.2", "SKILL.md")), "no history snapshot"],
    ])
  },
  "a dry run writes no manifest and no history folder": () => {
    const dir = copyExample(AUDIT, "dry")
    const r = build(dir, ["--dry-run"])
    return check([
      [r.status === 0, `exit ${r.status}: ${r.stderr.trim()}`],
      [!existsSync(manifestPath(dir)), "manifest written"],
      [!existsSync(join(dir, "dist")), "dist written"],
      [!existsSync(join(dir, "history")), "history written"],
    ])
  },
  "a build that stops on a build error writes no manifest and no history": () => {
    const dir = copyExample(AUDIT, "broken")
    writeFileSync(join(dir, "SKILL.md"), readFileSync(join(dir, "SKILL.md"), "utf8") + "\n<!-- target:mcp -->\nNever closed.\n")
    const r = build(dir)
    return check([
      [r.status === 1 && /build error/.test(r.stderr), `exit ${r.status}, stderr ${show(r.stderr.trim())}`],
      [!existsSync(manifestPath(dir)), "manifest written"],
      [!existsSync(join(dir, "history")), "history written"],
    ])
  },
  "a build whose editions fail --validate writes no manifest and no history": () => {
    const dir = copyExample(AUDIT, "invalid")
    const text = readFileSync(join(dir, "SKILL.md"), "utf8")
    // An angle bracket in the description builds, then fails description-angle in every edition.
    writeFileSync(join(dir, "SKILL.md"), text.replace("description: Audits the selected frames", "description: Audits the <selected> frames"))
    const r = build(dir, ["--validate"])
    const name = nameOf(dir)
    return check([
      [r.status === 1 && /description-angle/.test(r.stdout), `exit ${r.status}; no description-angle finding`],
      [existsSync(join(dir, "dist", `${name}.figma.md`)), "the editions were not written, so validation never ran"],
      [!existsSync(manifestPath(dir)), "manifest written"],
      [!existsSync(join(dir, "history")), "history written"],
    ])
  },
  "the builder names no child_process and a --validate build spawns no process": () => {
    // Read the source: no import or require of child_process, so the builder cannot start git or any
    // other process. Then run a --validate build with every child_process function made to throw.
    const src = readFileSync(BUILDER, "utf8")
    const preload = join(tmp, "no-spawn.mjs")
    writeFileSync(preload, [
      'import cp from "node:child_process"',
      'import { syncBuiltinESMExports } from "node:module"',
      'for (const k of ["spawn", "spawnSync", "exec", "execSync", "execFile", "execFileSync", "fork"]) cp[k] = () => { throw new Error(`spawned a process with ${k}`) }',
      "syncBuiltinESMExports()",
      "",
    ].join("\n"))
    const dir = copyExample(AUDIT, "no-spawn")
    const r = build(dir, ["--validate"], { nodeArgs: ["--import", pathToFileURL(preload).href] })
    return check([
      [!/child_process/.test(src), "the builder source names child_process"],
      [!/\.git\b/.test(src), "the builder source names .git"],
      [r.status === 0, `exit ${r.status}: ${r.stderr.trim()}`],
      [/OK: .*\[coding-agent\] — 0 errors, 0 warnings/.test(r.stdout), "the --validate output is missing"],
      [existsSync(manifestPath(dir)) && existsSync(join(dir, "history", "2.2", "SKILL.md")), "no manifest or no history"],
    ])
  },
  "enhancements lists regions in core helpers only, from the pack library's region scan": () => {
    const dir = copyExample(PROBE, "regions", ["SKILL.md"])
    const text = readFileSync(join(dir, "SKILL.md"), "utf8")
    if (!text.includes("// helper: probe\n")) return ["the probe master has no `// helper: probe` line"]
    // One region inside the probe helper (listed) and one in a plain fence outside the helpers (not listed).
    writeFileSync(join(dir, "SKILL.md"), text.replace("// helper: probe\n", "// helper: probe\n// enhancement: token-conformance begin\n// enhancement: token-conformance end\n")
      + "\n```js\n// enhancement: revert begin\nconst x = 1\n// enhancement: revert end\n```\n")
    const r = build(dir)
    const m = manifestOf(dir)
    return check([
      [r.status === 0, `exit ${r.status}: ${r.stderr.trim()}`],
      [same(m?.enhancements, ["token-conformance"]), `enhancements ${show(m?.enhancements)}`],
    ])
  },
  "a region contract error stops the build before anything is written": () => {
    const dir = copyExample(PROBE, "region-error", ["SKILL.md"])
    writeFileSync(join(dir, "SKILL.md"), readFileSync(join(dir, "SKILL.md"), "utf8") + "\n```js\n// enhancement: revert begin\nconst x = 1\n```\n")
    const r = build(dir)
    return check([
      [r.status === 1 && /build error: enhancement region problem at master line \d+: region "revert" never ends/.test(r.stderr), `exit ${r.status}, stderr ${show(r.stderr.trim())}`],
      [!existsSync(join(dir, "dist")), "dist written"],
      [!existsSync(join(dir, "history")), "history written"],
    ])
  },
  "metadata.cost is copied into the manifest when the master has it": () => {
    const dir = copyExample(PROBE, "cost", ["SKILL.md"])
    const text = readFileSync(join(dir, "SKILL.md"), "utf8")
    writeFileSync(join(dir, "SKILL.md"), text.replace('  runtimes: "', '  cost: "about 40 credits per run"\n  runtimes: "'))
    const r = build(dir)
    const m = manifestOf(dir)
    return check([
      [r.status === 0, `exit ${r.status}: ${r.stderr.trim()}`],
      [m?.cost === "about 40 credits per run", `cost ${show(m?.cost)}`],
      [same(Object.keys(m ?? {}), KEYS), `keys: ${Object.keys(m ?? {}).join(",")}`],
    ])
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
