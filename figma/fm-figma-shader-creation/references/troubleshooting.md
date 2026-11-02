# Troubleshooting, contradictions, and open questions

## Build and runtime failures

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `ReferenceError` for a name defined at the top of the file | Module-scope `var`/`let`/`const` stripped by the loader | Move data into `setup`, `render`, or `frame.state`; functions may stay at module scope |
| Build rejects a WGSL `const` inside a function | Figma policy | Use `let` |
| naga error about `textureSample` in non-uniform control flow | Missing directive, or an implicit-derivative call inside a per-pixel branch | Put `diagnostic(off,derivative_uniformity);` first; prefer `textureSampleLevel(..., 0.0)`; sample first then `select` |
| naga error about a swizzle assignment | `v.xy = ...` | Assign the whole vector |
| Bind group entry count mismatch or missing binding | Entry point never uses a declared binding, so `layout: "auto"` drops it | Match entries to the bindings the entry point actually reads; rebuild groups per pipeline |
| Validation error on `writeBuffer` size | Buffer size not a multiple of 16, or write larger than buffer | Recount floats; size = floats x 4 rounded up to 16 |
| Shader renders black or transparent | Pipeline hardcoded to `rgba8unorm` while output is another format; or fill wrote premultiplied with low alpha | Key the pipeline by `frame.output.format`; fills return straight alpha |
| Semi-transparent fill looks darker than the colour picker | Premultiplied output in a fill | Return straight alpha |
| Effect edges have dark fringes | Un-premultiplied input treated as straight | Un-premultiply before colour maths, re-premultiply at the end |
| Opaque streaks at the layer edge of an effect | Clamp-to-edge sampling in the output halo | Use `sampleInputOrZero` for samples that can land outside the content rect |
| Animation frozen on frame one | Source reads `frame.time` but `isAnimated` is false | `update_shader` with `metadata: { isAnimated: true }` |
| Mouse never updates | `usesMouse` false | `metadata: { usesMouse: true }`; guard a missing mouse |
| `update_shader` says animation or mouse unavailable | Capability gate | Terminal; build a static shader with a keyframable phase |
| Dots, cells, or grain change size with zoom or export scale | Geometry in physical texels | Divide `output` sizes by `renderScale`, keep user units in points |
| Spring or particle simulation explodes in Motion | Negative `deltaTime` when the playhead loops | Zero the delta on discontinuities, clamp to 100 ms |
| Dropdown value lost after editing | String select | Numeric select for new work; `.characters`-aware reader for existing |
| Preset renders differently on two layers | Resolver applied the delta to `live` instead of `defaults` | `Object.assign({}, defaults, factoryPresets[id])` |
| A preset silently became "Custom" | Its id was deleted or renumbered | Restore the entry; never delete ids |
| Second update fails with "cannot add files" | A path other than `main.ts` | Only `main.ts` |
| Kind mismatch | Wrong `kind` on update | Use `get_shader.type` |
| Shader works in a web harness but not in Figma | Harness does not strip module-scope data, or uses `gpu` / `mousePosition.down` | Validate with `scripts/validate-shader.mjs`; write Figma-first |

## Contradictions between sources, with the working rule

| Topic | Official | Observed | Rule |
| --- | --- | --- | --- |
| Manifest version | Studio spec and web runtime default to 2 | 19 of 20 first-party shaders are version 3 with `renderScaleAware: true`; a fresh scaffold is version 2 | No MCP field changes it; write render-scale-correct code regardless |
| Dropdowns | Numeric only | Seven first-party shaders use string selects | Numeric for new; keep existing strings |
| Fill alpha | Straight | Scaffold and Pattern grid premultiply; live probe confirms straight compositing | Straight |
| Re-review | Manage page: none after approval | Review page: material updates re-reviewed | Assume re-review; big visual changes become a new shader |
| `unit` vs `unitLabel` | `unit` | `unitLabel` on two shaders, undocumented | `unit` |
| `mode: "canvas"` | Not in the official skill | Shipped by Mesh gradient; Studio spec defines it as handle-only | Valid |
| `isAnimated` | True iff source reads time | Glowing wave is described as animated yet false (phase-driven) | Set strictly by source reads |
| `frame.renderScale` presence | Undocumented | Present on a version-2 fill in the live probe; first-party shaders divide by it unguarded | Present; still guard with `\|\| 1` |
| `output.width` meaning | "Use it for dimensions" | Physical texels; equals design pixels at 1x, 250 for 500 pt at 0.5x | Divide by `renderScale` for points |
| `physicalWidth`, padding fields | Undocumented | Undefined on the version-2 fill probe; read with `??` by version-3 effects | Optional; always fall back |
| Function-scope `const` | Forbidden | Legal WGSL | Policy; use `let` |
| Reserved names | `texture`, `sampler`, `min`, `max`, `meta` | Only `meta` and `mod` are spec-reserved | Avoid all of them anyway |
| Module-scope functions | Studio spec reserves module scope for five items | Many first-party helper functions | Functions allowed, data forbidden |
| Diagnostic directive | Mandatory | Clouds and Light rays omit it and ship | Always include it |
| `cleanup()` | None | One community file hopes for it | Destroy on reallocation yourself |
| Plan availability | All plans | One blog claims paid Full seats only | Follow the help centre |
| Export render scale | Undocumented | Exports at scale >= 1 rendered the shader at 1x; 0.5x rendered at 0.5 | Test downscaled exports; test high-DPI by zooming in the app |

## Open questions (not resolvable without a UI session or a Figma statement)

- How the in-app picker thumbnail is produced for an unpublished shader, and whether publishing
  replaces it.
- Whether `physicalWidth` and the padding fields are gated by manifest version or by kind.
- Whether exports above 1x ever render the shader above 1x, or always upscale a 1x raster.
- What `isAnimated` changes in the in-app host beyond enabling the clock (continuous re-render
  versus on-change).
- Whether `unitLabel` is an alias of `unit` or ignored.

When one of these matters for a decision, test it with a throwaway probe shader (design-patterns.md,
"Debugging without a console") rather than guessing.
