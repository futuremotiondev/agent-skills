# Example Presets

Validated, paste-ready presets that show the skill's conventions end to end. Each passes
`scripts/validate_preset.py` with zero errors and zero warnings. Use them as starting points,
not as finished answers: confirm facets against the user's own samples first.

| File                          | Rules | Rule types              | Shows                                                                                    |
| ----------------------------- | ----- | ----------------------- | ---------------------------------------------------------------------------------------- |
| `ui-design.preset.json`       | 18    | Description, Tags       | Optimized rewrite of the built-in UI Design preset; large Example vocabularies; OCR last |
| `app-icons.preset.json`       | 14    | Description, Tags       | Mostly Specific facets; file-name hints for icon sets and brands; N/A proper nouns       |
| `photo-reference.preset.json` | 14    | Name, Description, Tags | A Name rule; single-value camera facets; evidence-gated Location                         |

## What to copy from each

- **ui-design:** the Global Instructions tagging-rules block, the universal-tag guidance in
  UI Components, and the Brand evidence test that excludes incidental logos.
- **app-icons:** splitting "what shape, what fill, what mark, how rendered" into separate
  Specific facets instead of one style list; the Icon Set rule that trusts only the file name.
- **photo-reference:** the Name rule wording (keep meaningful words, drop camera codes), and
  pairing an open Subjects list with closed facets for light, framing, and angle.

## Try one

```bash
python scripts/validate_preset.py examples/app-icons.preset.json
python scripts/render_prompt.py examples/app-icons.preset.json --name "Adwaita Plus Apps Scalable Firefox-1024"
python scripts/preset_to_markdown.py examples/app-icons.preset.json -o app-icons.preset.md
```
