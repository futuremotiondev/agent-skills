# Reference — fm-extract-color-swatches

Depth material for the main [SKILL.md](SKILL.md). Read this when an extraction
hits something the quick workflow doesn't cover.

---

## 1. Name assembly rules

The `name` column is the swatch label Photoshop shows in its Swatches panel
(tooltip on hover, visible text in Small/Large List view, prefilled value in the
rename dialog). It is stored in the `.aco` version-2 block as a length-prefixed
UTF-16 big-endian string. It has no effect on the color itself.

### Rule set, in order of application

1. **Inherit the scale name.** Every swatch in a scale gets the scale's full
   name, regardless of whether the page printed it. `Red` + `200` → `Red 200`.
2. **One space separator.** `Deep Purple` + `A400` → `Deep Purple A400`. Never
   a hyphen, underscore, or slash — those read badly in the panel and some are
   awkward in filenames if the user later exports per-swatch.
3. **Zero-pad numeric tones to width 3.** `50` → `050`, `5` → `005`,
   `100` → `100`. Tones already at or above the pad width pass through
   untouched. This exists purely so alphabetical sort in Photoshop matches
   numeric order — without it `Red 100` sorts before `Red 50`.
4. **Pad the numeric part of accent tones, keep the prefix.** `A100` → `A100`,
   `A50` → `A050`. The prefix letter is preserved verbatim, including its case.
5. **Standalone colors bypass padding entirely.** `Black`, `White`,
   `Brand Primary` emit as written.
6. **Names must be unique across the file.** Photoshop tolerates duplicates
   (it identifies swatches by index, not name), but duplicates in your CSV
   almost always mean a transcription error — the same scale read twice, or a
   tone typo'd. The builder treats them as fatal.

### Naming conventions worth keeping consistent

If the user is building a swatch library over time, consistency across `.aco`
files matters more than any individual choice. Ask once, then stick to it:

- Title Case scale names (`Deep Orange`, not `deep orange` or `DEEP ORANGE`)
- Source prefix when mixing systems in one library (`MD Red 500` vs
  `Tailwind Red 500`) — prevents collisions and makes the panel scannable
- Regional spelling follows the source page unless told otherwise

---

## 2. Color space IDs

`space_id` values accepted by `Convert-Swatch`:

| ID | Space | Channels | Notes |
|:--:|:--|:--|:--|
| 0 | RGB | 3 | **Default for this skill.** 16-bit (`#RRGGBB`) or 32-bit (`#RRRRGGGGBBBB`) |
| 1 | HSB | 3 | Same width options as RGB |
| 2 | CMYK | 4 | `#CCMMYYKK` (16-bit) or double-width (32-bit) |
| 8 | Grayscale | 1 | `#GGGG` — a single 0–10000 value, **not** a hex gray |

Unsupported by the tool: 3 (Pantone), 4 (Focoltone), 5 (Trumatch), 6 (Toyo),
7 (Lab), 10 (HKS).

Web palettes are RGB. Stay on `0` unless the user explicitly asks for another
space, and if they ask for CMYK, flag that a naive RGB→CMYK conversion without
an ICC profile will not match print output — that conversion belongs in
Photoshop or Illustrator, not in this pipeline.

The Grayscale (`8`) trap: its value is not a hex gray level. `#1D4C` is decimal
7500, i.e. 75% gray on a 0–10000 scale. Converting `#808080` to grayscale means
computing luminance and rescaling to 0–10000, not truncating the hex.

---

## 3. Hex normalization

The builder applies these transforms before writing:

| Input | Output | Behavior |
|:--|:--|:--|
| `#ffebee` | `#FFEBEE` | Uppercased |
| `ffebee` | `#FFEBEE` | Leading `#` added |
| `#fbe` | `#FFBBEE` | 3-digit shorthand expanded (warn) |
| `#FFEBEEFF` | `#FFEBEE` | Alpha dropped (warn) |
| `#fbea` | `#FFBBEEAA` → `#FFBBEE` | 4-digit shorthand expanded, alpha dropped (warn) |
| `#FFEB` | — | Error: ambiguous length |
| `#GGHHII` | — | Error: non-hex characters |

`--strict` promotes every warn to an error. Use it when the extraction is going
straight into a shared library and silent alpha loss would be a problem.

### Non-hex notations

Modern design systems increasingly publish `oklch()`, `hsl()`, or `rgb()`.
Convert to sRGB hex before building the JSON:

- `rgb(244 67 54)` → clamp each channel to 0–255, format as two hex digits
- `hsl(4 90% 58%)` → standard HSL→RGB conversion
- `oklch(0.63 0.24 29)` → needs a real color library (`culori` in Node,
  `coloraide` in Python). Do not eyeball it. If neither is available, tell the
  user rather than approximating — an OKLCH palette approximated by hand will
  be visibly wrong in the wide-gamut regions, which is exactly why the source
  used OKLCH.

A wide-gamut source color may fall outside sRGB. Gamut-clip it and say so —
the resulting swatch is an approximation, and the user should know before it
lands in a print or brand workflow.

---

## 4. Image extraction

### Why detection beats reading the labels

A palette sheet prints its hex codes at whatever size the layout allows —
frequently 10–12px. Vision reads those, but the errors it makes are the
dangerous kind: `8`/`B`, `0`/`D`, `5`/`6`, `1`/`7` substitute cleanly and produce
a color that is *plausible*, sits next to its neighbors in the ramp, and looks
correct in the CSV. Nothing downstream flags it. Meanwhile the chip's actual
pixels are sitting right there, unambiguous.

So the rule is: **vision reads structure, pixels supply color.** Names and tones
are short, high-contrast, and constrained by the ramp's pattern — misreading
`700` as `100` is caught the moment the tone sequence stops making sense.
Misreading `#0086B4` as `#0D86B4` is caught by nothing.

`map` mode enforces this split. Its layout file has no place to put a hex, so
the failure mode is designed out rather than warned about.

### How detection works

`find_solid_rects` finds axis-aligned rectangles of uniform color by run-length
merging: per scanline it finds maximal runs of one color, then merges runs that
share an exact color and x-extent down the image. That is exactly the shape of a
palette chip, and it deliberately will not match photographs, gradients, or
anti-aliased text.

Two behaviors worth understanding:

**Row gaps (`--max-row-gap`, default 60).** Sheets routinely print the swatch
label *on top of* the color. That text breaks the run on every scanline it
crosses, so a strict consecutive-rows rule finds nothing at all on card-style
layouts. Allowing a bounded vertical gap fixes it. Each detected rect reports
`coverage` — the fraction of its rows carrying the full run. Solid chips land
near 1.0; a low value means heavy text overlay, or two same-colored chips wrongly
merged across a gap. Lower `--max-row-gap` if you see the latter.

**Exact x-extent matching.** A chip sitting inside a wider label card is found as
its own rect rather than being absorbed into the card. `drop_contained` then
removes the card, since it fully encloses the chip.

### Tuning detection

Work in this order:

1. `--sizes` first, always. It reports the most common rect dimensions. On a
   card-style sheet you will see two or three tight clusters: the chips, the
   cards, and the inter-card gaps. Chip count usually matches the visible swatch
   count exactly.
2. `--size WxH` to isolate the chip cluster. This is the highest-leverage filter
   by a wide margin — it removes cards, gaps, dividers, and headings in one move.
3. `--size-tolerance` (default 0.1) if a scale is short by one or two. Sub-pixel
   rendering makes nominally identical chips differ by a pixel or two; one real
   sheet has a single 140px chip in a row of 136px ones. An exact-match filter
   loses it and nothing tells you.
4. `--min-size` to set the floor. Raise it on dense sheets to cut noise from
   icons and rule lines.
5. `--max-area-frac` (default 0.02) drops page and card backgrounds. Raise it
   only if a legitimately huge chip is disappearing.

### The white-chip trap

A `#FFFFFF` swatch on a white page has no boundary. Its run merges with the
background, the merged rect exceeds the area limit, and the swatch vanishes from
detection with no error. This is not rare — it hit both reference sheets:

- Adobe Spectrum's `gray-50` is `#FFFFFF`
- Salesforce Lightning's `NEUTRAL_100` is `#FFFFFF`

Two consequences:

- **Never `--exclude "#FFFFFF"`** as a cleanup step. On a sheet with a real white
  swatch you will drop the swatch and keep the noise.
- **Always count.** Compare detected chips per scale against what you see in the
  image. A scale short by exactly one, at the light end, is this bug every time.

The fix is a literal tone in the layout, which holds ramp position without
consuming a detected chip:

```json
{ "name": "Gray", "tones": [{"tone": "100", "hex": "#FFFFFF"}, "95", "90"] }
```

The same applies to a black chip on a black background, and to any chip whose
color matches its card.

### Reading a sheet's structure

Before writing the layout, settle four things by looking at the image:

1. **Orientation.** Scales as rows or as columns? Getting this backwards
   mislabels everything while producing no error.
2. **Tone direction.** Light-to-dark is common but not universal — Salesforce
   Lightning runs 95 down to 10, the reverse of Material's 50 up to 900.
   Detection returns reading order; your tone list must match it.
3. **Ragged scales.** Neutral ramps often have extra steps (Spectrum's gray adds
   a `75`; Lightning's neutral adds `100` and `0`). Never assume every scale has
   the same tone list.
4. **Names vs. tokens.** A column headed `Gray` whose tokens read
   `$PALETTE_NEUTRAL_*` gives you two defensible names. Ask.

### When detection isn't the right tool

- **`sample` mode** — for layouts detection can't segment. Give it points
  (`--points 120,340`) or rects (`--rects x,y,w,h`) and it returns the modal
  color in a small box. Mode, not mean: averaging across a chip edge invents a
  color that isn't in the image. It returns `null` when the box isn't uniform,
  which reliably means the point missed the chip.
- **`quantize` mode** — for photographs, moodboards, gradients, artwork.
  `MEDIANCUT` (default) tracks the actual color distribution; `--spread`
  switches to `MAXCOVERAGE`, which spreads across the gamut and gives better
  variety at the cost of fidelity. Results are approximations of a continuous
  image and should be labeled as such to the user.
- **`verify` mode** — when a palette JSON was transcribed by hand and you want a
  safety net. It reports transcribed colors absent from the image, with the
  nearest detected color when one is within ~20 per channel, which is the
  signature of an OCR slip rather than a different swatch.

### Image quality caveats

Sampling is exact only if the pixels are. Flag these to the user rather than
silently producing wrong colors:

- **JPEG artifacts.** Lossy compression shifts flat colors by a few units and
  creates ringing at chip edges. A JPEG palette sheet yields near-right colors,
  not right ones. Ask for a PNG if one exists.
- **Screenshots on a wide-gamut display.** macOS screenshots on a P3 display can
  carry a Display P3 profile; the raw RGB then isn't sRGB. Pillow returns the raw
  values, so the hex may not match the source's published sRGB code.
- **Scaled screenshots.** Resampling blends chip edges. Chip interiors stay clean,
  which is why sampling uses the interior, but very small chips can lose their
  uniform core entirely.
- **Dark mode sheets.** Nothing special except that the vanishing-chip trap moves
  from white to whatever the background is.

---

## 5. Scraping notes by source type

**Static markdown-friendly pages** (Material Design, Bootstrap docs) — a plain
`firecrawl_scrape` with `formats: ["markdown"]` is enough. Palette grids
collapse to runs like `Red 50#FFEBEE`, one per line.

**JS-rendered palettes** (many modern design-system sites) — add
`waitFor: 3000`. If still empty, request `rawHtml` and read hexes out of
inline `style` attributes or `data-*` attributes.

**CSS-variable-driven palettes** (Tailwind, Radix) — the authoritative source
is usually a stylesheet or the framework's source repo, not the marketing page.
For Tailwind, the palette lives in the published theme rather than the docs
HTML; fetching the source is more reliable than scraping rendered swatch chips.

**Image-only palettes** — if the colors exist solely as pixels in a rendered
image, this skill can't extract them. Say so, and suggest sampling in an image
editor instead of guessing from a screenshot.

### Verification before emitting

Cross-check two things every time:

1. **Count.** Scales × tones + standalone entries should equal the row count.
   A mismatch means a scale was truncated mid-read.
2. **Spot-check three hexes** against the source at different points in the
   file — first scale, middle, last. Markdown flattening occasionally drops or
   merges a run, and the failure is silent.

---

## 6. The `.aco` format, briefly

Two versions exist, and real files typically contain both blocks back to back:

- **Version 1** — count + per-swatch (space ID, 4× uint16 color components).
  No names.
- **Version 2** — same color data plus a per-swatch name as a length-prefixed
  UTF-16BE string. This is what modern Photoshop reads, and the only reason
  your `name` column survives the round trip.

`Convert-Swatch` writes both, so generated files import into old and new
Photoshop alike.

For RGB, each 8-bit channel is scaled to 16 bits by multiplying by 257
(`0xFF` → `0xFFFF`), which is why `#FF00FF` and `#FFFF0000FFFF` describe the
same magenta in the CSV format.

---

## 7. Post-generation checklist

Before handing the `.aco` to the user:

- [ ] Row count matches the source palette
- [ ] Three spot-checked hexes match the page
- [ ] No duplicate names (the builder enforces this)
- [ ] Every `space_id` is `0` unless deliberately changed
- [ ] Padding applied consistently — no bare `50` alongside `050`
- [ ] Scale names use consistent casing
- [ ] User told about any dropped alpha or gamut clipping

For image extractions, additionally:

- [ ] Detected chip count per scale matches the visible sheet
- [ ] Orientation (rows vs. columns) matches the image
- [ ] Tone direction matches the sheet's own order
- [ ] Any white or background-colored chip accounted for explicitly
- [ ] Source was PNG, or the user was told JPEG colors are approximate
