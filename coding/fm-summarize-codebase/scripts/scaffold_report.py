#!/usr/bin/env python3
"""
Build the codebase summary skeleton from analyze.py's JSON: every fact filled in,
every piece of interpretation left as a [[FILL: instruction]] slot.

The skeleton has one slot per inventoried callable in the function index
(<!-- idx:ID -->) and one in the detailed reference (<!-- sym:ID -->), so a
summary that skips a function cannot pass check_report.py.

Layout (sections in this order):
  1. Specifications      identity/metadata table, purpose, languages, stack,
                         entry points, function & method inventory + index
  2. General overview    newcomer narrative + architecture diagram
  3. Detailed overview   structure, architecture, flows, modules, data, interfaces,
                         config/build, dependencies, testing, cross-cutting, risks
  4. Function & method reference
  Appendix               methodology and limits, extractor corrections

Large inventories are split: the reference goes to <parts>/reference/<module>.md
and, past --inline-index-limit, the index goes to <parts>/function-index.md.

Usage:
  python scaffold_report.py <workdir> -o CODEBASE_SUMMARY.md
  python scaffold_report.py <workdir> -o SUMMARY.md --split always --parts-dir summary-parts

Exit codes: 0 = written, 2 = missing input.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from _common import TOOL_NAME, load_json, module_of, now_iso, reference_pages, slug, utf8_stdio

FENCE_LANG = {"Python": "python", "JavaScript": "javascript", "TypeScript": "typescript", "C#": "csharp",
              "Java": "java", "Go": "go", "Rust": "rust", "C": "c", "C++": "cpp", "CUDA": "cpp",
              "PowerShell": "powershell", "Shell": "bash", "Ruby": "ruby", "PHP": "php", "Kotlin": "kotlin",
              "Swift": "swift", "Scala": "scala", "Dart": "dart", "Lua": "lua", "SQL": "sql",
              "Visual Basic .NET": "vbnet", "Elixir": "elixir", "F#": "fsharp", "Haskell": "haskell",
              "Julia": "julia", "R": "r", "Perl": "perl", "Objective-C": "objectivec", "Groovy": "groovy",
              "Zig": "zig", "Nim": "nim", "Clojure": "clojure", "Erlang": "erlang", "OCaml": "ocaml",
              "Batchfile": "batch", "CMake": "cmake", "Solidity": "solidity", "GDScript": "gdscript",
              "MATLAB": "matlab", "Fortran": "fortran", "Pascal": "pascal", "Crystal": "crystal"}
COMPACT_MAX_LINES = 3          # extent fallback when code-line counts are unavailable
COMPACT_MAX_CODE_LINES = 5     # header + a few statements + closer: one or two sentences suffice


def cell(text) -> str:
    return str(text if text is not None else "—").replace("|", "\\|").replace("\n", " ")


def code(text: str) -> str:
    """Inline code span that survives backticks inside the text."""
    text = str(text)
    runs = [len(r) for r in re.findall(r"`+", text)]
    fence = "`" * (max(runs) + 1 if runs else 1)
    pad = " " if text.startswith("`") or text.endswith("`") else ""
    return f"{fence}{pad}{text}{pad}{fence}"


def fence_block(text: str, lang: str) -> str:
    runs = [len(r) for r in re.findall(r"`{3,}", text)]
    fence = "`" * max(3, (max(runs) + 1) if runs else 3)
    return f"{fence}{FENCE_LANG.get(lang.split(' (')[-1].rstrip(')'), '')}\n{text}\n{fence}"


def fmt_date(iso: str | None) -> str:
    return iso.replace("T", " ")[:19] + (f" {iso[19:]}" if iso and len(iso) > 19 else "") if iso else "—"


def ev_str(e) -> str:
    if not e or e.get("value") in (None, ""):
        return "—"
    v = e["value"]
    if isinstance(v, dict):
        v = ", ".join(f"{k} {val}" for k, val in v.items())
    return f"{cell(v)} _({cell(e['source'])})_"


def evidence_list(items: list, limit: int = 8) -> str:
    if not items:
        return "—"
    vals = [cell(i["value"] if not isinstance(i["value"], dict) else
                 ", ".join(f"{k} {v}" for k, v in i["value"].items())) for i in items[:limit]]
    more = f" (+{len(items) - limit} more)" if len(items) > limit else ""
    return ", ".join(vals) + more


def bar(pct: float, width: int = 20) -> str:
    full = int(round(pct / 100 * width))
    return "█" * full + "░" * (width - full)


def fill(instruction: str) -> str:
    return f"[[FILL: {instruction}]]"


# ── Sections ─────────────────────────────────────────────────────────────────

def section_identity(meta: dict, langs: dict, syms: dict) -> list[str]:
    s = meta["summary"]
    g = meta.get("git", {})
    ident = meta["identity"]
    out = ["### 1.1 Identity and metadata", "",
           "| Field | Value |", "| --- | --- |"]
    name_val = s.get("readme_title") or s["name"]["value"]
    out.append(f"| Official name | **{cell(name_val)}** _({cell('README title' if s.get('readme_title') else s['name']['source'])})_ |")
    if s.get("package_id") and s["package_id"]["value"] != name_val:
        out.append(f"| Package / identifier | {code(s['package_id']['value'])} _({cell(s['package_id']['source'])})_ |")
    ver = s.get("version") or {}
    ver_txt = ev_str(ver) if ver.get("value") else "Not declared _(no manifest, tag, or changelog version)_"
    if s.get("version_conflict"):
        srcs = "; ".join(f"{cell(v['value'])} in {cell(v['source'])}" for v in ident["versions"][:6])
        ver_txt += f" — ⚠ sources disagree: {srcs}"
    out.append(f"| Version | {ver_txt} |")
    tag = g.get("latest_tag")
    if tag:
        rel = "HEAD is the tagged release" if tag.get("commits_since") == 0 else \
            f"HEAD is {tag.get('commits_since')} commit(s) past tag {code(tag['name'])} ({fmt_date(tag.get('date'))[:10]}) — unreleased changes"
        out.append(f"| Release status | {rel} |")
    elif g.get("is_repo"):
        out.append("| Release status | No git tags |")
    dates = meta.get("dates", {})
    lu = dates.get("last_updated")
    if lu:
        extra = " · uncommitted changes in the working tree" if dates.get("uncommitted_changes") else ""
        out.append(f"| Last updated | {fmt_date(lu['value'])} _({cell(lu['basis'])})_{extra} |")
    head = g.get("head")
    if head:
        dirty = g.get("dirty", {})
        state = "clean" if dirty.get("clean") else \
            f"dirty: {dirty.get('modified', 0)} modified, {dirty.get('staged', 0)} staged, {dirty.get('untracked', 0)} untracked"
        br = head.get("branch") or "detached HEAD"
        out.append(f"| Latest git snapshot | {code(head['short'])} on {code(br)} — “{cell(head['subject'])}” "
                   f"by {cell(head['author'])}, {fmt_date(head['commit_date'])} · {code(head.get('describe') or head['short'])} · {state} |")
        if g.get("path_last_commit"):
            pl = g["path_last_commit"]
            out.append(f"| Last commit touching {code(pl['scope'])} | {code(pl['short'])} — “{cell(pl['subject'])}”, "
                       f"{fmt_date(pl['commit_date'])} |")
        if g.get("upstream"):
            up = g["upstream"]
            out.append(f"| Upstream | {code(up['ref'])} — ahead {up.get('ahead')}, behind {up.get('behind')} |")
    elif g.get("is_repo"):
        out.append("| Latest git snapshot | Repository has no commits yet |")
    else:
        out.append("| Latest git snapshot | Not a git repository |")
    repo = s.get("repository")
    if repo and repo.get("value"):
        url = repo["value"]
        out.append(f"| Repository | {'<' + url + '>' if re.match(r'https?://', url) else cell(url)} |")
    if dates.get("created"):
        cc = g.get("commit_count", {})
        count = cc.get("path", cc.get("repository"))
        contrib = g.get("contributors", {})
        top = ", ".join(f"{cell(p['name'])} ({p['commits']})" for p in contrib.get("top", [])[:3])
        out.append(f"| History | First commit {fmt_date(dates['created']['value'])[:10]} · {count} commits · "
                   f"{contrib.get('count', '?')} contributor(s){': ' + top if top else ''}"
                   f"{' · ⚠ shallow clone: counts are partial' if g.get('shallow') else ''} |")
    out.append(f"| License | {ev_str(s.get('license')) if s.get('license') else 'Not declared'} |")
    if ident.get("authors"):
        out.append(f"| Authors | {evidence_list(ident['authors'], 5)} |")
    if s.get("description") and s["description"].get("value"):
        out.append(f"| Declared description | {ev_str(s['description'])} |")
    if meta.get("runtime"):
        out.append(f"| Runtime / platform targets | {evidence_list(meta['runtime'])} |")
    t = meta.get("tooling", {})
    for key, label in (("package_managers", "Package managers"), ("build_systems", "Build systems"),
                       ("ci", "CI/CD"), ("containers", "Containers / deployment"),
                       ("test_frameworks", "Test frameworks"), ("linters_formatters", "Linters / formatters")):
        if t.get(key):
            out.append(f"| {label} | {evidence_list(t[key])} |")
    tot = langs["totals"]["language_bar"]
    allc = langs["totals"]["all_counted"]
    ss = syms["summary"]
    out.append(f"| Size | {tot['files']:,} source files · {tot['code']:,} code lines ({tot['comment']:,} comment, "
               f"{tot['blank']:,} blank) · {allc['files']:,} files counted in total · "
               f"{ss['callables']:,} functions & methods · {ss['types']:,} types |")
    if langs.get("markers"):
        out.append(f"| Code markers | {', '.join(f'{k} {v}' for k, v in langs['markers'].items())} |")
    docs = meta.get("docs", {})
    doc_bits = []
    if docs.get("readme"):
        doc_bits.append(f"{docs['readme']['path']} ({docs['readme']['lines']} lines)")
    if docs.get("changelog"):
        cl = docs["changelog"]
        doc_bits.append(f"{cl['path']} (latest {cl.get('latest_version') or '?'}"
                        f"{', ' + cl['latest_date'] if cl.get('latest_date') else ''})")
    doc_bits += docs.get("community", []) + docs.get("agent_instructions", [])
    doc_bits += [f"{d}/" for d in docs.get("docs_dirs", [])]
    if doc_bits:
        out.append(f"| Documentation | {cell(', '.join(doc_bits))} |")
    if meta.get("sensitive_files"):
        out.append(f"| Secret-bearing files present | {cell(', '.join(meta['sensitive_files'][:8]))} "
                   f"_(contents not read or reproduced)_ |")
    for a in meta.get("artifacts", [])[:8]:
        note = f" — ⚠ {cell(a['possibly_stale'])}" if a.get("possibly_stale") else (
            " — contents match the working tree" if a.get("zip_members_matching_tree") and
            not a.get("zip_members_differing") else "")
        out.append(f"| Packaged artifact | {code(a['path'])} ({a['bytes']:,} bytes){note} |")
    if meta.get("subprojects"):
        subs = ", ".join(f"{p['path']} ({p.get('name') or '?'} {p.get('version') or ''})".strip()
                         for p in meta["subprojects"][:10])
        out.append(f"| Workspace members | {cell(subs)} |")
    for f in ident.get("flags", []):
        out.append(f"| Note | {ev_str(f)} |")
    out.append(f"| Other important metadata | {fill('add any metadata the table misses that matters to this codebase (supported platforms, published package/registry, deployment target, data stores, licenses of bundled assets). Write None if nothing applies.')} |")
    return out


def section_languages(langs: dict) -> list[str]:
    rows = langs["languages"]
    out = ["### 1.3 Languages", "",
           "Measured over programming and markup files; data files and prose are listed separately and are not part "
           "of the percentages. Vendored, generated, and binary files are excluded.", "",
           "| Language | Type | Files | Code lines | Comment | Blank | % of code | % of bytes | Share |",
           "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
    for r in rows:
        out.append(f"| {cell(r['language'])} | {r['type']} | {r['files']:,} | {r['code']:,} | {r['comment']:,} | "
                   f"{r['blank']:,} | {r['pct_code']:.1f}% | {r['pct_bytes']:.1f}% | `{bar(r['pct_code'])}` |")
    t = langs["totals"]["language_bar"]
    out.append(f"| **Total** | | **{t['files']:,}** | **{t['code']:,}** | {t['comment']:,} | {t['blank']:,} | 100% | 100% | |")
    if len(rows) > 1:
        out += ["", "```mermaid", "pie showData title Code lines by language"]
        top = rows[:8]
        for r in top:
            out.append(f'    "{r["language"]}" : {r["code"]}')
        rest = sum(r["code"] for r in rows[8:])
        if rest:
            out.append(f'    "Other" : {rest}')
        out.append("```")
    if langs.get("other"):
        out += ["", "Other files (not in the percentages):", "",
                "| Kind | Type | Files | Lines |", "| --- | --- | ---: | ---: |"]
        for r in langs["other"]:
            out.append(f"| {cell(r['language'])} | {r['type']} | {r['files']:,} | {r['lines']:,} |")
    exc = langs.get("excluded", {})
    if exc:
        parts = [f"{b['files']:,} {k}" for k, b in exc.items()]
        out += ["", f"Excluded from measurement: {', '.join(parts)} files (see the appendix)."]
    return out


SCOPE_ORDER = {"runtime": 0, "peer": 1, "workspace": 2, "optional": 3, "build": 4, "project": 5, "dev": 6}


def merge_deps(deps: list[dict]) -> list[dict]:
    """One row per (ecosystem, name) across manifests, runtime scopes first."""
    merged: dict = {}
    for d in deps:
        key = (d["ecosystem"], d["name"].lower())
        row = merged.setdefault(key, {"name": d["name"], "ecosystem": d["ecosystem"], "scopes": [], "specs": [],
                                      "manifests": []})
        for fld, val in (("scopes", d["scope"]), ("specs", d.get("spec")), ("manifests", d["manifest"])):
            if val and val not in row[fld]:
                row[fld].append(val)
    rank = lambda r: min(SCOPE_ORDER.get(s.split("[")[0], 3) for s in r["scopes"]) if r["scopes"] else 9  # noqa
    return sorted(merged.values(), key=lambda r: (rank(r), r["ecosystem"], r["name"].lower()))


def section_stack(meta: dict) -> list[str]:
    fw = meta.get("tooling", {}).get("frameworks", [])
    deps = merge_deps(meta.get("dependencies", []))
    runtime = [d for d in deps if any(s.split("[")[0] in ("runtime", "peer", "workspace") for s in d["scopes"])]
    out = ["### 1.4 Technology stack", ""]
    rows = []
    fw_names = set()
    for f in fw:
        label = str(f["value"])
        fw_names.add(label.split(" ")[0].lower())
        rows.append((label, f["source"]))
    if len(runtime) <= 30:                        # small enough to account for every runtime dependency
        for d in runtime:
            if d["name"].lower() not in fw_names:
                rows.append((f"{d['name']} {d['specs'][0] if d['specs'] else ''}".strip(), ", ".join(d["manifests"])))
    if rows:
        out += ["| Framework / library | Declared in | Used for |", "| --- | --- | --- |"]
        for label, src in rows[:40]:
            out.append(f"| {cell(label)} | {cell(src)} | "
                       f"{fill('what this codebase uses it for, from reading the code; write Unused if nothing imports it')} |")
        out.append("")
    by = Counter((d["ecosystem"], s) for d in deps for s in d["scopes"][:1])
    if by:
        out.append(f"{len(deps)} distinct declared dependencies: "
                   + ", ".join(f"{n} {eco} {scope}" for (eco, scope), n in by.most_common())
                   + " (full list in section 3.8).")
        out.append("")
    out.append(fill("2–4 sentences on the stack as a whole: primary language and runtime, key frameworks, storage, "
                    "UI technology, notable build or packaging tools. Name only technologies the code actually uses."))
    return out


def section_entry_points(meta: dict) -> list[str]:
    eps = meta.get("entry_points", [])
    out = ["### 1.5 Entry points", ""]
    if eps:
        out += ["| Kind | Name | Target | Declared in |", "| --- | --- | --- | --- |"]
        for e in eps[:40]:
            tgt = e.get("target")
            tgt = ", ".join(tgt) if isinstance(tgt, list) else tgt
            out.append(f"| {cell(e['kind'])} | {cell(e.get('name'))} | {code(tgt) if tgt else '—'} | {cell(e['source'])} |")
        out.append("")
    else:
        out += ["No entry points were detected automatically.", ""]
    out.append(fill("state how the codebase is started or consumed (command, import, host application, trigger) and "
                    "which entry point is primary; add any entry point the table missed"))
    return out


GEN_INVENTORY = ("<!-- gen:inventory -->", "<!-- /gen:inventory -->")
GEN_INDEX = ("<!-- gen:index -->", "<!-- /gen:index -->")
INDEX_PENDING = fill("filled from the reference entry's Summary line by sync_report.py")


def inventory_block(entries: list[dict], syms: dict) -> list[str]:
    """Counts and breakdowns for 1.6; regenerated by sync_report.py after corrections.

    entries: dicts with kind, language, file, is_test, abstract (inventory minus drops plus manual).
    """
    n = len(entries)
    tests = sum(1 for e in entries if e.get("is_test"))
    abstract = sum(1 for e in entries if e.get("abstract"))
    out = [GEN_INVENTORY[0], f"**Total functions & methods:** {n} <!-- total-callables -->", "",
           f"{n - tests} in application code, {tests} in tests; {abstract} are abstract or interface declarations. "
           f"{syms['summary']['types']} types (classes, structs, interfaces, enums, modules) are counted "
           "separately.", "", "| Kind | Count |", "| --- | ---: |"]
    for k, v in Counter(e["kind"] for e in entries).most_common():
        out.append(f"| {cell(k)} | {v} |")
    out += ["", "| Language | Count |", "| --- | ---: |"]
    for k, v in Counter(e["language"] for e in entries).most_common():
        out.append(f"| {cell(k)} | {v} |")
    per_mod = Counter(module_of(e["file"]) for e in entries)
    out += ["", "| Module | Functions & methods |", "| --- | ---: |"]
    for k, v in sorted(per_mod.items(), key=lambda kv: (-kv[1], kv[0])):
        out.append(f"| {code(k)} | {v} |")
    out.append(GEN_INVENTORY[1])
    return out


def section_inventory(syms: dict, index_path: str | None) -> list[str]:
    ss = syms["summary"]
    out = ["### 1.6 Function and method inventory", ""] + inventory_block(syms["symbols"], syms)
    conf = ss.get("by_confidence", {})
    out += ["", f"Counting rule: {syms['counting_rule']} Extraction confidence: "
            + ", ".join(f"{v} {k}" for k, v in conf.items())
            + " (exact = parsed with a real parser; heuristic = pattern-based, verified while reading)."]
    if syms.get("unsupported"):
        out.append(f"{len(syms['unsupported'])} source file(s) are in languages without an extractor and were "
                   "reviewed by hand (see the appendix).")
    out.append("")
    if index_path:
        out.append(f"The one-line description of every function and method is in the [function index]({index_path}).")
    else:
        out += ["#### Function index", ""] + index_body(syms["symbols"])
    return out


def index_body(entries: list[dict], summaries: dict | None = None) -> list[str]:
    """The function index, one table per file; regenerated by sync_report.py."""
    summaries = summaries or {}
    out = [GEN_INDEX[0]]
    by_file = defaultdict(list)
    for s in entries:
        by_file[s["file"]].append(s)
    for f in sorted(by_file, key=lambda p: (module_of(p), p)):
        items = sorted(by_file[f], key=lambda s: (s.get("cell") or 0, s.get("line") or 0))
        out += [f"**{code(f)}** ({len(items)})", "", "| Function | Kind | Lines | Summary |", "| --- | --- | --- | --- |"]
        for s in items:
            lines = f"{s['line']}–{s['end_line']}" if s.get("end_line") and s["end_line"] != s["line"] else \
                str(s.get("line") or "?")
            flags = " · test" if s.get("is_test") else (" · abstract" if s.get("abstract") else "")
            summary = summaries.get(s["id"], INDEX_PENDING).replace("|", "\\|")
            out.append(f"| <!-- idx:{s['id']} -->{code(s['qualname'])} | {cell(s['kind'])}{flags} | {lines} | "
                       f"{summary} |")
        out.append("")
    out.append(GEN_INDEX[1])
    return out


def section_overview() -> list[str]:
    return ["## 2. General overview", "",
            fill("300–600 words for someone new to the codebase: what it is and does, who uses it and how, the main "
                 "parts and how they cooperate, the most important design decisions, and what it depends on. Plain "
                 "language, no function-by-function detail, every claim traceable to code or docs."), "",
            "### Architecture at a glance", "",
            fill("a Mermaid flowchart (```mermaid, flowchart LR/TD) of the 5–12 major components, external systems, "
                 "and the data flow between them, followed by one sentence per node that is not self-explanatory")]


def dir_rows(syms: dict, langs: dict) -> list[tuple[str, int, int]]:
    """(module, files of any kind, code lines, callables): data-only folders are listed too."""
    files = langs.get("files") or []
    code_by_mod = Counter()
    files_by_mod = Counter()
    for f in files:
        files_by_mod[module_of(f["path"])] += 1
        if f["type"] in ("programming", "markup"):
            code_by_mod[module_of(f["path"])] += f["code"]
    sym_by_mod = Counter(module_of(s["file"]) for s in syms["symbols"])
    mods = set(files_by_mod) | set(sym_by_mod)
    return sorted(((m, files_by_mod[m], code_by_mod[m], sym_by_mod[m]) for m in mods),
                  key=lambda r: (-r[2], -r[1], r[0]))


def fncount(n: int, module: str) -> str:
    """A callable count sync_report.py can recompute after corrections (anchor renders invisibly)."""
    return f"{n}<!-- fncount:{module.replace(' ', '%20')} -->"


def section_detailed(meta: dict, langs: dict, syms: dict) -> list[str]:
    out = ["## 3. Detailed overview", "", "### 3.1 Directory structure", "",
           "| Module | Files | Code lines | Functions | Role |", "| --- | ---: | ---: | ---: | --- |"]
    rows = dir_rows(syms, langs)
    for m, nf, nc, ns in rows[:60]:
        out.append(f"| {code(m)} | {nf} | {nc:,} | {fncount(ns, m)} | {fill('role of this directory in one phrase')} |")
    if len(rows) > 60:
        out.append(f"| … {len(rows) - 60} smaller modules | | | | |")
    out += ["", "### 3.2 Architecture and design", "",
            fill("architectural style and layering, the main abstractions and how responsibilities are divided, "
                 "patterns in use (with file references), and the reasoning visible in code or docs"), "",
            "### 3.3 Execution flow", "",
            fill("walk the primary flow from entry point to result (startup, configuration, main loop or request "
                 "handling, shutdown), naming the functions involved; include a Mermaid sequenceDiagram for the most "
                 "important flow and describe secondary flows in prose"), "",
            "### 3.4 Components and modules", ""]
    types_by_mod = defaultdict(list)
    for t in syms.get("types", []):
        types_by_mod[module_of(t["file"])].append(t)
    for m, nf, nc, ns in rows[:40]:
        tnames = ", ".join(code(t["name"]) for t in types_by_mod.get(m, [])[:8])
        out += [f"#### {code(m)}", "",
                f"{nf} files · {nc:,} code lines · {fncount(ns, m)} functions & methods"
                + (f" · types: {tnames}" if tnames else ""),
                "", fill("responsibility, key files, public API (what other modules call), what it depends on, "
                         "state it owns, and notable implementation details"), ""]
    if len(rows) > 40:
        out += [fill(f"one paragraph covering the remaining {len(rows) - 40} smaller modules"), ""]
    types = syms.get("types", [])
    out += ["### 3.5 Data model and state", ""]
    if types:
        out.append(f"{len(types)} types were inventoried ({', '.join(f'{v} {k}' for k, v in Counter(t['kind'] for t in types).most_common())}).")
        out.append("")
    out += [fill("the core data structures, schemas, and persistent state: what each important type represents, "
                 "how data moves between them, where it is stored (files, databases, caches, memory), and its "
                 "lifecycle"), "",
            "### 3.6 External interfaces", "",
            fill("every way the outside world talks to the codebase: CLI commands and flags, HTTP/RPC/MCP/IPC "
                 "endpoints, events, public library API, configuration files, environment variables (names only), "
                 "file formats read or written. Use tables where there are many"), "",
            "### 3.7 Configuration, build, and run", ""]
    for sc in meta.get("scripts", [])[:4]:
        out.append(f"Scripts in {code(sc['manifest'])}:")
        out.append("")
        out += ["| Script | Command |", "| --- | --- |"]
        for k, v in list(sc["scripts"].items())[:25]:
            out.append(f"| {code(k)} | {code(v)} |")
        out.append("")
    out += [fill("how to install, configure, build, run, and package it, with exact commands taken from the repo; "
                 "required tools and versions; configuration options and their defaults"), "",
            "### 3.8 Dependencies", ""]
    deps = merge_deps(meta.get("dependencies", []))
    if deps:
        out += ["| Dependency | Version spec | Scope | Ecosystem | Declared in |", "| --- | --- | --- | --- | --- |"]
        for d in deps[:120]:
            out.append(f"| {code(d['name'])} | {cell(' / '.join(d['specs']) or None)} | {cell(', '.join(d['scopes']))} "
                       f"| {cell(d['ecosystem'])} | {cell(', '.join(d['manifests']))} |")
        if len(deps) > 120:
            out.append(f"| … {len(deps) - 120} more | | | | |")
        out.append("")
    else:
        out += ["No dependency manifests were found.", ""]
    out += [fill("which dependencies are load-bearing and why, anything pinned, vendored, or unusual"), "",
            "### 3.9 Testing", ""]
    ss = syms["summary"]
    test_files = sum(1 for f in syms.get("files", []) if f.get("is_test"))
    tf = meta.get("tooling", {}).get("test_frameworks", [])
    out += [f"{ss['test_callables']} test functions in {test_files} test files"
            + (f"; frameworks: {evidence_list(tf)}" if tf else "; no test framework declared") + ".", "",
            fill("what is tested and what is not, how to run the tests, test types (unit, integration, e2e), "
                 "fixtures, and CI coverage"), "",
            "### 3.10 Cross-cutting concerns", "",
            fill("error handling strategy, logging and diagnostics, concurrency and async model, performance "
                 "considerations, security model (authentication, input validation, secrets handling), "
                 "internationalization, accessibility — only those that apply"), "",
            "### 3.11 Observations and risks", "",
            "Assessment, not fact: each point cites file:line evidence and is labeled with a severity.", ""]
    hints = []
    s = meta["summary"]
    if s.get("version_conflict"):
        hints.append(f"version sources disagree ({', '.join(s['version_conflict'])})")
    if s.get("unreleased_commits_since_tag"):
        hints.append(f"{s['unreleased_commits_since_tag']} commits since the latest tag")
    if langs.get("markers"):
        hints.append("code markers: " + ", ".join(f"{k} {v}" for k, v in langs["markers"].items()))
    if not tf:
        hints.append("no declared test framework")
    for a in meta.get("artifacts", []):
        if a.get("possibly_stale"):
            hints.append(f"packaged artifact {code(a['path'])} may be stale: {a['possibly_stale']}")
    # Dead-code candidates: not public, never called, and the name appears nowhere else in the
    # same language (so it isn't passed as a callback or registered by reference either).
    uncalled = [x for x in syms["symbols"] if not x["called_by"] and x.get("references") == 0 and
                not x["is_test"] and x["visibility"] != "public" and
                x["kind"] not in ("constructor", "destructor", "operator", "script", "main block", "iife")]
    if uncalled:
        hints.append(f"{len(uncalled)} non-public callables whose name appears nowhere else (dead-code candidates; "
                     "dynamic dispatch and string lookups are invisible to the scan): "
                     + ", ".join(code(x["qualname"]) for x in uncalled[:12]))
    if hints:
        out += ["Starting points found by the scripts (verify each):", ""] + [f"- {h}" for h in hints] + [""]
    out.append(fill("bugs, fragile code, dead code, security concerns, performance hazards, missing tests, "
                    "documentation drift, and version inconsistencies you verified while reading — or state that "
                    "none were found"))
    return out


def reference_entry(s: dict) -> list[str]:
    small = (s["code_lines"] <= COMPACT_MAX_CODE_LINES) if s.get("code_lines") is not None else \
        ((s.get("lines") or 99) <= COMPACT_MAX_LINES)
    compact = s["abstract"] or small
    marker = f"<!-- sym:{s['id']}{' compact' if compact else ''} -->"
    loc = f"lines {s['line']}–{s['end_line']}" if s.get("end_line") and s["end_line"] != s["line"] else f"line {s['line']}"
    if s.get("code_lines") is not None and s.get("end_line") and s["end_line"] != s["line"]:
        loc += f" ({s['code_lines']} code)"
    if s.get("cell"):
        loc = f"cell {s['cell']}, {loc}"
    tags = [s["kind"]] + (["abstract"] if s["abstract"] else []) + (["test"] if s["is_test"] else []) + \
        ([s["visibility"]] if s["visibility"] not in ("unknown",) else [])
    head = [f"#### {code(s['qualname'])} {marker}", "",
            f"{' · '.join(tags)} · {loc}" + (" · heuristic extraction" if s["confidence"] != "exact" else "")]
    sig = s.get("signature") or ""
    body = head + [""]
    if sig:
        body += [fence_block(sig, s["language"]), ""]
    facts = []
    if s.get("doc"):
        facts.append(f"Doc comment: “{cell(s['doc'])}”")
    if s.get("decorators"):
        facts.append("Decorators/attributes: " + ", ".join(code(d) for d in s["decorators"][:6]))
    if s.get("calls"):
        facts.append("Calls: " + ", ".join(code(c.split("::", 1)[-1]) for c in s["calls"][:12]))
    if s.get("called_by"):
        facts.append("Called by: " + ", ".join(code(c.split("::", 1)[-1]) for c in s["called_by"][:12]))
    if facts:
        body += [" · ".join(facts), ""]
    body += ["**Summary:** " + fill("one line, verb first, ≤ 15 words: what calling it accomplishes, "
                                    "not the name restated"), ""]
    if compact:
        body.append(fill("one or two sentences: what it does or, for a declaration, the contract implementers fulfil"))
    else:
        body.append(fill("what it does and how (the steps in order), each parameter's meaning, the return value, "
                         "side effects (I/O, state, network, globals), errors raised or handled, and notable edge "
                         "cases or constraints. Based on reading the body, not the name"))
    body.append("")
    return body


def reference_body(symbols: list[dict], part_of: dict | None = None) -> list[str]:
    """File groups with their entries. part_of: file -> (part, parts) when a file spans pages."""
    out = []
    by_file = defaultdict(list)
    for s in symbols:
        by_file[s["file"]].append(s)
    for f in sorted(by_file, key=lambda p: (module_of(p), p)):
        items = by_file[f]
        k, n = (part_of or {}).get(f, (1, 1))
        title = f"### {code(f)}" + (f" (part {k} of {n})" if n > 1 else "")
        out += [title, "", f"{len(items)} functions & methods · {items[0]['language']}", ""]
        if k == 1:
            out += [fill("the file's role in one sentence"), ""]
        for s in items:
            out += reference_entry(s)
    return out


def appendix(meta: dict, langs: dict, syms: dict, parts_note: str) -> list[str]:
    g = meta.get("git", {})
    out = ["## Appendix A. Methodology and limits", "",
           f"- Generated by {TOOL_NAME} on {now_iso()}; file listing via {langs['file_listing']} "
           f"({'tracked plus untracked, non-ignored files' if langs['file_listing'] == 'git' else 'directory walk with default excludes'}).",
           f"- Snapshot: {code(g['head']['short']) if g.get('head') else 'not a git repository'}"
           f"{' (working tree has uncommitted changes)' if meta.get('dates', {}).get('uncommitted_changes') else ''}.",
           f"- Functions and methods: {syms['counting_rule']}",
           "- Language percentages use non-blank, non-comment lines (and bytes, GitHub's basis) over programming "
           "and markup files.",
           "- Calls / Called by are heuristic: call sites matched by name and receiver (self/this, the object's "
           "class or module name, or a unique free function) to callables in the same language."]
    exc = langs.get("excluded", {})
    for k, b in exc.items():
        out.append(f"- Excluded as {k}: {b['files']:,} files, e.g. {cell('; '.join(b['examples'][:4]))}")
    if g.get("shallow"):
        out.append("- ⚠ Shallow clone: commit counts, first-commit date, and contributors are incomplete.")
    if syms.get("unsupported"):
        out.append("- Files without a symbol extractor (their functions were identified by reading):")
        for u in syms["unsupported"][:40]:
            out.append(f"  - {code(u['path'])} ({u['language']}, {u.get('lines') or '?'} lines)")
    if parts_note:
        out.append(f"- {parts_note}")
    out += ["", "## Appendix B. Extractor corrections", "",
            "Heuristic extraction can report a declaration that is not a real callable, or miss one. Record every "
            "correction here so the counts stay auditable:", "",
            "- False positive: delete its reference entry and add a line `<!-- drop:ID reason -->` below.",
            "- Missed callable: add a reference entry headed `#### Name <!-- sym:manual:path::Name -->` in its "
            "file's group (add a `### path` group if the file has none) with the usual kind line, Summary, and "
            "description, and list it below.",
            "- Then run sync_report.py: it rebuilds the index rows and every count from the entries.", "",
            fill("list corrections, or write: No corrections were needed."), ""]
    return out


# ── Driver ───────────────────────────────────────────────────────────────────

def build(work: Path, output: Path, split: str, split_threshold: int, inline_limit: int, parts_dir: str) -> dict:
    meta = load_json(work / "metadata.json")
    langs = load_json(work / "languages.json")
    syms = load_json(work / "symbols.json")
    n = syms["summary"]["callables"]
    do_split = split == "always" or (split == "auto" and n > split_threshold)
    separate_index = do_split and n > inline_limit
    parts = output.parent / parts_dir
    written = []
    name = meta["summary"].get("readme_title") or meta["summary"]["name"]["value"]
    head = meta.get("git", {}).get("head")
    tot = langs["totals"]["language_bar"]
    lines = [f"# {name} — Codebase Summary", "",
             f"<!-- {TOOL_NAME}: parts={parts_dir if do_split else ''} symbols={n} -->", "",
             f"> Generated {now_iso()[:10]} by {TOOL_NAME} from {code(meta['root'])}"
             + (f" at {code(head['short'])}" if head else "")
             + f" · {tot['files']:,} source files · {tot['code']:,} lines of code · {fncount(n, '*')} functions & "
             "methods", "",
             "**Contents:** [1. Specifications](#1-specifications) · [2. General overview](#2-general-overview) · "
             "[3. Detailed overview](#3-detailed-overview) · [4. Function and method reference]"
             "(#4-function-and-method-reference) · [Appendix](#appendix-a-methodology-and-limits)", "",
             "## 1. Specifications", ""]
    lines += section_identity(meta, langs, syms) + [""]
    lines += ["### 1.2 Purpose", "",
              fill("2–4 sentences: the codebase's general purpose and the task it performs — what problem it solves, "
                   "for whom, and in what form (CLI, library, service, app, plugin, skill). Evidence first: README, "
                   "manifests, entry points, then code"), ""]
    lines += section_languages(langs) + [""]
    lines += section_stack(meta) + [""]
    lines += section_entry_points(meta) + [""]
    index_rel = f"{parts_dir}/function-index.md" if separate_index else None
    lines += section_inventory(syms, index_rel) + [""]
    lines += section_overview() + [""]
    lines += section_detailed(meta, langs, syms) + [""]
    lines += ["## 4. Function and method reference", ""]
    parts_note = ""
    if do_split:
        page_of = reference_pages(syms["symbols"])
        by_page = defaultdict(list)
        for s in syms["symbols"]:
            by_page[page_of[s["id"]]].append(s)
        # Files that span several pages (very large files) are labelled "part k of n".
        file_pages = defaultdict(list)
        for pg in sorted(by_page):
            for f in sorted({s["file"] for s in by_page[pg]}):
                file_pages[f].append(pg)
        file_pages = {f: sorted(pgs, key=lambda p: int(p.rsplit("-", 1)[-1]) if "-part-" in p else 0)
                      for f, pgs in file_pages.items()}
        lines += ["Every function and method, grouped by module and file. Each module has its own page; large "
                  "modules get a page per file and very large files are split into parts:", "",
                  "| Module / file | Functions & methods | Reference |", "| --- | ---: | --- |"]
        for pg in sorted(by_page, key=lambda k: (module_of(by_page[k][0]["file"]), by_page[k][0]["file"],
                                                 by_page[k][0]["line"])):
            items = by_page[pg]
            files = sorted({s["file"] for s in items})
            part_of = {f: (file_pages[f].index(pg) + 1, len(file_pages[f])) for f in files}
            single = len(files) == 1 and (pg == slug(files[0]) or "-part-" in pg)
            label = files[0] if single else module_of(files[0])
            if single and part_of[files[0]][1] > 1:
                label += f" (part {part_of[files[0]][0]} of {part_of[files[0]][1]})"
            page = f"{parts_dir}/reference/{pg}.md"
            lines.append(f"| {code(label)} | {len(items)} | [{page}]({page}) |")
            body = [f"# {name} — Reference: {code(label)}", "",
                    f"[← Back to the summary](../../{output.name}) · {len(items)} functions & methods", ""]
            body += reference_body(items, part_of)
            p = parts / "reference" / f"{pg}.md"
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("\n".join(body).rstrip() + "\n", encoding="utf-8")
            written.append(str(p))
        lines.append("")
        parts_note = f"The reference is split into {len(by_page)} pages under {code(parts_dir + '/reference/')}."
        if separate_index:
            idx = [f"# {name} — Function index", "", f"[← Back to the summary](../{output.name}) · "
                   f"{n} functions & methods, one line each, grouped by file.", ""] + index_body(syms["symbols"])
            p = parts / "function-index.md"
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("\n".join(idx).rstrip() + "\n", encoding="utf-8")
            written.append(str(p))
    else:
        lines += ["Every function and method, grouped by file in module order.", ""] + reference_body(syms["symbols"])
    lines += appendix(meta, langs, syms, parts_note)
    output.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(lines)
    text = re.sub(r"\n{3,}", "\n\n", text).rstrip() + "\n"
    output.write_text(text, encoding="utf-8")
    written.insert(0, str(output))
    fills = sum(Path(w).read_text(encoding="utf-8").count("[[FILL:") for w in written)
    return {"files": written, "split": do_split, "separate_index": separate_index, "fill_slots": fills,
            "callables": n}


def main(argv: list[str] | None = None) -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("workdir", type=Path, help="directory holding metadata.json, languages.json, symbols.json")
    ap.add_argument("-o", "--output", type=Path, required=True, help="report path, e.g. CODEBASE_SUMMARY.md")
    ap.add_argument("--split", choices=("auto", "always", "never"), default="auto",
                    help="put the detailed reference in per-module pages (auto: above --split-threshold)")
    ap.add_argument("--split-threshold", type=int, default=250, metavar="N")
    ap.add_argument("--inline-index-limit", type=int, default=400, metavar="N",
                    help="when split, move the function index to its own page above N callables")
    ap.add_argument("--parts-dir", default="codebase-summary", help="folder (next to the report) for split pages")
    args = ap.parse_args(argv)
    for name in ("metadata.json", "languages.json", "symbols.json"):
        if not (args.workdir / name).is_file():
            print(f"error: {args.workdir / name} not found — run analyze.py first", file=sys.stderr)
            return 2
    res = build(args.workdir, args.output, args.split, args.split_threshold, args.inline_index_limit, args.parts_dir)
    print(f"wrote {len(res['files'])} file(s); {res['callables']} callables; {res['fill_slots']} [[FILL]] slots to "
          f"complete{' (split into module pages)' if res['split'] else ''}")
    for f in res["files"]:
        print(f"  {f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
