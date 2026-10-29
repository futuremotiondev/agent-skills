---
name: fm-extract-color-swatches
description: Extract a color palette from a webpage URL or an image file and emit a swatch CSV (name,space_id,color) ready for the Convert-Swatch PowerShell function to convert into a Photoshop .aco or .ase file. Use when the user wants to extract, rip, scrape, sample, or harvest color swatches, a color palette, a design-system color ramp, or brand colors from a URL, a screenshot, a palette sheet, a design-system export, or any image — including Material, Tailwind, Radix, Adobe Spectrum, and Salesforce Lightning palettes — or asks for a .aco / Photoshop swatch file from web or image colors.
---

# FM Extract Color Swatches

Turns a palette published on a webpage **or captured in an image** into a swatch
CSV in the `Convert-Swatch` import format, ready to compile into a Photoshop
`.aco` or `.ase`.

The division of labor is the same for both inputs: **you** do the interpretive
part (fetching, recognizing what is a scale name vs. a tone vs. a color). The
**scripts** do the deterministic part (reading exact pixel values, name
assembly, zero-padding, hex normalization, validation). Never hand-write the
CSV, and never transcribe a hex string you could sample instead.

## Output contract

```csv
name,space_id,color
Red 050,0,#FFEBEE
Red 100,0,#FFCDD2
Red A100,0,#FF8A80
```

- `name` — scale name + tone, one space between.
- `space_id` — always `0` (RGB) unless the user explicitly asks otherwise.
- `color` — `#` + 6 uppercase hex digits.

Numeric tones are zero-padded so alphabetical sort matches numeric order. Pad
width is derived from the palette automatically: a ramp topping out at 900 pads
to 3 (`050`), one reaching 1400 pads to 4 (`0050` … `1400`). Don't override it
unless the user asks.

## Pick a route

| Input | Route |
|:--|:--|
| URL | [Route A — scrape](#route-a--scrape-a-url) |
| Image with printed hex codes and names | [Route B — image with labels](#route-b--image-with-labels) |
| Image with names but no hex codes | Route B — the pixels are the source either way |
| Image with neither | [Route C — image without labels](#route-c--image-without-labels) |
| Photo, moodboard, artwork | [Route D — photographs and artwork](#route-d--photographs-and-artwork) |

If the user supplies both an image and a URL for the same palette, prefer the
image: sampled pixels are exact, and no rendering or JS timing can go wrong.

---

## Route A — scrape a URL

1. **Fetch** with an MCP crawler (Firecrawl `firecrawl_scrape`, Tavily
   `tavily_extract`, or Exa) using `formats: ["markdown"]`. Palette grids
   collapse into readable runs like `Red 50#FFEBEE`. If the result is empty,
   retry with `waitFor: 3000`, then fall back to `formats: ["rawHtml"]` and read
   inline styles or CSS custom properties.
2. **Confirm scope** if the page has several palette sections. Name what you
   found and let the user pick rather than guessing.
3. **Transcribe** into the palette JSON below.
4. Skip to [Build the CSV](#build-the-csv).

---

## Route B — image with labels

Vision reads the labels; the script reads the pixels. This split is the whole
point. A hex string rendered at 10px is exactly the kind of thing OCR gets
subtly wrong — `8`/`B`, `0`/`D`, and `5`/`6` flip silently and produce a
plausible wrong color nobody catches. Chip geometry has no such failure mode.

**Never transcribe hex codes from an image.** Read only names and tones.

### B1. Detect the chips

```bash
python3 scripts/sample_image_palette.py detect sheet.png --min-size 40 --sizes
```

`--sizes` reports the most common rectangle dimensions. Palette chips cluster
hard at one size; label cards and background gaps cluster at others. Pick the
chip size and re-run:

```bash
python3 scripts/sample_image_palette.py detect sheet.png \
    --min-size 40 --size 136x126 --grid -o detected.json
```

`--grid` prints a compact row/column view. **Check it against the image before
going further** — count the rows and the chips per row. This is the step that
catches every downstream mislabeling.

### B2. Write the layout

Transcribe only the structure — scale names in grid order, with their tone
labels:

```json
{
  "space_id": 0,
  "orientation": "rows",
  "scales": [
    { "name": "Gray", "tones": ["50", "75", "100", "200"] },
    { "name": "Red",  "tones": ["100", "200", "300"] }
  ]
}
```

`orientation` is `"rows"` when each scale runs left-to-right across a row, or
`"columns"` when each scale runs top-to-bottom down a column. Get this wrong and
every name is wrong, so check the image.

A tone may also be an object supplying its color literally:
`{"tone": "100", "hex": "#FFFFFF"}`. That entry consumes no detected chip and
holds its position in the ramp — the fix for chips detection cannot see.

### B3. Join and build

```bash
python3 scripts/sample_image_palette.py map detected.json layout.json -o palette.json
python3 scripts/build_swatch_csv.py palette.json -o palette.csv
```

`map` refuses to proceed on any count mismatch and prints which row or scale is
off. Fix the layout or the detect filters — never trim tones to make the numbers
line up.

---

## Route C — image without labels

When there are no names to read, number the chips in reading order:

```bash
python3 scripts/sample_image_palette.py detect sheet.png \
    --min-size 40 --emit-palette Color -o palette.json
python3 scripts/build_swatch_csv.py palette.json -o palette.csv
```

Produces `Color 01`, `Color 02`, … padded to the width the count requires, in
`space_id` 0. Ask the user for a prefix if the context implies one (a brand
name, the sheet's title); `Color` is only the fallback.

---

## Route D — photographs and artwork

No flat rectangles to detect, so reduce the image to its dominant colors:

```bash
python3 scripts/sample_image_palette.py quantize photo.jpg -n 16 \
    --emit-palette Photo -o palette.json
```

Add `--spread` to maximize gamut coverage instead of matching frequency — better
when the user wants a varied palette rather than an accurate one.

Say plainly that these are approximations derived from a continuous image, not
colors an author chose. Don't run `quantize` on a palette sheet: it returns the
background white and a muddled average instead of the actual swatches.

---

## Build the CSV

```bash
python3 scripts/build_swatch_csv.py palette.json -o palette.csv
```

Palette JSON — what `map` emits, and what Route A produces by hand:

```json
{
  "space_id": 0,
  "scales": [
    { "name": "Red", "swatches": [
      { "tone": "50",   "hex": "FFEBEE" },
      { "tone": "A100", "hex": "FF8A80" }
    ]}
  ],
  "standalone": [{ "name": "Black", "hex": "000000" }]
}
```

- **Carry the scale name forward** — most sources print it only on the first
  swatch and bare tones after.
- **`standalone`** is for colors with no tone (`Black`, `White`, brand one-offs);
  they emit as written, unpadded.
- **`tone` is a string**, so `A100` and `050` survive round-tripping.

| Flag | Effect |
|:--|:--|
| `--space-id N` | Override the color space (default `0`) |
| `--pad-width N` | Fix the zero-pad width (default: auto from the palette) |
| `--no-pad` | Emit tones verbatim |
| `--stdout` | Print instead of writing |
| `--strict` | Turn warnings (dropped alpha, shorthand hex) into errors |

The script fails loudly on duplicate names and malformed hex rather than
emitting a CSV Photoshop will silently mangle.

## Verify, then offer the swatch-file step

If a palette JSON was transcribed by hand from an image, cross-check it against
the pixels before building:

```bash
python3 scripts/sample_image_palette.py verify sheet.png palette.json
```

Report the swatch count and scales covered, then offer the conversion — the CSV
is a useful deliverable on its own, so don't compile it unprompted.

```powershell
Convert-Swatch -LiteralPath palette.csv -TargetFormat ACO
```

The output lands beside the CSV. Only reach for the other parameters when the
user asks for what they do:

| Need | Add |
|:--|:--|
| Several formats at once | `-TargetFormat ACO, ASE` |
| Write somewhere else | `-OutputDirectory "C:\Swatches"` |
| Drop it in a subfolder instead | `-PlaceInSubfolder` (mutually exclusive with `-OutputDirectory`) |
| Overwrite an existing file | `-Force` |
| See what was written | `-Summary` |

`Convert-Swatch` is a PowerShell function in `FMDevToolbox`, which autoloads —
no `Import-Module` needed, even under `-NoProfile`. From bash or WSL:

```bash
pwsh -NoProfile -Command "Convert-Swatch -LiteralPath palette.csv -TargetFormat ACO"
```

**Do not add `-Organize`** unless the user asks for it by name. It re-sorts the
palette into OKLab hue families, which discards the scale-and-tone order this
skill spent the whole pipeline preserving — and makes the zero-padded names
pointless. It's a fine flag for an unordered pile of colors; it's the wrong flag
for an extracted design-system ramp.

In Photoshop: **Swatches panel → flyout menu → Import Swatches**, then switch to
Small List view to see the names.

## Edge cases

Full treatment in [reference.md](reference.md). The ones that bite most often:

- **White chips vanish.** A `#FFFFFF` swatch merges into a white page background
  and never appears in detection. Both example sheets hit this. Supply it
  literally in the layout: `{"tone": "100", "hex": "#FFFFFF"}`.
- **Never `--exclude "#FFFFFF"`** on a sheet that has a legitimate white swatch.
- **Chip sizes vary by a pixel or two** from sub-pixel rendering — which is why
  `--size` has a tolerance. An exact-size filter drops swatches silently.
- **Alpha.** `.aco` has no alpha; 8-digit hex loses its last two digits with a
  warning. `--strict` makes it an error.
- **Multi-word scale names** (`Deep Purple`, `Hot Orange`, `Cloud Blue`) are one
  scale each.
- **Token names vs. header names.** Sheets sometimes label a column `Gray` but
  name its tokens `$PALETTE_NEUTRAL_*`. Ask which the user wants.
- **Non-hex notations** (`oklch()`, `hsl()`) need real conversion before entering
  the JSON — never eyeball them.

## Requirements

- CSV step: Python 3.9+, standard library only.
- Image steps: `pillow` and `numpy` (`pip install pillow numpy`).
- `.aco` / `.ase` conversion: PowerShell 7.4+ with `FMDevToolbox` (`Convert-Swatch`).

## Worked examples

[examples/](examples/) holds complete inputs for three real palettes: a scraped
one (Material Design 2014), a row-oriented image sheet (Adobe Spectrum), and a
column-oriented one (Salesforce Lightning).
