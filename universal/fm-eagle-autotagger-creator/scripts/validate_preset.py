#!/usr/bin/env python3
"""
Validate and lint an Eagle AI Autotagger preset (JSON).

Two layers of checks:
  ERROR    — the plugin would reject the import, fail to save it in the editor,
             or produce broken output (duplicate JSON keys, bad enums, commas in tags…).
  WARNING  — the preset imports fine but will tag worse than it should
             (missing labels/cardinality, synonym pairs, universal tags, merged descriptions…).
  INFO     — facts worth knowing (defaults the plugin will apply, cost notes).

Usage:
  python validate_preset.py preset.json                # report
  python validate_preset.py preset.json --strict       # warnings also fail (exit 1)
  python validate_preset.py preset.json --json         # machine-readable report
  python validate_preset.py copied.json --normalize clean.json   # strip ids/timestamps, trim, dedupe
  type preset.json | python validate_preset.py -       # read stdin

Accepts a single preset, a list of presets, or a backup shaped like {"presets": [...]}.
Exit codes: 0 = clean (or warnings without --strict), 1 = problems, 2 = unreadable input.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from _preset_common import (MAX_DEPTH, MAX_JSON_BYTES, MAX_RULES, POSITIONS, RULE_TYPES,
                            SCHEMA_VERSION, TAGS_TYPES, VOLATILE_PRESET_KEYS, VOLATILE_RULE_KEYS,
                            dump_json, final_tag, iter_presets, json_depth, load_json, snake_key)

# ── Heuristics ───────────────────────────────────────────────────────────────
# A Specific rule should say how many tags to return, because the plugin always
# introduces Specific lists as "Should be only one of these tags list: …".
CARDINALITY_RE = re.compile(
    r"exactly (one|\d)|only one|a single|return one|one tag|at most|up to \w+|"
    r"\b\d+\s*(?:–|-|to)\s*\d+\b|every (?:tag|term|value|one|classification|\w+) that applies|"
    r"all that apply|each .{0,40} (?:shown|present|applies)|return every|any number",
    re.IGNORECASE)

# Words allowed to stay lowercase inside a Title Case tag.
MINOR_WORDS = {"a", "an", "and", "as", "at", "by", "for", "in", "of", "on", "or", "per",
               "the", "to", "vs", "via", "with", "de", "la", "le", "du", "von", "van"}

# Tags that almost always end up on every item (useless as filters) unless the
# image is about them. Matched case-insensitively against unprefixed Example lists.
UNIVERSAL_TAGS = {"button", "icon", "text", "divider", "separator", "divider/separator",
                  "header", "heading", "image", "scrollbar", "link", "label", "control",
                  "element", "design", "ui", "interface", "photo", "picture", "graphic",
                  "clean", "modern", "simple", "nice", "good", "beautiful", "professional"}

# Common synonym groups that models treat as interchangeable (heuristic, extend as needed).
SYNONYM_GROUPS = [
    {"switch", "toggle"}, {"modal", "dialog"}, {"chip", "pill"}, {"toast", "snackbar"},
    {"dropdown", "dropdown menu"}, {"minimal", "minimalist", "minimalistic"},
    {"black and white", "b&w", "monochrome photo"}, {"gray", "grey"}, {"colour", "color"},
    {"sans serif", "sans-serif"}, {"hand-drawn", "hand drawn", "handdrawn"},
    {"3d", "three-dimensional"}, {"ai", "artificial intelligence"}, {"e-commerce", "ecommerce"},
]

WORDS_LONG_INSTRUCTION = 180   # beyond this, instructions start to dilute each other
WORDS_LONG_GLOBAL = 450
RULES_SOFT_MAX = 22            # quality/cost soft ceiling for cloud models
RULES_LOCAL_MAX = 6            # local providers run one request per rule
EXAMPLE_LIST_SOFT_MAX = 160
SPECIFIC_LIST_SOFT_MAX = 60


class Report:
    """Collects findings for one preset."""

    def __init__(self, label: str) -> None:
        self.label = label
        self.items: list[tuple[str, str, str]] = []  # (level, where, message)

    def add(self, level: str, where: str, msg: str) -> None:
        self.items.append((level, where, msg))

    def count(self, level: str) -> int:
        return sum(1 for lv, _, _ in self.items if lv == level)


def norm_key(tag: str) -> str:
    """Loose key for near-duplicate detection: case, spaces, hyphens, plural 's'."""
    k = re.sub(r"[^0-9a-z]+", "", tag.lower())
    return k[:-1] if len(k) > 3 and k.endswith("s") and not k.endswith("ss") else k


def is_title_case(tag: str) -> bool:
    """Lenient Title Case check that tolerates acronyms and brand casing (iOS, macOS)."""
    for i, word in enumerate(re.split(r"[\s/]+", tag)):
        core = re.sub(r"^[^\w]+|[^\w]+$", "", word)
        if not core or core[0].isdigit():
            continue
        if core[0].isupper():
            continue
        if i > 0 and core.lower() in MINOR_WORDS:
            continue
        if any(c.isupper() for c in core[1:]):   # brand casing like iOS, macOS, eBay
            continue
        # Hyphenated compounds: every part should start uppercase ("Sans-Serif")
        return False
    return True


# ── Checks ───────────────────────────────────────────────────────────────────
def check_preset(p: object, raw_bytes: int | None, rep: Report) -> None:
    if not isinstance(p, dict):
        rep.add("ERROR", "root", "Preset must be a JSON object.")
        return

    # Import limits
    if raw_bytes is not None and raw_bytes > MAX_JSON_BYTES:
        rep.add("ERROR", "root", f"JSON is {raw_bytes:,} bytes; the plugin rejects more than {MAX_JSON_BYTES:,}.")
    if json_depth(p) > MAX_DEPTH:
        rep.add("ERROR", "root", f"JSON nesting deeper than {MAX_DEPTH}.")

    version = p.get("version", 1)
    if not isinstance(version, int):
        rep.add("ERROR", "version", "version must be an integer.")
    elif version > SCHEMA_VERSION:
        rep.add("ERROR", "version", f"version {version} is newer than the plugin supports ({SCHEMA_VERSION}).")
    elif version < SCHEMA_VERSION:
        rep.add("INFO", "version", f"version {version} will be migrated on import; emit {SCHEMA_VERSION} for new presets.")

    name = p.get("name")
    if not isinstance(name, str) or not name.strip():
        rep.add("WARNING", "name", "Missing preset name; the plugin will call it “Imported Preset”.")

    gi = p.get("globalInstructions")
    if gi is not None and not isinstance(gi, str):
        rep.add("ERROR", "globalInstructions", "globalInstructions must be a string.")
    elif not gi or not gi.strip():
        rep.add("WARNING", "globalInstructions", "Empty Global Instructions: the model gets no role, purpose or shared rules.")
    else:
        words = len(gi.split())
        if words > WORDS_LONG_GLOBAL:
            rep.add("WARNING", "globalInstructions", f"{words} words; long global text dilutes rule instructions.")
        if "<DESCRIPTION>" in gi:
            rep.add("INFO", "globalInstructions", "<DESCRIPTION> feeds the item's existing description back in; re-runs will see earlier AI output.")
        if "<NAME>" in gi:
            rep.add("INFO", "globalInstructions", "<NAME> is replaced with the item's file name (in quotes).")

    skip = p.get("skipRule")
    if skip is None:
        rep.add("INFO", "skipRule", f"No skipRule; the plugin adds “Processed with AI Autotagger: {name or 'Imported Preset'}”.")
    elif not (isinstance(skip, dict) and isinstance(skip.get("tag"), str) and isinstance(skip.get("shouldAddOnSkip"), bool)):
        rep.add("ERROR", "skipRule", "skipRule must be {\"tag\": string, \"shouldAddOnSkip\": boolean}.")

    rules = p.get("rules", [])
    if not isinstance(rules, list):
        rep.add("ERROR", "rules", "rules must be an array.")
        return
    if not rules:
        rep.add("ERROR", "rules", "Preset has no rules.")
        return
    if len(rules) > MAX_RULES:
        rep.add("ERROR", "rules", f"{len(rules)} rules; the plugin imports at most {MAX_RULES}.")
    elif len(rules) > RULES_SOFT_MAX:
        rep.add("WARNING", "rules", f"{len(rules)} rules; above ~{RULES_SOFT_MAX}, output quality and cost suffer.")
    if len(rules) > RULES_LOCAL_MAX:
        rep.add("INFO", "rules", f"Local providers (Ollama, LM Studio) send one request per rule WITHOUT Global Instructions ({len(rules)} requests per item).")

    check_rules(rules, rep)


def check_rules(rules: list, rep: Report) -> None:
    keys: dict[str, str] = {}
    names = Counter()
    final_tags: dict[str, str] = {}
    raw_unprefixed: dict[str, str] = {}
    desc_seen = 0
    name_rules = 0

    for idx, r in enumerate(rules, 1):
        where = f"rule {idx}"
        if not isinstance(r, dict):
            rep.add("ERROR", where, "Rule must be an object.")
            continue
        rtype, rname, instr = r.get("type"), r.get("name"), r.get("instruction")
        where = f"rule {idx} “{rname}”" if isinstance(rname, str) else where

        if rtype not in RULE_TYPES:
            rep.add("ERROR", where, f"type must be one of {sorted(RULE_TYPES)} (got {rtype!r}).")
            continue
        if not isinstance(rname, str) or not rname.strip():
            rep.add("ERROR", where, "Rule name is required.")
            continue
        names[rname] += 1

        # JSON key collisions break structured output (duplicate keys).
        key = snake_key(rname)
        if not key:
            rep.add("ERROR", where, "Rule name has no letters or digits; its JSON key would be empty.")
        elif key in keys and keys[key] != rname:
            rep.add("ERROR", where, f"JSON key “{key}” collides with rule “{keys[key]}”. Rename one.")
        keys.setdefault(key, rname)
        if len(rname.split()) > 3:
            rep.add("WARNING", where, "Rule names work best as one or two words (they become JSON keys and headers).")

        if not isinstance(instr, str) or not instr.strip():
            rep.add("ERROR", where, "Instruction is empty.")
            instr = ""
        else:
            if not instr.lstrip().lower().startswith(rname.lower() + ":"):
                rep.add("WARNING", where, f"Instruction should start with “{rname}: ” (rule names are not in the prompt text; the label maps the instruction to its JSON key).")
            words = len(instr.split())
            if words > WORDS_LONG_INSTRUCTION:
                rep.add("WARNING", where, f"Instruction is {words} words; aim for one paragraph (40–140 words).")
            elif words < 8:
                rep.add("WARNING", where, "Instruction is very short; say what to look for, how many values, and when to return nothing.")

        extra = set(r) - {"type", "name", "instruction", "id", "dependsOnRuleIds", "includeNameAsTitle",
                          "replaceExisting", "tagsType", "tagsList", "tagModifier", "tagPrefix"}
        if extra:
            rep.add("INFO", where, f"Unknown fields are dropped on import: {sorted(extra)}.")

        if rtype == "description":
            desc_seen += 1
            check_description(r, where, desc_seen, rep)
        elif rtype == "name":
            name_rules += 1
            if name_rules > 1:
                rep.add("WARNING", where, "More than one Name rule; each overwrites the previous rename.")
        else:
            check_tags(r, where, instr, rep, final_tags, raw_unprefixed)

    for n, c in names.items():
        if c > 1:
            rep.add("ERROR", f"rule “{n}”", f"Rule name used {c} times; names must be unique.")


def check_description(r: dict, where: str, position: int, rep: Report) -> None:
    for fld in ("includeNameAsTitle", "replaceExisting"):
        if fld in r and not isinstance(r[fld], bool):
            rep.add("ERROR", where, f"{fld} must be true or false.")
    title = r.get("includeNameAsTitle", True)
    replace = r.get("replaceExisting", False)
    if not title and position > 1:
        rep.add("WARNING", where, "Include Name as Title is off: this text will run straight on from the previous description section with no header.")
    if replace:
        msg = ("Replace Existing wipes the item's whole description"
               + (", including the output of the description rules before it in this run." if position > 1 else
                  " (fine for a one-off re-run, risky as a default)."))
        rep.add("WARNING", where, msg)


def check_tags(r: dict, where: str, instr: str, rep: Report,
               final_tags: dict[str, str], raw_unprefixed: dict[str, str]) -> None:
    ttype = r.get("tagsType", "example")
    if ttype not in TAGS_TYPES:
        rep.add("ERROR", where, f"tagsType must be one of {sorted(TAGS_TYPES)} (got {ttype!r}).")
        return
    tags = r.get("tagsList", [])
    if tags is None:
        tags = []
    if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
        rep.add("ERROR", where, "tagsList must be an array of strings.")
        return

    mod = r.get("tagModifier")
    if "tagPrefix" in r:
        rep.add("INFO", where, "Legacy tagPrefix is converted to a Prefix modifier with a space on import; use tagModifier.")
        mod = mod or {"position": "prefix", "text": r["tagPrefix"], "useSpace": True}
    if mod is not None:
        if not (isinstance(mod, dict) and mod.get("position") in POSITIONS
                and isinstance(mod.get("text"), str) and isinstance(mod.get("useSpace"), bool)):
            rep.add("ERROR", where, "tagModifier must be {\"position\": \"prefix\"|\"suffix\", \"text\": string, \"useSpace\": boolean}.")
            mod = None
        else:
            if mod["text"].strip() and not mod["useSpace"] and mod["position"] == "prefix":
                rep.add("WARNING", where, f"Include Space is off: tags render as “{final_tag('Tag', mod)}”.")
            if mod["position"] == "suffix" and mod["text"].strip():
                rep.add("INFO", where, f"Suffix modifiers add no colon: tags render as “{final_tag('Tag', mod)}”.")
            if not mod["text"].strip():
                mod = None

    # List presence rules (the editor refuses to save Example/Specific with an empty list)
    if ttype in ("example", "specific") and not tags:
        rep.add("ERROR", where, f"tagsType “{ttype}” needs a non-empty tagsList (use “none” for open-ended rules).")
    if ttype == "none" and tags:
        rep.add("WARNING", where, "tagsType “none” ignores tagsList in the editor; switch to “example” to use these tags.")
    if ttype == "specific":
        if not CARDINALITY_RE.search(instr):
            rep.add("WARNING", where, "Specific rule doesn't state how many tags to return (“exactly one”, “every tag that applies”, “1–3”). The plugin labels the list “Should be only one of these tags”, which is ambiguous.")
        if len(tags) > SPECIFIC_LIST_SOFT_MAX:
            rep.add("WARNING", where, f"{len(tags)} Specific values; long closed lists are hard to apply consistently. Split the facet or use Example.")
    if ttype == "example" and len(tags) > EXAMPLE_LIST_SOFT_MAX:
        rep.add("WARNING", where, f"{len(tags)} example tags; consider trimming to the ones that matter for filtering.")
    if ttype in ("example", "none") and "empty" not in instr.lower() and "nothing" not in instr.lower():
        rep.add("INFO", where, "Consider telling the model when to return an empty list (prevents guessed tags).")

    # Per-tag checks
    lowered = Counter(t.strip().lower() for t in tags)
    for t, c in lowered.items():
        if c > 1:
            rep.add("WARNING", where, f"Duplicate tag “{t}” ({c}×).")
    near = defaultdict(list)
    for t in tags:
        near[norm_key(t)].append(t)
    for variants in near.values():
        if len(set(v.lower() for v in variants)) > 1:
            rep.add("WARNING", where, f"Near-duplicate tags: {', '.join(sorted(set(variants)))}.")
    present = {t.strip().lower() for t in tags}
    for group in SYNONYM_GROUPS:
        hit = sorted(group & present)
        if len(hit) > 1:
            rep.add("WARNING", where, f"Synonyms in one list: {', '.join(hit)}. Keep one.")

    for t in dict.fromkeys(tags):   # unique, order kept
        ts = t.strip()
        if not ts:
            rep.add("ERROR", where, "Empty tag in tagsList.")
            continue
        if "," in ts:
            rep.add("ERROR", where, f"“{ts}” contains a comma; the editor's comma-separated field will split it.")
        if ts != t:
            rep.add("WARNING", where, f"“{t}” has leading/trailing spaces.")
        # "Chip/Pill", "Divider/Separator" = two concepts; brand names like "shadcn/ui" or "I/O" are fine
        parts = ts.split("/")
        if len(parts) > 1 and all(len(x.strip()) >= 3 and x.strip()[0].isupper() for x in parts):
            rep.add("WARNING", where, f"“{ts}” joins two terms with a slash; pick one term per tag.")
        if len(ts) > 48:
            rep.add("WARNING", where, f"“{ts}” is long for a tag ({len(ts)} chars).")
        if not is_title_case(ts):
            level = "WARNING" if ttype == "specific" else "INFO"
            rep.add(level, where, f"“{ts}” isn't Title Case; the plugin asks for Title Case, so Specific values should match it (brand casing excepted).")
        if not mod and ts.lower() in UNIVERSAL_TAGS:
            rep.add("WARNING", where, f"“{ts}” is likely to land on almost every item, which makes it useless as a filter.")

        # Cross-rule collisions on the final tag string
        ft = final_tag(ts, mod).lower()
        owner = r.get("name", "?")
        if ft in final_tags and final_tags[ft] != owner:
            rep.add("WARNING", where, f"Final tag “{final_tag(ts, mod)}” is also produced by rule “{final_tags[ft]}”.")
        final_tags.setdefault(ft, owner)
        if not mod:
            if ts.lower() in raw_unprefixed and raw_unprefixed[ts.lower()] != owner:
                rep.add("WARNING", where, f"Unprefixed “{ts}” also appears in rule “{raw_unprefixed[ts.lower()]}”.")
            raw_unprefixed.setdefault(ts.lower(), owner)


# ── Normalization ────────────────────────────────────────────────────────────
def normalize(p: dict) -> dict:
    """Paste-ready copy: drop ids/timestamps, trim strings, dedupe tags, set version and skipRule."""
    out = {k: v for k, v in p.items() if k not in VOLATILE_PRESET_KEYS}
    out["name"] = str(out.get("name") or "Imported Preset").strip()
    out["globalInstructions"] = str(out.get("globalInstructions") or "").strip()
    rules = []
    for r in out.get("rules", []):
        r = {k: v for k, v in r.items() if k not in VOLATILE_RULE_KEYS}
        if not r.get("dependsOnRuleIds"):
            r.pop("dependsOnRuleIds", None)
        for k in ("name", "instruction"):
            if isinstance(r.get(k), str):
                r[k] = r[k].strip()
        if r.get("type") == "tags":
            seen, clean = set(), []
            for t in r.get("tagsList") or []:
                ts = t.strip()
                if ts and ts.lower() not in seen:
                    seen.add(ts.lower())
                    clean.append(ts)
            r["tagsList"] = clean
            r.setdefault("tagsType", "example")
            if "tagPrefix" in r:
                r.setdefault("tagModifier", {"position": "prefix", "text": r["tagPrefix"], "useSpace": True})
                r.pop("tagPrefix")
        elif r.get("type") == "description":
            r.setdefault("includeNameAsTitle", True)
            r.setdefault("replaceExisting", False)
        rules.append(r)
    out["rules"] = rules
    out.setdefault("skipRule", {"tag": f"Processed with AI Autotagger: {out['name']}", "shouldAddOnSkip": True})
    out["version"] = SCHEMA_VERSION
    # Stable key order: name, globalInstructions, rules, skipRule, version
    order = ["name", "globalInstructions", "rules", "skipRule", "version"]
    return {k: out[k] for k in order if k in out} | {k: v for k, v in out.items() if k not in order}


# ── Output ───────────────────────────────────────────────────────────────────
def summary_lines(p: dict) -> list[str]:
    lines = []
    for i, r in enumerate(p.get("rules", []), 1):
        if not isinstance(r, dict):
            continue
        t = r.get("type", "?")
        extra = ""
        if t == "tags":
            mod = r.get("tagModifier") or {}
            extra = f"{r.get('tagsType', 'example'):<8} {len(r.get('tagsList') or []):>3} tags"
            if mod.get("text"):
                extra += f"  → {final_tag('X', mod)}"
        elif t == "description":
            extra = ("title " if r.get("includeNameAsTitle", True) else "no-title ") + \
                    ("REPLACE" if r.get("replaceExisting") else "append")
        lines.append(f"  {i:>2}. {snake_key(str(r.get('name', ''))):<24} {t:<11} {extra}")
    return lines


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate and lint an Eagle AI Autotagger preset.")
    ap.add_argument("path", help="preset JSON file, or '-' for stdin")
    ap.add_argument("--strict", action="store_true", help="treat warnings as failures")
    ap.add_argument("--json", action="store_true", help="print a JSON report")
    ap.add_argument("--quiet", action="store_true", help="hide INFO findings")
    ap.add_argument("--normalize", metavar="OUT", help="write a cleaned, paste-ready preset to OUT")
    args = ap.parse_args()

    try:
        data, raw = load_json(args.path)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Cannot read preset: {e}", file=sys.stderr)
        return 2

    raw_bytes = len(raw.encode("utf-8"))
    reports, presets = [], []
    for label, p in iter_presets(data):
        rep = Report(label)
        check_preset(p, raw_bytes, rep)
        reports.append(rep)
        presets.append(p)

    if args.normalize:
        cleaned = [normalize(p) for p in presets if isinstance(p, dict)]
        payload = cleaned[0] if len(cleaned) == 1 else cleaned
        Path(args.normalize).write_text(
            dump_json(payload) if isinstance(payload, dict) else json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8")

    if args.json:
        print(json.dumps([{"preset": r.label,
                           "errors": r.count("ERROR"), "warnings": r.count("WARNING"),
                           "findings": [{"level": lv, "where": w, "message": m} for lv, w, m in r.items]}
                          for r in reports], indent=2, ensure_ascii=False))
    else:
        for rep, p in zip(reports, presets):
            print(f"\n=== {rep.label} ===")
            if isinstance(p, dict):
                print("\n".join(summary_lines(p)))
            for level in ("ERROR", "WARNING", "INFO"):
                if args.quiet and level == "INFO":
                    continue
                found = [(w, m) for lv, w, m in rep.items if lv == level]
                if found:
                    print(f"\n{level}S ({len(found)})")
                    for w, m in found:
                        print(f"  - [{w}] {m}")
            status = "FAIL" if rep.count("ERROR") or (args.strict and rep.count("WARNING")) else "PASS"
            print(f"\nRESULT: {status}  ({rep.count('ERROR')} errors, {rep.count('WARNING')} warnings)")
        if args.normalize:
            print(f"\nNormalized preset written to {args.normalize}")

    failed = any(r.count("ERROR") or (args.strict and r.count("WARNING")) for r in reports)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
