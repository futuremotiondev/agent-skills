#!/usr/bin/env python3
"""
Show exactly what the AI model receives for a preset — prompt text and JSON schema.

Reconstructs AI Autotagger v11's prompt builder so you can review a preset the way the
model reads it (numbered instructions, tag-list suffixes, appended "Important" lines).

Modes
  cloud  (default) OpenAI / Anthropic / Google / OpenRouter / Custom / CLI providers:
         ONE system prompt with Global Instructions + all rules, one structured-output call.
  video  Same as cloud, for gif/mov/mp4 items (frames instead of slices wording).
  local  Ollama / LM Studio: ONE request PER RULE, simplified prompt, NO Global Instructions.

Usage:
  python render_prompt.py preset.json
  python render_prompt.py preset.json --name "Eagle_y1SA6m4g6G" --schema
  python render_prompt.py preset.json --mode local --rule "Color Scheme"
  python render_prompt.py preset.json --stats          # size estimate only
"""

from __future__ import annotations

import argparse
import json
import sys

from _preset_common import utf8_stdio, iter_presets, load_json, snake_key

IMPORTANT_IMAGE = (
    "- If you're provided with multiple images, ALWAYS assume they are vertical slices of a single, "
    "long image. Analyze them as parts of a whole.\n"
    "- Your output should describe the entire image, considering all slices equally and sequentially.")
IMPORTANT_VIDEO = (
    "- The multiple images you're provided with are individual frames from the same video (typically "
    "spaced out at 1 second intervals). Give all frames equal weight.\n"
    "- Your output must describe the video as a whole, and your answers should refer to the video as a whole.\n"
    "- Answers should refer to the video, not the individual frames.")
TITLE_CASE = "- Tags should be title case."


def list_suffix(rule: dict) -> str:
    """The text the plugin appends after a tags rule's instruction."""
    label = "Should be only one of these tags" if rule.get("tagsType") == "specific" else "Example tags"
    tags = rule.get("tagsList")
    joined = ", ".join(tags) if tags is not None else "(none)"
    return f"{label} list: {joined}"


def cloud_prompt(p: dict, name: str, description: str, video: bool) -> str:
    head = (p.get("globalInstructions") or "").replace("<NAME>", f'"{name}"').replace("<DESCRIPTION>", f'"{description}"')
    lines = []
    for i, r in enumerate(p.get("rules", []), 1):
        line = f"{i}. {r.get('instruction', '')}"
        if r.get("type") == "tags":
            line += " " + list_suffix(r)
        lines.append(line)
    important = IMPORTANT_VIDEO if video else IMPORTANT_IMAGE
    return f"{head.strip()}\n\n## Output\n" + "\n".join(lines) + f"\n\n## Important\n{important}\n{TITLE_CASE}"


def local_prompt(rule: dict) -> str:
    """Simplified single-rule prompt used for Ollama / LM Studio (Global Instructions are NOT sent)."""
    name = rule.get("name", "")
    if rule.get("type") == "tags":
        shape = f'{{\n  "{name}": ["Tag 1", "Tag 2", "Tag 3"]\n}}'
        if rule.get("tagsList"):
            shape += "\n\n" + list_suffix(rule)
    else:
        shape = f'{{\n  "{name}": "Your text response here"\n}}'
    return f"## Instructions\n{rule.get('instruction', '')}\n\n## JSON Shape\n{shape}\n\n## Important\n{TITLE_CASE}"


def json_schema(p: dict) -> dict:
    """Structured-output schema the plugin sends (strict object, one key per rule)."""
    props = {}
    for r in p.get("rules", []):
        key = snake_key(r.get("name", ""))
        if r.get("type") == "tags":
            item = {"type": "string"}
            if r.get("tagsType") == "specific" and r.get("tagsList"):
                item["enum"] = list(dict.fromkeys(r["tagsList"]))
            props[key] = {"type": "array", "items": item}
        else:
            props[key] = {"type": "string"}
    return {"type": "object", "properties": props, "required": list(props), "additionalProperties": False}


def main() -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description="Render the exact prompt/schema AI Autotagger sends for a preset.")
    ap.add_argument("path", help="preset JSON file, or '-' for stdin")
    ap.add_argument("--mode", choices=("cloud", "video", "local"), default="cloud")
    ap.add_argument("--name", default="example_item", help="item file name substituted for <NAME>")
    ap.add_argument("--description", default="", help="item description substituted for <DESCRIPTION>")
    ap.add_argument("--rule", help="local mode: render only this rule")
    ap.add_argument("--schema", action="store_true", help="also print the JSON schema")
    ap.add_argument("--stats", action="store_true", help="print size estimates only")
    args = ap.parse_args()

    try:
        data, _ = load_json(args.path)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Cannot read preset: {e}", file=sys.stderr)
        return 2

    for label, p in iter_presets(data):
        if len(list(iter_presets(data))) > 1:
            print(f"\n######## {label} ########")
        if args.mode == "local":
            rules = [r for r in p.get("rules", []) if not args.rule or r.get("name") == args.rule]
            texts = [local_prompt(r) for r in rules]
            if args.stats:
                words = sum(len(t.split()) for t in texts)
                print(f"{label}: {len(texts)} requests per item, ~{words:,} prompt words total (plus images per request)")
                continue
            for r, t in zip(rules, texts):
                print(f"\n----- request: {r.get('name')} -----\n{t}")
        else:
            text = cloud_prompt(p, args.name, args.description, args.mode == "video")
            if args.stats:
                words = len(text.split())
                print(f"{label}: 1 request per item, ~{words:,} words (~{int(words * 1.4):,} tokens) of prompt text plus images")
                continue
            print(text)
        if args.schema and not args.stats:
            print("\n----- JSON schema -----")
            print(json.dumps(json_schema(p), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
