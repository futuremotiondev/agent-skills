// collect.harness.mjs: runs the master's collect helper under Node against a mock `figma` object.
//
// Usage, from figma/fm-figma-skill-creator:
//   node examples/fm-spacing-rhythm-audit/tests/collect.harness.mjs
//
// The harness reads SKILL.md, takes the `// helper: collect` fence body as written (top-level
// `await`, final `return`), sets its `let MODE` line per case, and runs it with
// `new AsyncFunction("figma", body)`. Each case builds its own mock file and checks the result; a
// case may also return its own fence body (case 24 strips the token-conformance pack in-process).
// It exports nothing and exits 1 when any case fails.
//
// A mock proves the helper's logic only. Every write path and every live number is proved over the
// Figma MCP server (see README.md); the numbers here are sanity checks, not oracle results.

import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { normalize, scanFences } from "../../../scripts/lib/skill-md.mjs"
import { loadPack, findUnits, stripUnits } from "../../../scripts/lib/enhancements.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const master = join(here, "..", "SKILL.md")
const masterLines = () => normalize(readFileSync(master, "utf8")).split("\n")

// ---------------------------------------------------------------------------
// Helper extraction
// ---------------------------------------------------------------------------

/** The body of the `// helper: collect` fence in `lines` (default: the master's), between the fence lines, exactly as written. */
function collectBody(lines = masterLines()) {
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
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor

/** Run the collect helper `body` (default: the master's) with MODE set to `mode` against the mock `figma`. */
async function runCollect(figma, mode, body = BODY) {
  const at = body.findIndex((l) => /^let MODE = /.test(l))
  if (at < 0) throw new Error("the collect helper has no `let MODE = ...` line")
  const lines = body.slice()
  lines[at] = `let MODE = "${mode}";`
  return new AsyncFunction("figma", lines.join("\n"))(figma)
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
// Shared builders: one mock file run in either mode
// ---------------------------------------------------------------------------

/** Cases 18 and 19: negative gaps bound to a spacing token, unbound, and bound to a variable discovery does not match. */
function negGroups(mode) {
  const space = collection("VC:space", "Space"), overlap = collection("VC:overlap", "Overlap")
  const neg200 = variable("V:sn200", "Space/Negative 200", space, [-8])
  const border = variable("V:border", "overlap/border", overlap, [-1], ["ALL_SCOPES"])
  const vars = [variable("V:s100", "Space/100", space, [4]), variable("V:s200", "Space/200", space, [8]), neg200, border]
  const a = node("A", "FRAME", { itemSpacing: -8, boundVariables: { itemSpacing: { type: "VARIABLE_ALIAS", id: neg200.id } } })
  const b = node("B", "FRAME", { itemSpacing: -8, boundVariables: { itemSpacing: { type: "VARIABLE_ALIAS", id: neg200.id } } })
  const c = node("C", "FRAME", { itemSpacing: -8 })
  const d = node("D", "FRAME", { itemSpacing: -1, boundVariables: { itemSpacing: { type: "VARIABLE_ALIAS", id: border.id } } })
  // [label, values, exampleId], largest first.
  const want = [["Space/Negative 200 = -8", 2, a.id], ["unbound -8", 1, c.id], ["overlap/border = -1", 1, d.id]]
  return {
    figma: mockFigma({ top: [a, b, c, d], collections: [space, overlap], variables: vars }), mode,
    assert: (r) => {
      const neg = r.negatives || {}, got = (neg.list || []).map((e) => [e.label, e.values, e.exampleId])
      return check([
        [r.mode === mode, "mode " + mode + ", got " + show(r.mode)],
        [r.rows.length === 0, "no rows, got " + show(r.rows)],
        [neg.values === 4, "negatives.values 4, got " + show(neg.values)],
        [r.boundPassed === 0, "boundPassed 0, got " + show(r.boundPassed)],
        [show(r.offRhythmTokens) === "[]", "offRhythmTokens empty, got " + show(r.offRhythmTokens)],
        [show(r.unbound) === "[]", "unbound empty, got " + show(r.unbound)],
        [show(r.matchedCollections) === "[]", "matchedCollections empty, got " + show(r.matchedCollections)],
        [show(got) === show(want), "negatives.list " + show(want) + ", got " + show(got)],
      ])
    },
  }
}

/** Cases 22 and 23: the live file's "Edge values" frame (fractional paddings, a negative gap) holding a "Stack" frame whose negative gap is bound to an unmatched variable. */
function edgeValues(mode) {
  const spacing = collection("VC:spacing", "Spacing"), overlap = collection("VC:overlap", "Overlap")
  const steps = [["Space/100", 4], ["Space/150", 6], ["Space/200", 8], ["Space/300", 12], ["Space/400", 16]]
  const stackVar = variable("V:stack", "overlap/stack", overlap, [-8], ["ALL_SCOPES"])
  const vars = [...steps.map(([n, v], i) => variable("V:sp" + i, n, spacing, [v])), stackVar]
  const edge = node("Edge values", "FRAME", { paddingTop: 5.5, paddingBottom: 6.5, itemSpacing: -2 })
  const stack = node("Stack", "FRAME", { itemSpacing: -8, boundVariables: { itemSpacing: { type: "VARIABLE_ALIAS", id: stackVar.id } } })
  edge.children = [stack]
  stack.parent = edge
  const note = mode === "rhythm" ? "fractional; nearest token Space/150 (6)" : "fractional"
  // [priority, property, current, nearest, delta, note], in the order the rows must come back.
  const want = [["P3", "Padding top", 5.5, 6, 0.5, note], ["P3", "Padding bottom", 6.5, 6, -0.5, note]]
  const wantNeg = [["unbound -2", 1, "Edge values"], ["overlap/stack = -8", 1, "Edge values / Stack"]]
  const set6 = { kind: "set", value: 6, reason: "nearest on-grid" }
  return {
    figma: mockFigma({ top: [edge], collections: [spacing, overlap], variables: vars }), mode,
    assert: (r) => {
      const got = r.rows.map((x) => [x.priority, x.property, x.current, x.nearest, x.delta, x.note])
      const neg = r.negatives || {}, gotNeg = (neg.list || []).map((e) => [e.label, e.values, e.examplePath])
      const fixOk = mode === "rhythm"
        ? r.rows.every((x) => show(x.fix) === show(set6))
        : r.rows.every((x) => x.fix && x.fix.kind === "bind" && x.fix.name === "Space/150" && x.fix.value === 6)
      return check([
        [r.framesMeasured === 2, "framesMeasured 2, got " + show(r.framesMeasured)],
        [show(r.byPriority) === show({ P0: 0, P1: 0, P2: 0, P3: 2 }), "byPriority P0 0, P1 0, P2 0, P3 2, got " + show(r.byPriority)],
        [r.boundPassed === 0, "boundPassed 0, got " + show(r.boundPassed)],
        [show(r.offRhythmTokens) === "[]", "offRhythmTokens empty, got " + show(r.offRhythmTokens)],
        [neg.values === 2, "negatives.values 2, got " + show(neg.values)],
        [show(gotNeg) === show(wantNeg), "negatives.list " + show(wantNeg) + ", got " + show(gotNeg)],
        [show(got) === show(want), "rows " + show(want) + ", got " + show(got)],
        [fixOk, (mode === "rhythm" ? "every fix " + show(set6) : "every fix bind Space/150, value 6") + ", got " + show(r.rows.map((x) => x.fix))],
      ])
    },
  }
}

// ---------------------------------------------------------------------------
// Cases: each returns { figma, mode, assert(result) } and may add `body`, a collect fence body to run
// instead of the master's; assert returns the failed messages.
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
    // The losing collection holds a 0, so a span test of "0 or more" instead of "above 0" elects it.
    const vars = [
      variable("V:n0", "Neg/space-0", neg, [0]), variable("V:n4", "Neg/space-4", neg, [-4]),
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

  "10b discover with spacing tokens returns the discover summary, not an audit"() {
    const { col, vars } = spaceTokens([["Space/200", 8], ["Space/400", 16]])
    const f = node("Plain", "FRAME", { paddingTop: 18 })
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "discover",
      assert: (r) => check([
        [r.mode === "discover", "mode discover, got " + show(r.mode)],
        [r.tokenCount === 2, "tokenCount 2, got " + show(r.tokenCount)],
        [show(r.candidateValues) === show([8, 16]), "candidateValues [8,16], got " + show(r.candidateValues)],
        [r.spacingCollection && r.spacingCollection.name === "Space", "spacingCollection Space, got " + show(r.spacingCollection)],
        [r.rows === undefined && r.framesMeasured === undefined, "an audit came back: " + show(Object.keys(r))],
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

  "14 a positive value below 4 snaps to 4, never to 0 (rhythm mode)"() {
    const f = node("Tiny", "FRAME", { paddingTop: 1, paddingRight: 2, paddingBottom: 3, paddingLeft: 0.5, itemSpacing: 2 })
    const set4 = { kind: "set", value: 4, reason: "nearest on-grid" }
    // [priority, property, current, nearest, delta, note], in the order the rows must come back.
    const want = [
      ["P1", "Padding left", 0.5, 4, 3.5, "fractional"],
      ["P1", "Padding top", 1, 4, 3, ""],
      ["P1", "Padding right", 2, 4, 2, ""],
      ["P2", "Padding bottom", 3, 4, 1, ""],
      ["P3", "Gap", 2, 4, 2, "2 px half-step"],
    ]
    return {
      figma: mockFigma({ top: [f] }), mode: "rhythm",
      assert: (r) => {
        const got = r.rows.map((x) => [x.priority, x.property, x.current, x.nearest, x.delta, x.note])
        return check([
          [show(got) === show(want), "rows " + show(want) + ", got " + show(got)],
          [r.rows.every((x) => show(x.fix) === show(set4)), "every fix " + show(set4) + ", got " + show(r.rows.map((x) => x.fix))],
          [show(r.byPriority) === show({ P0: 0, P1: 3, P2: 1, P3: 1 }), "byPriority P0 0, P1 3, P2 1, P3 1, got " + show(r.byPriority)],
          [!r.rows.some((x) => x.nearest === 0), "nearest 0 on " + show(r.rows.filter((x) => x.nearest === 0).map((x) => x.property))],
          [!r.rows.some((x) => x.fix && x.fix.value === 0), "fix.value 0 on " + show(r.rows.filter((x) => x.fix && x.fix.value === 0).map((x) => x.property))],
        ]).concat((() => {
          // The live oracle run of the same frame on the seed file (scope 6) must return these rows too.
          const scope6 = JSON.parse(readFileSync(join(here, "expected.json"), "utf8")).scopes.find((s) => s.scope === 6)
          if (!scope6) return ["expected.json has no scope 6"]
          const live = scope6.rows.map((x) => [x.priority, x.property, x.current, x.nearest, x.delta, x.note])
          return check([[show(live) === show(got), "expected.json scope 6 rows " + show(live) + ", mock rows " + show(got)]])
        })())
      },
    }
  },

  "15 token mode: no token within 4 of a value below 4 sets 4"() {
    const col = collection("VC:spacing", "Spacing")
    const vars = [variable("V:s200", "Space/200", col, [8]), variable("V:s400", "Space/400", col, [16])]
    const f = node("Plain", "FRAME", { itemSpacing: 2 })
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const row = r.rows[0] || {}
        return check([
          [r.rows.length === 1, "one row, got " + r.rows.length],
          [row.property === "Gap" && row.current === 2, "Gap 2, got " + show([row.property, row.current])],
          [row.nearest === 4 && row.delta === 2, "nearest 4, delta 2, got " + show([row.nearest, row.delta])],
          [row.priority === "P1", "priority P1, got " + row.priority],
          [show(row.fix) === show({ kind: "set", value: 4, reason: "no token within 4" }), "fix.value 4 with reason no token within 4, got " + show(row.fix)],
          [String(row.note).includes("no token within 4"), "note names no token within 4, got " + show(row.note)],
        ])
      },
    }
  },

  "17 a negative value is counted on the Negative values line and never becomes a row"() {
    const stack = node("Stack", "FRAME", { itemSpacing: -2 })
    const grid = node("Stack on grid", "FRAME", { itemSpacing: -8 })
    const overlap = node("Overlap", "COMPONENT", { itemSpacing: -6 })
    const a = instance("Overlap / A", overlap), b = instance("Overlap / B", overlap)
    // [label, values, exampleId, examplePath]; the inherited -6 is counted once, on the main component.
    const want = [["unbound -2", 1, stack.id, "Stack"], ["unbound -8", 1, grid.id, "Stack on grid"], ["unbound -6", 1, overlap.id, "Overlap"]]
    return {
      figma: mockFigma({ top: [stack, grid, overlap, a, b] }), mode: "rhythm",
      assert: (r) => {
        const neg = r.negatives || {}, got = (neg.list || []).map((e) => [e.label, e.values, e.exampleId, e.examplePath])
        return check([
          [r.rows.length === 0, "no rows, got " + show(r.rows)],
          [r.values === 0, "values 0, got " + show(r.values)],
          [r.tableRows === 0, "tableRows 0, got " + show(r.tableRows)],
          [show(r.byPriority) === show({ P0: 0, P1: 0, P2: 0, P3: 0 }), "byPriority all 0, got " + show(r.byPriority)],
          [r.framesMeasured === 5, "framesMeasured 5, got " + show(r.framesMeasured)],
          [neg.values === 3, "negatives.values 3, got " + show(neg.values)],
          [show(got) === show(want), "negatives.list " + show(want) + ", got " + show(got)],
        ])
      },
    }
  },

  "18 rhythm mode: negative values group per variable and per unbound value"() {
    return negGroups("rhythm")
  },

  "19 token mode: the same negative values, no rows, no bind offer, not counted as bound"() {
    return negGroups("tokens")
  },

  "20 token mode never offers a negative token to a positive value"() {
    const { col, vars } = spaceTokens([["Space/Negative 025", -1], ["Space/100", 4], ["Space/200", 8]])
    const f = node("Plain", "FRAME", { paddingTop: 1, paddingLeft: 0.5 })
    // [priority, property, current, nearest, delta, fix.kind, fix.name], in the order the rows must come back.
    const want = [
      ["P1", "Padding left", 0.5, 4, 3.5, "bind", "Space/100"],
      ["P1", "Padding top", 1, 4, 3, "bind", "Space/100"],
    ]
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "tokens",
      assert: (r) => {
        const got = r.rows.map((x) => [x.priority, x.property, x.current, x.nearest, x.delta, x.fix && x.fix.kind, x.fix && x.fix.name])
        return check([[show(got) === show(want), "rows " + show(want) + ", got " + show(got)]])
      },
    }
  },

  "21 rhythm mode: the nearest value comes from the on-grid set, and a snap to an off-rhythm token names it"() {
    const { col, vars } = spaceTokens([["Space/0", 0], ["Space/Negative 100", -4], ["Space/050", 2], ["Space/100", 4], ["Space/150", 6], ["Space/200", 8]])
    const f = node("Plain", "FRAME", { paddingTop: 1, paddingRight: 3, paddingBottom: 6.5, paddingLeft: 7, itemSpacing: 5 })
    // [priority, property, current, nearest, delta, note], in the order the rows must come back.
    const want = [
      ["P2", "Padding top", 1, 2, 1, "nearest token Space/050 (2)"],
      ["P2", "Padding right", 3, 2, -1, "nearest token Space/050 (2)"],
      ["P2", "Padding left", 7, 8, 1, ""],
      ["P2", "Gap", 5, 4, -1, ""],
      ["P3", "Padding bottom", 6.5, 6, -0.5, "fractional; nearest token Space/150 (6)"],
    ]
    return {
      figma: mockFigma({ top: [f], collections: [col], variables: vars }), mode: "rhythm",
      assert: (r) => {
        const got = r.rows.map((x) => [x.priority, x.property, x.current, x.nearest, x.delta, x.note])
        const badFix = r.rows.filter((x) => show(x.fix) !== show({ kind: "set", value: x.nearest, reason: "nearest on-grid" }))
        return check([
          [show(got) === show(want), "rows " + show(want) + ", got " + show(got)],
          [badFix.length === 0, "every fix { kind: set, value: nearest, reason: nearest on-grid }, got " + show(badFix.map((x) => [x.property, x.fix]))],
          [!r.rows.some((x) => x.nearest <= 0), "nearest at or below 0 on " + show(r.rows.filter((x) => x.nearest <= 0).map((x) => x.property))],
          [show(r.negatives) === show({ values: 0, list: [] }), "negatives { values: 0, list: [] }, got " + show(r.negatives)],
        ])
      },
    }
  },

  "22 Edge values, rhythm mode: token 6 is the nearest value and two negative gaps are counted"() {
    return edgeValues("rhythm")
  },

  "23 Edge values, token mode: binds to Space/150 and counts the same negative gaps"() {
    return edgeValues("tokens")
  },

  "24 the token pack stripped: the base still counts a negative value and does not snap it"() {
    const lines = masterLines()
    const pack = loadPack(join(here, "..", "..", "..", "enhancements", "token-conformance"))
    const body = collectBody(stripUnits(lines, findUnits(lines, pack)))
    const stack = node("Stack", "FRAME", { itemSpacing: -2, paddingTop: 5 })
    const want = { values: 1, list: [{ label: "unbound -2", values: 1, exampleId: stack.id, examplePath: "Stack" }] }
    return {
      figma: mockFigma({ top: [stack] }), mode: "rhythm", body,
      assert: (r) => {
        const row = r.rows[0] || {}
        return check([
          [r.rows.length === 1, "one row, got " + show(r.rows)],
          [row.property === "Padding top" && row.nearest === 4, "Padding top, nearest 4, got " + show([row.property, row.nearest])],
          [show(r.negatives) === show(want), "negatives " + show(want) + ", got " + show(r.negatives)],
          [!("mode" in r), "no mode field, got " + show(r.mode)],
        ])
      },
    }
  },

  "25 more than eight kinds of negative value fold into one others entry"() {
    const top = Array.from({ length: 10 }, (_, i) => node("S" + (i + 1), "FRAME", { itemSpacing: -(i + 1) }))
    top.push(node("S1 twin", "FRAME", { itemSpacing: -1 }))
    const s9 = top[8]
    return {
      figma: mockFigma({ top }), mode: "rhythm",
      assert: (r) => {
        const neg = r.negatives || {}, list = neg.list || [], first = list[0] || {}
        const others = { label: "others", values: 2, exampleId: s9.id, examplePath: "S9" }
        const sum = list.reduce((s, e) => s + e.values, 0)
        return check([
          [neg.values === 11, "negatives.values 11, got " + show(neg.values)],
          [list.length === 9, "nine entries, got " + list.length],
          [first.label === "unbound -1" && first.values === 2, "first unbound -1 with 2 values, got " + show(first)],
          [show(list[8]) === show(others), "ninth " + show(others) + ", got " + show(list[8])],
          [sum === 11, "entries add up to 11, got " + sum],
        ])
      },
    }
  },
}

// A case may instead return { files() }: a check on the committed files, run without the mock.
cases["13 the oracle mirrors the collect fence except its declared hunks, and expected.json names the master's version"] = () => ({
  files() {
    const fence = BODY.slice(1) // the fence body after its `// helper: collect` marker line
    const oracle = normalize(readFileSync(join(here, "oracle.use_figma.js"), "utf8")).replace(/\n$/, "").split("\n")
    const expected = JSON.parse(readFileSync(join(here, "expected.json"), "utf8"))
    const version = /^\s+version:\s*"([^"]*)"/m.exec(readFileSync(master, "utf8"))?.[1] ?? null
    const problems = []
    // Hunk 1: the header and preamble, everything before the oracle's MODE line.
    const modeAt = oracle.findIndex((l) => /^let MODE = /.test(l))
    if (modeAt < 0) return ["the oracle has no `let MODE = ` line"]
    const header = oracle.slice(0, modeAt)
    let rest = oracle.slice(modeAt)
    // Hunk 2: the MODE preset. Hunk 3: MAX_ROWS lifted to Infinity.
    if (!/^let MODE = /.test(fence[0])) problems.push("the fence does not start with its `let MODE = ` line")
    rest = rest.slice(1).map((l) => l.replace("MAX_ROWS = Infinity", "MAX_ROWS = 60"))
    // Hunk 4: one line after the walk that clears the selection.
    const walk = rest.indexOf("for (const n of page.selection) await walk(n, false, null);")
    if (walk < 0 || !/^figma\.currentPage\.selection = \[\]; \/\/ oracle: /.test(rest[walk + 1] ?? "")) problems.push("hunk 4 (the selection clear after the walk) is not where the README says")
    else rest.splice(walk + 1, 1)
    // Hunk 5: a three-line block before the final return that restores tokens and unbound ids.
    const restore = rest.findIndex((l) => l.startsWith("// oracle: restore"))
    if (restore < 0 || rest.length - restore !== 4 || rest[rest.length - 1] !== "return out;") problems.push("hunk 5 (the restore block before `return out;`) is not where the README says")
    else rest.splice(restore, 3)
    const body = fence.slice(1)
    const at = body.findIndex((l, i) => l !== rest[i])
    if (at !== -1 || body.length !== rest.length) problems.push(`the oracle differs from the fence outside the declared hunks at fence line ${at === -1 ? body.length + 1 : at + 2}: ${show(rest[at === -1 ? body.length : at] ?? "<end>").slice(0, 100)}`)
    return [...problems, ...check([
      [version !== null && expected.masterVersion === version, `expected.json masterVersion ${show(expected.masterVersion)}, master metadata.version ${show(version)}`],
      [header.some((l) => l.includes(`metadata.version "${version}"`)), `the oracle header does not name metadata.version "${version}"`],
    ])]
  },
})

// The Output contract's template is printed verbatim, so it may hold only printable text and `<…>` placeholders.
cases["16 the report template is literal"] = () => ({
  files() {
    const lines = normalize(readFileSync(master, "utf8")).split("\n")
    const inFence = scanFences(lines)
    const heading = lines.findIndex((l, i) => !inFence[i] && /^## Output contract\s*$/.test(l))
    if (heading < 0) return ["no `## Output contract` heading in the master"]
    const open = lines.findIndex((l, i) => i > heading && /^\s*```/.test(l))
    if (open < 0) return ["no fenced block after `## Output contract`"]
    let close = open + 1
    while (close < lines.length && !/^\s*```/.test(lines[close])) close++
    const block = lines.slice(open + 1, close)
    const notes = ["(only ", "(token mode", "(table below", "(or the", "one entry per"]
    const required = [
      "## Spacing rhythm audit: <scope name>",
      "- Off-grid values: P0 <n> · P1 <n> · P2 <n> · P3 <n> (<n> values in <n> rows)",
      "- Changed: <n> properties on <n> layers · Verified: <n> of <n>",
    ]
    return [
      ...notes.flatMap((s) => block.filter((l) => l.includes(s)).map((l) => `a line holds ${show(s)}: ${show(l)}`)),
      ...block.filter((l) => !l.startsWith("|") && l.includes(" | ")).map((l) => `a line outside a table holds " | ": ${show(l)}`),
      ...block.filter((l) => l.includes("Space/150")).map((l) => `a line holds "Space/150": ${show(l)}`),
      ...required.filter((r) => !block.includes(r)).map((r) => `the block has no line ${show(r)}`),
    ]
  },
})

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

let failed = 0
for (const [name, make] of Object.entries(cases)) {
  let problems
  try {
    const { figma, mode, assert, files, body } = make()
    problems = files ? files() : assert(await runCollect(figma, mode, body))
  } catch (e) {
    problems = ["threw: " + (e && e.stack ? e.stack.split("\n")[0] : String(e))]
  }
  if (problems.length) failed++
  console.log((problems.length ? "FAIL " : "PASS ") + name + (problems.length ? "\n  - " + problems.join("\n  - ") : ""))
}
const total = Object.keys(cases).length
console.log(`${total} cases, ${failed} failed`)
process.exit(failed ? 1 : 0)
