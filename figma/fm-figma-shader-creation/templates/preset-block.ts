// Factory-preset block. Paste the first part at the top of render() (after `var p = frame.params || {}`)
// and the second part at the top of defineProperties(). Then make every later line of render()
// read `v.*` instead of frame.params. See references/factory-presets.md.

// ===== Part 1: inside render() ==============================================================

  // ---------------------------------------------------------------------------
  // Param readers. Every control is read into `live` so the preset engine can replace
  // it wholesale. Readers return exactly the shapes `defaults` uses.
  // ---------------------------------------------------------------------------
  function fin(x, fb) { var n = Number(x); return Number.isFinite(n) ? n : fb }
  function num(name, fb) { return fin(p[name], fb) }
  function bool(name, fb) { return typeof p[name] === "boolean" ? (p[name] ? 1 : 0) : (fb ? 1 : 0) }
  function color(name, fb) { var c = p[name] || {}; return [fin(c.r, fb[0]), fin(c.g, fb[1]), fin(c.b, fb[2]), fin(c.a, fb[3])] }
  function point(name, fb) { var q = p[name] || {}; return [fin(q.x, fb[0]), fin(q.y, fb[1])] }
  function par(name, fb) { var q = p[name] || {}; return { x: fin(q.x, fb.x), y: fin(q.y, fb.y), radius: fin(q.radius, fb.radius), angle: fin(q.angle, fb.angle) } }
  function str(name, fb) {
    var s = p[name]
    if (typeof s === "string") return s
    if (s != null && typeof s === "object" && typeof s.characters === "string") return s.characters
    return fb
  }
  function stops(name, fb) { var g = p[name] || {}; return Array.isArray(g.stops) && g.stops.length > 0 ? g.stops : fb }

  // ---------------------------------------------------------------------------
  // Control defaults. MUST mirror the defaultValue of every control in
  // defineProperties() below (module-scope constants are stripped by the build, so
  // the table lives here). Presets are applied on top of these, never on top of the
  // live sliders; that is what makes a preset render identically everywhere.
  // ---------------------------------------------------------------------------
  var defaults = {
    // <key>: <defaultValue in reader format>,
  }

  // Live values from the panel, in the same shape as `defaults`.
  var live = {
    // <key>: num("<key>", defaults.<key>),
  }

  // ---------------------------------------------------------------------------
  // Factory presets. Each entry is a delta applied to `defaults`.
  //
  // To add a preset:
  //   1. Add { value: N, label: "Name" } to the `preset` options in defineProperties().
  //   2. Add factoryPresets[N] = { ...only the controls that differ from defaults... }.
  // Keys and value formats match `defaults` exactly (colors are [r,g,b,a] in 0..1,
  // points are [x%, y%], booleans are 0/1, selects use numeric ids, gradients are
  // stop arrays). Anything not listed renders at its default, never at the live slider.
  // Ids are permanent: styles store them. Never renumber or reuse an id.
  // ---------------------------------------------------------------------------
  var factoryPresets = {
    // 1: { // <Label>
    //   <key>: <value>,
    // },
  }

  // Resolve the effective control set: a preset fully replaces the live panel.
  var presetId = num("preset", 0)
  var v = live
  if (presetId > 0 && factoryPresets[presetId]) {
    v = Object.assign({}, defaults, factoryPresets[presetId])
  }

// ===== Part 2: first entry inside defineProperties(Effect, { ... }) =========================

  // ---- Presets ----
  // "Custom" renders the live controls below. Any other entry renders the preset exactly
  // (defaults + delta in render()); the sliders are ignored while a preset is selected.
  preset: {
    type: "number", label: "Presets", defaultValue: 0, control: "select",
    options: [
      { value: 0, label: "Custom (use controls)" },
      // { value: 1, label: "<Label>" },
    ],
  },
