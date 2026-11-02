#!/usr/bin/env python3
"""
Rebuild every derived part of a summary from its reference entries.

The reference entries are the source of truth; this regenerates what depends
on them, so nothing is ever hand-edited twice:

  - the function index (<!-- gen:index --> block): one row per entry, with the
    entry's **Summary:** line copied in
  - the 1.6 inventory block (<!-- gen:inventory -->): total, kinds, languages,
    modules
  - every callable count anchored with <!-- fncount:MODULE --> (header line,
    3.1 table, 3.4 module headers)

It applies corrections recorded in the report: entries dropped with
<!-- drop:ID reason --> leave the index and the counts; manual entries
(<!-- sym:manual:path::Name -->) are added, with kind and lines read from the
entry's first line. Run it after filling or correcting entries, before
check_report.py. Safe to run repeatedly.

Usage:
  python sync_report.py <work>/symbols.json CODEBASE_SUMMARY.md

Exit codes: 0 = synced and every entry has a Summary, 1 = synced but some
Summary lines are unfinished, 2 = bad input.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

from _common import detect_language, load_json, module_of, utf8_stdio
from scaffold_report import GEN_INDEX, GEN_INVENTORY, index_body, inventory_block

SYM_RE = re.compile(r"<!--\s*sym:(\S+?)(\s+compact)?\s*-->")
DROP_RE = re.compile(r"<!--\s*drop:(\S+?)(?:\s+[^>]*)?-->")
SUMMARY_RE = re.compile(r"^\*\*Summary:\*\*\s*(.+?)\s*$", re.M)
PARTS_RE = re.compile(r"<!--\s*fm-summarize-codebase:\s*parts=(\S*)")
FNCOUNT_RE = re.compile(r"\d[\d,]*(<!--\s*fncount:(\S+?)\s*-->)")


def strip_code(text: str) -> str:
    text = re.sub(r"^(`{3,}|~{3,}).*?^\1[^\n]*$", "", text, flags=re.S | re.M)
    return re.sub(r"(`+)(?!`).+?(?<!`)\1(?!`)", "", text)


def report_files(report: Path) -> list[Path]:
    files = [report]
    m = PARTS_RE.search(report.read_text(encoding="utf-8"))
    if m and m.group(1) and (report.parent / m.group(1)).is_dir():
        files += sorted((report.parent / m.group(1)).rglob("*.md"))
    return files


def read_entries(files: list[Path]) -> tuple[dict, set]:
    """id -> {summary, heading, kind_line, file}; plus dropped ids."""
    entries, drops = {}, set()
    for f in files:
        text = f.read_text(encoding="utf-8")
        live = strip_code(text)
        drops |= {m.group(1) for m in DROP_RE.finditer(live)}
        live_ids = {m.group(1) for m in SYM_RE.finditer(live)}
        marks = [m for m in SYM_RE.finditer(text) if m.group(1) in live_ids]
        for i, m in enumerate(marks):
            end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
            seg = text[m.end():end]
            nxt = re.search(r"^#{1,4}\s", seg, re.M)
            seg = seg[:nxt.start()] if nxt else seg
            head_line = text[text.rfind("\n", 0, m.start()) + 1:m.start()]
            heading = re.sub(r"^#+\s*", "", head_line).strip().strip("`").strip()
            group = None
            for g in re.finditer(r"^###\s+`([^`]+)`", text[:m.start()], re.M):
                group = g.group(1)
            first = next((ln.strip() for ln in seg.splitlines() if ln.strip()), "")
            sm = SUMMARY_RE.search(seg)
            entries[m.group(1)] = {"summary": sm.group(1) if sm and "[[FILL" not in sm.group(1) else None,
                                   "heading": heading, "kind_line": first, "file": group}
    return entries, drops


def manual_record(sid: str, e: dict) -> dict:
    path = sid[len("manual:"):].split("::", 1)[0] if "::" in sid else (e["file"] or "?")
    kind = e["kind_line"].split(" · ", 1)[0].strip() or "function"
    lm = re.search(r"lines?\s+(\d+)(?:\s*[–-]\s*(\d+))?", e["kind_line"])
    lang = detect_language(path)
    return {"id": sid, "qualname": e["heading"] or sid.rsplit("::", 1)[-1], "kind": kind, "file": path,
            "language": lang.name if lang else "unknown", "line": int(lm.group(1)) if lm else None,
            "end_line": int(lm.group(2)) if lm and lm.group(2) else (int(lm.group(1)) if lm else None),
            "is_test": "test" in e["kind_line"].split(" · "), "abstract": "abstract" in e["kind_line"].split(" · ")}


def replace_block(text: str, markers: tuple[str, str], lines: list[str]) -> tuple[str, bool]:
    a, b = text.find(markers[0]), text.find(markers[1])
    if a < 0 or b < 0:
        return text, False
    return text[:a] + "\n".join(lines) + text[b + len(markers[1]):], True


def main(argv: list[str] | None = None) -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("symbols", type=Path, help="symbols.json from analyze.py")
    ap.add_argument("report", type=Path, help="the summary markdown (split pages are found automatically)")
    args = ap.parse_args(argv)
    if not args.symbols.is_file() or not args.report.is_file():
        print("error: symbols.json or report not found", file=sys.stderr)
        return 2
    syms = load_json(args.symbols)
    files = report_files(args.report)
    entries, drops = read_entries(files)
    effective = [s for s in syms["symbols"] if s["id"] not in drops]
    manual = [manual_record(i, e) for i, e in entries.items() if i.startswith("manual:")]
    effective += manual
    summaries = {i: e["summary"] for i, e in entries.items() if e["summary"]}
    per_module = Counter(module_of(e["file"]) for e in effective)
    index_done = inventory_done = False
    for f in files:
        text = f.read_text(encoding="utf-8")
        new, ok = replace_block(text, GEN_INDEX, index_body(effective, summaries))
        index_done |= ok
        new, ok = replace_block(new, GEN_INVENTORY, inventory_block(effective, syms))
        inventory_done |= ok

        def count_sub(m):
            mod = m.group(2).replace("%20", " ")
            n = len(effective) if mod == "*" else per_module.get(mod, 0)
            return f"{n}{m.group(1)}"

        new = FNCOUNT_RE.sub(count_sub, new)
        if new != text:
            f.write_text(new, encoding="utf-8")
    missing = [e["id"] for e in effective if e["id"] not in summaries]
    print(f"synced: {len(effective)} callables ({len(syms['symbols'])} inventoried - "
          f"{len(drops & {s['id'] for s in syms['symbols']})} dropped + {len(manual)} manual); "
          f"index {'rebuilt' if index_done else 'NOT FOUND'}, inventory {'rebuilt' if inventory_done else 'NOT FOUND'}; "
          f"{len(missing)} entries without a finished Summary line")
    for sid in missing[:30]:
        print(f"  no summary: {sid}")
    if not (index_done and inventory_done):
        print("  the generated blocks are missing: was this report made by scaffold_report.py?", file=sys.stderr)
        return 2
    return 0 if not missing else 1


if __name__ == "__main__":
    sys.exit(main())
