#!/usr/bin/env python3
"""
validate-output.py

Validates a JSON output from the i2i-clone-prompt-generator skill against the
output contract defined in references/output-contract.md. Returns exit code 0
on success and prints a clean summary; returns exit code 1 on failure and
prints specific error messages for each violation.

Usage:
    python validate-output.py path/to/output.json
    cat output.json | python validate-output.py -
    python validate-output.py --quiet path/to/output.json   # only exit code

The script uses only the Python standard library so it can run anywhere
Python 3.8+ is available, with no pip-install friction.

The checks mirror the eight groups in references/self-check-protocol.md so
error messages map cleanly to remediation steps. The script is intentionally
verbose by default — silent passes are worse than no validation at all —
but supports --quiet for CI use.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from typing import Any


# The thirteen model keys that every variant's per_model object must contain.
# Order matters only for display; the contract requires all keys present.
MODEL_KEYS = [
    "midjourney_v7",
    "flux_1",
    "flux_2",
    "nano_banana",
    "wan_2_6",
    "seedream_4",
    "kling_image",      # the only key allowed to be null without user request
    "grok_imagine",
    "qwen_image",
    "z_image",
    "ideogram_3",
    "imagen_4",
    "adobe_firefly",
]

# The eight named stochastic axes. The contract requires each of the 8
# stochastic variants to declare one of these (or compound, noted in
# shift_description).
STOCHASTIC_AXES = {
    "framing_nudge",
    "lighting_angle",
    "palette_shift",
    "fragment_density",
    "lens_change",
    "depth_of_field",
    "color_temperature",
    "negative_space",
}

# Negation words that Z-Image silently drops. The Z-Image variant must
# contain zero instances of these.
Z_IMAGE_NEGATIONS = re.compile(
    r"\b(no|not|without|avoid|free of|lacking|absent)\b",
    re.IGNORECASE,
)

# Description-mode phrasings that indicate the prompt is in caption mode
# rather than instruction mode. Their presence is a smell, not a hard fail.
DESCRIPTION_SMELLS = [
    "the image shows", "this is a photograph", "we can see",
    "in this scene", "the composition features", "you can see",
    "the photograph depicts", "this picture",
]


@dataclass
class Report:
    """Accumulates violations and warnings during validation."""
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def err(self, group: str, msg: str) -> None:
        """Record a hard contract violation."""
        self.errors.append(f"[{group}] {msg}")

    def warn(self, group: str, msg: str) -> None:
        """Record a soft warning that doesn't fail validation."""
        self.warnings.append(f"[{group}] {msg}")

    @property
    def passed(self) -> bool:
        return len(self.errors) == 0


def load_json(source: str) -> Any:
    """Load JSON from a file path or from stdin if source is '-'."""
    if source == "-":
        raw = sys.stdin.read()
    else:
        with open(source, "r", encoding="utf-8") as f:
            raw = f.read()
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        # Raise with a more user-friendly message; the top-level handler
        # will format the exit.
        raise ValueError(f"Input is not valid JSON: {e}") from e


def check_top_level_shape(data: Any, report: Report) -> None:
    """Group 1: top-level keys and types."""
    if not isinstance(data, dict):
        report.err("shape", "Output must be a JSON object at the top level.")
        return

    required = [
        "visual_dna", "universal_prompts",
        "clone_prompts", "stylistic_siblings", "stochastic_variants",
        "recreation_notes", "flagged_for_firefly",
    ]
    for k in required:
        if k not in data:
            report.err("shape", f"Missing required top-level field: '{k}'.")

    # If shape is fundamentally broken, downstream checks will spam noise;
    # bail early on the catastrophic failures.
    if any(k not in data for k in required):
        return

    if not isinstance(data["visual_dna"], dict):
        report.err("shape", "'visual_dna' must be an object.")
    if not isinstance(data["universal_prompts"], list):
        report.err("shape", "'universal_prompts' must be an array.")
    if not isinstance(data["recreation_notes"], list):
        report.err("shape", "'recreation_notes' must be an array.")
    if not isinstance(data["flagged_for_firefly"], bool):
        report.err("shape", "'flagged_for_firefly' must be a boolean.")

    for variant_set in ("clone_prompts", "stylistic_siblings", "stochastic_variants"):
        v = data[variant_set]
        if not isinstance(v, dict) or "variants" not in v or not isinstance(v["variants"], list):
            report.err("shape", f"'{variant_set}' must be an object with a 'variants' array.")


def check_counts(data: dict, report: Report) -> None:
    """Group 1 continued: variant counts."""
    # Universal prompts: 3 to 5.
    n_universal = len(data.get("universal_prompts", []))
    if n_universal < 3 or n_universal > 5:
        report.err(
            "counts",
            f"universal_prompts must have 3-5 entries; found {n_universal}.",
        )

    # Clone variants: exactly 5 (unless user overrode count — the validator
    # cannot detect that, so emit a warning rather than an error when off by 1).
    n_clones = len(data.get("clone_prompts", {}).get("variants", []))
    if n_clones != 5:
        if abs(n_clones - 5) == 1:
            report.warn("counts", f"clone_prompts.variants has {n_clones}; contract specifies 5.")
        else:
            report.err("counts", f"clone_prompts.variants must have exactly 5 entries; found {n_clones}.")

    # Sibling variants: exactly 6.
    n_siblings = len(data.get("stylistic_siblings", {}).get("variants", []))
    if n_siblings != 6:
        report.err("counts", f"stylistic_siblings.variants must have exactly 6 entries; found {n_siblings}.")

    # Stochastic variants: exactly 8.
    n_stochastic = len(data.get("stochastic_variants", {}).get("variants", []))
    if n_stochastic != 8:
        report.err("counts", f"stochastic_variants.variants must have exactly 8 entries; found {n_stochastic}.")


def check_variant_common(variant: dict, kind: str, idx: int, report: Report) -> None:
    """Check the fields common to all variant types."""
    if "index" not in variant or not isinstance(variant["index"], int):
        report.err(f"{kind}.{idx}", "Missing or non-integer 'index'.")
    if "natural_language" not in variant or not isinstance(variant["natural_language"], str):
        report.err(f"{kind}.{idx}", "Missing or non-string 'natural_language'.")
    if "rationale" not in variant or not isinstance(variant["rationale"], str):
        report.err(f"{kind}.{idx}", "Missing or non-string 'rationale'.")
    if "per_model" not in variant or not isinstance(variant["per_model"], dict):
        report.err(f"{kind}.{idx}", "Missing or non-object 'per_model'.")
        return

    per_model = variant["per_model"]
    for key in MODEL_KEYS:
        if key not in per_model:
            report.err(
                f"{kind}.{idx}.per_model",
                f"Missing required model key '{key}'. All 13 keys must be present (use null when not requested).",
            )

    # Check that non-null values are non-empty strings.
    for key, value in per_model.items():
        if value is None:
            continue
        if not isinstance(value, str):
            report.err(f"{kind}.{idx}.per_model", f"'{key}' must be a string or null; got {type(value).__name__}.")
        elif not value.strip():
            report.err(f"{kind}.{idx}.per_model", f"'{key}' is an empty string; use null instead.")


def check_per_model_idiom(variant: dict, kind: str, idx: int, report: Report) -> None:
    """Group 3: per-model idiom checks for non-null prompts."""
    per_model = variant.get("per_model", {})

    # Midjourney must contain --ar.
    mj = per_model.get("midjourney_v7")
    if isinstance(mj, str) and mj.strip() and "--ar" not in mj:
        report.err(
            f"{kind}.{idx}.midjourney_v7",
            "Midjourney prompt is missing required '--ar' parameter; without it, output defaults to 1:1.",
        )

    # Flux.1 word count: 30 to 80 (soft; we warn outside that range).
    flux1 = per_model.get("flux_1")
    if isinstance(flux1, str) and flux1.strip():
        wc = len(flux1.split())
        if wc < 25:
            report.warn(f"{kind}.{idx}.flux_1", f"Flux.1 prompt is {wc} words; aim for 30-80.")
        elif wc > 100:
            report.warn(f"{kind}.{idx}.flux_1", f"Flux.1 prompt is {wc} words; attention falls off past ~80.")

    # Flux.2: if it looks like JSON, verify it parses.
    flux2 = per_model.get("flux_2")
    if isinstance(flux2, str) and flux2.strip().startswith("{"):
        try:
            json.loads(flux2)
        except json.JSONDecodeError as e:
            report.err(
                f"{kind}.{idx}.flux_2",
                f"Flux.2 prompt looks like JSON but does not parse: {e}",
            )

    # Z-Image must contain ZERO negation language. This is a hard rule
    # because Z-Image silently drops negations, wasting attention budget.
    z = per_model.get("z_image")
    if isinstance(z, str) and z.strip():
        for m in Z_IMAGE_NEGATIONS.finditer(z):
            report.err(
                f"{kind}.{idx}.z_image",
                f"Z-Image prompt contains negation word '{m.group()}'. Z-Image silently drops negations; phrase positively.",
            )
            break  # one error per variant is enough; don't spam

    # Qwen-Image must end with the magic suffix.
    q = per_model.get("qwen_image")
    if isinstance(q, str) and q.strip():
        has_english_suffix = "Ultra HD, 4K, cinematic composition" in q
        has_chinese_suffix = "超清，4K，电影级构图" in q
        if not (has_english_suffix or has_chinese_suffix):
            report.warn(
                f"{kind}.{idx}.qwen_image",
                "Qwen-Image prompt is missing the magic suffix ', Ultra HD, 4K, cinematic composition.' (English) or ', 超清，4K，电影级构图.' (Chinese).",
            )

    # Grok / Aurora attention: warn if over 80 words.
    grok = per_model.get("grok_imagine")
    if isinstance(grok, str) and grok.strip():
        wc = len(grok.split())
        if wc > 90:
            report.warn(
                f"{kind}.{idx}.grok_imagine",
                f"Grok prompt is {wc} words; Aurora attention falls off past ~70.",
            )


def check_description_smells(variant: dict, kind: str, idx: int, report: Report) -> None:
    """Group 8: catch description-mode phrasings across all per-model prompts."""
    per_model = variant.get("per_model", {})
    for model_key, prompt in per_model.items():
        if not isinstance(prompt, str) or not prompt.strip():
            continue
        lower = prompt.lower()
        for smell in DESCRIPTION_SMELLS:
            if smell in lower:
                report.warn(
                    f"{kind}.{idx}.{model_key}",
                    f"Prompt contains description-mode phrasing '{smell}'. Rewrite as an instruction.",
                )
                break  # one warning per prompt is enough


def check_stochastic_axes(data: dict, report: Report) -> None:
    """Group 7: every stochastic variant declares one of the named axes, and the
    8 variants collectively cover at least 5 distinct axes."""
    variants = data.get("stochastic_variants", {}).get("variants", [])
    seen_axes: set[str] = set()
    for i, v in enumerate(variants):
        axis = v.get("shifted_axis")
        if axis not in STOCHASTIC_AXES:
            report.err(
                f"stochastic.{i}",
                f"shifted_axis '{axis}' is not in the named set: {sorted(STOCHASTIC_AXES)}.",
            )
        else:
            seen_axes.add(axis)
        if "shift_description" not in v or not isinstance(v["shift_description"], str) or not v["shift_description"].strip():
            report.err(f"stochastic.{i}", "Missing or empty 'shift_description'.")

    # Require breadth across the named axes.
    if variants and len(seen_axes) < 5:
        report.warn(
            "stochastic.coverage",
            f"Only {len(seen_axes)} distinct axes used across 8 variants; aim for at least 5 for breadth.",
        )


def check_sibling_diversity(data: dict, report: Report) -> None:
    """Group 1.3 detail: sibling subjects must be distinct."""
    variants = data.get("stylistic_siblings", {}).get("variants", [])
    subjects: list[str] = []
    for i, v in enumerate(variants):
        subj = v.get("sibling_subject")
        if not isinstance(subj, str) or not subj.strip():
            report.err(f"siblings.{i}", "Missing or empty 'sibling_subject'.")
            continue
        subjects.append(subj.strip().lower())

    if len(subjects) != len(set(subjects)):
        report.err("siblings.diversity", "Sibling subjects must all be distinct; found duplicates.")


def check_firefly_flag(data: dict, report: Report) -> None:
    """If recreation_difficulty.notes flags IP issues, flagged_for_firefly should be true."""
    vdna = data.get("visual_dna", {})
    notes = vdna.get("recreation_difficulty", {}).get("notes", [])
    ip_flags = {"contains_real_person", "specific_artist_style", "branded_character", "trademark_logo"}
    has_ip = isinstance(notes, list) and any(n in ip_flags for n in notes)
    flagged = data.get("flagged_for_firefly", False)
    if has_ip and not flagged:
        report.warn(
            "firefly",
            "Visual DNA notes contain IP-sensitive flags but flagged_for_firefly is false. Did the IP cleaner run?",
        )


def validate(data: Any) -> Report:
    """Run all validation groups against the parsed JSON. Returns a Report."""
    report = Report()
    check_top_level_shape(data, report)

    # If basic shape is broken, downstream checks may NPE or spam noise.
    # Continue only on a passable top-level structure.
    if not isinstance(data, dict):
        return report
    if not all(k in data for k in ("visual_dna", "clone_prompts", "stylistic_siblings", "stochastic_variants")):
        return report

    check_counts(data, report)

    # Per-variant checks across all three variant sets.
    for kind, set_key in [
        ("clone", "clone_prompts"),
        ("sibling", "stylistic_siblings"),
        ("stochastic", "stochastic_variants"),
    ]:
        for i, v in enumerate(data.get(set_key, {}).get("variants", [])):
            if not isinstance(v, dict):
                report.err(f"{kind}.{i}", "Variant must be an object.")
                continue
            check_variant_common(v, kind, i, report)
            check_per_model_idiom(v, kind, i, report)
            check_description_smells(v, kind, i, report)

    check_stochastic_axes(data, report)
    check_sibling_diversity(data, report)
    check_firefly_flag(data, report)
    return report


def format_report(report: Report, quiet: bool) -> str:
    """Format the report for human-readable output. Returns the formatted string."""
    if quiet:
        return ""
    lines: list[str] = []
    if report.passed and not report.warnings:
        lines.append("✓ Output validates clean against the contract.")
    elif report.passed:
        lines.append("✓ Output validates against the contract (with warnings).")
    else:
        lines.append(f"✗ Output has {len(report.errors)} violation(s) of the contract.")

    if report.errors:
        lines.append("")
        lines.append("ERRORS (hard violations):")
        for e in report.errors:
            lines.append(f"  - {e}")

    if report.warnings:
        lines.append("")
        lines.append("WARNINGS (soft issues; not failure-blocking):")
        for w in report.warnings:
            lines.append(f"  - {w}")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate i2i-clone-prompt-generator output JSON against the contract.",
    )
    parser.add_argument(
        "source",
        help="Path to JSON file, or '-' to read from stdin.",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress human-readable output; rely on exit code only.",
    )
    args = parser.parse_args()

    try:
        data = load_json(args.source)
    except (FileNotFoundError, ValueError) as e:
        if not args.quiet:
            print(f"ERROR: {e}", file=sys.stderr)
        return 2

    report = validate(data)
    output = format_report(report, args.quiet)
    if output:
        print(output)

    return 0 if report.passed else 1


if __name__ == "__main__":
    sys.exit(main())
