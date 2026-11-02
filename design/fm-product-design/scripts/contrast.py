#!/usr/bin/env python3
"""Compute the WCAG 2.x contrast ratio between two hex colors.

Usage:
    python scripts/contrast.py "#374151" "#FFFFFF"
    python scripts/contrast.py 374151 ffffff

Prints the ratio and pass/fail against WCAG 2.2 thresholds:
    4.5:1  AA body text (1.4.3)
    3.0:1  AA large text (1.4.3) and non-text UI contrast (1.4.11)
    7.0:1  AAA body text (1.4.6)

No dependencies beyond the Python standard library. Read-only; makes no
network calls and writes no files.
"""
import sys


def _channel(value: int) -> float:
    c = value / 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def luminance(hex_color: str) -> float:
    h = hex_color.strip().lstrip("#")
    if len(h) == 3:
        h = "".join(ch * 2 for ch in h)
    if len(h) != 6:
        raise ValueError(f"Expected a 3- or 6-digit hex color, got '{hex_color}'")
    r, g, b = (int(h[i : i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b)


def contrast(a: str, b: str) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def main(argv: list) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    ratio = contrast(argv[1], argv[2])

    def verdict(threshold: float) -> str:
        return "pass" if ratio >= threshold else "FAIL"

    print(f"{ratio:.2f}:1  {argv[1]} on {argv[2]}")
    print(f"  AA body text  (4.5:1): {verdict(4.5)}")
    print(f"  AA large/UI   (3.0:1): {verdict(3.0)}")
    print(f"  AAA body text (7.0:1): {verdict(7.0)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
