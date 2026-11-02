#!/usr/bin/env python3
"""
Measure a codebase's languages: files, code/comment/blank lines, and bytes.

Percentages are computed over programming + markup languages (the "language
bar", as GitHub linguist does); data files (JSON, YAML, XML, ...) and prose
(Markdown, text) are reported separately so a big README or lock-free config
folder can't masquerade as the main language. Vendored, generated, binary, and
unrecognized files are excluded from all percentages and listed with counts.

Two percentage bases are reported, because they answer different questions:
  pct_code   share of non-blank, non-comment lines   (how much logic)
  pct_bytes  share of bytes, linguist's basis         (matches the GitHub bar)
Rounded with the largest-remainder method so each column sums to exactly 100.0.

Usage:
  python language_stats.py <root>                     # human-readable table
  python language_stats.py <root> --json -o langs.json
  python language_stats.py <root> --exclude "docs/*" --exclude tests --files

Exit codes: 0 = ok, 2 = root not found.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from _common import (MAX_PARSE_BYTES, SCHEMA_VERSION, TOOL_NAME, dump_json, list_files, now_iso,
                     read_text, scan, utf8_stdio)

MARKER_RE = re.compile(r"\b(TODO|FIXME|HACK|XXX|BUG|DEPRECATED)\b")


def largest_remainder(values: dict[str, float], total_points: int = 1000) -> dict[str, float]:
    """Percentages with one decimal that sum to exactly 100.0."""
    total = sum(values.values())
    if total <= 0:
        return {k: 0.0 for k in values}
    raw = {k: v * total_points / total for k, v in values.items()}
    floor = {k: int(v) for k, v in raw.items()}
    short = total_points - sum(floor.values())
    for k in sorted(raw, key=lambda k: raw[k] - floor[k], reverse=True)[:short]:
        floor[k] += 1
    return {k: floor[k] / (total_points / 100) for k in values}


def count_file(path: Path, lang) -> dict:
    text = read_text(path)
    if not text:
        return {"lines": 0, "code": 0, "comment": 0, "blank": 0, "markers": Counter()}
    lines = text.split("\n")
    if text.endswith("\n"):
        lines = lines[:-1]
    res = scan(text, lang)
    code = comment = blank = 0
    for i, line in enumerate(lines):
        if res.code_lines[i]:
            code += 1
        elif res.comment_lines[i]:
            comment += 1
        elif not line.strip():
            blank += 1
        else:
            code += 1          # scanner saw only punctuation it didn't classify
    # Markers count only inside comments: TODO in a string or a word list is data, not a to-do.
    markers = Counter(m.group(1) for a, b in res.comment_spans for m in MARKER_RE.finditer(text, a, b)) \
        if lang else Counter()
    return {"lines": len(lines), "code": code, "comment": comment, "blank": blank, "markers": markers}


def analyze(root: Path, exclude: list[str], include_vendored: bool, want_files: bool) -> dict:
    listing = list_files(root, exclude, include_vendored)
    per_lang: dict[str, dict] = defaultdict(lambda: {"files": 0, "lines": 0, "code": 0, "comment": 0,
                                                     "blank": 0, "bytes": 0, "test_files": 0})
    lang_types: dict[str, str] = {}
    excluded: dict[str, dict] = defaultdict(lambda: {"files": 0, "bytes": 0, "examples": []})
    unknown_ext: Counter = Counter()
    markers: Counter = Counter()
    file_rows = []
    largest = []
    untracked = 0
    for entry in listing["files"]:
        if not entry.tracked:
            untracked += 1
        if entry.status != "source":
            bucket = excluded[entry.status]
            bucket["files"] += 1
            bucket["bytes"] += entry.size
            if len(bucket["examples"]) < 8:
                bucket["examples"].append(f"{entry.path} ({entry.reason})")
            if entry.status == "unknown":
                ext = Path(entry.path).suffix.lower() or Path(entry.path).name
                unknown_ext[ext] += 1
            continue
        lang = entry.lang
        if entry.size > MAX_PARSE_BYTES * 5:
            bucket = excluded["large"]
            bucket["files"] += 1
            bucket["bytes"] += entry.size
            if len(bucket["examples"]) < 8:
                bucket["examples"].append(f"{entry.path} ({entry.size:,} bytes)")
            continue
        counts = count_file(root / entry.path, lang)
        markers.update(counts.pop("markers"))
        row = per_lang[lang.name]
        lang_types[lang.name] = lang.type
        row["files"] += 1
        row["bytes"] += entry.size
        row["test_files"] += int(entry.is_test)
        for k in ("lines", "code", "comment", "blank"):
            row[k] += counts[k]
        if lang.type in ("programming", "markup"):
            largest.append((counts["code"], entry.path, lang.name))
        if want_files:
            file_rows.append({"path": entry.path, "language": lang.name, "type": lang.type,
                              "bytes": entry.size, "is_test": entry.is_test,
                              "tracked": entry.tracked, **counts})

    bar = {k: v for k, v in per_lang.items() if lang_types[k] in ("programming", "markup")}
    pct_code = largest_remainder({k: v["code"] for k, v in bar.items()})
    pct_bytes = largest_remainder({k: v["bytes"] for k, v in bar.items()})
    languages = sorted(
        ({"language": k, "type": lang_types[k], **v, "pct_code": pct_code[k], "pct_bytes": pct_bytes[k]}
         for k, v in bar.items()),
        key=lambda r: (-r["code"], -r["bytes"], r["language"]))
    other = sorted(({"language": k, "type": lang_types[k], **v} for k, v in per_lang.items()
                    if k not in bar), key=lambda r: (r["type"], -r["lines"], r["language"]))

    def total(rows):
        return {k: sum(r[k] for r in rows) for k in ("files", "lines", "code", "comment", "blank", "bytes")}

    result = {
        "tool": f"{TOOL_NAME}/language_stats",
        "schema": SCHEMA_VERSION,
        "generated": now_iso(),
        "root": str(root),
        "file_listing": listing["mode"],
        "basis": "programming + markup languages; data and prose listed separately",
        "totals": {
            "language_bar": total(languages),
            "all_counted": total(languages + other),
            "untracked_files_included": untracked,
        },
        "languages": languages,
        "other": other,
        "excluded": dict(excluded),
        "unknown_extensions": dict(unknown_ext.most_common(25)),
        "markers": dict(markers.most_common()),
        "largest_files": [{"path": p, "language": l, "code": c}
                          for c, p, l in sorted(largest, reverse=True)[:12]],
    }
    if want_files:
        result["files"] = sorted(file_rows, key=lambda r: r["path"])
    return result


def print_table(data: dict) -> None:
    rows = data["languages"]
    t = data["totals"]["language_bar"]
    print(f"Root: {data['root']}  (file listing: {data['file_listing']})")
    print(f"{'Language':<22}{'Files':>7}{'Code':>10}{'Comment':>9}{'Blank':>8}{'% code':>8}{'% bytes':>9}")
    for r in rows:
        print(f"{r['language']:<22}{r['files']:>7}{r['code']:>10,}{r['comment']:>9,}{r['blank']:>8,}"
              f"{r['pct_code']:>7.1f}%{r['pct_bytes']:>8.1f}%")
    print(f"{'Total':<22}{t['files']:>7}{t['code']:>10,}{t['comment']:>9,}{t['blank']:>8,}")
    if data["other"]:
        print("\nData and prose (not in percentages):")
        for r in data["other"]:
            print(f"  {r['language']:<20}{r['type']:<12}{r['files']:>5} files {r['lines']:>9,} lines")
    if data["excluded"]:
        print("\nExcluded:")
        for status, b in data["excluded"].items():
            print(f"  {status:<10}{b['files']:>6} files  e.g. {', '.join(b['examples'][:3])}")
    if data["markers"]:
        print("\nMarkers:", ", ".join(f"{k} {v}" for k, v in data["markers"].items()))


def main(argv: list[str] | None = None) -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default=".", help="codebase directory (default: .)")
    ap.add_argument("--exclude", action="append", default=[], metavar="GLOB",
                    help="skip paths matching this glob or directory prefix (repeatable)")
    ap.add_argument("--include-vendored", action="store_true", help="count vendored directories too")
    ap.add_argument("--files", action="store_true", help="include a per-file table in the JSON")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a table")
    ap.add_argument("-o", "--output", type=Path, help="write JSON to this file")
    args = ap.parse_args(argv)
    root = Path(args.root)
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 2
    data = analyze(root.resolve(), args.exclude, args.include_vendored, args.files)
    if args.json or args.output:
        dump_json(data, args.output)
        if args.output:
            print(f"wrote {args.output}")
    else:
        print_table(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
