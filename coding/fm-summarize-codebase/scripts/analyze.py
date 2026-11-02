#!/usr/bin/env python3
"""
One command for the whole deterministic pass: metadata, language statistics,
and the symbol inventory, written to a work directory, plus a brief that sizes
the job and plans it.

Writes to --workdir:
  metadata.json    collect_metadata.py output
  languages.json   language_stats.py output (with the per-file table)
  symbols.json     extract_symbols.py output
  plan.json        size tier, module table, and reading batches for subagents

Tiers (by callables): S ≤ 150 single file · M ≤ 600 split reference ·
L ≤ 3000 split + parallel batches · XL > 3000 confirm scope with the user first.

Usage:
  python analyze.py <root> --workdir <dir>
  python analyze.py <root> --workdir <dir> --exclude "docs/*" --no-tests --batch-size 150

Exit codes: 0 = ok, 2 = root not found.
"""

from __future__ import annotations

import argparse
import sys
import tempfile
import time
from collections import defaultdict
from pathlib import Path

import collect_metadata
import extract_symbols
import language_stats
from _common import TOOL_NAME, dump_json, module_of, reference_pages, slug, utf8_stdio

TIERS = [(150, "S", "Single agent, single file. Read every file in full."),
         (600, "M", "Single file or split reference (scaffold decides at 250). Read module by module; subagents "
                    "optional."),
         (3000, "L", "Split reference. Fan out one subagent per batch in plan.json when the harness has subagents; "
                     "otherwise work batch by batch and check after each."),
         (10 ** 9, "XL", "Confirm scope with the user before writing: whole codebase, application code only "
                         "(--no-tests), or selected modules (--exclude). Then proceed as tier L.")]


def plan_batches(symbols: list[dict], batch_size: int) -> list[dict]:
    """Pack whole reference pages into batches of ~batch_size callables.

    A page is never split across batches, so parallel agents never edit the same file.
    """
    page_of = reference_pages(symbols)
    by_page = defaultdict(lambda: {"files": set(), "n": 0})
    for s in symbols:
        pg = by_page[page_of[s["id"]]]
        pg["files"].add(s["file"])
        pg["n"] += 1
    pages = sorted(by_page, key=lambda p: (module_of(min(by_page[p]["files"])), p))
    batches, cur, cur_n = [], [], 0
    for p in pages:
        n = by_page[p]["n"]
        if cur and cur_n + n > batch_size:
            batches.append((cur, cur_n))
            cur, cur_n = [], 0
        cur.append(p)
        cur_n += n
    if cur:
        batches.append((cur, cur_n))
    out = []
    for i, (pgs, n) in enumerate(batches, 1):
        files = sorted(f for p in pgs for f in by_page[p]["files"])
        out.append({"batch": i, "callables": n, "modules": sorted({module_of(f) for f in files}),
                    "reference_pages": [f"reference/{p}.md" for p in pgs], "files": files})
    return out


def main(argv: list[str] | None = None) -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default=".", help="codebase directory (default: .)")
    ap.add_argument("--workdir", type=Path, help="where to write the JSON (default: a temp folder)")
    ap.add_argument("--exclude", action="append", default=[], metavar="GLOB")
    ap.add_argument("--include-vendored", action="store_true")
    ap.add_argument("--no-tests", action="store_true", help="leave test files out of the inventory")
    ap.add_argument("--batch-size", type=int, default=150, help="callables per reading batch (default 150)")
    args = ap.parse_args(argv)
    root = Path(args.root)
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 2
    root = root.resolve()
    work = args.workdir or Path(tempfile.gettempdir()) / TOOL_NAME / slug(root.name)
    work.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    meta = collect_metadata.collect(root)
    dump_json(meta, work / "metadata.json")
    langs = language_stats.analyze(root, args.exclude, args.include_vendored, True)
    dump_json(langs, work / "languages.json")
    syms = extract_symbols.analyze(root, args.exclude, args.include_vendored, not args.no_tests)
    dump_json(syms, work / "symbols.json")
    n = syms["summary"]["callables"]
    tier = next(t for t in TIERS if n <= t[0])
    mods = defaultdict(lambda: {"files": set(), "callables": 0})
    for s in syms["symbols"]:
        mods[module_of(s["file"])]["files"].add(s["file"])
        mods[module_of(s["file"])]["callables"] += 1
    module_table = sorted(({"module": m, "files_with_callables": len(v["files"]), "callables": v["callables"]}
                           for m, v in mods.items()), key=lambda r: -r["callables"])
    batches = plan_batches(syms["symbols"], args.batch_size)
    plan = {"tool": f"{TOOL_NAME}/analyze", "root": str(root), "workdir": str(work), "callables": n,
            "tier": tier[1], "approach": tier[2], "modules": module_table,
            "batches": batches if tier[1] in ("L", "XL") or len(batches) > 1 else batches[:1],
            "exclude": args.exclude, "no_tests": args.no_tests, "seconds": round(time.time() - t0, 2)}
    dump_json(plan, work / "plan.json")

    s = meta["summary"]
    lt = langs["totals"]["language_bar"]
    print(f"{TOOL_NAME}: analyzed {root} in {plan['seconds']}s")
    print(f"  name        {s['name']['value']}  ({s['name']['source']})")
    print(f"  version     {s['version']['value']}  ({s['version']['source']})"
          + (f"  ⚠ conflict: {', '.join(s['version_conflict'])}" if s.get("version_conflict") else ""))
    git = meta.get("git", {})
    head = git.get("head")
    if head:
        print(f"  snapshot    {head.get('describe') or head['short']} on {head.get('branch') or 'detached'} — "
              f"{head['subject'][:70]}")
        d = git.get("dirty", {})
        if not d.get("clean", True):
            print(f"  ⚠ working tree has uncommitted changes: {d.get('modified', 0)} modified, "
                  f"{d.get('staged', 0)} staged, {d.get('untracked', 0)} untracked")
        if git.get("shallow"):
            print("  ⚠ shallow clone: commit counts, first commit, and contributors are partial")
    elif not git.get("is_repo"):
        print("  snapshot    not a git repository (last-updated falls back to file times)")
    for a in meta.get("artifacts", []):
        if a.get("possibly_stale"):
            print(f"  ⚠ packaged artifact {a['path']} may be stale: {a['possibly_stale']}")
    print(f"  size        {lt['files']:,} source files, {lt['code']:,} code lines")
    print("  languages   " + ", ".join(f"{r['language']} {r['pct_code']:.1f}%" for r in langs["languages"][:6]))
    ss = syms["summary"]
    print(f"  callables   {n:,} ({ss['non_test_callables']:,} app, {ss['test_callables']:,} test; "
          + ", ".join(f"{v} {k}" for k, v in ss["by_confidence"].items()) + f"), {ss['types']:,} types")
    if syms["unsupported"]:
        print(f"  read by hand {len(syms['unsupported'])} file(s) in languages without an extractor: "
              + ", ".join(u["path"] for u in syms["unsupported"][:6]))
    if meta.get("sensitive_files"):
        print(f"  ⚠ secret-bearing files present (never quote them): {', '.join(meta['sensitive_files'][:6])}")
    print(f"  tier        {tier[1]} — {tier[2]}")
    if len(batches) > 1:
        print(f"  batches     {len(batches)} reading batches of ≤ ~{args.batch_size} callables (plan.json)")
    print(f"  workdir     {work}")
    here = Path(__file__).resolve().parent
    print(f"next: python \"{here / 'scaffold_report.py'}\" \"{work}\" -o <report.md>")
    return 0


if __name__ == "__main__":
    sys.exit(main())
