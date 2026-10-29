#!/usr/bin/env python3
"""
Verify a finished codebase summary against the symbol inventory.

Errors (exit 1):
  - [[FILL: ...]] slots left in the report or its split pages
  - an inventoried callable without its reference entry (<!-- sym:ID -->) or its
    function-index row (<!-- idx:ID -->), unless dropped with <!-- drop:ID reason -->
  - the stated total (<N> <!-- total-callables -->) differs from
    inventory - drops + manual additions
  - relative links to .md pages that don't exist
  - strings that look like secrets (API keys, tokens, private keys, passwords)

Warnings (exit 1 only with --strict):
  - thin reference entries (fewer words of description than a real explanation needs)
  - one-line summaries that only restate the function's name
  - duplicate entries, markers for IDs that aren't in the inventory
  - mermaid blocks that don't start with a diagram type

Usage:
  python check_report.py symbols.json CODEBASE_SUMMARY.md
  python check_report.py symbols.json CODEBASE_SUMMARY.md --strict --json

Exit codes: 0 = complete, 1 = problems found, 2 = unreadable input.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

from _common import load_json, utf8_stdio

FILL_RE = re.compile(r"\[\[FILL:")
SYM_RE = re.compile(r"<!--\s*sym:(\S+?)(\s+compact)?\s*-->")
IDX_RE = re.compile(r"<!--\s*idx:(\S+?)\s*-->")
DROP_RE = re.compile(r"<!--\s*drop:(\S+?)(?:\s+[^>]*)?-->")
TOTAL_RE = re.compile(r"([\d,]+)\s*<!--\s*total-callables\s*-->")
PARTS_RE = re.compile(r"<!--\s*fm-summarize-codebase:\s*parts=(\S*)")
LINK_RE = re.compile(r"\]\(([^)#\s]+\.md)(?:#[^)]*)?\)")
SECRET_RES = [
    (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS access key id"),
    (re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----"), "private key block"),
    (re.compile(r"\b(?:sk|rk)-(?:ant-|proj-|live-|test-)?[A-Za-z0-9_\-]{20,}"), "API secret key"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}"), "GitHub token"),
    (re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"), "Slack token"),
    (re.compile(r"\bAIza[0-9A-Za-z_\-]{35}"), "Google API key"),
    (re.compile(r"(?i)\b(?:password|passwd|secret|api[_-]?key|token)\s*[:=]\s*['\"][^'\"\s]{8,}['\"]"),
     "hard-coded credential"),
]
MERMAID_TYPES = ("flowchart", "graph", "sequenceDiagram", "classDiagram", "stateDiagram", "erDiagram",
                 "gantt", "pie", "journey", "mindmap", "timeline", "quadrantChart", "gitGraph", "C4",
                 "block-beta", "architecture", "sankey", "xychart", "requirementDiagram", "packet", "kanban")
STOP = {"the", "a", "an", "of", "for", "to", "and", "or", "in", "on", "by", "with", "from", "this", "that",
        "it", "its", "is", "are", "be", "as", "at", "given", "value", "function", "method", "returns", "return"}
MIN_WORDS = {"full": 25, "compact": 6}
FACTS_LINE = re.compile(r"^(?:Doc comment|Decorators/attributes|Calls|Called by): |^\*\*Summary:\*\*")


def strip_code(text: str) -> str:
    """Remove fenced blocks and inline code so markers quoted in instructions don't count."""
    text = re.sub(r"^(`{3,}|~{3,}).*?^\1[^\n]*$", "", text, flags=re.S | re.M)
    return re.sub(r"(`+)(?!`).+?(?<!`)\1(?!`)", "", text)


def split_words(name: str) -> set[str]:
    base = re.sub(r"[^A-Za-z0-9]+", " ", re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", name.split(".")[-1]))
    return {w.lower() for w in base.split() if w}


def entry_texts(text: str) -> dict[str, tuple[str, bool]]:
    """ID -> (agent-written prose of the reference entry, compact?)."""
    out = {}
    marks = list(SYM_RE.finditer(text))
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        chunk = text[m.end():end]
        nxt = re.search(r"^#{1,4}\s", chunk, re.M)
        if nxt:
            chunk = chunk[:nxt.start()]
        chunk = re.sub(r"```.*?```", " ", chunk, flags=re.S)              # signature blocks
        lines = [ln for ln in chunk.splitlines() if ln.strip()]
        # Line 0 is the pre-filled "kind · lines …" line; the facts line starts with one of these labels
        # followed by a colon. Prose that merely begins with "Calls …" still counts.
        prose = [ln for ln in lines[1:] if not FACTS_LINE.match(ln)] if lines else []
        out.setdefault(m.group(1), (" ".join(prose), bool(m.group(2))))
    return out


def index_summaries(text: str) -> dict[str, str]:
    out = {}
    for line in text.splitlines():
        m = IDX_RE.search(line)
        if m:
            cells = [c.strip() for c in re.split(r"(?<!\\)\|", line)]
            cells = [c for c in cells if c != ""]
            out[m.group(1)] = cells[-1] if cells else ""
    return out


def check(symbols_path: Path, report: Path, strict: bool) -> dict:
    inv = load_json(symbols_path)
    ids = [s["id"] for s in inv["symbols"]]
    by_id = {s["id"]: s for s in inv["symbols"]}
    main_text = report.read_text(encoding="utf-8")
    files = [report]
    pm = PARTS_RE.search(main_text)
    if pm and pm.group(1):
        parts = report.parent / pm.group(1)
        if parts.is_dir():
            files += sorted(parts.rglob("*.md"))
    texts = {f: f.read_text(encoding="utf-8") for f in files}
    errors, warnings = [], []

    for f, t in texts.items():
        for ln_no, line in enumerate(t.splitlines(), 1):
            if FILL_RE.search(line):
                errors.append(f"unfilled slot: {f.name}:{ln_no}: {line.strip()[:100]}")
    all_text = "\n".join(texts.values())
    live = strip_code(all_text)                   # markers only count outside code
    sym_hits = Counter(m.group(1) for m in SYM_RE.finditer(live))
    idx_hits = Counter(m.group(1) for m in IDX_RE.finditer(live))
    drops = {m.group(1) for m in DROP_RE.finditer(live)}
    manual = {i for i in sym_hits if i.startswith("manual:")}
    missing_sym = [i for i in ids if i not in sym_hits and i not in drops]
    missing_idx = [i for i in ids if i not in idx_hits and i not in drops]
    for i in missing_sym[:50]:
        errors.append(f"no reference entry for {i}")
    if len(missing_sym) > 50:
        errors.append(f"... and {len(missing_sym) - 50} more callables without reference entries")
    for i in missing_idx[:50]:
        errors.append(f"no function-index row for {i}")
    if len(missing_idx) > 50:
        errors.append(f"... and {len(missing_idx) - 50} more callables without index rows")
    for i, n in sym_hits.items():
        if n > 1:
            warnings.append(f"duplicate reference entry: {i} ({n}x)")
        if i not in by_id and not i.startswith("manual:"):
            warnings.append(f"reference entry for an ID not in the inventory: {i} (stale inventory?)")
    for i in idx_hits:
        if i not in by_id and not i.startswith("manual:"):
            warnings.append(f"index row for an ID not in the inventory: {i}")
    for i in sorted(manual):
        if i not in idx_hits:
            errors.append(f"manual entry without an index row: {i} (run sync_report.py)")
    expected_total = len(ids) - len(drops & set(ids)) + len(manual)
    tm = TOTAL_RE.search(strip_code(main_text))
    if not tm:
        errors.append("the total-callables marker is missing from section 1.6")
    elif int(tm.group(1).replace(",", "")) != expected_total:
        errors.append(f"stated total {tm.group(1)} != expected {expected_total} "
                      f"(inventory {len(ids)} - {len(drops & set(ids))} dropped + {len(manual)} manual)")
    # Quality.
    thin = []
    for i, (prose, compact) in entry_texts(all_text).items():
        need = MIN_WORDS["compact" if compact else "full"]
        if len(re.findall(r"\w+", prose)) < need and "[[FILL" not in prose:
            thin.append(i)
    for i in thin[:40]:
        warnings.append(f"thin reference entry (fewer than {MIN_WORDS['full']} words): {i}")
    if len(thin) > 40:
        warnings.append(f"... and {len(thin) - 40} more thin entries")
    restated = []
    for i, summ in index_summaries(all_text).items():
        if "[[FILL" in summ or i not in by_id:
            continue
        words = {w.lower() for w in re.findall(r"[A-Za-z0-9]+", summ)} - STOP
        if not words or words <= split_words(by_id[i]["name"]):
            restated.append(i)
    for i in restated[:30]:
        warnings.append(f"index summary only restates the name: {i}")
    # Links, secrets, mermaid.
    for f, t in texts.items():
        for m in LINK_RE.finditer(t):
            target = m.group(1)
            if re.match(r"^[a-z]+://", target):
                continue
            if not (f.parent / target).resolve().is_file():
                errors.append(f"broken link in {f.name}: {target}")
        for rx, label in SECRET_RES:
            for m in rx.finditer(t):
                errors.append(f"possible {label} in {f.name}: {m.group(0)[:12]}… — remove it")
        for m in re.finditer(r"```mermaid\s*\n(.*?)```", t, re.S):
            first = m.group(1).strip().split("\n", 1)[0].strip()
            if not first.startswith(MERMAID_TYPES):
                warnings.append(f"mermaid block in {f.name} starts with {first[:30]!r}, not a diagram type")
    ok = not errors and not (strict and warnings)
    return {"ok": ok, "files": [str(f) for f in files], "inventory": len(ids), "drops": len(drops),
            "manual": len(manual), "reference_entries": sum(1 for i in ids if i in sym_hits),
            "index_rows": sum(1 for i in ids if i in idx_hits), "errors": errors, "warnings": warnings}


def main(argv: list[str] | None = None) -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("symbols", type=Path, help="symbols.json from analyze.py / extract_symbols.py")
    ap.add_argument("report", type=Path, help="the summary markdown (split pages are found automatically)")
    ap.add_argument("--strict", action="store_true", help="warnings also fail")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args(argv)
    if not args.symbols.is_file() or not args.report.is_file():
        print("error: symbols.json or report not found", file=sys.stderr)
        return 2
    res = check(args.symbols, args.report, args.strict)
    if args.json:
        print(json.dumps(res, indent=2))
    else:
        print(f"{'PASS' if res['ok'] else 'FAIL'}: {res['reference_entries']}/{res['inventory']} reference entries, "
              f"{res['index_rows']}/{res['inventory']} index rows, {res['drops']} dropped, {res['manual']} manual, "
              f"{len(res['errors'])} error(s), {len(res['warnings'])} warning(s) across {len(res['files'])} file(s)")
        for e in res["errors"][:80]:
            print(f"  ERROR    {e}")
        for w in res["warnings"][:60]:
            print(f"  WARNING  {w}")
    return 0 if res["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
