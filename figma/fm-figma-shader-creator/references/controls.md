# Controls: every `defineProperties` type and field

`defineProperties(Effect, { key: spec, ... })` takes a flat object. **Keys are permanent
identifiers** that applied layers, effect styles, and presets store by definition id; labels are UI
text you can change freely. Figma itself diverges them (key `offset`, label "Phase").

## Property types

"Documented" means Figma's official skill or docs state it. "Observed" means seen in first-party
source or the Plugin API on 2026-11-02.

| Type | Fields | Value in `frame.params` | Plugin API type | Status |
| --- | --- | --- | --- | --- |
| `boolean` | `label`, `defaultValue` | `true` / `false` | `BOOLEAN` | Documented |
| `string` | `label`, `defaultValue` | string, sometimes `{ characters: string }` | `TEXT` | Documented ("genuine free text only") |
| `number` slider | `control: "slider"`, `min`, `max`, `step`, optional `unit` | raw slider value (not normalised by unit) | `NUMBER` | Documented; always give all three bounds |
| `number` input | `control: "input"`, optional `unit`, `min`, `max` | number | `NUMBER` | Documented |
| `number` select | `control: "select"`, `options: [{ value: number, label }]` | number | `NUMBER` | Documented; the rule for every dropdown |
| `color` | `label`, `defaultValue: { r, g, b, a }` | `{ r, g, b, a }` floats 0..1 | `COLOR` | Documented |
| `gradient` | `label`, `defaultValue: { stops: [...] }` | `{ stops: [{ position: 0..1, color: { r, g, b, a } }] }`, 2 to 8 stops | `GRADIENT` | Documented; pack a fixed 8-stop uniform plus a count |
| `point` | `control: "point"`, `mode`, `unit` | `{ x, y }` in the declared unit | `POINT` | Documented; prefer `mode: "canvas_and_ui"`, `unit: "%"` |
| `point-radius` | `control: "point-radius"`, `mode`, `positionUnit`, `radiusUnit`, `minRadius`, `maxRadius` | `{ x, y, radius }` | observed on Bloom | Documented; radius percent is relative to the smaller layer dimension |
| `point-point-line` | `unit` | `{ x, y, x2, y2 }` | none seen | Documented, never declared in any first-party source |
| `point-angle-radius` | `mode`, `positionUnit`, `radiusUnit`, `minRadius`, `maxRadius` | `{ x, y, radius, angle }`, angle in degrees | observed on Pixel stretch, Pattern grid, Glowing wave | Documented |
| `color-point` | `control: "color-point"`, `mode`, `unit` | `{ x, y, color: { r, g, b, a } }` | observed on Mesh gradient | Documented; prefer over separate position and colour controls |

Field notes:

- `mode`: `"canvas_and_ui"` (handle plus panel fields), `"ui"` (panel only), `"canvas"` (handle
  only; used by Mesh gradient). Do not replace a supported canvas handle with X/Y sliders.
- `unit`: `"%"` or `"px"`. A `"px"` control is in design points; multiply by `renderScale` only
  when you need texels. Percent values are divided by 100 in JS before upload.
- `unitLabel`: appears on two first-party shaders and in no documentation. Use `unit`.
- `description`: no first-party property uses it. Your house style may; it is harmless.
- There is no `image`, `texture`, `angle`, `vector`, `range`, `group`, or `section` type. The panel
  has no grouping; order is the only organisation.

## Dropdown rule: numeric selects only for new work

Official: "Dropdowns must be numeric selects. Do not use a string with `control: "select"`; it
becomes unstable after edits." Seven first-party shaders still ship string selects and defend
themselves by unwrapping `{ characters }`.

- **New dropdown**: `type: "number"`, `control: "select"`, integer `value`s, labels carry the names.
  Decode in WGSL with `i32(u.mode + 0.5)`.
- **Existing string select in a shader you modify**: keep it. Stored layers and styles hold the
  string; changing the type orphans them. Read it with a `.characters`-aware reader and map to an
  integer in JS.
- Numeric ids need not follow display order. fm-halftone lists `gridType` values `0, 1, 7, 2, 3, 4,
  5, 6` because ids are permanent and the dropdown is ordered for humans. Never renumber.

## Naming and units

- Control keys are `camelCase` nouns (`cellSize`, `lineOpacity`, `colorA`); a group prefix is fine
  when a group has several members (`angleC`, `angleM`). Keys are permanent, so choose them as if
  they will be read by someone else's style a year from now.
- Define every unit where it is not obvious. `%` must say percent *of what* in the label or the
  header ("Line thickness" as percent of line pitch; "Radius" as percent of the smaller layer
  dimension). `px` means design points. Unitless 0..100 "amount" sliders map to an engineering
  range in JS; state that range in the uniform comment.
- Two `color` controls when the brief names two colours or roles ("top" and "bottom", "ink" and
  "paper"). A `gradient` control when the user should be able to add stops. Interpolate colours in
  linear light unless the look is meant to match a plain sRGB mix.
- Adding a control the brief did not ask for is fine when the presets or the look need it (a
  strength control so "Subtle" and "Heavy" can differ). Keep it minimal and say so in the report.

## Defaults, ranges, labels, and order

Figma's review guideline doubles as the quality bar for every shader, published or not:

- Defaults are the finished result. Never put a default at a range edge, with one exception:
  keyframable phase, scroll, travel, or progress controls rest at 0 by design (the validator
  reports those as info, not errors). Zero-means-off amounts (jitter, bleed, misregistration) are
  also acceptable at 0 when the default look should not include the effect.
- Expose only settings a user would meaningfully adjust per layer; hardcode the rest inside
  `setup` or `render`.
- The shader must be correct at every value and at extreme combinations.
- Labels: one to three words, sentence case ("Edge softness", not "Edge Softness").
- Order: discrete mode selects first, then size and scale, then colour, then quality and softness,
  then booleans, then spatial handles last. Put a `preset` select first when the shader has factory
  presets.
- Every `defaultValue` must equal the fallback the JS reader uses. Two first-party shaders drifted
  (Halftone `softness` 0.1 vs 0.0). The factory-preset pattern removes the drift by making one
  `defaults` table the single fallback source.

## Reading params defensively

Copy this reader block into `render()`. It returns exactly the value shapes the `defaults` table
uses in factory-presets.md.

```ts
var p = frame.params || {}
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
// Packs up to 8 gradient stops into 41 floats: 8 x RGBA, 8 positions, count.
function packGradient(list) {
  var out = new Array(41).fill(0)
  var n = Math.min(list.length, 8)
  for (var i = 0; i < n; i += 1) {
    var s = list[i] || {}, c = s.color || {}
    out[i * 4] = fin(c.r, 0); out[i * 4 + 1] = fin(c.g, 0); out[i * 4 + 2] = fin(c.b, 0); out[i * 4 + 3] = fin(c.a, 1)
    out[32 + i] = fin(s.position, 0)
  }
  out[40] = n
  return out
}
```

Gradient positions should be clamped and sorted; a single stop is duplicated to positions 0 and 1
(Shape-based particles does this). Convert units in JS before upload: percent to fraction, degrees
to radians, 0..100 UI sliders to engineering ranges.

## How applied values are stored on layers

Through the Plugin API, an applied shader is `ShaderEffect` in `node.effects` or `ShaderPaint` in
`node.fills` / `node.strokes`, each `{ type: 'SHADER', id, properties }`. `properties` is keyed by
**definition id** strings such as `"3081908717:2821741862"`, not by control key. Resolve names
through `shader.propertyDefinitions[defId].name` for the same version. Numbers come back
float32-rounded (`0.10000000149`). See mcp-workflow.md for the harvesting script.
