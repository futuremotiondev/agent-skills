# `<fm-name-shader>` — architecture notes

Reference for anyone editing `main.ts`. Kept separate from HANDOFF.md so the handoff stays short.

## Identity

| Thing | Value |
| --- | --- |
| Shader id | `<uuid>` |
| Kind | `effect` or `fill` |
| Current built version (SHA) | `<40-char sha>` |
| Manifest | version `<2 or 3>`, isAnimated `<bool>`, usesMouse `<bool>` |
| Owner account | `<email>` (plan key `team::<n>`) |

## Runtime model

- `setup(device, frame)` compiles WGSL, creates buffers, textures, sampler.
- `render(device, frame)` reads params, writes uniforms, encodes passes, submits.
- Units: design points; `renderScale` divides physical sizes. Padding handled: `<yes or no>`.
- Alpha: `<premultiplied in and out | straight out>`.

## Passes

1. `<pass>` → `<target texture, size, format>`
2. `<pass>` → `frame.output`

## Uniform layout (`<N>` bytes = `<N/4>` f32)

| Slot | Fields |
| --- | --- |
| `p0` | `<a>, <b>, <c>, <d>` |
| ... | |

Offsets in the JS `data.set` call: `<list>`. Keep the WGSL struct comments and this table in sync.

## Select ids

| Control | Ids |
| --- | --- |
| `<mode>` | 0 `<A>` · 1 `<B>` (display order may differ; ids are permanent) |

## Presets

Factory presets (ids are permanent):

| Id | Label | Delta summary |
| --- | --- | --- |
| 1 | `<Label>` | `<keys>` |

User presets: Figma effect or fill styles.

## Known limitations and ideas

- `<limitation>`
