#!/usr/bin/env python3
"""
Refresh support: move finished descriptions from an earlier summary into a new
scaffold, but only for callables whose code did not change.

A callable is carried over when its id exists in both inventories and its
content hash (extract_symbols.py "hash") is identical. Changed callables keep
their [[FILL]] slot and get the old text beneath it as a hint to revise; new
callables stay empty; removed ones are listed. Section-level prose (overviews,
purpose, risks) is never carried: it must be re-read against the new code.

Usage:
  python carry_over.py --old-symbols old/symbols.json --old-report OLD.md \\
                       --new-symbols new/symbols.json --new-report NEW.md

The new report (and its split pages) is edited in place.
Exit codes: 0 = done, 2 = missing input.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from _common import load_json, utf8_stdio

SYM_RE = re.compile(r"<!--\s*sym:(\S+?)(\s+compact)?\s*-->")
IDX_ROW_RE = re.compile(r"^(\|\s*<!--\s*idx:(\S+?)\s*-->.*\|)\s*(.*?)\s*\|\s*$", re.M)
PARTS_RE = re.compile(r"<!--\s*fm-summarize-codebase:\s*parts=(\S*)")
FILL_RE = re.compile(r"\[\[FILL:[^\]]*\]\]")


def report_files(report: Path) -> list[Path]:
    files = [report]
    m = PARTS_RE.search(report.read_text(encoding="utf-8"))
    if m and m.group(1) and (report.parent / m.group(1)).is_dir():
        files += sorted((report.parent / m.group(1)).rglob("*.md"))
    return files


def entry_prose(segment: str) -> str:
    """Agent-written part of one reference entry (everything after the facts)."""
    nxt = re.search(r"^#{1,4}\s", segment, re.M)
    seg = segment[:nxt.start()] if nxt else segment
    seg = re.sub(r"^(`{3,}).*?^\1\s*$", "", seg, flags=re.S | re.M)
    paras = [p.strip() for p in re.split(r"\n\s*\n", seg) if p.strip()]
    keep = [p for p in paras[1:] if not re.match(r"^(Doc comment|Decorators|Calls|Called by)\b", p)]
    return "\n\n".join(keep).strip()


def old_entries(files: list[Path]) -> tuple[dict, dict]:
    prose, index = {}, {}
    for f in files:
        text = f.read_text(encoding="utf-8")
        marks = list(SYM_RE.finditer(text))
        for i, m in enumerate(marks):
            end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
            p = entry_prose(text[m.end():end])
            if p and "[[FILL" not in p:
                prose[m.group(1)] = p
        for m in IDX_ROW_RE.finditer(text):
            if "[[FILL" not in m.group(3) and m.group(3):
                index[m.group(2)] = m.group(3)
    return prose, index


def main(argv: list[str] | None = None) -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--old-symbols", type=Path, required=True)
    ap.add_argument("--old-report", type=Path, required=True)
    ap.add_argument("--new-symbols", type=Path, required=True)
    ap.add_argument("--new-report", type=Path, required=True)
    args = ap.parse_args(argv)
    for p in (args.old_symbols, args.old_report, args.new_symbols, args.new_report):
        if not p.is_file():
            print(f"error: not found: {p}", file=sys.stderr)
            return 2
    old = {s["id"]: s for s in load_json(args.old_symbols)["symbols"]}
    new = {s["id"]: s for s in load_json(args.new_symbols)["symbols"]}
    unchanged = {i for i in new if i in old and old[i].get("hash") and old[i]["hash"] == new[i].get("hash")}
    changed = {i for i in new if i in old} - unchanged
    prose, index = old_entries(report_files(args.old_report))
    carried = hinted = 0
    for f in report_files(args.new_report):
        text = f.read_text(encoding="utf-8")
        out, pos = [], 0
        marks = list(SYM_RE.finditer(text))
        for i, m in enumerate(marks):
            end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
            seg = text[m.end():end]
            sid = m.group(1)
            nxt = re.search(r"^#{1,4}\s", seg, re.M)
            entry_end = nxt.start() if nxt else len(seg)
            slots = list(FILL_RE.finditer(seg, 0, entry_end))
            if slots and sid in prose:
                # The entry's slots run from its **Summary:** line through the detailed description.
                first = seg.rfind("\n", 0, slots[0].start()) + 1
                last = slots[-1].end()
                if sid in unchanged:
                    seg = seg[:first] + prose[sid] + seg[last:]
                    carried += 1
                elif sid in changed:
                    hint = "\n\n> Previous description (the code has changed since; revise, then delete this " \
                           "note):\n>\n" + "\n".join(f"> {ln}" if ln else ">" for ln in prose[sid].splitlines())
                    seg = seg[:last] + hint + seg[last:]
                    hinted += 1
            out.append(text[pos:m.end()] + seg)
            pos = end
        out.append(text[pos:])
        f.write_text("".join(out), encoding="utf-8")
    removed = sorted(set(old) - set(new))
    added = sorted(set(new) - set(old))
    print(f"carried {carried} unchanged descriptions; {hinted} changed callables got the old text as a hint; "
          f"{len(added)} new; {len(removed)} removed. Run sync_report.py once the reference is complete.")
    for r in removed[:30]:
        print(f"  removed: {r}")
    for a in added[:30]:
        print(f"  new:     {a}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
