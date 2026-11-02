---
name: fm-renamer-preset-creator
description: Create, modify, explain and verify den4b ReNamer presets (.rnp) for any batch-renaming job - cleanup, casing (APA title case + brand dictionary), prefixes/suffixes, serialization, dates, regex and Pascal Script - following Futuremotion FILE/CONTENTS naming and filter conventions. Use whenever ReNamer, .rnp files, rename presets or rename rule sets are mentioned.
---

# ReNamer preset creator

Turns a plain-language renaming request into correct, minimal **den4b ReNamer 7.10** presets that look exactly like
presets Jay saves himself, proves them on throwaway files, and explains or edits existing presets.

**Environment:** ReNamer portable at `C:\Tools\den4b Renamer` (from `config.json`), presets in its `Presets\` folder,
Windows 11, PowerShell 7.4+. All scripts are in `scripts/` and run with `pwsh`; paths come from `config.json`.

| Need | Read |
|---|---|
| Exact keys, enums, defaults and encoding of all 18 rules | `references/rnp-format.md` (verified; authoritative) |
| RegEx flavour, Pascal API, meta tags, CLI, pipeline behaviour | `references/engine-notes.md` |
| Which rule for which goal, composition, verified patterns | `references/rule-selection.md` |
| Casing modes, APA title case, dictionary, CamelCase rejoin | `references/casing.md` |
| Writing, embedding and testing Pascal scripts | `references/pascal-script.md` |
| Preset-spec JSON schema, tools, validator checks | `references/preset-spec.md` |

## Workflow

### 1. Intake: examples first
The most common failure is the right rules for the wrong interpretation. Before designing, hold **3–8 concrete
`before → after` pairs**, including at least one awkward case (extra dots, brackets, digits, mixed case, an
already-correct name). They become the spec's `tests`.
- Jay gave examples → restate them as a fixture table; ask only about genuine gaps.
- He gave none → invent representative pairs and ask him to confirm or correct them in **one** message.
- When both variants are built, include at least one CONTENTS fixture (`"variant": "CONTENTS"`, the folder in
  `inputs`, nested files in `expect`); otherwise the CONTENTS preset ships unverified (the harness warns).
- Settle these too (defaults when unattended):

| Question | Default |
|---|---|
| Rename passed items, folder contents, or both? | **Both**: `FILE` and `CONTENTS` variants (D2) |
| Restrict to extensions (masks)? | No masks |
| Casing? | `preserve`: fix brand casing from the default dictionary, keep the rest, lowercase the extension |
| Can the rules create duplicate names? | Analyse (see Collisions). If yes, ask for serializer padding; unattended → `nopad` + warning (D7) |
| Preset name? | Title Case from the intent, verb-first where natural (`Remove Envato Timestamp`) |

### 2. Design the rule stack
Use `rule-selection.md`. Draft a numbered list, one line of intent per rule, in pipeline order (normalise → remove junk
→ structural edits → casing tail → collision script). Walk every fixture through it. **Deletion test:** remove any
user-designed rule that changes no fixture. Merge literal substitutions into one Replace with `*|*` pairs.

### 3. Write the preset-spec
A JSON file in the staging folder (`%TEMP%\rnp-staging`), schema in `preset-spec.md`. Every rule gets a `comment`. Give
only the keys you change; the builder fills canonical defaults. Pascal source goes in a `.pas` file via `sourceFile`.
Write files with a file-writing tool, not shell `echo`/here-strings (a remote shell can expand `$1`, `$_`).

### 4. Build → validate → verify
```powershell
$spec  = "$env:TEMP\rnp-staging\<name>.json"
$built = & .\scripts\Build-RnpPreset.ps1 -LiteralPath $spec                      # FILE + CONTENTS into staging
$built.Path | & .\scripts\Test-RnpPreset.ps1                                     # must be 0 errors (exit 0)
$probe = & .\scripts\Build-RnpPreset.ps1 -LiteralPath $spec -SkipCollisionRule -OutputDirectory "$env:TEMP\rnp-probe-build"
& .\scripts\Invoke-RnpProbe.ps1 -Preset $probe.Path -Tests $spec | Format-Table Status, Name, ExitCode, Actual
```
Fix and rebuild until the validator reports 0 errors and every fixture passes. The harness asserts names **and** exit
code, works on copies in `%TEMP%`, restores `Settings.ini` and reports drift in `Presets\`. If PowerShell or the
harness is unavailable, say so and mark the preset **unverified**.

### 5. Deliver
- Install with `scripts\Install-RnpPreset.ps1` (target `<ReNamerPath>\Presets\<Variant> <Name>.rnp`; `-Subfolder
  Icons` for `Presets\Icons\`; it flags a same-named preset in another subfolder). It never overwrites silently: an
  existing, different preset returns `NeedsConfirmation` with a rule-level diff. Show the diff, ask, then rerun with
  `-Force` (it backs the old file up to `BackupDir` first; never back up inside `Presets\`, every `.rnp` there shows
  in ReNamer's menu).
- Report in chat:
  1. Files written (full paths).
  2. Rule table: `# | Rule | Key settings (human words) | Why`.
  3. Before → after table, each row ✓ (harness-verified) or ◻ (verify in GUI).
  4. Warnings: every builder warning, GUI-only parts, order dependence (Serialize), review-tier terms used, known limits
     hit by the fixtures.
  5. How to run it, e.g. `ReNamer.exe /preset "<Variant> <Name>"` or Jay's context-menu wrapper.

### 6. Explain or modify an existing preset
```powershell
$d = & .\scripts\ConvertFrom-Rnp.ps1 -LiteralPath 'C:\Tools\den4b Renamer\Presets\<file>.rnp'
$d.Explanation          # Markdown: filters, one sentence per rule, validator notes (Legacy profile)
```
- **Explain:** relay the explanation in plain words; add what the rules do together and any pitfalls.
- **Modify:** edit `$d.SpecPath` (a verbatim spec: keys in file order, values as strings). Mark every new or changed
  rule `"strict": true` (the builder then fills defaults and type-checks it), rebuild into staging, validate with
  `-Profile Legacy -StrictRules $built.StrictRules` (old rules leniently, yours strictly), show the diff via
  `Install-RnpPreset`, verify with fixtures, deliver. An untouched round trip is byte-identical. If the decoder refuses
  (not lossless, e.g. a hand-edited file without a final CRLF), it still explains the preset: say why, and rebuild
  from a fresh spec instead of approximating.

## Hard rules
1. **Never write `.rnp` syntax from memory.** Keys, enums and encoding come from `rnp-format.md`; the scripts implement
   them. Anything marked ◐ or ✗ there must be probed before use.
2. **Never rename Jay's real files** and never edit ReNamer's `Settings.ini`. Tests run only on throwaway copies.
3. **Stage first, deliver after validation.** Never write straight into `Presets\`; never overwrite without showing the
   diff and getting a yes.
4. **Extension always lowercase** (validator check 6): the last Case rule sets `EXTENSIONALWAYSLOWERCASE=1`, and only
   `SKIPEXTENSION=1` rules or the collision script may follow it. The builder appends the standard rule when needed.
5. **`[Filters]` always included**, from the variant (FILE `0/1/0/1/1/0/0`, CONTENTS `1/0/1/1/1/0/0`, masks empty unless
   requested). Masks are raw text (`*.jpg;*.png`), never percent-encoded.
6. **Every rule has a comment** stating its intent. The collision script's comment carries `[fm-collision]`.
7. **Fewest rules that stay readable.** Every user rule must pass the deletion test.
8. **Anchor and guard patterns**: `^`/`$`/lookarounds; guard numbers against resolutions, dates and versions; set
   `CASESENSITIVE=1` when a pattern depends on case; literal `$` in a replacement is `\$`.
9. **Validator 0 errors + all fixtures passing** before a preset is called done. Report anything not harness-verified.

## Jay's conventions
- **Names:** `FILE <Name>.rnp` renames exactly the passed files *and* folders, never their contents; `CONTENTS
  <Name>.rnp` renames what's inside passed folders, recursively. `<Name>` is Title Case, descriptive, a valid Windows
  file name. Topic sub-prefixes like `CASE` are fine (`FILE CASE Kebab`). **`UI`** marks templates meant to be edited
  before running (`FILE UI Prefix`): ask before generating one (D5).
- **Style fidelity:** the builder emits exactly what ReNamer saves (canonical key order, all keys, CRLF, UTF-8 without
  BOM, `Marked=1`, sections from `[Rule0]`), so presets diff cleanly against GUI-saved ones.

## Casing (details: `casing.md`)
Modes: `preserve` (default: dictionary fixes brand casing only), `title` (APA: minor words lowercase inside, first word,
subtitle start and last word capitalized, brands kept), `sentence`, `lower`, `upper`, `kebab`, `snake`, `none` (just the
ext-lowercase rule if needed), `verbatim` (decoded presets). The dictionary (`data/casing-dictionary.tsv`) defaults to
`core`+`proper` terms (`core` only in title mode); opt-in packs and review-tier terms only when the request's domain
calls for them, named in the report. CamelCase splitting = CleanUp `INSERTSPACEBEFORECAPITALS` in the user rules +
`camelCaseRejoin.enabled` (brand rejoin pairs; `repairDigitCapitals` for `Model3D`/`Render4K`).

## Collisions
Any rule that removes or normalises information (timestamps, counters, brackets, case folding, separators) can merge
distinct names. When the fixtures could collide, add colliding inputs and set `collisions`:
- `nopad|pad2|pad3|pad4` → Jay's serializer (`Save 1.svg`, `Save 2.svg`), appended as the **last** rule. **GUI-only:
  preview twice** (learning pass, then serializing pass), uses a shared tally file, shows popups, doesn't work from
  `/silent` or context-menu "rename with preset". Tell Jay this in the report.
- `stock` → den4b's single-pass script (`Save.svg`, `Save (2).svg`, …), CLI-safe ✓. Offer it when the preset must run
  unattended. It only sees the batch: if a serialized name already exists (a `Save (2).svg` in the folder), ReNamer
  refuses the whole batch.
- **Verify** (the harness runs without a GUI-only serializer): each colliding input as its own test (its
  pre-serialization name) + one batch test with `expectExit: 1` and unchanged names (ReNamer refuses conflicting new
  names ✓). The serializer itself is ◻ "verify in GUI".

## Decisions in force (Jay can change any)
| # | Decision | Default |
|---|---|---|
| D1 | Script language | PowerShell 7.4+ |
| D2 | Variants emitted by default | Both FILE and CONTENTS |
| D3 | Where presets go | Staging → `<ReNamerPath>\Presets\` after confirmation; backups to `%TEMP%\rnp-backups` |
| D4 | Capitalize the last word in title case (Chicago rule, not APA) | Yes (`lastWordRule`) |
| D5 | `UI` prefix | Template to edit before running; ask before using it |
| D6 | Dictionary default | Sources base + added; tiers core + proper (title: core); legacy packs opt-in |
| D7 | Serializer padding when unattended | `nopad` |
| D8 | CamelCase rejoin default | `kind=brand` rows only; review rows via `includeReview` |

## Known limits
- **Mapping and User Input lists** (calibrated from GUI-saved presets, `rnp-format.md` §1.2, §3.17–3.18): give
  Mapping `SOURCE`/`TARGET` and User Input `INPUT` as JSON arrays and the builder writes ReNamer's format (Mapping rows
  joined with a raw `|`, User Input lines with a bare CR). Mapping rows must pair up one-to-one: a missing TARGET row
  renames a file to an empty name, so the builder and validator reject it. User Input names files in file-table order.
- **CamelCase rejoin** can't rejoin a brand glued to digits (`iPhone15ProReview` → `i Phone15 Pro Review`) or to a
  lowercase word (`BackupToiCloud` → `Backup Toi Cloud`). Report these rows; a protected-split script is future work.
- **Title case** can't tell a particle from a preposition (`Set up the Server` keeps `up` lowercase).
- **Padding** zero-pads every digit run (years and versions too); **Serialize** follows the file-table sort order.
- **GUI-only serializers** can't be verified by the harness (see Collisions).
- **No renaming onto an existing name:** ReNamer refuses the whole batch when a new name equals another file's current
  name, even one being renamed away in the same batch (swaps, chains) ✓. Exit 1, nothing renamed.
- **No PowerShell available** (e.g. a sandbox without Jay's machine): write the `.rnp` by hand from `rnp-format.md`
  §1.2/§4, read the TSVs directly, and label the preset **unverified**.

## Maintenance
- After a ReNamer update, everything must pass (otherwise `rnp-format.md` is out of date):
  `.\scripts\Invoke-RnpProbe.ps1 -CaseFile .\tests\rule-semantics.probes.psd1`, the same with
  `.\tests\acceptance-reference.probes.psd1`, `.\tests\Invoke-AcceptanceSuite.ps1 -UseReference`, and
  `Get-ChildItem .\tests\examples\*.json | .\tests\Invoke-AcceptanceSuite.ps1`.
- Dictionary changes: edit `data/casing-dictionary.tsv` (see `casing.md` §6), then regenerate the rejoin pairs with the
  tools in `_spec\tools\camelcase-rejoin\`.
