#!/usr/bin/env python3
"""
sample_image_palette.py — pull exact color values out of a palette image.

Companion to build_swatch_csv.py in the fm-extract-color-swatches skill. Vision
reads the *labels* in a palette screenshot; this script reads the *pixels*, which
is the half that has to be exact. A hex string OCR'd from a 10px font can flip a
character silently; a sampled pixel cannot.

Three modes:

  detect   Find every solid rectangle of flat color and report its hex, bounding
           box, area, and reading-order position. Use on any palette image.

  sample   Sample specific points or rectangles you already know the location of.
           Use when detect's heuristics miss an unusual layout.

  verify   Cross-check an existing palette JSON against the image's detected
           colors and report transcription mismatches. Use after vision has read
           the labels off a hex-annotated sheet.

Detection finds axis-aligned rectangles of *uniform* color via run-length
merging. That is exactly what a palette chip is, and it deliberately will not
match photographs, gradients, or anti-aliased text.

Requires: Pillow, numpy.

Examples:
    python3 sample_image_palette.py detect palette.png --min-size 40 -o detected.json
    python3 sample_image_palette.py detect palette.png --grid --min-size 40
    python3 sample_image_palette.py sample palette.png --points 120,340 260,340
    python3 sample_image_palette.py verify palette.png transcribed.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

# Palette sheets are routinely 5–8k px wide. Pillow refuses very large images by
# default as a decompression-bomb guard; these are our own local files.
Image.MAX_IMAGE_PIXELS = None


class Rect(dict):
    """A detected solid-color rectangle. dict subclass so it serializes directly."""

    @property
    def area(self) -> int:
        return self["width"] * self["height"]


# --------------------------------------------------------------------------- #
# Detection
# --------------------------------------------------------------------------- #

def load_rgb(path: Path) -> np.ndarray:
    """Load an image as an (H, W, 3) uint8 array, flattening any alpha onto white."""
    image = Image.open(path)
    if image.mode in ("RGBA", "LA", "P"):
        image = image.convert("RGBA")
        # Composite onto white so semi-transparent chips report the color the
        # viewer actually saw, not the premultiplied source.
        background = Image.new("RGBA", image.size, (255, 255, 255, 255))
        image = Image.alpha_composite(background, image)
    return np.asarray(image.convert("RGB"))


def find_solid_rects(rgb: np.ndarray, min_width: int, min_height: int,
                     max_row_gap: int = 60) -> List[Rect]:
    """
    Find every axis-aligned rectangle of near-uniform color.

    Two-pass run-length approach, fully vectorized:
      1. Per scanline, find maximal horizontal runs of one color.
      2. Merge runs that share color and exact x-extent down the image.

    Requiring an exact x-extent match keeps rectangles crisp: a chip sitting on a
    wider card background is found as its own rect rather than being absorbed.

    `max_row_gap` allows a rectangle to survive rows where its run is broken —
    which is the normal case, because palette sheets print the swatch label
    *on top of* the color. Without it, every card with text in it is invisible.
    Each rect reports `coverage`: the fraction of its rows that carried the full
    run. Solid chips land near 1.0; a low value means either heavy text overlay
    or two same-colored chips wrongly merged across a gap.
    """
    height, width, _ = rgb.shape

    # Pack RGB into one int32 id per pixel so comparisons are single-column.
    ids = (rgb[:, :, 0].astype(np.int32) << 16
           | rgb[:, :, 1].astype(np.int32) << 8
           | rgb[:, :, 2].astype(np.int32))

    # A run starts at column 0 or wherever the color differs from the pixel left.
    starts_mask = np.ones((height, width), dtype=bool)
    starts_mask[:, 1:] = ids[:, 1:] != ids[:, :-1]

    flat_starts = np.flatnonzero(starts_mask.reshape(-1))
    run_rows = flat_starts // width
    run_x0 = flat_starts % width

    # Run length = distance to the next start, clipped at the row boundary.
    next_start = np.append(flat_starts[1:], height * width)
    row_end = (run_rows + 1) * width
    run_len = np.minimum(next_start, row_end) - flat_starts

    keep = run_len >= min_width
    run_rows, run_x0, run_len = run_rows[keep], run_x0[keep], run_len[keep]
    run_color = ids[run_rows, run_x0]

    if run_rows.size == 0:
        return []

    # Group runs sharing (color, x0, length); within a group, rows that are close
    # enough together form one rectangle.
    order = np.lexsort((run_rows, run_len, run_x0, run_color))
    c, x0, ln, rw = run_color[order], run_x0[order], run_len[order], run_rows[order]

    new_group = np.ones(c.size, dtype=bool)
    new_group[1:] = (c[1:] != c[:-1]) | (x0[1:] != x0[:-1]) | (ln[1:] != ln[:-1])
    # A large vertical jump also breaks a rectangle (same chip color twice in a column).
    new_group[1:] |= (rw[1:] - rw[:-1]) > max_row_gap

    group_start = np.flatnonzero(new_group)
    group_end = np.append(group_start[1:], c.size)  # exclusive

    rects: List[Rect] = []
    for start, end in zip(group_start, group_end):
        top, bottom = int(rw[start]), int(rw[end - 1])
        rect_height = bottom - top + 1
        if rect_height < min_height:
            continue
        color_id = int(c[start])
        rects.append(Rect(
            hex="#%06X" % color_id,
            rgb=[color_id >> 16 & 0xFF, color_id >> 8 & 0xFF, color_id & 0xFF],
            x=int(x0[start]),
            y=top,
            width=int(ln[start]),
            height=rect_height,
            coverage=round((end - start) / rect_height, 3),
        ))
    return rects


def drop_background(rects: List[Rect], image_area: int, max_area_frac: float) -> List[Rect]:
    """
    Discard rectangles large enough to be page or card background.

    A palette chip is a small fraction of the sheet; the white canvas behind it
    is not. Tune with --max-area-frac when a legitimate chip is being dropped.
    """
    limit = image_area * max_area_frac
    return [r for r in rects if r.area <= limit]


def filter_by_size(rects: List[Rect], spec: str, tolerance: float) -> List[Rect]:
    """
    Keep only rects close to a target WxH.

    The single most useful knob for card-style sheets, where each swatch is a
    small chip sitting on a much larger label card: filtering to the chip size
    drops every card and gap in one move. Tolerance matters — sub-pixel rendering
    means nominally identical chips differ by a pixel or two, so an exact match
    silently loses swatches.
    """
    try:
        target_w, target_h = (int(part) for part in spec.lower().split("x"))
    except ValueError:
        raise SystemExit(f"error: bad --size '{spec}' (expected WxH, e.g. 136x126)")

    def close(actual: int, target: int) -> bool:
        return abs(actual - target) <= max(2, round(target * tolerance))

    return [r for r in rects if close(r["width"], target_w) and close(r["height"], target_h)]


def drop_contained(rects: List[Rect]) -> List[Rect]:
    """
    Remove rectangles fully contained inside a larger one of a different color.

    Card-style layouts (a chip inside a white label card) produce both; the inner
    chip is the color we want, the outer card is chrome.
    """
    ordered = sorted(rects, key=lambda r: r.area, reverse=True)
    kept: List[Rect] = []
    for rect in ordered:
        contained = any(
            other["x"] <= rect["x"]
            and other["y"] <= rect["y"]
            and other["x"] + other["width"] >= rect["x"] + rect["width"]
            and other["y"] + other["height"] >= rect["y"] + rect["height"]
            and other.area > rect.area
            for other in kept
        )
        if not contained:
            kept.append(rect)
    return kept


def assign_grid(rects: List[Rect], tolerance: int) -> List[Rect]:
    """
    Label each rect with a row/column index so it maps onto the visual grid.

    Chips in one palette row rarely share a pixel-exact y, so centers are bucketed
    within `tolerance`. Rects are returned in reading order (row, then column),
    which is the order a palette sheet is meant to be read.
    """
    def bucket(values: List[int]) -> Dict[int, int]:
        """Map each center coordinate to an index of its cluster."""
        mapping: Dict[int, int] = {}
        cluster_anchors: List[int] = []
        for value in sorted(set(values)):
            for index, anchor in enumerate(cluster_anchors):
                if abs(value - anchor) <= tolerance:
                    mapping[value] = index
                    break
            else:
                cluster_anchors.append(value)
                mapping[value] = len(cluster_anchors) - 1
        return mapping

    centers_y = [r["y"] + r["height"] // 2 for r in rects]
    centers_x = [r["x"] + r["width"] // 2 for r in rects]
    row_of, col_of = bucket(centers_y), bucket(centers_x)

    for rect, cy, cx in zip(rects, centers_y, centers_x):
        rect["row"] = row_of[cy]
        rect["col"] = col_of[cx]

    return sorted(rects, key=lambda r: (r["row"], r["col"]))


# --------------------------------------------------------------------------- #
# Sampling
# --------------------------------------------------------------------------- #

def sample_point(rgb: np.ndarray, x: int, y: int, box: int) -> Optional[str]:
    """
    Sample the modal color in a small box around (x, y).

    Mode, not mean: averaging across a chip edge invents a color that is not in
    the image, while the mode returns an actual pixel value. Returns None if the
    box is not reasonably uniform, which usually means the point missed the chip.
    """
    height, width, _ = rgb.shape
    if not (0 <= x < width and 0 <= y < height):
        return None

    half = max(box // 2, 0)
    patch = rgb[max(0, y - half):y + half + 1, max(0, x - half):x + half + 1]
    ids = (patch[:, :, 0].astype(np.int32) << 16
           | patch[:, :, 1].astype(np.int32) << 8
           | patch[:, :, 2].astype(np.int32)).reshape(-1)

    values, counts = np.unique(ids, return_counts=True)
    winner = int(values[counts.argmax()])
    if counts.max() / ids.size < 0.6:
        return None  # too mixed to trust — likely on an edge or over text
    return "#%06X" % winner


# --------------------------------------------------------------------------- #
# Modes
# --------------------------------------------------------------------------- #

def run_detect(args: argparse.Namespace) -> int:
    rgb = load_rgb(args.image)
    height, width, _ = rgb.shape

    rects = find_solid_rects(rgb, args.min_size, args.min_size, args.max_row_gap)
    rects = drop_background(rects, height * width, args.max_area_frac)

    if args.sizes:
        # Chip-sized rects cluster hard; the top entry is almost always the chip.
        from collections import Counter
        tally = Counter((r["width"], r["height"]) for r in rects)
        print(f"{len(rects)} rects; most common sizes (pass the chip size to --size):")
        for (w, h), count in tally.most_common(10):
            print(f"  {w}x{h}  x{count}")
        return 0

    if args.size:
        rects = filter_by_size(rects, args.size, args.size_tolerance)
    if not args.keep_nested:
        rects = drop_contained(rects)
    if args.exclude:
        excluded = {h.upper() if h.startswith("#") else "#" + h.upper() for h in args.exclude}
        rects = [r for r in rects if r["hex"] not in excluded]

    rects = assign_grid(rects, args.grid_tolerance)

    payload = {
        "image": str(args.image),
        "image_size": [width, height],
        "swatch_count": len(rects),
        "rows": (max(r["row"] for r in rects) + 1) if rects else 0,
        "cols": (max(r["col"] for r in rects) + 1) if rects else 0,
        "swatches": rects,
    }

    if args.emit_palette is not None:
        # Unlabeled sheet: no names to read, so number the chips in reading order
        # and let build_swatch_csv.py apply the zero-padding.
        prefix = args.emit_palette or "Color"
        palette = {
            "space_id": 0,
            "scales": [{
                "name": prefix,
                "swatches": [{"tone": str(i), "hex": r["hex"]}
                             for i, r in enumerate(rects, start=1)],
            }],
        }
        text = json.dumps(palette, indent=2)
        if args.output:
            args.output.write_text(text, encoding="utf-8")
            print(f"{len(rects)} swatches -> {args.output}", file=sys.stderr)
        else:
            print(text)
        return 0

    if args.grid:
        emit_grid(payload)
    else:
        text = json.dumps(payload, indent=2)
        if args.output:
            args.output.write_text(text, encoding="utf-8")
            print(f"{len(rects)} swatches -> {args.output}", file=sys.stderr)
        else:
            print(text)
    return 0


def emit_grid(payload: dict) -> None:
    """Print a compact row-by-row view — far easier to eyeball than raw JSON."""
    by_row: Dict[int, List[Rect]] = {}
    for rect in payload["swatches"]:
        by_row.setdefault(rect["row"], []).append(rect)

    print(f"{payload['swatch_count']} swatches, "
          f"{payload['rows']} rows x {payload['cols']} cols "
          f"(image {payload['image_size'][0]}x{payload['image_size'][1]})")
    for row_index in sorted(by_row):
        cells = " ".join(r["hex"] for r in sorted(by_row[row_index], key=lambda r: r["col"]))
        print(f"row {row_index:>3}: {cells}")


def run_sample(args: argparse.Namespace) -> int:
    rgb = load_rgb(args.image)
    results = []

    for raw in args.points or []:
        try:
            x_text, y_text = raw.split(",")
            x, y = int(x_text), int(y_text)
        except ValueError:
            print(f"error: bad point '{raw}' (expected x,y)", file=sys.stderr)
            return 1
        results.append({"x": x, "y": y, "hex": sample_point(rgb, x, y, args.box)})

    for raw in args.rects or []:
        try:
            x, y, w, h = (int(part) for part in raw.split(","))
        except ValueError:
            print(f"error: bad rect '{raw}' (expected x,y,w,h)", file=sys.stderr)
            return 1
        # Sample the center of the rect, using a box sized to its interior.
        results.append({
            "x": x, "y": y, "width": w, "height": h,
            "hex": sample_point(rgb, x + w // 2, y + h // 2, min(w, h) // 2 or 1),
        })

    if not results:
        print("error: pass --points and/or --rects", file=sys.stderr)
        return 1

    print(json.dumps({"image": str(args.image), "samples": results}, indent=2))
    return any(r["hex"] is None for r in results)


def run_map(args: argparse.Namespace) -> int:
    """
    Join detected pixel colors to a layout you read off the image.

    This is the mode that makes image extraction trustworthy. Vision transcribes
    only scale names and tone labels — short, structured, high-contrast strings
    it reads reliably. Every hex comes from the pixels. Nothing has to be OCR'd
    from a 10px hex string, so the class of error that produces a wrong-but-
    plausible color simply cannot occur.

    Layout JSON:
        {
          "space_id": 0,
          "orientation": "rows",          # or "columns" — how scales are laid out
          "scales": [
            {"name": "Gray", "tones": ["50", "75", "100"]},
            {"name": "Red",  "tones": ["100", "200"]}
          ],
          "standalone": [{"name": "Black", "position": [13, 0]}]   # [row, col]
        }
    """
    detected = json.loads(args.detected.read_text(encoding="utf-8"))
    layout = json.loads(args.layout.read_text(encoding="utf-8"))

    axis = layout.get("orientation", "rows")
    if axis not in ("rows", "columns"):
        print("error: orientation must be 'rows' or 'columns'", file=sys.stderr)
        return 1

    key, cross = ("row", "col") if axis == "rows" else ("col", "row")
    groups: Dict[int, List[dict]] = {}
    for swatch in detected["swatches"]:
        groups.setdefault(swatch[key], []).append(swatch)
    ordered = [sorted(groups[k], key=lambda s: s[cross]) for k in sorted(groups)]

    scales = layout.get("scales") or []
    if len(scales) != len(ordered):
        print(f"error: layout has {len(scales)} scale(s) but detection found "
              f"{len(ordered)} {axis}. Fix the detect filters or the layout "
              f"before mapping — a silent off-by-one here mislabels every "
              f"downstream swatch.", file=sys.stderr)
        for index, group in enumerate(ordered):
            name = scales[index]["name"] if index < len(scales) else "(none)"
            print(f"  {axis[:-1]} {index}: {len(group)} chips -> {name}", file=sys.stderr)
        return 1

    output: dict = {"space_id": layout.get("space_id", 0), "scales": []}
    problems = []

    for scale, group in zip(scales, ordered):
        tones = scale.get("tones") or []
        # A tone may be a plain string (take the next detected chip) or an object
        # {"tone": "100", "hex": "#FFFFFF"} supplying the color literally. The
        # literal form exists for chips detection cannot see — most often a white
        # chip that merged into a white page background. It holds its place in
        # the ramp instead of being appended out of order at the end.
        sampled_count = sum(1 for t in tones if not isinstance(t, dict))
        if sampled_count != len(group):
            problems.append(
                f"{scale['name']}: {sampled_count} sampled tone(s) vs {len(group)} chip(s)")
            continue

        swatches, chips = [], iter(group)
        for tone in tones:
            if isinstance(tone, dict):
                swatches.append({"tone": str(tone["tone"]), "hex": str(tone["hex"])})
            else:
                swatches.append({"tone": str(tone), "hex": next(chips)["hex"]})
        output["scales"].append({"name": scale["name"], "swatches": swatches})

    if problems:
        print("error: tone/chip count mismatch:", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    # Standalone entries are addressed by explicit [row, col] since they sit
    # outside the scale grid.
    lookup = {(s["row"], s["col"]): s for s in detected["swatches"]}
    standalone = []
    for entry in layout.get("standalone") or []:
        position = tuple(entry["position"])
        if position not in lookup:
            print(f"error: no chip at row/col {list(position)} for "
                  f"'{entry['name']}'", file=sys.stderr)
            return 1
        standalone.append({"name": entry["name"], "hex": lookup[position]["hex"]})
    if standalone:
        output["standalone"] = standalone

    total = sum(len(s["swatches"]) for s in output["scales"]) + len(standalone)
    text = json.dumps(output, indent=2)
    if args.output:
        args.output.write_text(text, encoding="utf-8")
        print(f"{total} swatches -> {args.output}", file=sys.stderr)
    else:
        print(text)
    return 0


def run_quantize(args: argparse.Namespace) -> int:
    """
    Reduce an arbitrary image to its N most prominent colors.

    The fallback for images `detect` cannot help with: photographs, moodboards,
    gradients, artwork — anything without flat rectangular chips. Results are
    approximations of a continuous image, not swatches an author chose, so they
    carry generic names and should be reviewed before shipping into a library.
    """
    image = Image.open(args.image)
    if image.mode != "RGB":
        image = image.convert("RGB")

    # Downscale first: quantization quality is unaffected and it turns a
    # multi-second pass on a 40MP sheet into a near-instant one.
    image.thumbnail((args.max_dimension, args.max_dimension), Image.Resampling.LANCZOS)

    # MEDIANCUT tracks the actual color distribution; MAXCOVERAGE spreads across
    # the gamut and is the better pick when you want visual variety over fidelity.
    method = Image.Quantize.MAXCOVERAGE if args.spread else Image.Quantize.MEDIANCUT
    quantized = image.quantize(colors=args.colors, method=method)

    palette_bytes = quantized.getpalette()
    counts = sorted(quantized.getcolors(args.colors * 2) or [], reverse=True)

    swatches = []
    for rank, (count, index) in enumerate(counts[:args.colors], start=1):
        r, g, b = palette_bytes[index * 3:index * 3 + 3]
        swatches.append({
            "tone": str(rank),
            "hex": "#%02X%02X%02X" % (r, g, b),
            "share": round(count / (image.width * image.height), 4),
        })

    if args.emit_palette is not None:
        prefix = args.emit_palette or "Color"
        payload = {"space_id": 0, "scales": [{
            "name": prefix,
            "swatches": [{"tone": s["tone"], "hex": s["hex"]} for s in swatches],
        }]}
    else:
        payload = {"image": str(args.image), "colors": swatches}

    text = json.dumps(payload, indent=2)
    if args.output:
        args.output.write_text(text, encoding="utf-8")
        print(f"{len(swatches)} colors -> {args.output}", file=sys.stderr)
    else:
        print(text)
    return 0


def run_verify(args: argparse.Namespace) -> int:
    """
    Compare hexes in a transcribed palette JSON against colors present in the
    image. Catches OCR slips (8/B, 0/D, 5/6) before they reach the CSV.
    """
    rgb = load_rgb(args.image)
    height, width, _ = rgb.shape

    rects = find_solid_rects(rgb, args.min_size, args.min_size, args.max_row_gap)
    rects = drop_background(rects, height * width, args.max_area_frac)
    present = {r["hex"] for r in rects}

    data = json.loads(args.palette.read_text(encoding="utf-8"))
    entries: List[Tuple[str, str]] = []
    for scale in data.get("scales") or []:
        for swatch in scale.get("swatches") or []:
            entries.append((f"{scale['name']} {swatch['tone']}", str(swatch["hex"])))
    for entry in data.get("standalone") or []:
        entries.append((entry["name"], str(entry["hex"])))

    missing = []
    for name, raw_hex in entries:
        normalized = "#" + raw_hex.lstrip("#").upper()[:6]
        if normalized not in present:
            missing.append((name, normalized, nearest(normalized, present)))

    print(f"{len(entries)} transcribed / {len(present)} distinct colors detected in image")
    if not missing:
        print("all transcribed colors found in image")
        return 0

    print(f"\n{len(missing)} not found — likely misread labels:")
    for name, value, near in missing:
        suffix = f"   nearest in image: {near}" if near else ""
        print(f"  {name}: {value}{suffix}")
    return 1


def nearest(target_hex: str, candidates: set) -> Optional[str]:
    """Closest detected color by squared RGB distance, if it's plausibly the same chip."""
    def to_rgb(value: str) -> Tuple[int, int, int]:
        v = value.lstrip("#")
        return int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16)

    if not candidates:
        return None
    tr, tg, tb = to_rgb(target_hex)
    best, best_distance = None, None
    for candidate in candidates:
        cr, cg, cb = to_rgb(candidate)
        distance = (tr - cr) ** 2 + (tg - cg) ** 2 + (tb - cb) ** 2
        if best_distance is None or distance < best_distance:
            best, best_distance = candidate, distance
    # ~20 per channel; beyond that it is a different swatch, not a typo.
    return best if best_distance is not None and best_distance < 1200 else None


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1],
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="mode", required=True)

    def add_detection_flags(p: argparse.ArgumentParser) -> None:
        p.add_argument("--min-size", type=int, default=20,
                       help="minimum chip width and height in px (default 20)")
        p.add_argument("--max-area-frac", type=float, default=0.02,
                       help="drop rects larger than this fraction of the image (default 0.02)")
        p.add_argument("--max-row-gap", type=int, default=60,
                       help="rows a chip's run may be interrupted by overlaid label "
                            "text before it is treated as two chips (default 60)")

    detect = sub.add_parser("detect", help="find all solid-color rectangles")
    detect.add_argument("image", type=Path)
    detect.add_argument("-o", "--output", type=Path, help="write JSON here instead of stdout")
    detect.add_argument("--grid", action="store_true", help="print a compact row/column view")
    detect.add_argument("--emit-palette", nargs="?", const="Color", metavar="PREFIX",
                        help="emit build_swatch_csv.py palette JSON with generic "
                             "sequential names (default prefix 'Color') instead of "
                             "detection JSON — for sheets with no readable labels")
    detect.add_argument("--grid-tolerance", type=int, default=20,
                        help="px tolerance when clustering chips into rows/cols (default 20)")
    detect.add_argument("--keep-nested", action="store_true",
                        help="keep rects contained inside larger ones")
    detect.add_argument("--size", metavar="WxH",
                        help="keep only chips near this size, e.g. 136x126 "
                             "(run once without it to see the common sizes)")
    detect.add_argument("--size-tolerance", type=float, default=0.1,
                        help="fractional tolerance for --size (default 0.1)")
    detect.add_argument("--sizes", action="store_true",
                        help="report the most common rect sizes and exit — "
                             "use this to pick a --size value")
    detect.add_argument("--exclude", nargs="*", metavar="HEX",
                        help="drop these colors (e.g. #FFFFFF card backgrounds)")
    add_detection_flags(detect)

    sample = sub.add_parser("sample", help="sample explicit points or rects")
    sample.add_argument("image", type=Path)
    sample.add_argument("--points", nargs="*", metavar="X,Y")
    sample.add_argument("--rects", nargs="*", metavar="X,Y,W,H")
    sample.add_argument("--box", type=int, default=5,
                        help="sample box size in px for --points (default 5)")

    quant = sub.add_parser("quantize", help="reduce any image to its N most prominent colors")
    quant.add_argument("image", type=Path)
    quant.add_argument("-n", "--colors", type=int, default=16, help="how many colors (default 16)")
    quant.add_argument("-o", "--output", type=Path)
    quant.add_argument("--spread", action="store_true",
                       help="maximize gamut coverage instead of matching frequency")
    quant.add_argument("--max-dimension", type=int, default=1200,
                       help="downscale longest edge before quantizing (default 1200)")
    quant.add_argument("--emit-palette", nargs="?", const="Color", metavar="PREFIX",
                       help="emit build_swatch_csv.py palette JSON instead of a report")

    mapper = sub.add_parser("map", help="join detected colors to a name/tone layout")
    mapper.add_argument("detected", type=Path, help="JSON from `detect -o`")
    mapper.add_argument("layout", type=Path, help="scale names and tones you read off the image")
    mapper.add_argument("-o", "--output", type=Path, help="write palette JSON here")

    verify = sub.add_parser("verify", help="check a transcribed palette JSON against the image")
    verify.add_argument("image", type=Path)
    verify.add_argument("palette", type=Path, help="palette JSON in build_swatch_csv.py format")
    add_detection_flags(verify)

    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    if args.mode == "map":
        return run_map(args)
    if not args.image.exists():
        print(f"error: no such image: {args.image}", file=sys.stderr)
        return 1
    return {"detect": run_detect, "sample": run_sample, "quantize": run_quantize,
            "map": run_map, "verify": run_verify}[args.mode](args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
