"""
Shared helpers for the fm-eagle-autotagger-creator scripts (stdlib only).

Mirrors behavior verified in the AI Autotagger plugin (v11.0.0, preset schema v5):
  - snake_key(): the plugin's rule-name → JSON-key normalizer.
  - final_tag(): how a tag modifier is applied when tags are written to Eagle.
  - iter_presets(): accepts a single preset, a list of presets, or {"presets": [...]}.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any, Iterator

# ── Plugin constants (AI Autotagger v11) ─────────────────────────────────────
SCHEMA_VERSION = 5            # newest preset version the plugin imports
MAX_JSON_BYTES = 1_048_576    # import rejects larger clipboard payloads
MAX_RULES = 100               # import rejects presets with more rules
MAX_DEPTH = 64                # import rejects deeper JSON structures
NAME_MAX_CHARS = 245          # Name-rule output is truncated to this length

RULE_TYPES = {"description", "name", "tags"}
TAGS_TYPES = {"example", "specific", "none"}
POSITIONS = {"prefix", "suffix"}

# Metadata the plugin adds on export/storage; never needed in a paste-ready preset.
VOLATILE_PRESET_KEYS = {"id", "createdAt", "updatedAt", "folderId"}
VOLATILE_RULE_KEYS = {"id"}


def snake_key(name: str) -> str:
    """Rule name → JSON schema key, identical to the plugin's normalizer."""
    s = re.sub(r"([a-z\d])([A-Z])", r"\1_\2", name)
    s = re.sub(r"([A-Z])([A-Z][a-z])", r"\1_\2", s)
    s = re.sub(r"[\W_]+", "_", s, flags=re.UNICODE)  # non letter/digit runs → "_"
    s = re.sub(r"_+", "_", s).lower()
    return s.strip("_")


def final_tag(tag: str, modifier: dict | None) -> str:
    """Return the tag string exactly as the plugin writes it to Eagle."""
    tag = tag.strip()
    if not modifier:
        return tag
    text = str(modifier.get("text", "")).strip()
    if not text:
        return tag
    space = " " if modifier.get("useSpace") else ""
    if modifier.get("position") == "prefix":
        colon = "" if text.endswith(":") else ":"
        return f"{text}{colon}{space}{tag}"
    return f"{tag}{space}{text}"


def json_depth(value: Any, depth: int = 0) -> int:
    """Nesting depth as the plugin measures it (objects and arrays)."""
    if not isinstance(value, (dict, list)):
        return depth
    children = value.values() if isinstance(value, dict) else value
    return max((json_depth(c, depth + 1) for c in children), default=depth + 1)


def load_json(path: str) -> tuple[Any, str]:
    """Load JSON from a path or '-' (stdin). Returns (data, raw_text)."""
    raw = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8-sig")
    return json.loads(raw), raw


def iter_presets(data: Any) -> Iterator[tuple[str, dict]]:
    """Yield (label, preset) for a preset, a list of presets, or a {presets: [...]} backup."""
    if isinstance(data, dict) and isinstance(data.get("presets"), list):
        data = data["presets"]
    if isinstance(data, list):
        for i, p in enumerate(data):
            label = p.get("name", f"#{i + 1}") if isinstance(p, dict) else f"#{i + 1}"
            yield str(label), p
    else:
        label = data.get("name", "preset") if isinstance(data, dict) else "preset"
        yield str(label), data


def dump_json(preset: dict) -> str:
    """Canonical paste-ready formatting: 2-space indent, UTF-8, trailing newline."""
    return json.dumps(preset, indent=2, ensure_ascii=False) + "\n"
