# Markdown and Text Output

JSON is the default deliverable. Produce a markdown or plain-text field sheet **only** when the
user asks for one ("give me the fields as markdown", "a text version I can copy from", "no
JSON"). Even then, build and validate the JSON first, and generate the sheet from it so the two
never disagree.

## Generate

```bash
python scripts/preset_to_markdown.py my-preset.preset.json -o my-preset.preset.md
python scripts/preset_to_markdown.py my-preset.preset.json --format txt -o my-preset.preset.txt
```

If the user wants only the sheet, deliver the `.md` or `.txt` and keep the JSON as a working file
(offer it in one line; it's the faster way to install).

## Layout

The sheet mirrors the plugin's editor, top to bottom:

1. **Preset** block: Preset Name, Skip If Has Tag, Add On Skip.
2. **Global Instructions** in a `text` code block.
3. One section per rule, in rule order, titled `Rule N — <Type> Rule: <Name>`, with a `text` code
   block holding each field as `Label: value`, separated by `---` lines:
   - Description rules: Name, Instruction, Include Name as Title, Replace Existing.
   - Tags rules: Name, Instruction, Tags Type, Example Tags or Specific Tags (comma-separated,
     ready to paste), Modifier Position, Modifier Text (or "(leave empty)"), Include Space, and a
     tag preview such as `Style: Minimalist`.
   - Name rules: Name, Instruction.

## Manual entry notes for the user

- The Example Tags and Specific Tags fields take a comma-separated list; paste the line as is.
- Tags Type "N/A" hides the tag list field.
- Modifier Text empty = no modifier, whatever the Position says.
- The skip tag field follows the preset name automatically unless edited.
- Manual entry is slower and error-prone for large presets; recommend **New → Paste Preset** with
  the JSON whenever possible.
