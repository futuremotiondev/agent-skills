# Preset-spec and tools

> The preset-spec is the skill's source of truth for a preset: a JSON file the builder turns into `.rnp` files. This
> file documents every field, the four scripts that work on it, and the validator's checks.

## 1. Schema

```jsonc
{
  "name": "Remove Envato Timestamp",            // Title Case; the builder adds the "FILE " / "CONTENTS " prefix
  "variants": ["FILE", "CONTENTS"],              // one or both (default request: both, D2)
  "filters": { "Masks": "*.zip;*.rar" },         // optional overrides merged into each variant's [Filters] block.
                                                 // verbatim mode: the complete block, written as-is; null = no [Filters]
  "casing": {
    "mode": "preserve",                          // none|preserve|title|sentence|lower|upper|kebab|snake|verbatim
    "dictionary": {                              // casing.md §2; omit any field to get the mode's default
      "sources": ["base", "added"],
      "tiers": ["core", "proper"],
      "optInPacks": [],                          // audio|media|design|legacy-tech|brand|roman|code
      "reviewTerms": [],                         // review-tier terms to include, by name (e.g. "Apple")
      "extraTerms": []                           // ad-hoc terms not in the TSV (no commas)
    },
    "preserveCase": true,                        // title mode only: rule ① PRESERVECASE
    "lastWordRule": true                         // title mode only (D4)
  },
  "camelCaseRejoin": { "enabled": false, "includeReview": [], "repairDigitCapitals": false },   // casing.md §5
  "collisions": "none",                          // none|nopad|pad2|pad3|pad4|stock (SKILL.md, collisions)
  "rules": [                                     // user-designed rules; casing tail + collision rule are appended
    { "id": "RegEx", "comment": "Strip trailing Envato UTC timestamp", "marked": 1,
      "config": { "EXPRESSION": "[-\\s]\\d{4}(?:[-\\s]\\d{2}){5}[-\\s]utc$", "REPLACE": "" } }
  ],
  "tests": [
    { "in": "Retro Pack-2024-05-01-10-20-30-utc.zip", "out": "Retro Pack.zip" },
    { "in": "Film LUT 2024 05 01 10 20 30 UTC.CUBE", "out": "Film LUT.cube" },
    { "name": "Nested file via CONTENTS", "variant": "CONTENTS",
      "files": ["Pack\\a-2024-05-01-10-20-30-utc.zip"], "inputs": ["Pack"],
      "expect": ["Pack\\", "Pack\\a.zip"], "expectExit": 0 }
  ]
}
```

Unknown keys anywhere in the spec (top level, `casing`, `dictionary`, `camelCaseRejoin`, rules, tests) are an error:
a misspelt `colisions` or `expected` would otherwise silently default. Also allowed at the top level: `description`,
`$schema`, `acceptance` and `referenceRules` (acceptance files), and `outputFileName` (verbatim specs from
`ConvertFrom-Rnp.ps1`: the exact file name, at most one variant). `"casing": "title"` is shorthand for
`"casing": { "mode": "title" }`. JSON comments and trailing commas are accepted; strings are never reinterpreted
(an ISO date-time stays text).

## 2. Field reference

**`name`** — valid Windows file name, no trailing dot or space, no `\ / : * ? " < > |`. The builder writes
`<Variant> <name>.rnp`.

**`variants`** — `FILE` renames exactly the passed files and folders; `CONTENTS` renames what is inside passed folders,
recursively. Each gets Futuremotion's canonical `[Filters]` block (`assets/filters/FILE.ini`, `CONTENTS.ini`).

**`filters`** — only known `[Filters]` keys; values are raw text (`*.jpg;*.png`), never percent-encoded. Requested masks
apply to both variants.

**`rules[]`** —
- `id`: one of the 18 rule IDs, case-sensitive (`rnp-format.md` §3). An unknown ID is an error, because ReNamer would
  silently skip it.
- `config`: UPPERCASE keys from `rnp-format.md` §4. Omitted keys get the skill defaults; keys marked "—" there are
  required (an explicit empty string is allowed, e.g. RegEx `REPLACE`). Values may be strings, integers or booleans
  (`true`/`false` → `1`/`0`). Booleans must be 0/1, integers integers, enums in range; legacy values (Insert `WHERE=3`,
  Serialize `WHERE=3`/`TYPE=2`, Case `WHAT=6`, ReformatDate `ADJUSTTIMEPART=0`) are rejected.
- `comment`: always give one; it shows in ReNamer's rule list.
- `marked`: default 1; 0 keeps the rule but disables it (`true`/`false` are accepted).
- `strict` (verbatim specs only): `true` resolves this rule like normal mode (defaults, canonical order, type and enum
  checks). Use it for every rule added or changed in the modify flow; the builder lists them as `StrictRules`.
- `sourceFile` (PascalScript only): a `.pas` file embedded as `SOURCEUTF8` (`pascal-script.md` §3).
- **Lists:** Mapping `SOURCE`/`TARGET` and User Input `INPUT` also take JSON arrays, one row or line per item. The
  builder writes ReNamer's format (Mapping rows joined with a raw `|`, User Input lines with a bare CR; line breaks in
  an `INPUT` string are converted to CR). Mapping needs the same number of non-empty rows in both, or the build fails:
  ```json
  { "id": "Mapping", "comment": "Vendor names to catalogue names",
    "config": { "SOURCE": ["IMG_0001", "IMG_0002"], "TARGET": ["Hero Shot", "Detail Shot"] } }
  ```

**`tests[]`** — mirror the harness's case fields:
- `files`: relative paths to create (a trailing `\` makes a folder). `inputs`: what to pass to ReNamer (default: all
  `files`; `.` = the test's root folder). `expect`: every relative path after the run, folders included with a trailing
  `\`; order-insensitive, case-sensitive. `expectExit`: default 0 (1 = ReNamer must refuse, e.g. a collision).
  `variant`: which built preset runs it (default `FILE` if built, else `CONTENTS`). `name`: a label.
- Shorthand `{ "in": x, "out": y }` = `files: [x]`, `expect: [y]` plus every parent folder of `y` with a trailing `\`
  (the harness lists folders too: `Icons\home.SVG` → expect `Icons\`, `Icons\Icons home.svg`). For a folder rename
  end both with `\` (`{ "in": "old name\", "out": "New Name\" }`).
- Every test must assert something: `expect` and/or `expectExit` (or the shorthand). The builder rejects a test
  without one, and the harness fails it.
- A FILE preset renames the passed items themselves, so pass the file (`Icons\home.SVG`), not its folder. A CONTENTS
  preset needs the folder in `inputs` (`["Textures"]`).
- With a GUI-only serializer, the harness runs without it: add each colliding input as its own test (asserting the
  pre-serialization name) plus one batch test with `expectExit: 1` and unchanged names (SKILL.md, collisions).

**Verbatim specs** (`casing.mode: "verbatim"`) — produced by `ConvertFrom-Rnp.ps1`. Nothing is added or filled in:
config keys, values (always strings), `marked`/`comment` (`null` = the line is absent) and `filters` are written
exactly as given, and rebuilding an untouched spec is byte-identical. Collisions and rejoin are not allowed.

## 3. Tools

All scripts need PowerShell 7.4+ and live in `scripts/`; `RnpCommon.psm1` is their shared engine (codec, parser,
writer, rule catalog, dictionary selection). Paths come from `config.json`.

| Script | Does | Key parameters | Exit code |
|---|---|---|---|
| `Build-RnpPreset.ps1` | spec → one `.rnp` per variant (defaults, rejoin, casing tail, ext rule, serializer, filters) | `-LiteralPath` spec(s) or `-SpecJson`, `-OutputDirectory` (default StagingDir), `-SkipCollisionRule` | 1 if any spec failed |
| `Test-RnpPreset.ps1` | the 15 checks below; emits `Path, Check, Level, Rule, Message` (`Rule` is 0-based) | `-LiteralPath`, `-Profile Strict\|Legacy`, `-StrictRules` (1-based), `-Variant`, `-MaskOverrides` | 1 on any Error |
| `ConvertFrom-Rnp.ps1` | `.rnp` → verbatim spec + Markdown explanation; proves the round trip | `-LiteralPath`, `-OutputDirectory` (default StagingDir\decoded) | 1 if not lossless |
| `Invoke-RnpProbe.ps1` | runs fixtures through `ReNamer.exe /silent /rename` on throwaway files | `-Preset` + `-Tests`, or `-CaseFile` (.psd1 suites) | number of failures |
| `Install-RnpPreset.ps1` | staging → `Presets\`; never overwrites silently (diff + `NeedsConfirmation`); backs up before replacing | `-LiteralPath`, `-Subfolder`, `-Force`, `-WhatIf` | 1 if confirmation is needed |

Build output (one object per preset): `Name, Variant, Path, RuleCount, DictionaryTerms, FragmentsBytes, Collision,
StrictRules, Warnings`. Report every warning to the user. The harness also warns when a built variant has no test.

**Typical session** (PowerShell 7, from the skill folder):
```powershell
$spec = "$env:TEMP\rnp-staging\remove-envato-timestamp.json"          # written by Claude
$full = & .\scripts\Build-RnpPreset.ps1 -LiteralPath $spec            # FILE + CONTENTS into staging
$full.Path | & .\scripts\Test-RnpPreset.ps1                           # must report 0 errors
$probe = & .\scripts\Build-RnpPreset.ps1 -LiteralPath $spec -SkipCollisionRule -OutputDirectory "$env:TEMP\rnp-probe-build"
& .\scripts\Invoke-RnpProbe.ps1 -Preset $probe.Path -Tests $spec | Format-Table Status, Name, ExitCode
```

**Test suites** (`tests/`): `Invoke-AcceptanceSuite.ps1 -UseReference` (scenario self-check; `-SkipHarness` builds and
validates without ReNamer), `Test-RnpRoundTrip.ps1` (T13; `-All` for every installed preset),
`Test-RnpEncoderRoundTrip.ps1`, and the two `.psd1` probe suites for `Invoke-RnpProbe.ps1 -CaseFile`. Re-run the
rule-semantics suite after every ReNamer update.

## 4. Validator checks

Profile **Strict** (default) is for every generated preset. **Legacy** is for the user's existing presets in the explain and
modify flows: checks 1, 3, 4, 6, 7, 8 and 14 drop to warnings, except for the rules named in `-StrictRules` (the ones
the skill added or changed), which must still pass Strict. An empty RegEx `EXPRESSION` in a `UI` template preset is a
warning (a placeholder the user fills in), otherwise an error.

| # | Check | Level |
|---|---|---|
| 1 | Sections `[Rule0..N]` contiguous; each has ID/Config/Marked/Comment; CRLF; no BOM; trailing CRLF; exact ReNamer layout | error |
| 2 | `ID` ∈ the 18 IDs, case-sensitive (an unknown ID is silently skipped by ReNamer) | error |
| 3 | Config keys exactly equal the canonical set for that ID, in canonical order, uppercase | error |
| 4 | Booleans 0/1, integers, enum values valid; legacy values rejected | error |
| 5 | Every value is canonically encoded (decode → encode reproduces it) | error |
| 6 | Lowercase-extension guarantee (`casing.md` §1); `EXTENSIONALWAYSUPPERCASE=0` everywhere | error |
| 7 | `[Filters]` present; variant-defining keys match the variant; masks not percent-encoded (other differences warn) | error |
| 8 | File name is `FILE <Name>.rnp` or `CONTENTS <Name>.rnp`, Windows-valid | error |
| 9 | `EXTENSION` without a leading dot; ReformatDate `TARGETFORMAT` without filename-illegal characters | error |
| 10 | Fragments: no empty or duplicate (case-insensitive) entries; `FORCECASE=1` when fragments exist; count and size as Info | warn |
| 11 | RegEx: empty group or alternative (e.g. an empty `<LC>`) → error; `\E` in REPLACE, case-dependent EXPRESSION with `CASESENSITIVE=0`, a `$` in REPLACE not followed by a digit or `{` → warn | error / warn |
| 12 | Pascal: BOM; dialog calls (GUI-only); `{$INCLUDE}`; bounds check and index access in one `and`/`or` expression (skipped for `[fm-collision]` scripts) | warn |
| 13 | Order-dependent rules (Serialize, UserInput) → warn; User Input lines not separated by a bare CR, Mapping SOURCE/TARGET row counts that differ, empty rows, line breaks in Mapping → error | warn / error |
| 14 | `[fm-collision]` script present but not last, more than one, or on a non-Pascal rule | error |
| 15 | Every rule has a non-empty comment | warn |
