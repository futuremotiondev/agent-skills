# Worked examples

Three real palettes, one per input route.

## Material Design 2014 — scraped URL (Route A)

`material-design-2014.json` — palette JSON transcribed from
<https://m2.material.io/design/color/the-color-system.html>. Three scales plus
standalone Black and White. Feed straight to the builder:

```bash
python3 ../scripts/build_swatch_csv.py material-design-2014.json -o md2014.csv
```

## Adobe Spectrum Light Theme — row-oriented image (Route B)

`adobe-spectrum-layout.json` — 14 scales laid out as rows, 193 swatches.
Illustrates two things worth studying: a ragged neutral ramp (`Gray` carries an
extra `75` step the other scales don't have), and a 4-digit ramp reaching `1400`,
which makes the builder auto-select pad width 4 (`Gray 0050` … `Red 1400`).

```bash
python3 ../scripts/sample_image_palette.py detect sheet.png --min-size 40 --sizes
python3 ../scripts/sample_image_palette.py detect sheet.png \
    --min-size 40 --size 136x126 -o detected.json
python3 ../scripts/sample_image_palette.py map detected.json \
    adobe-spectrum-layout.json -o palette.json
python3 ../scripts/build_swatch_csv.py palette.json -o spectrum.csv
```

Note the chip filter: `--sizes` reports a 136x126 cluster (the chips) alongside
310x126 (label cards) and 72x132 (gaps). One chip in the gray row renders at
140px wide, which the default `--size-tolerance` of 0.1 absorbs.

## Salesforce Lightning Vibrant — column-oriented image (Route B)

`lightning-vibrant-layout.json` — 14 scales laid out as columns, 170 swatches.
Illustrates three more: `"orientation": "columns"`, a descending tone order
(95 → 10, the reverse of Material), and the white-chip trap — `Gray 100` is
`#FFFFFF`, dissolves into the white page background, and is supplied as a literal
tone so it holds its position at the top of the ramp.

The label text printed on each card is also why `--max-row-gap` exists: without
it, every chip on this sheet is invisible to detection.
