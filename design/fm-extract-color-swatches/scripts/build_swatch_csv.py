#!/usr/bin/env python3
"""
build_swatch_csv.py — turn an extracted palette (JSON) into a swatch CSV in the
Convert-Swatch import format:

    name,space_id,color
    Red 050,0,#FFEBEE

Deterministic half of the fm-extract-color-swatches skill. The agent transcribes
the page into JSON; this script owns every formatting rule so name assembly,
zero-padding, and hex normalization can't drift between runs.

Input JSON:
    {
      "space_id": 0,                       # optional, default 0, CLI overrides
      "scales": [
        { "name": "Red",
          "swatches": [ {"tone": "50", "hex": "FFEBEE"}, ... ] }
      ],
      "standalone": [ {"name": "Black", "hex": "000000"} ]   # optional
    }

Usage:
    python3 build_swatch_csv.py palette.json -o palette.csv
    python3 build_swatch_csv.py palette.json --stdout --strict

Python 3.9+, standard library only.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import List, NamedTuple, Tuple

# Color spaces Convert-Swatch actually implements. Anything else is refused
# up front rather than producing an .aco Photoshop will reject on import.
VALID_SPACE_IDS = {0: "RGB", 1: "HSB", 2: "CMYK", 8: "Grayscale"}

# Accent tones look like "A100" / "a700": one or more letters, then digits.
# Only the digits get padded; the prefix is preserved verbatim.
ACCENT_TONE_RE = re.compile(r"^(?P<prefix>[A-Za-z]+)(?P<digits>\d+)$")

HEX_CHARS_RE = re.compile(r"^[0-9A-Fa-f]+$")


class Row(NamedTuple):
    """One emitted CSV line."""
    name: str
    space_id: int
    color: str


class PaletteError(Exception):
    """Fatal problem in the input palette — aborts without writing output."""


# --------------------------------------------------------------------------- #
# Normalization
# --------------------------------------------------------------------------- #

def normalize_hex(raw: str, context: str, warnings: List[str]) -> str:
    """
    Normalize a hex color to '#RRGGBB' (uppercase, no alpha).

    Handles 3/4-digit shorthand and 6/8-digit forms. Alpha is dropped because
    the .aco format has no alpha channel — a swatch is opaque by definition.
    Anything else is fatal: a half-understood color is worse than a hard stop.
    """
    value = raw.strip().lstrip("#").strip()

    if not value:
        raise PaletteError(f"{context}: empty color value")
    if not HEX_CHARS_RE.match(value):
        raise PaletteError(f"{context}: '{raw}' contains non-hex characters")

    if len(value) in (3, 4):
        # Shorthand: each digit doubles ('fbe' -> 'ffbbee').
        warnings.append(f"{context}: expanded shorthand '#{value}'")
        value = "".join(ch * 2 for ch in value)

    if len(value) == 8:
        warnings.append(f"{context}: dropped alpha channel from '#{raw.lstrip('#')}'")
        value = value[:6]

    if len(value) != 6:
        raise PaletteError(
            f"{context}: '#{value}' is {len(value)} hex digits; expected 3, 4, 6, or 8"
        )

    return "#" + value.upper()


def pad_tone(tone: str, pad_width: int, pad: bool) -> str:
    """
    Zero-pad a tone so alphabetical sorting matches numeric order.

        '50' -> '050'      '100' -> '100'
        'A50' -> 'A050'    'A100' -> 'A100'

    Non-numeric tones (e.g. 'Base', 'DEFAULT') pass through untouched.
    """
    tone = tone.strip()
    if not pad or not tone:
        return tone

    if tone.isdigit():
        return tone.zfill(pad_width)

    match = ACCENT_TONE_RE.match(tone)
    if match:
        return match.group("prefix") + match.group("digits").zfill(pad_width)

    return tone


# --------------------------------------------------------------------------- #
# Build
# --------------------------------------------------------------------------- #

def widest_numeric_tone(data: dict) -> int:
    """
    Widest run of digits in any tone in the palette.

    Pad width has to match the palette, not a fixed guess: a ramp that reaches
    1400 needs width 4, or '1400' sorts between '100' and '200' and the whole
    point of padding is lost. Palettes topping out at 900 need width 3.
    """
    widest = 1
    for scale in data.get("scales") or []:
        for swatch in scale.get("swatches") or []:
            tone = str(swatch.get("tone", "")).strip()
            digits = tone if tone.isdigit() else (
                ACCENT_TONE_RE.match(tone).group("digits") if ACCENT_TONE_RE.match(tone) else ""
            )
            widest = max(widest, len(digits))
    return widest


def build_rows(data: dict, args: argparse.Namespace) -> Tuple[List[Row], List[str]]:
    """Flatten the palette JSON into ordered CSV rows, collecting warnings."""
    warnings: List[str] = []

    # Default pad width is derived from the palette itself; --pad-width overrides.
    pad_width = args.pad_width if args.pad_width is not None else widest_numeric_tone(data)

    # CLI --space-id wins over the JSON field, which wins over the default.
    space_id = args.space_id if args.space_id is not None else int(data.get("space_id", 0))
    if space_id not in VALID_SPACE_IDS:
        raise PaletteError(
            f"space_id {space_id} is not supported by Convert-Swatch "
            f"(valid: {', '.join(map(str, sorted(VALID_SPACE_IDS)))})"
        )
    if space_id != 0:
        warnings.append(
            f"space_id is {space_id} ({VALID_SPACE_IDS[space_id]}); "
            "hex values are interpreted as that space's channels, not RGB"
        )

    scales = data.get("scales") or []
    standalone = data.get("standalone") or []
    if not scales and not standalone:
        raise PaletteError("palette contains no 'scales' and no 'standalone' entries")

    rows: List[Row] = []

    for scale_index, scale in enumerate(scales):
        scale_name = str(scale.get("name", "")).strip()
        if not scale_name:
            raise PaletteError(f"scales[{scale_index}] is missing a 'name'")

        swatches = scale.get("swatches") or []
        if not swatches:
            raise PaletteError(f"scale '{scale_name}' has no swatches")

        for swatch_index, swatch in enumerate(swatches):
            context = f"{scale_name}[{swatch_index}]"
            tone = str(swatch.get("tone", "")).strip()
            if not tone:
                raise PaletteError(f"{context}: missing 'tone'")
            if "hex" not in swatch:
                raise PaletteError(f"{context}: missing 'hex'")

            # Scale name is inherited by every swatch, even when the source page
            # printed it only once at the top of the ramp.
            name = f"{scale_name} {pad_tone(tone, pad_width, not args.no_pad)}"
            rows.append(Row(name, space_id, normalize_hex(str(swatch["hex"]), context, warnings)))

    for entry_index, entry in enumerate(standalone):
        # Standalone colors (Black, White, brand one-offs) carry no tone and are
        # never padded — the name is emitted exactly as given.
        name = str(entry.get("name", "")).strip()
        if not name:
            raise PaletteError(f"standalone[{entry_index}] is missing a 'name'")
        if "hex" not in entry:
            raise PaletteError(f"standalone '{name}': missing 'hex'")
        rows.append(Row(name, space_id, normalize_hex(str(entry["hex"]), name, warnings)))

    # Duplicate names are legal in .aco but nearly always signal a transcription
    # error upstream (a scale read twice, a typo'd tone), so fail loudly.
    seen: dict = {}
    duplicates: List[str] = []
    for row in rows:
        if row.name in seen:
            duplicates.append(row.name)
        seen[row.name] = True
    if duplicates:
        unique = sorted(set(duplicates))
        preview = ", ".join(unique[:10]) + (" ..." if len(unique) > 10 else "")
        raise PaletteError(f"{len(unique)} duplicate swatch name(s): {preview}")

    return rows, warnings


def write_csv(rows: List[Row], destination) -> None:
    """
    Emit the CSV by hand rather than via csv.writer: Convert-Swatch expects
    an unquoted three-column layout, and no field here can legally contain a
    comma, quote, or newline.
    """
    destination.write("name,space_id,color\n")
    for row in rows:
        if "," in row.name or '"' in row.name or "\n" in row.name:
            raise PaletteError(f"name '{row.name}' contains a character that breaks the CSV format")
        destination.write(f"{row.name},{row.space_id},{row.color}\n")


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a Convert-Swatch CSV from extracted palette JSON.",
    )
    parser.add_argument("input", type=Path, help="palette JSON file")
    parser.add_argument("-o", "--output", type=Path, help="output CSV path")
    parser.add_argument("--stdout", action="store_true", help="print CSV instead of writing a file")
    parser.add_argument("--space-id", type=int, default=None,
                        help="override color space for every row (default 0 = RGB)")
    parser.add_argument("--pad-width", type=int, default=None,
                        help="zero-pad width for numeric tones "
                             "(default: auto, matched to the widest tone in the palette)")
    parser.add_argument("--no-pad", action="store_true", help="emit tones verbatim, no padding")
    parser.add_argument("--strict", action="store_true", help="treat warnings as errors")

    args = parser.parse_args(argv)
    if not args.stdout and not args.output:
        parser.error("specify -o/--output or --stdout")
    if args.pad_width is not None and args.pad_width < 1:
        parser.error("--pad-width must be at least 1")
    return args


def main(argv: List[str]) -> int:
    args = parse_args(argv)

    try:
        data = json.loads(args.input.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"error: no such file: {args.input}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"error: {args.input} is not valid JSON: {exc}", file=sys.stderr)
        return 1

    try:
        rows, warnings = build_rows(data, args)
    except PaletteError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)
    if warnings and args.strict:
        print(f"error: {len(warnings)} warning(s) under --strict; nothing written", file=sys.stderr)
        return 1

    try:
        if args.stdout:
            try:
                write_csv(rows, sys.stdout)
            except BrokenPipeError:
                # `--stdout | head` closes the pipe early; that is a normal way to
                # peek at output, not an error worth a traceback.
                sys.stdout = None
                return 0
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            # newline="" keeps Python from translating \n to \r\n on Windows.
            with args.output.open("w", encoding="utf-8", newline="") as handle:
                write_csv(rows, handle)
            scale_count = len(data.get("scales") or [])
            print(f"{len(rows)} swatches from {scale_count} scale(s) -> {args.output}", file=sys.stderr)
    except PaletteError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
