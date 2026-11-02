# AI Autotagger Internals

How the plugin turns a preset into model calls and writes results back to Eagle. Every
statement here was verified by reading the plugin's bundled source (AI Autotagger 11.0.0,
preset schema version 5, published 2026-04-07). Re-verify after plugin updates (see
[Re-verifying after an update](#re-verifying-after-an-update)).

## Contents

- [Prompt assembly (cloud providers)](#prompt-assembly-cloud-providers)
- [Structured output schema](#structured-output-schema)
- [Local providers run one request per rule](#local-providers-run-one-request-per-rule)
- [CLI providers](#cli-providers)
- [Images, slices, video, and resolution](#images-slices-video-and-resolution)
- [Write-back behavior](#write-back-behavior)
- [Skip rule](#skip-rule)
- [Import, export, and limits](#import-export-and-limits)
- [Provider settings](#provider-settings)
- [Built-in presets](#built-in-presets)
- [Re-verifying after an update](#re-verifying-after-an-update)

## Prompt assembly (cloud providers)

Applies to OpenAI, Anthropic, Google, OpenRouter, and Custom (OpenAI-compatible) providers.
The whole preset becomes **one system message**; each image (or video frame, or slice) is sent
as a separate user message. Some models also get a user text "Please analyze these images."

The system message is built like this:

```text
<Global Instructions, with <NAME> and <DESCRIPTION> substituted>

## Output
1. <rule 1 instruction>
2. <rule 2 instruction> Example tags list: A, B, C
3. <rule 3 instruction> Should be only one of these tags list: X, Y, Z
...

## Important
- If you're provided with multiple images, ALWAYS assume they are vertical slices of a single, long image. Analyze them as parts of a whole.
- Your output should describe the entire image, considering all slices equally and sequentially.
- Tags should be title case.
```

Consequences for preset authors:

- **Rule names are not in the prompt text.** Instructions appear only as a numbered list. The
  name reaches the model only as a JSON key (below). Start every instruction with
  `Rule Name:` so the model can map list item → key.
- **Tag lists are appended inline** after the instruction on the same line: `Example tags list: …`
  for Example rules, `Should be only one of these tags list: …` for **every** Specific rule —
  even multi-select ones. State cardinality in the instruction ("Return exactly one tag",
  "Return every tag that applies", "Return 1–3 tags") to override the ambiguous label.
- **N/A rules** (tagsType `none`) get `Example tags list:` followed by nothing when imported
  from JSON (their `tagsList` becomes `[]`). Harmless.
- **"Tags should be title case." is always appended.** Write vocabularies in Title Case;
  spell out brand-casing exceptions (iOS, macOS, shadcn/ui) in Global Instructions.
- **Placeholders in Global Instructions only:** `<NAME>` becomes the item's file name and
  `<DESCRIPTION>` becomes the item's current description (Eagle "annotation"), each wrapped in
  double quotes. File names often carry product, set, or place names, so `<NAME>` is a cheap,
  strong hint. `<DESCRIPTION>` feeds prior AI output back in on re-runs; use it deliberately.
- Rule order is prompt order and JSON output order. Models write keys in schema order, so
  description rules placed first act as visible reasoning for the tag rules after them.

`scripts/render_prompt.py` reproduces this text exactly for review.

## Structured output schema

Alongside the prompt, the plugin sends a JSON schema (strict object, no extra keys):

| Rule type          | Key                | Value schema                                |
| ------------------ | ------------------ | ------------------------------------------- |
| Description, Name  | `snake_case(name)` | string                                      |
| Tags — Example/N/A | `snake_case(name)` | array of strings                            |
| Tags — Specific    | `snake_case(name)` | array of enum (the list values, exact case) |

- Key normalization: camelCase split, runs of non-letters/digits → `_`, lowercased, trimmed.
  `Higher-level UI Elements` → `higher_level_ui_elements`. Two names that normalize to the same
  key cause a duplicate-key failure; the validator catches this.
- Every key is required, but arrays may be empty, so "return an empty list" is always a valid
  instruction. Empty strings for descriptions are skipped at write-back.
- Specific enums are enforced by providers that support strict schemas (OpenAI and LM Studio run
  with `strictJsonSchema: true`). Specific values come back exactly as written, which is why
  their casing must be deliberate.

## Local providers run one request per rule

Ollama and LM Studio do **not** use the combined prompt. The plugin loops over the rules and sends
one request per rule, with a simplified prompt that **omits Global Instructions entirely**:

```text
## Instructions
<rule instruction>

## JSON Shape
{
  "<Rule Name>": ["Tag 1", "Tag 2", "Tag 3"]
}

Should be only one of these tags list: X, Y, Z

## Important
- Tags should be title case.
```

LM Studio additionally gets the JSON schema and strict "output only JSON" rules as text.
Implications:

- Every instruction must be self-contained (role, what to look at, when to return nothing).
- `<NAME>` is unavailable, so Name rules that should keep parts of the original file name
  cannot see it.
- Cost is time: N rules = N image requests per item. Keep local presets to about 3–6 rules.

## CLI providers

"Claude Code CLI" and "Codex CLI" run the local command-line tools against the user's existing
subscription instead of per-call API billing (experimental in v11). They receive the same
combined prompt plus the schema (`--json-schema` / `--output-schema`) and read the image from
disk. Differences that matter:

- **One image per item.** JPG, PNG, and WebP items are passed as the **original file path**, so
  the Image Resolution setting and tall-image slicing don't apply; the CLI downsizes the file
  itself, which makes long full-page captures unreadable. GIF, MOV, and MP4 items are reduced to
  their **first frame**. Use an API provider for full-page captures and video.
- Items processed through thumbnails (SVG, PDF, and other non-media files) are written to a
  temporary JPG first.
- Every item spawns a new `claude` (or `codex`) process that loads the user's settings, plugins,
  skills, MCP servers, and user-level CLAUDE.md. Keep **Maximum Processes at 2–4**.
- **Extra CLI Args** are appended to every call. One unknown flag makes every item fail with
  `error: unknown option` (seen with `--no-progress`). Lean, verified flags for Claude Code 2.1.x:
  `--strict-mcp-config` (no MCP servers), `--disable-slash-commands` (no skills),
  `--no-session-persistence` (no saved transcripts). In a test, these cut per-call startup
  from about 4.8 s to 1.9 s. Don't use `--bare`: it never reads OAuth, so subscription login stops
  working.
- The cost widget records $0; usage counts against the plan's limits. An expired login fails
  every item with "OAuth session expired": run `claude` in a terminal and `/login`.

## Images, slices, video, and resolution

- **Image Resolution** setting: Original, Low (512 px max), Very Low (256 px). The plugin's own
  help warns that Low is unsuitable for images with detail or text. Use **Original** for UI,
  documents, icons with fine detail, and anything with readable text. Items over 20 MP or 20 MB
  are downscaled automatically.
- **Tall images are sliced** into several vertical images; the prompt tells the model they are
  slices of one image. Full-page website captures arrive this way.
- **Video** (gif, mov, mp4): up to 60 frames (2 fps for clips of 10 s or less, sparser for longer
  ones). The "Important" block switches to video wording ("describe the video as a whole").
  ffmpeg must be available.
- **Supported formats:** JPG/JPEG, PNG, GIF, WebP, MOV, MP4. Everything else, **including SVG**,
  needs the **Use Document Thumbnails** setting, which analyzes Eagle's preview thumbnail instead
  (lower resolution). Mention this whenever a preset targets SVGs, PDFs, fonts, or design files.

## Write-back behavior

| Output      | What the plugin does                                                                                                                                                     |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Tags        | Trims each tag, drops empties and the literal `undefined`, applies the modifier, then **merges** with existing tags case-insensitively (existing casing wins) and sorts. |
| Prefix      | `Text: Tag` — a colon is added automatically unless the text already ends with `:`. With Include Space off: `Text:Tag`.                                                  |
| Suffix      | `Tag Text` (no colon). With Include Space off: `TagText`.                                                                                                                |
| Description | Normalizes line endings. With Include Name as Title: prepends `# Rule Name` (an H1). **Appends** to the existing description after a blank line.                         |
| Replace     | Replace Existing overwrites the entire description at that point, including text written by earlier description rules in the same run.                                   |
| Name        | Trims, truncates to 245 characters, and ignores empty output, `undefined`, or an unchanged name.                                                                         |

Consequences:

- Old tags are never removed by a re-run. Changing a vocabulary means cleaning up old tags
  separately (see [library-integration.md](library-integration.md)).
- Eagle tags are case-sensitive as separate tags, so `Typeface: sans-serif` and
  `Typeface: Sans-Serif` coexist until merged.
- A description rule with Include Name as Title **off** blends into the previous section with no
  header. Keep titles on unless the text is meant to continue the section above.
- Re-running a preset appends a second copy of every description section. Either clear
  descriptions first or enable Replace Existing on the **first** description rule for that run.

## Skip rule

Each preset has an optional `skipRule`: `{ "tag": "…", "shouldAddOnSkip": true }`. Items that
already carry the tag are skipped, and with `shouldAddOnSkip` the tag is added after processing.
The editor keeps the tag in sync with the preset name by default; import defaults it to
`Processed with AI Autotagger: <Preset Name>`.

- Use a distinct skip tag per preset (and per major version) so a new version can re-process items
  the old one touched.
- The skip tag is a real Eagle tag. It's handy as a smart-folder filter ("not yet tagged").

## Import, export, and limits

- **Import:** copy the JSON to the clipboard, then in AI Autotagger click **New** (bottom of the
  presets list) → **Paste Preset**. Import always creates a **new** preset; nothing is overwritten.
- **Export:** a preset's **Copy** action puts its JSON on the clipboard, minus `id`, `createdAt`,
  and `updatedAt` for the preset and `id` for each rule. That is also the shape to emit.
- Import validation: JSON root must be an object; ≤ 1,048,576 bytes; ≤ 100 rules; nesting depth
  ≤ 64; `version` ≤ 5 (older versions are migrated). Missing rule ids are generated. Unknown
  fields are dropped. A legacy `tagPrefix` string becomes a Prefix modifier with a space.
- The editor refuses to save an Example or Specific rule with an empty tag list.
- Automatic backups and manual backup/restore exist in the plugin; presets can be organized in
  folders (`folderId`, not needed for import).

## Provider settings

- Providers: OpenAI, Anthropic, Google, OpenRouter, Custom (OpenAI-compatible), Ollama, LM Studio,
  Claude Code CLI, Codex CLI. Custom model names are allowed for every provider, so new models work
  before the plugin's dropdown lists them. Per-model prices are editable for the cost widget.
- Advanced settings per provider: temperature, max output tokens, and a thinking budget (Anthropic
  and OpenAI only). **Blank means "provider default"; any number counts as set.** A Thinking Budget
  of `0` turns thinking **on** with a zero budget, which the Anthropic API rejects (minimum 1,024);
  leave it blank to keep thinking off.
- **Max output tokens for custom model names:** the bundled Anthropic SDK only knows models up to
  Claude 4.5. Any other name (for example `claude-sonnet-5`) falls back to a **4,096-token** output
  cap and tool-call-based JSON. Long presets (detailed descriptions plus OCR) can exceed that and
  fail with "could not parse the response", so set Max Output Tokens to about 8,000–12,000. You
  pay only for tokens actually generated.
- Maximum Processes options: Low (1), Medium (5), High (25), Very High (100).
- Retries are automatic; 429 rate-limit errors mean Maximum Processes is too high for the account tier.
- Per-model token prices: Settings → Pricing → Edit Token Prices. Custom model names start at $0,
  so enter prices or the cost widget stays at $0.00.
- Google requests are sent with safety filters set to `BLOCK_NONE`.

See [model-selection.md](model-selection.md) for which model to recommend.

## Built-in presets

The plugin ships these defaults (New → Defaults). They are useful baselines but show the
weaknesses this skill fixes: unlabeled instructions, open adjective lists, lowercase Specific
values, and overlapping rules.

| Preset              | Rules (type)                                                                                                                                                                                                                                   |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UI Design           | Description, Detailed Description, UI Elements, Higher-level UI Elements, Device Type, Color Scheme, Aesthetic Adjectives, Design Type, Notes, Company, Brands, Typefaces, Color Harmony, Language, Text                                       |
| Photography         | Description, Genre, Lighting, Color and Tone, Time or Season, Subjects (N/A), Similar Artists                                                                                                                                                  |
| Fashion Inspiration | Brief Description, Detailed Description, Category/Style, Garments/Accessories, Color Palette, Patterns/Textures, Season/Occasion, Era/Decade, Gender Presentation, Designers/Brands, Setting/Context, Mood/Aesthetic, Trends, Additional Notes |
| Extract Text        | Text (description)                                                                                                                                                                                                                             |
| Rename Item         | Name, Original Name (description); Global Instructions use `<NAME>`                                                                                                                                                                            |

## Re-verifying after an update

Plugin folder on Windows: `%APPDATA%\Eagle\Plugins\4B56113D-EB3E-4020-A82C-6214FA08CB14\`.
The logic lives in one minified bundle, `assets\main-*.js`. Search it for these literal strings:

| Behavior                  | Search string                                      |
| ------------------------- | -------------------------------------------------- |
| Prompt builder            | `## Output` and `Should be only one of these tags` |
| Local per-rule prompt     | `## JSON Shape`                                    |
| Tag write-back, modifiers | `[UPDATE-TAGS]`                                    |
| Description write-back    | `[UPDATE-DESCRIPTION]`                             |
| Import parser and limits  | `[PresetImport]`                                   |
| Enums                     | `e.Specific="specific"`                            |
| Current schema version    | the `version` value near `presets.uiDesign`        |

If any behavior above changed, update this file, `preset-schema.md`, and the scripts'
`_preset_common.py` constants together.
