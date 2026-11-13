// collect.harness.mjs: runs the master's collect helper under Node against a mock `figma` object.
//
// Usage, from figma/fm-figma-skill-creator:
//   node examples/fm-spacing-rhythm-audit/tests/collect.harness.mjs
//
// The harness reads SKILL.md, takes the `// helper: collect` fence body as written (top-level
// `await`, final `return`), sets its `let MODE` line per case, and runs it with
// `new AsyncFunction("figma", body)`. Each case builds its own mock file and checks the result.
// It exports nothing and exits 1 when any case fails.
//
// A mock proves the helper's logic only. Every write path and every live number is proved over the
// Figma MCP server (see README.md); the numbers here are sanity checks, not oracle results.

import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize, scanFences } from "../../../scripts/lib/skill-md.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const master = join(here, "..", "SKILL.md")

// ---------------------------------------------------------------------------
// Helper extraction
// ---------------------------------------------------------------------------

/** The body of the `// helper: collect` fence, between the fence lines, exactly as written. */
function collectBody() {
  const lines = normalize(readFileSync(master, "utf8")).split("\n")
  const inFence = scanFences(lines)
  for (let i = 0; i < lines.length; i++) {
    if (!inFence[i] || lines[i + 1] !== "// helper: collect") continue
    let end = i + 1
    while (end < lines.length && inFence[end] && !/^\s*```/.test(lines[end])) end++
    return lines.slice(i + 1, end)
  }
  throw new Error("no `// helper: collect` fence in " + master)
}

const BODY = collectBody()
const MODE_LINE = BODY.findIndex((l) => /^let MODE = /.test(l))
if (MODE_LINE < 0) throw new Error("the collect helper has no `let MODE = ...` line")
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor

/** Run the collect helper with MODE set to `mode` against the mock `figma`. */
async function runCollect(figma, mode) {
  const body = BODY.slice()
  body[MODE_LINE] = `let MODE = "${mode}";`
  return new AsyncFunction("figma", body.join("\n"))(figma)
}

// ---------------------------------------------------------------------------
// Mock builders
// ---------------------------------------------------------------------------

/** A variable collection; the first mode is the Default mode. */
function collection(id, name, modeNames = ["Default"]) {
  const modes = modeNames.map((n, i) => ({ modeId: id + ":" + i, name: n }))
  return { id, name, modes, defaultModeId: modes[0].modeId }
}

/** A FLOAT variable with one value per mode of its collection (a number, or { alias: variableId }). */
function variable(id, name, col, values, scopes = ["GAP"]) {
  const valuesByMode = {}
  col.modes.forEach((m, i) => {
    const v = values[i]
    valuesByMode[m.modeId] = v && typeof v === "object" ? { type: "VARIABLE_ALIAS", id: v.alias } : v
  })
  return { id, name, variableCollectionId: col.id, valuesByMode, scopes, resolvedType: "FLOAT" }
}

/** A Default-mode spacing collection named "Space" with one GAP-scoped variable per [name, value]. */
function spaceTokens(pairs, id = "VC:space", name = "Space") {
  const col = collection(id, name)
  return { col, vars: pairs.map(([n, v], i) => variable(id + "/" + i, n, col, [v])) }
}

let nextId = 1

/** An auto-layout node: every padding and gap 0 unless overridden, no bindings, no children. */
function node(name, type = "FRAME", props = {}) {
  return {
    id: "N:" + nextId++, name, type, visible: true, parent: null, children: [],
    layoutMode: "VERTICAL", layoutWrap: "NO_WRAP", layoutPositioning: "AUTO",
    paddingTop: 0, paddingRight: 0, paddingBottom: 0, paddingLeft: 0, itemSpacing: 0, counterAxisSpacing: 0,
    boundVariables: {}, resolvedVariableModes: {},
    ...props,
  }
}

/** An instance of `main` that inherits every value unless `props` overrides it. */
function instance(name, main, props = {}) {
  const pick = ["paddingTop", "paddingRight", "paddingBottom", "paddingLeft", "itemSpacing", "counterAxisSpacing"]
  const own = Object.fromEntries(pick.map((k) => [k, main[k]]))
  return node(name, "INSTANCE", { ...own, ...props, getMainComponentAsync: async () => main })
}

/** The mock `figma`: one page holding `top` (all selected), plus the given collections and variables. */
function mockFigma({ top = [], collections = [], variables = [] } = {}) {
  const page = { type: "PAGE", name: "Page 1", parent: null, children: top, selection: top }
  for (const n of top) n.parent = page
  const byId = new Map(variables.map((v) => [v.id, v]))
  return {
    currentPage: page,
    teamLibrary: undefined,
    variables: {
      getLocalVariableCollectionsAsync: async () => collections,
      getLocalVariablesAsync: async (type) => variables.filter((v) => !type || v.resolvedType === type),
      getVariableByIdAsync: async (id) => byId.get(id) || null,
    },
  }
}

// ---------------------------------------------------------------------------
// Assertions
// ---------------------------------------------------------------------------

/** Turn [condition, message] pairs into the list of failed messages. */
const check = (pairs) => pairs.filter(([ok]) => !ok).map(([, msg]) => msg)
const show = (x) => JSON.stringify(x)

// ---------------------------------------------------------------------------
// Cases: each returns { figma, mode, assert(result) }; assert returns the failed messages.
// ---------------------------------------------------------------------------

const cases = {
  "1 near miss with a tie on a main component ranks P3"() {
    const { col, vars } = spaceTokens([["Space/400", 16], ["Space/600", 24]])
    const card = node("Card", "COMPONENT", { paddingTop: 20 })
    return {
      figma: mockFigma({ top: [card], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const row = r.rows[0] || {}, fix = row.fix || {}
        return check([
          [r.rows.length === 1, "one row, got " + r.rows.length],
          [row.priority === "P3", "priority P3, got " + row.priority],
          [fix.kind === "bind", "fix.kind bind, got " + fix.kind],
          [fix.value === 16, "fix.value 16, got " + fix.value],
          [fix.nearMiss === true, "fix.nearMiss true, got " + fix.nearMiss],
          [String(row.note).includes("tie: Space/400 (16) or Space/600 (24)"), "tie note, got " + show(row.note)],
          [r.byPriority.P0 === 0, "byPriority.P0 0, got " + r.byPriority.P0],
          [r.byPriority.P3 === 1, "byPriority.P3 1, got " + r.byPriority.P3],
        ])
      },
    }
  },

  "2 off-rhythm tie goes to the multiple of 8"() {
    const { col, vars } = spaceTokens([["Space/300", 12], ["Space/400", 16]])
    const f = node("Plain", "FRAME", { itemSpacing: 14 })
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const row = r.rows[0] || {}, fix = row.fix || {}
        return check([
          [r.rows.length === 1, "one row, got " + r.rows.length],
          [fix.value === 16, "fix.value 16, got " + fix.value],
          [row.priority === "P1", "priority P1, got " + row.priority],
          [fix.nearMiss === undefined, "no nearMiss, got " + fix.nearMiss],
        ])
      },
    }
  },

  "3 off-rhythm tie keeps 8, the multiple of 8"() {
    const { col, vars } = spaceTokens([["Space/200", 8], ["Space/300", 12]])
    const f = node("Plain", "FRAME", { itemSpacing: 10 })
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const fix = (r.rows[0] || {}).fix || {}
        return check([
          [r.rows.length === 1, "one row, got " + r.rows.length],
          [fix.value === 8, "fix.value 8, got " + fix.value],
        ])
      },
    }
  },

  "4 off rhythm and no token within 4 sets the rhythm number"() {
    const { col, vars } = spaceTokens([["Space/400", 16]])
    const card = node("Card", "COMPONENT", { paddingTop: 22 })
    return {
      figma: mockFigma({ top: [card], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const row = r.rows[0] || {}, fix = row.fix || {}
        return check([
          [r.rows.length === 1, "one row, got " + r.rows.length],
          [row.priority === "P0", "priority P0, got " + row.priority],
          [fix.kind === "set", "fix.kind set, got " + fix.kind],
          [fix.value === 24, "fix.value 24, got " + fix.value],
          [fix.reason === "no token within 4", "reason, got " + show(fix.reason)],
          [fix.nearMiss === undefined, "no nearMiss, got " + fix.nearMiss],
        ])
      },
    }
  },

  "5 on rhythm, token exactly 4 away on a main component ranks P3"() {
    const { col, vars } = spaceTokens([["Space/400", 16]])
    const card = node("Card", "COMPONENT", { paddingTop: 20 })
    return {
      figma: mockFigma({ top: [card], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const row = r.rows[0] || {}, fix = row.fix || {}
        return check([
          [r.rows.length === 1, "one row, got " + r.rows.length],
          [row.priority === "P3", "priority P3, got " + row.priority],
          [fix.nearMiss === true, "fix.nearMiss true, got " + fix.nearMiss],
          [String(row.note).includes("on rhythm, no token; nearest Space/400 (16)"), "nearest note, got " + show(row.note)],
        ])
      },
    }
  },

  "6a on rhythm 12, token 16 exactly 4 away on a plain frame is a near miss"() {
    const { col, vars } = spaceTokens([["Space/400", 16]])
    const f = node("Plain", "FRAME", { paddingTop: 12 })
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const row = r.rows[0] || {}, fix = row.fix || {}
        return check([
          [r.rows.length === 1, "one row, got " + r.rows.length],
          [row.priority === "P3", "priority P3, got " + row.priority],
          [fix.nearMiss === true, "fix.nearMiss true, got " + fix.nearMiss],
          [fix.value === 16, "fix.value 16, got " + fix.value],
          [r.onRhythmNoToken === 0, "onRhythmNoToken 0, got " + r.onRhythmNoToken],
        ])
      },
    }
  },

  "6b on rhythm 8, token 16 is 8 away: passes"() {
    const { col, vars } = spaceTokens([["Space/400", 16]])
    const f = node("Plain", "FRAME", { paddingTop: 8 })
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => check([
        [r.rows.length === 0, "no row, got " + r.rows.length],
        [r.onRhythmNoToken === 1, "onRhythmNoToken 1, got " + r.onRhythmNoToken],
      ]),
    }
  },

  "7 an alias-only collection never elects"() {
    const size = collection("VC:size", "Size"), sem = collection("VC:sem", "Semantic")
    const s1 = variable("V:s1", "Size/100", size, [4]), s2 = variable("V:s2", "Size/200", size, [8])
    const aliases = ["a", "b", "c"].map((x, i) => variable("V:sem" + x, "Semantic/space-" + x, sem, [{ alias: i % 2 ? s2.id : s1.id }]))
    return {
      figma: mockFigma({ collections: [sem, size], variables: [...aliases, s1, s2] }), mode: "tokens",
      assert: (r) => {
        const m = (r.matchedCollections || []).find((x) => x.name === "Semantic")
        return check([
          [r.spacingCollection && r.spacingCollection.name === "Size", "spacingCollection Size, got " + show(r.spacingCollection)],
          [!!m && /alias only/.test(m.reasons), "Semantic matched with reason alias only, got " + show(r.matchedCollections)],
        ])
      },
    }
  },

  "8 a collection of 0 and negative values still elects"() {
    const col = collection("VC:neg", "Offsets")
    const vars = [["Space/0", 0], ["Space/neg-4", -4], ["Space/neg-8", -8]].map(([n, v], i) => variable("V:n" + i, n, col, [v]))
    return {
      figma: mockFigma({ collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const s = r.spacingCollection || {}
        return check([
          [!!r.spacingCollection, "spacingCollection elected, got null"],
          [s.minPositive === null, "minPositive null, got " + s.minPositive],
          [s.minNegative === -8, "minNegative -8, got " + s.minNegative],
          [s.min === -8, "min -8, got " + s.min],
          [s.max === 0, "max 0, got " + s.max],
        ])
      },
    }
  },

  "9 a tie on candidate count goes to the collection with a positive candidate"() {
    const neg = collection("VC:neg", "Neg"), space = collection("VC:space", "Space")
    const vars = [
      variable("V:n4", "Neg/space-4", neg, [-4]), variable("V:n8", "Neg/space-8", neg, [-8]),
      variable("V:p4", "Space/100", space, [4]), variable("V:p8", "Space/200", space, [8]),
    ]
    return {
      figma: mockFigma({ collections: [neg, space], variables: vars }), mode: "tokens",
      assert: (r) => {
        const s = r.spacingCollection || {}
        return check([
          [s.name === "Space", "spacingCollection Space, got " + show(r.spacingCollection)],
          [s.minPositive === 4, "minPositive 4, got " + s.minPositive],
          [s.minNegative === null, "minNegative null, got " + s.minNegative],
        ])
      },
    }
  },

  "10 discover with no variables returns the rhythm audit"() {
    const f = node("Plain", "FRAME", { paddingTop: 18 })
    return {
      figma: mockFigma({ top: [f] }), mode: "discover",
      assert: (r) => check([
        [r.mode === "rhythm", "mode rhythm, got " + show(r.mode)],
        [typeof r.framesMeasured === "number", "framesMeasured present, got " + show(r.framesMeasured)],
      ]),
    }
  },

  "11a an inherited bind opportunity names its instance count"() {
    const { col, vars } = spaceTokens([["Space/200", 8]])
    const card = node("Card", "COMPONENT", { paddingTop: 8 })
    const a = instance("Card / A", card), b = instance("Card / B", card)
    return {
      figma: mockFigma({ top: [card, a, b], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const opp = r.rows.filter((x) => String(x.note).startsWith("unbound; bind to"))
        return check([
          [r.framesMeasured === 3, "3 frames, got " + r.framesMeasured],
          [opp.length === 1, "one opportunity row, got " + opp.length],
          [!!opp[0] && opp[0].note.includes("inherited by 2 instances"), "inherited note, got " + show(opp[0] && opp[0].note)],
        ])
      },
    }
  },

  "11b opportunity rows sort by path then property"() {
    const { col, vars } = spaceTokens([["Space/200", 8]])
    const beta = node("Beta", "FRAME", { paddingTop: 8, itemSpacing: 8 })
    const alpha = node("Alpha", "FRAME", { paddingTop: 8, itemSpacing: 8 })
    return {
      figma: mockFigma({ top: [beta, alpha], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const got = r.rows.map((x) => x.path + " · " + x.property)
        const want = ["Alpha · Gap", "Alpha · Padding top", "Beta · Gap", "Beta · Padding top"]
        return check([[show(got) === show(want), "order " + show(want) + ", got " + show(got)]])
      },
    }
  },

  "12 three near misses on one frame stay three P3 rows"() {
    const { col, vars } = spaceTokens([["Space/400", 16], ["Space/600", 24]])
    const f = node("Plain", "FRAME", { paddingTop: 20, paddingLeft: 20, itemSpacing: 20 })
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => check([
        [r.rows.length === 3, "three rows, got " + r.rows.length],
        [r.rows.every((x) => x.priority === "P3"), "all P3, got " + show(r.rows.map((x) => x.priority))],
        [r.byPriority.P3 === 3, "byPriority.P3 3, got " + r.byPriority.P3],
      ]),
    }
  },
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

let failed = 0
for (const [name, make] of Object.entries(cases)) {
  let problems
  try {
    const { figma, mode, assert } = make()
    problems = assert(await runCollect(figma, mode))
  } catch (e) {
    problems = ["threw: " + (e && e.stack ? e.stack.split("\n")[0] : String(e))]
  }
  if (problems.length) failed++
  console.log((problems.length ? "FAIL " : "PASS ") + name + (problems.length ? "\n  - " + problems.join("\n  - ") : ""))
}
const total = Object.keys(cases).length
console.log(`${total} cases, ${failed} failed`)
process.exit(failed ? 1 : 0)
