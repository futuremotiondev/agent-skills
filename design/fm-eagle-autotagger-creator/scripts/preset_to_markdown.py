#!/usr/bin/env python3
"""
Convert an AI Autotagger preset (JSON) into a human-readable field sheet.

Use only when the user asks for a text or markdown version: JSON stays the source of truth.
Every field is laid out in the same order and wording as the plugin's editor, so values can
be copied into the UI one at a time.

Usage:
  python preset_to_markdown.py preset.json                   # markdown to stdout
  python preset_to_markdown.py preset.json -o preset.md      # markdown file
  python preset_to_markdown.py preset.json --format txt -o preset.txt
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from _preset_common import utf8_stdio, final_tag, iter_presets, load_json

TYPE_TITLE = {"description": "Description Rule", "tags": "Tags Rule", "name": "Name Rule"}
TAGS_TYPE_UI = {"example": "Example", "specific": "Specific", "none": "N/A"}


def checked(v: bool) -> str:
    return "Checked" if v else "Unchecked"


def rule_fields(r: dict) -> list[tuple[str, str]]:
    """(label, value) pairs in the editor's field order."""
    fields = [("Name", r.get("name", "")), ("Instruction", r.get("instruction", ""))]
    t = r.get("type")
    if t == "description":
        fields += [("Include Name as Title", checked(r.get("includeNameAsTitle", True))),
                   ("Replace Existing", checked(r.get("replaceExisting", False)))]
    elif t == "tags":
        tt = r.get("tagsType", "example")
        fields.append(("Tags Type", TAGS_TYPE_UI.get(tt, tt)))
        if tt != "none":
            label = "Specific Tags" if tt == "specific" else "Example Tags"
            fields.append((label, ", ".join(r.get("tagsList") or [])))
        mod = r.get("tagModifier") or {}
        text = (mod.get("text") or "").strip()
        fields += [("Modifier Position", (mod.get("position") or "prefix").capitalize()),
                   ("Modifier Text", text if text else "(leave empty)"),
                   ("Include Space", checked(mod.get("useSpace", True)))]
        if text and r.get("tagsList"):
            fields.append(("Tag preview", final_tag(r["tagsList"][0], mod)))
    return fields


def to_markdown(p: dict) -> str:
    out = [f"# {p.get('name', 'Preset')} — AI Autotagger Preset", ""]
    skip = p.get("skipRule") or {}
    out += ["## Preset", "", "```text",
            f"Preset Name: {p.get('name', '')}",
            "",
            f"Skip If Has Tag: {skip.get('tag', '(plugin default)')}",
            "",
            f"Add On Skip: {checked(skip.get('shouldAddOnSkip', True))}",
            "```", "",
            "## Global Instructions", "", "```text", (p.get("globalInstructions") or "").strip(), "```", ""]
    for i, r in enumerate(p.get("rules", []), 1):
        out += [f"## Rule {i} — {TYPE_TITLE.get(r.get('type'), 'Rule')}: `{r.get('name', '')}`", "", "```text"]
        blocks = [f"{label}:\n{value}" if label in ("Instruction", "Example Tags", "Specific Tags")
                  else f"{label}: {value}" for label, value in rule_fields(r)]
        out.append("\n\n---\n\n".join(blocks))
        out += ["```", ""]
    return "\n".join(out).rstrip() + "\n"


def to_text(p: dict) -> str:
    bar = "=" * 72
    skip = p.get("skipRule") or {}
    out = [bar, f"{p.get('name', 'Preset')} — AI Autotagger Preset", bar, "",
           f"Preset Name: {p.get('name', '')}",
           f"Skip If Has Tag: {skip.get('tag', '(plugin default)')}",
           f"Add On Skip: {checked(skip.get('shouldAddOnSkip', True))}", "",
           "GLOBAL INSTRUCTIONS", "-" * 19, (p.get("globalInstructions") or "").strip(), ""]
    for i, r in enumerate(p.get("rules", []), 1):
        title = f"RULE {i} — {TYPE_TITLE.get(r.get('type'), 'Rule').upper()}: {r.get('name', '')}"
        out += [bar, title, bar]
        for label, value in rule_fields(r):
            out.append(f"{label}:\n{value}\n" if "\n" in value or len(value) > 60 else f"{label}: {value}")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def main() -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description="Render an AI Autotagger preset as a markdown or text field sheet.")
    ap.add_argument("path", help="preset JSON file, or '-' for stdin")
    ap.add_argument("--format", choices=("md", "txt"), default="md")
    ap.add_argument("-o", "--out", help="output file (default: stdout)")
    args = ap.parse_args()

    try:
        data, _ = load_json(args.path)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Cannot read preset: {e}", file=sys.stderr)
        return 2

    render = to_markdown if args.format == "md" else to_text
    doc = "\n".join(render(p) for _, p in iter_presets(data))
    if args.out:
        Path(args.out).write_text(doc, encoding="utf-8")
        print(f"Wrote {args.out}")
    else:
        sys.stdout.write(doc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
