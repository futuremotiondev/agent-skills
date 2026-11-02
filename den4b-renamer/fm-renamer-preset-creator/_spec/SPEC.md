# SPEC — `fm-renamer-preset-creator` (v2.1)

> **Purpose of this document:** the build brief for an agent skill that turns plain-language renaming requests into correct,
> minimal, convention-compliant **den4b ReNamer** presets (`.rnp`), and can explain, modify and verify them.
> **Target:** ReNamer **7.10** (portable, `C:\Tools\den4b Renamer`), used by Jay on Windows 11.
> **Skill location:** `D:\AI\Skills\futuremotion\fm-renamer-preset-creator\` (this package lives in its `_spec\` subfolder).
> **Version history:** v1 = Jay's original brief (its rule syntax was largely incorrect; see Appendix A). v2 (2026-09-27) = rewritten and
> verified against Jay's 158 real presets, the ReNamer binary and CLI probes. **v2.1** (same day) = revised after an independent review:
> every flagged claim re-probed, and **162 asserting CLI probes now pass** (140 rule-semantics + 22 acceptance reference probes; each
> checks the resulting names *and* ReNamer's exit code).

## 0. How to use this package (building session: read first)

| File | Role | Goes into the skill as |
|---|---|---|
| `SPEC.md` | Requirements, workflow, conventions, acceptance tests | Source for `SKILL.md` + `references/rule-selection.md`, `references/casing.md`, `references/pascal-script.md` |
| `reference/rnp-format.md` | **Verified** file format, encoding and every rule's keys/enums | `references/rnp-format.md`, verbatim except for link rewrites (rule 5) |
| `reference/engine-notes.md` | RegEx flavour, Pascal Script API and gotchas, meta tags, CLI, pipeline behaviour | `references/engine-notes.md`, verbatim except for link rewrites |
| `data/casing-dictionary.tsv` | 15,528-entry tiered casing dictionary (5,646 in v2.1; +9,883 researched rows on 2026-09-28, audit trail in `data/expansion-2026-09-28/`). Tab-separated, header row `term tier pack source note`, no comment lines | `data/casing-dictionary.tsv` |
| `data/casing-dictionary-review.md` | How the dictionary was curated, plus items for Jay to review | Stays in `_spec` (human-facing) |
| `data/apa-minor-words.txt` | The 22 APA minor words, one per line (`#` lines are comments) | `data/apa-minor-words.txt` |
| `data/camelcase-rejoin.tsv` | 3,771 `split → term` pairs that undo CleanUp's CamelCase split for dictionary terms (1,131 `brand`, 2,640 `review`; v2.1 had 1,264 = 419 + 845), §7.5 | `data/camelcase-rejoin.tsv` |
| `tools/rnp-probe/Invoke-RnpProbe.ps1` | Working CLI harness (tested): asserts names and exit code | `scripts/Invoke-RnpProbe.ps1` |
| `tools/rnp-probe/rule-semantics.probes.psd1` | 142-case regression suite for `rnp-format.md`: 140 assertions, all pass on 7.10; the 2 unresolved cases (C1) are informational | `tests/rule-semantics.probes.psd1` |
| `tools/rnp-probe/acceptance-reference.probes.psd1` | 22 hand-built reference probes for the §11 scenarios, all pass (list under §11) | `tests/acceptance-reference.probes.psd1` (yardstick, not answers to copy) |
| `tools/rnp-probe/Test-RnpEncoderRoundTrip.ps1` | Proves the encoder matches ReNamer: 6,860/6,860 values in 158 presets round-trip byte-for-byte | `tests/Test-RnpEncoderRoundTrip.ps1` |
| `tools/camelcase-rejoin/` | Split-map probe + `classify-rejoin.py`: regenerate `camelcase-rejoin.tsv` after dictionary changes (§7.5) | Stays in `_spec` (maintenance) |

**Ground rules for the builder:**
1. **Never re-derive `.rnp` syntax from memory, the den4b docs, or v1.** `reference/rnp-format.md` is authoritative. If you need a value it marks ◐/✗, probe it with the harness first.
2. Load the `fm-powershell-coding-style` skill before writing any `.ps1` (Jay's conventions: PowerShell 7.4+, `-LiteralPath`, `begin/process/end`, comment-based help).
3. Keep `SKILL.md` lean (≤ ~250 lines: workflow + hard rules + pointers). Put depth in `references/`, loaded on demand. This is Jay's stated preference.
4. Finish by running `tests/rule-semantics.probes.psd1`, `tests/acceptance-reference.probes.psd1` and the §11 acceptance suite on Jay's machine. Everything must pass before the skill is considered done.
5. **Link rewrites for the verbatim copies.** The two reference files point back into this package. When copying them, rewrite: every `SPEC §7.x` → `casing.md`; `SPEC §12` / "calibration item C1" → the Known-limits section of `SKILL.md`; `../tools/rnp-probe/*.psd1` and `Test-RnpEncoderRoundTrip.ps1` → `../tests/…`; `Invoke-RnpProbe.ps1` → `../scripts/…`. Afterwards, grep the skill for `SPEC §` and `../tools/`: zero hits.
6. **Markdown pipes.** Inside table cells, `\|` is an escaped `|` (the Replace multi-find separator is the three characters `*|*`). Every regex or multi-value string that must be copied exactly lives in a code block in this package, never in a table cell. Keep it that way in the skill.

---

## 1. Goal and definition of done

The skill produces presets that are **correct the first time**, **as small as possible**, and **indistinguishable from presets Jay would save himself**.

A generated preset is *done* when all of the following hold:
1. It loads in ReNamer 7.10 with no warnings, and every rule shows the intended settings in the GUI.
2. `Test-RnpPreset.ps1` (validator, §10.3) reports **0 errors**.
3. Its fixture tests (the before→after examples agreed with Jay) **pass in the CLI harness**. The only exception is GUI-only parts (§8), which are listed as "verify in GUI".
4. It follows every convention in §6 (naming, filters, extension casing, rule comments).
5. It uses the **fewest rules that stay readable**. Deletion test: removing any **user-designed** rule must change at least one fixture result. Builder-appended rules (the casing tail and the collision script) are exempt: they encode conventions, and the fixtures may not exercise them.

## 2. Scope

**In scope:** creating new presets from a description or examples; modifying existing presets (decode → change → rebuild → diff); explaining any `.rnp` in plain English; producing FILE/CONTENTS pairs; writing Pascal Script when native rules can't express the logic; verifying through the CLI harness on throwaway copies.

**Out of scope:** renaming Jay's real files (the skill builds presets; Jay runs them); editing ReNamer's `Settings.ini`; generating multi-row **Mapping** or multi-line **User Input** rules until calibration item C1 (§12) is closed.

## 3. Skill architecture (target layout)

```
fm-renamer-preset-creator/
├─ SKILL.md                      # workflow, hard rules, decision summary, known limits, pointers (lean)
├─ config.json                   # { "ReNamerPath": "C:\\Tools\\den4b Renamer", "PresetsSubfolder": "", "BackupDir": "%TEMP%\\rnp-backups" }
├─ references/
│  ├─ rnp-format.md              # verbatim from _spec/reference (+ link rewrites)
│  ├─ engine-notes.md            # verbatim from _spec/reference (+ link rewrites)
│  ├─ rule-selection.md          # §5 expanded, with worked examples
│  ├─ casing.md                  # §7 pipelines, dictionary selection, CamelCase rejoin
│  └─ pascal-script.md           # §9 patterns, skeletons, test recipe
├─ data/
│  ├─ casing-dictionary.tsv
│  ├─ camelcase-rejoin.tsv
│  └─ apa-minor-words.txt
├─ assets/
│  ├─ pascal/                    # BOM-stripped copies of Jay's field-tested scripts (see engine-notes §6)
│  │  ├─ serialize-duplicates-nopad.pas   (+ -pad2, -pad3, -pad4; GUI-only, Jay's v5)
│  │  └─ serialize-duplicates-stock.pas   # den4b's single-pass `Serialize duplicates.pas`, CLI-safe
│  └─ filters/                   # FILE.ini and CONTENTS.ini [Filters] blocks (§6.2)
├─ scripts/
│  ├─ Build-RnpPreset.ps1        # preset-spec JSON → .rnp (encoding, defaults, casing tail, dictionary, filters)
│  ├─ Test-RnpPreset.ps1         # validator / linter (§10.3); non-zero exit on errors
│  ├─ ConvertFrom-Rnp.ps1        # .rnp → preset-spec JSON + Markdown explanation (explain + modify flows)
│  └─ Invoke-RnpProbe.ps1        # CLI harness (provided, tested)
└─ tests/
   ├─ rule-semantics.probes.psd1        # provided regression suite
   ├─ acceptance-reference.probes.psd1  # provided reference solutions
   ├─ Test-RnpEncoderRoundTrip.ps1      # provided encoder proof
   └─ acceptance/*.json                 # §11 scenarios as preset-specs with fixtures
```

**Draft frontmatter:**
```yaml
name: fm-renamer-preset-creator
description: Create, modify, explain and verify den4b ReNamer presets (.rnp) for any batch-renaming job: cleanup,
  casing (APA title case + brand dictionary), prefixes/suffixes, serialization, dates, regex and Pascal Script, following
  Futuremotion FILE/CONTENTS naming and filter conventions. Use whenever ReNamer, .rnp files, rename presets or rename
  rule sets are mentioned.
```

**Scripting language (decision D1, default applied):** PowerShell 7.4+ for all scripts. It is Jay's primary stack, the harness is Windows-only anyway, and he will maintain these. Fallback when no PowerShell is available (e.g. claude.ai sandbox): Claude writes the `.rnp` by hand using `rnp-format.md` §1.2/§4 and reads the TSVs directly. Presets built that way must say they are **unverified**.

---

## 4. Operating workflow (what the skill does per request)

### 4.1 Intake: examples first
The most common failure is building the right rules for the wrong interpretation. Before designing anything, the skill must hold **3–8 concrete `before → after` pairs**, including at least one awkward case (extra dots, brackets, digits, mixed case, already-correct names). These pairs become the preset-spec `tests` (§10.1).
- If Jay gave examples, restate them as a fixture table and ask only about genuine gaps.
- If he gave none, **invent representative pairs from the description and ask him to confirm or correct them.** This is one message, not a questionnaire.
- Also settle, with defaults when unattended:

| Question | Default when not specified |
|---|---|
| Rename passed items, folder contents, or both? | **Both**: emit the `FILE` and `CONTENTS` pair (D2) |
| Restrict to extensions (masks)? | No masks |
| Casing policy? | `preserve`: keep existing case, fix brand casing from the default dictionary (core + proper tiers), lowercase the extension (§7) |
| Can the rules create duplicate names? | Analyse the stack (§8). If yes, ask which serializer padding to use; unattended → `nopad` + warning (D7) |
| Preset name? | Derive a Title Case name from the intent, e.g. `Remove Envato Timestamp` |

### 4.2 Design the rule stack
Use §5. Draft the stack as a numbered list with one line of intent per rule, and check it mentally against every fixture. Then apply the deletion test (§1.5) to every user-designed rule: if no fixture changes, the rule goes.

### 4.3 Author the preset-spec (JSON, §10.1)
Every rule gets a `comment` (it becomes ReNamer's rule comment). Omitted config keys take the defaults in `rnp-format.md` §3/§4; keys marked "—" there are required.

### 4.4 Build → 4.5 Validate → 4.6 Verify
`Build-RnpPreset.ps1` writes the `.rnp` to a **staging folder** (`%TEMP%\rnp-staging`), never straight into Presets. `Test-RnpPreset.ps1` must return 0 errors, fixing and rebuilding as needed. `Invoke-RnpProbe.ps1` then runs every test on throwaway files (§10.4), with the collision script stripped (§8). If the harness is unavailable, say so and mark the preset unverified.

### 4.7 Deliver
1. Target: `<ReNamerPath>\Presets\<Variant> <Name>.rnp` (portable install; subfolders allowed, e.g. `Presets\Icons\…`).
2. **Never overwrite silently.** If the file exists, show a rule-level diff (via `ConvertFrom-Rnp`), ask, and back the old file up to `config.BackupDir` first. Never back up inside `Presets\`: every `.rnp` there appears in ReNamer's menu.
3. Report in chat, in this format:
   - Files written (full paths).
   - A rule table: `# | Rule | Key settings (human words) | Why`.
   - A before → after table marked ✓ (harness-verified) or ◻ (verify in GUI).
   - Warnings: GUI-only parts, order-dependence (Serialize), review-tier dictionary terms used, legacy values avoided.
   - A one-line reminder of how to run it (e.g. context-menu wrapper → `ReNamer.exe /preset "<name>"`).

### 4.8 Explain / modify existing presets
`ConvertFrom-Rnp.ps1` decodes any `.rnp` into a preset-spec with `casing.mode: "verbatim"` and a Markdown explanation. For a change request: decode → edit the spec → rebuild → validate (`-Profile Legacy`, §10.3) → show a diff → verify → deliver. Round-tripping an untouched preset must reproduce it **byte-for-byte**. That property is an acceptance test (§11, T13).

---

## 5. Rule selection guide

**Pipeline order** (each stage is optional): **1** normalise separators/whitespace → **2** remove junk → **3** structural edits (insert / delete / rearrange / dates / numbers) → **4** casing tail (its last Case rule lowercases the extension, §7.1) → **5** collision script, always last (§8).

| Goal | Preferred rule(s) | Use instead when… | Pitfalls (see rnp-format §3) |
|---|---|---|---|
| Literal find → replace (one or many) | **Replace**, many pairs in one rule¹, `WHICH=3` | Pattern-based → RegEx | The n-th find pairs with the n-th replacement; `WHOLEWORDSONLY` treats `_` and digits as word characters |
| Remove literal junk | **Remove**, many targets in one rule¹ | Junk with variable content → RegEx or CleanUp brackets | — |
| Separators `_ . - + , %20` → spaces, collapse spaces | **CleanUp** (`SPACES*`, `SPACESFIX`, `SPACESSKIPVERSIONS` for `v1.2.3`) | Only one separator → Replace | CleanUp dots also hit version numbers unless SKIPVERSIONS |
| Remove `(…)` `[…]` `{…}` with content | **CleanUp** `BRACKETS*` | Keep content, drop brackets → Strip `CHECKBRACKETS` | — |
| Split CamelCase | **CleanUp** `INSERTSPACEBEFORECAPITALS` + one **Replace** of rejoin pairs from `camelcase-rejoin.tsv` (§7.5) | A brand glued to digits or to a lowercase word (`iPhone15Pro`, `BackupToiCloud`) → a protected-split Pascal script (future asset, §9) | CleanUp alone splits brands (`GitHub` → `Git Hub`) and digit-glued capitals (`Model3D` → `Model3 D`) |
| Prefix / suffix / insert at position | **Insert** (`WHERE` 1/2/4) | Around specific text → Insert WHERE 5/6 (every occurrence) or RegEx | Never WHERE=3 |
| Insert folder name, dates, tags | **Insert** with `:File_FolderName:` etc. | Needs formatting logic → Pascal `CalculateMetaTagFormat` | Meta tag syntax is `:Tag:` |
| Delete by position, delimiter, first/last word | **Delete** (`RIGHTTOLEFT` for "last") | Conditional → RegEx | `LEAVEDELIMITER=0` also deletes the delimiter |
| Reorder parts (`A - B` → `B - A`) | **Rearrange** (`DELIMITERTYPE=2` exact pattern for safety) | Irregular → RegEx with groups | Type 0 silently drops unreferenced parts |
| Reformat or shift dates | **Reformat Date** (several source formats allowed¹) | Date is ambiguous → RegEx with guards | `nn` = minutes; never `ADJUSTTIMEPART=0` |
| Zero-pad / unpad numbers | **Padding** | Only some numbers (track no. but not year) → RegEx or Pascal | Padding hits **every** digit run |
| Numbering | **Serialize** (`RESETIFFOLDERCHANGES` for per-folder) | — | Depends on file-table order |
| Change or append extension | **Extension** (no leading dot) | Only certain extensions → RegEx with `SKIPEXTENSION=0` (T12; pattern in §11) | `.md` → `x..md` |
| Strip character classes / Unicode ranges | **Strip** | — | Brackets keep their content |
| Transliterate | **Translit** with the map *text* embedded | — | `ADJUSTCASE=1` for case-insensitive matching |
| Casing | The casing tail (§7.3) | A one-off Case rule in the user rules (T14) | See §7 |
| Conditional, stateful, cross-file, or lookup-driven logic | **Pascal Script** | Anything a native rule can do natively | §9 |

¹ Separators: Remove/Replace use the three characters `*|*` between targets; Reformat Date `SOURCEFORMATS` and Rearrange `DELIMETERS` use a single `|`.

**Composition principles**
- **One readable RegEx beats five Replace rules; for literal finds, one Replace rule with many `*|*` pairs beats both.** This is the biggest lever for small presets.
- **Don't fight earlier rules.** If rule 7 undoes rule 3, redesign.
- **Anchor RegEx rules** (`^`, `$`, lookarounds) so they can't fire on unrelated parts of other files in the batch.
- **Guard numeric patterns** against resolutions (`1920x1080`), dates and versions. Jay's version-string rules in `00 Clean Up Filename` are the starting model (T6), but they also turn dates into versions (`Invoice 2024-05-01` → `Invoice v2024.05.01` ✓ observed), and so would T6's reference regex for a space-separated date. Add a date guard (a 19xx/20xx year followed by a month ≤ 12 and a day ≤ 31) unless the request says otherwise.
- **Prefer `SKIPEXTENSION=1` everywhere** unless the extension itself is the target.

---

## 6. Jay's conventions (mandatory)

### 6.1 Naming
- `CONTENTS <Name>.rnp`: renames the **contents** of passed folders (recursive).
- `FILE <Name>.rnp`: renames exactly the passed files **and** folders, never their contents.
- `<Name>` is Title Case and descriptive, verb-first where natural (`FILE Delete Last Word Dash`, `CONTENTS Prefix Folder Name`). Topic sub-prefixes such as `CASE` are used in his library (`FILE CASE Kebab`). **Observed:** `UI` marks templates meant to be edited before running (e.g. `FILE UI Prefix` inserts a placeholder `KEY `). Confirm with Jay (D5) before generating `UI` presets.
- The name must be a valid Windows filename, with no `\ / : * ? " < > |`.

### 6.2 `[Filters]`: always included, determined by the variant
Use the two blocks in `rnp-format.md` §2 verbatim (FILE: `0/1/0/1/1/0/0`, CONTENTS: `1/0/1/1/1/0/0`, empty masks). Values are **raw** text (masks like `*.jpg;*.png`). A request may add masks, which apply to both variants.

### 6.3 Extension always lowercase
The preset must **guarantee** a lowercase extension (§7.1). `EXTENSIONALWAYSUPPERCASE` is always `0`.

### 6.4 Rule comments
Every rule gets a short `Comment=` stating its intent (`Strip Envato UTC timestamp`). They show in ReNamer's rules list, so Jay can read a preset at a glance. The collision script's comment also carries the `[fm-collision]` marker (§8).

### 6.5 Style fidelity
Emit exactly what ReNamer would save: canonical key order (`rnp-format.md` §4), all keys present, CRLF, no BOM, `Marked=1`, sections from `[Rule0]`. A preset the skill writes should be indistinguishable from one Jay saved in the GUI.

---

## 7. Casing system

### 7.1 Lowercase-extension guarantee (validator-enforced)
1. The **last Case rule** in the stack has `EXTENSIONALWAYSLOWERCASE=1` and `EXTENSIONALWAYSUPPERCASE=0`.
2. After that rule, only two kinds of rule may follow: (a) rules whose Config contains `SKIPEXTENSION=1` (e.g. the title-case RegEx fix-ups, the kebab Replace), and (b) the collision script, identified by the `[fm-collision]` marker in its comment (§8). Rules without a SKIPEXTENSION key (Extension, PascalScript) or with `SKIPEXTENSION=0` may not follow it.
3. **Append only when needed.** If the user rules plus the casing tail already satisfy 1–2, the builder appends nothing. Otherwise (e.g. mode `none` with no Case rule) it appends Jay's standard rule, comment `Extension always lower case`:
   ```text
   Case  WHAT=0  PRESERVECASE=0  SKIPEXTENSION=1  EXTENSIONALWAYSLOWERCASE=1  EXTENSIONALWAYSUPPERCASE=0  FORCECASE=0  FRAGMENTSTEXT=
   ```
4. With a collision script, the order is: user rules → casing tail → collision script (the very last rule).

### 7.2 Dictionary selection (`data/casing-dictionary.tsv`)
Tiers (see `casing-dictionary-review.md`): `core` = non-trivial casing that doesn't collide with ordinary words (`GitHub`, `iOS`, `.NET`); `proper` = plain capitalized names (`Google`, `Blender`), a no-op under Capitalize Every Word but meaningful in preserve and sentence modes; `review` = collides with ordinary words (`Apple`, `Word`, `Spring`), opt-in only. The preset-spec's `casing.dictionary` object (§10.1) drives this deterministic selection:

```text
mode defaults   preserve, sentence → tiers [core, proper] · title → tiers [core] · other modes → no dictionary
                sources [base, added] · optInPacks [] · reviewTerms [] · extraTerms []
select rows     (source ∈ sources AND tier ∈ tiers)
            OR  (pack ∈ optInPacks AND tier ∈ tiers)                -- an opted-in pack adds its legacy rows
            OR  (pack ∈ optInPacks AND pack ∈ {roman, code})        -- review-only packs: opting in is the justification
            OR  (tier = review AND term ∈ reviewTerms)              -- case-insensitive; unknown or non-review name → error
add             extraTerms                                          -- containing a comma, or empty → error
drop            terms whose lowercase is an APA minor word          -- warn
dedupe          case-insensitively; precedence extraTerms > reviewTerms > base > added > legacy
sort            by whitespace-token count ↑, then character length ↑, then ordinal ↑
emit            FRAGMENTSTEXT = [22 minor words in file order, title mode only] + sorted terms, joined with ","
```

- **Why this sort:** overlapping fragments apply in list order and the later one wins (✓), so phrases (`Visual Studio Code`) must come after their parts (`Visual Studio`). The ordinal tie-break makes builds byte-reproducible.
- **Opt-in packs:** `audio`, `media`, `design`, `legacy-tech`, `brand`, `roman`, `code`, only when the request's domain calls for them. Name every review-tier term used in the report.
- **Size (verified at full scale ✓):** title default = 1,892 terms + 22 minor words ≈ 16.5 KB raw / 20.4 KB encoded (T4b); preserve default = 2,444 terms ≈ 21.0 KB raw / 26.0 KB encoded (T5b). Comparable to Jay's current 2,171-entry "Main Case" rule, so no performance concern. *(v2.1 numbers. After the 2026-09-28 expansion: title 8,199 terms ≈ 81 KB raw, preserve 11,299 ≈ 116 KB, ≈ 16–19 ms/file vs ≈ 4 ms; see `references/casing.md` for the lean `"sources": ["base"]` option.)*
- **Known limits** (verified): underscores and digits glue words together, so run separator normalisation (CleanUp/Replace) *before* the Case rule; plurals need their own entries (`API` ≠ `APIs`); fragments can't contain commas.

### 7.3 Casing modes (the builder's `casing.mode`)

The builder appends the mode's rules **after** the user rules. Every Case rule it emits has `SKIPEXTENSION=1`, `EXTENSIONALWAYSLOWERCASE=1`, `EXTENSIONALWAYSUPPERCASE=0`.

| mode | Rules appended | Default dictionary tiers | Notes |
|---|---|---|---|
| `none` | The standard ext-lowercase Case rule, only if §7.1 isn't already met | — | For stacks without casing (T1) or with their own Case rule (T14) |
| `preserve` *(default)* | 1 Case rule: `WHAT=0 PRESERVECASE=1 FORCECASE=1` + fragments | core, proper | Mirrors Jay's "Main Case": fixes brand casing, touches nothing else. T5/T5b ✓ |
| `title` | 4 rules, see the block below | core | APA. T4/T4b ✓ |
| `sentence` | 1 Case rule: `WHAT=7 PRESERVECASE=0 FORCECASE=1` + fragments | core, proper | Sentence case lowercases proper nouns, which is why `proper` matters here. It also capitalizes after `. ` ✓ |
| `lower` / `upper` | 1 Case rule: `WHAT=1` / `WHAT=2`, no fragments | — | — |
| `kebab` / `snake` | CleanUp (`_`, `-`, `%20` → space; fix spaces) → Case `WHAT=1` → Replace space → `-` / `_` | — | T3 ✓. Jay's `FILE CASE Kebab` minus its redundant `--` rule |
| `verbatim` | Nothing | — | Explain/modify flows only (§4.8): rules are emitted exactly as given |

**Title pipeline** (verified end-to-end ✓ with the full default dictionary, T4b):
```text
① Case   WHAT=3  PRESERVECASE=1  FORCECASE=1  FRAGMENTSTEXT=<minor words + dictionary, §7.2>
② RegEx  EXPRESSION  ^(?!(?:<LC>)\b)(\p{Ll})
         REPLACE     \U$1                                   first word of the title
③ RegEx  EXPRESSION  ( - | – | — )(?!(?:<LC>)\b)(\p{Ll})
         REPLACE     $1\U$2                                 first word of a subtitle
④ RegEx  EXPRESSION  (\s)(?!(?:<LC>)\b)(\p{Ll})(\p{L}*)$
         REPLACE     $1\U$2$3                               last word (lastWordRule / D4; omit ④ to disable)
   ②–④ all use CASESENSITIVE=1 and SKIPEXTENSION=1.
   Empty <LC>: drop the whole (?!(?:<LC>)\b) group, giving  ^(\p{Ll})   ( - | – | — )(\p{Ll})   (\s)(\p{Ll})(\p{L}*)$
   (an empty alternation matches everywhere and would silently disable every fix-up).
```
- `<LC>` = the selected **dictionary** terms (never the minor words, or ② would stop capitalizing a leading "the") that begin with a lowercase letter (`iPhone`, `npm`, `macOS`; 163 in the default title selection), each regex-escaped (a backslash before any of `\ ^ $ . | ? * + ( ) [ ] { }`), sorted by length ↓ then ordinal ↑, joined with `|` (≈ 1.2 KB). It keeps brand casing intact through the fix-ups. The validator warns if an `<LC>` term ends in a non-word character, where `\b` misbehaves (none do in the default selection).
- `casing.preserveCase: false` sets ① `PRESERVECASE=0`. Use it only when names arrive in ALL CAPS: it also destroys correct internal capitals the dictionary doesn't know.

### 7.4 APA notes
- Minor words (lowercase *inside* a title): `and as but for if nor or so yet · a an the · at by in of off on per to up via` (`data/apa-minor-words.txt`).
- APA capitalizes the first word of the title and of any subtitle (after ` - `, ` – `, ` — `; colons can't occur in filenames), both halves of hyphenated major words (ReNamer does this ✓), and every word of four or more letters (`With`, `From`).
- **Last-word capitalization is Jay's stated rule, not APA** (it comes from Chicago/AP). It's kept as the default (D4) and can be turned off with `lastWordRule: false`.
- Known limit: the pipeline can't tell a particle ("Set **Up** the Server") from a preposition ("Walk **up** the hill"), so `up` stays lowercase mid-title. A future Pascal APA rule (§9) could handle a phrasal-verb list.

### 7.5 CamelCase rejoin (`data/camelcase-rejoin.tsv`)
- **Problem:** CleanUp `INSERTSPACEBEFORECAPITALS` is the best native splitter (acronym-aware: `HTMLParser` → `HTML Parser` ✓), but it also splits brands (`GitHub` → `Git Hub` ✓, T10a), and a Case fragment can't join two words.
- **Data:** for every core dictionary term that ReNamer splits, the TSV records the exact split ReNamer produced (observed by running the splitter over all of them, not predicted). `kind=brand` (419) = compound brands and technical terms never written apart (`GitHub`, `iPhone`, `APIs`, `macOS`, `SpaceX`): the default set. `kind=review` (845) = names often written as separate words (`Google Drive`, `Adobe Photoshop`, `Samsung Galaxy S`): include only rows the request names.
- **Emission:** requested with `camelCaseRejoin.enabled` (§10.1). The builder inserts one Replace rule immediately after the first user CleanUp rule with `INSERTSPACEBEFORECAPITALS=1` (error if there is none):
  ```text
  Replace  TEXTWHAT=<splits joined with *|*>   TEXTWITH=<terms joined with *|*, same order>
           WHICH=3  CASESENSITIVE=1  WHOLEWORDSONLY=1  USEWILDCARDS=0  SKIPEXTENSION=1
  pairs    kind=brand + the review rows named in camelCaseRejoin.includeReview, sorted by token count ↓, then length ↓, then ordinal ↑
  ```
  Longest first, so a three-word split rejoins before a two-word split it contains. `CASESENSITIVE=1` because the split keeps the term's capitals exactly; `WHOLEWORDSONLY=1` so `Git Hub` inside `Git Hubs` is left alone.
- **Digit-capital repair** (`camelCaseRejoin.repairDigitCapitals`; use it when fixtures contain a letter+digit run followed by a capital). CleanUp also splits a capital off a digit (`Model3D` → `Model3 D`, `Render4K` → `Render4 K` ✓), which no dictionary pair can fix. One RegEx **after** the rejoin Replace repairs it:
  ```text
  RegEx  EXPRESSION  (\p{L}\d+) (\p{Lu})(?=\s|$)
         REPLACE     $1$2                CASESENSITIVE=1  SKIPEXTENSION=1
  ```
  It only rejoins a single capital that ends a word and follows letters+digits, so `Win10 Pro` and an already-spaced `Track 1 A` are left alone (T10d ✓).
- **Verified ✓:** T10c runs all 419 brand pairs (≈ 8.7 KB raw / 13.7 KB encoded) on five names, including one whose base name must stay unchanged.
- **Limits (verified, T10e):** a brand glued to digits is not rejoined, because `WHOLEWORDSONLY` treats digits as word characters (`iPhone15ProReview` → `i Phone15 Pro Review`, `PowerShell7Guide` → `Power Shell7 Guide`), and neither is a lowercase word glued to the next capital (`BackupToiCloud` → `Backup Toi Cloud`). Report these in the before → after table; closing them needs the protected-split script in §9. Terms ReNamer doesn't split need no pair. **Coverage is the default dictionary only** (core tier, `base` + `added`, no spaces: 1,264 terms). The 1,683 CamelCase-style core terms in legacy packs have no pairs, so when a request combines opt-in packs with the CamelCase split, warn in the report (or regenerate with `make-probe --sources base,added,legacy`).
- **Maintenance:** after dictionary changes, regenerate with `tools/camelcase-rejoin/classify-rejoin.py`: `make-probe` writes the split-map probe from the dictionary, the harness runs it, `classify` pairs and classifies the result (its rules are documented in the script). Verified end-to-end: a live run reproduces the shipped TSV byte-for-byte. Only the TSV ships in the skill.

---

## 8. Collisions and serialization

- **Detect risk:** any rule that removes or normalises information (timestamps, counters, brackets, case folding, separator changes) can merge distinct names. When risk exists, add colliding inputs to the tests.
- **Default remedy:** append Jay's **`serialize-duplicates-<pad>.pas`** (`nopad|pad2|pad3|pad4`) as the **last** rule, BOM stripped, embedded via `SOURCEUTF8`, with a comment ending in the marker `[fm-collision]`, e.g. `Serialize duplicates, no padding (GUI only: preview twice) [fm-collision]`. The validator uses the marker to recognise it (§7.1, §10.3). Tell Jay in the report: **GUI-only, preview twice** (learning pass, then serializing pass), uses the shared tally file, and doesn't work from `/silent` or "rename with preset" shortcuts.
- **CLI-safe alternative** (when the preset must run unattended): den4b's stock single-pass `Serialize duplicates.pas` (`collisions: "stock"`; appends ` (2)`, ` (3)` … to the 2nd and later occurrences per its docs, so probe it once before first use; it also carries the `[fm-collision]` marker) or Serialize with `RESETIFFILENAMECHANGES=1` (numbers every file, requires adjacency). Offer these only on request.
- **Verification** (the harness runs the preset **without** a GUI-only serializer; the CLI-safe `stock` script stays in, and its tests assert the final serialized names):
  1. Each colliding input as **its own test**, asserting its pre-serialization name. This proves the upstream rules.
  2. One **batch test** with all colliding inputs, asserting `expectExit: 1` and unchanged names. ReNamer refuses conflicting new names ✓, so this proves the collision is real and the serializer is needed.
  3. The serializer itself is marked ◻ "verify in GUI". T14 + T14a–c demonstrate the pattern.

## 9. Pascal Script policy
- **Use it when native rules can't express the logic:** conditions on name structure, cross-file state, external lookups (dictionary files), per-file meta tag formatting, or when it replaces 4+ fragile rules with one clear script.
- **Write it** from the skeleton in `engine-notes.md` §2: a `CONFIG` `const` block at the top, comments for skimmability, `Wide*` functions throughout, nested `if`s for index guards (no short-circuit evaluation), no dialogs unless the preset is explicitly GUI-only, no `{$INCLUDE}`.
- **Embed** with `SOURCEUTF8` (BOM stripped, CRLF). **Verify** with the harness: a compile error shows up as a non-zero exit code with names unchanged, which the harness's exit-code assertion catches.
- **Existing assets:** the serializers are ready to embed. Jay's old CamelCase scripts are retired (Appendix B #4); don't use or port them.
- **Future assets** worth creating once the skill exists (not required for v1):
  - `camelcase-protected-split.pas`: find dictionary terms first (case-sensitive; not preceded by a letter, not followed by a lowercase letter), protect them, then split the rest. It closes the §7.5 limits (`iPhone15Pro`, `BackupToiCloud`). Embed the term list in a `CONFIG` block generated from `camelcase-rejoin.tsv` so the preset stays self-contained, and prove it against T10c–T10e before shipping.
  - `apa-title-case.pas`: full APA, including a phrasal-verb list and dictionary protection.
  - `casing-from-dictionary-file.pas`: reads the TSV at runtime, generalising Jay's `CasingCorrector.pas` approach.

---

## 10. Tooling to build

### 10.1 Preset-spec (the skill's internal representation)
```jsonc
{
  "name": "Remove Envato Timestamp",            // Title Case; the variant prefix is added by the builder
  "variants": ["FILE", "CONTENTS"],              // one or both
  "filters": { "Masks": "*.zip;*.rar" },         // partial overrides merged into each variant's block (§6.2).
                                                 // verbatim mode: the complete block, written as-is; null = no [Filters] section
  "casing": {
    "mode": "preserve",                          // none|preserve|title|sentence|lower|upper|kebab|snake|verbatim (§7.3)
    "dictionary": {                              // §7.2; omit any field to get the mode's default
      "sources": ["base", "added"],
      "tiers": ["core", "proper"],
      "optInPacks": [],                          // audio|media|design|legacy-tech|brand|roman|code
      "reviewTerms": [],                         // review-tier terms to include, by name
      "extraTerms": []                           // ad-hoc terms not in the TSV
    },
    "preserveCase": true,                        // title mode only: rule ① PRESERVECASE (§7.3)
    "lastWordRule": true                         // title mode only (D4)
  },
  "camelCaseRejoin": { "enabled": false, "includeReview": [], "repairDigitCapitals": false },   // §7.5; includeReview lists review-row terms, e.g. "GoogleDrive"
  "collisions": "none",                          // none|nopad|pad2|pad3|pad4|stock (§8)
  "rules": [                                     // user-designed rules; the casing tail + collision rule are appended by the builder
    { "id": "RegEx", "comment": "Strip trailing Envato UTC timestamp (hyphen or space separated)", "marked": 1,
      "config": { "EXPRESSION": "[-\\s]\\d{4}(?:[-\\s]\\d{2}){5}[-\\s]utc$", "REPLACE": "", "CASESENSITIVE": 0 } }
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
- **Rules:** `marked` defaults to 1. Omitted config keys get the defaults of `rnp-format.md` §4; required keys ("—") must be present. In `verbatim` mode nothing is filled in and config keys are written in the order given.
- **Tests** mirror the harness's case fields 1:1. `files`: relative paths to create (trailing `\` = folder). `inputs`: what to pass to ReNamer (default: all `files`; `.` = the test's root folder). `expect`: every relative path after the run, folders included with a trailing `\`; order-insensitive, case-sensitive. `expectExit`: default 0. `variant`: which built preset runs the test (default `FILE` if built, else `CONTENTS`). Shorthand `{ "in": x, "out": y }` = `{ "files": [x], "expect": [y] + every parent folder of y (with a trailing `\`) }`, because the harness lists folders too (T1: `Icons\home.SVG` → expect `Icons\`, `Icons\Icons home.svg`).

### 10.2 `Build-RnpPreset.ps1`
Input: a preset-spec path (or JSON via pipeline). Steps: fill defaults (rnp-format §4; never for required keys) → insert the CamelCase rejoin rule and, if requested, the digit-capital repair after it (§7.5) → append the casing tail (§7.3), then the ext rule only if §7.1 needs it, then the collision rule (§8) → select, sort and join dictionary terms (§7.2) → encode values (rnp-format §1.2) → number sections from 0 → append the variant's `[Filters]` block → write one `.rnp` per variant (UTF-8 no BOM, CRLF) to staging → emit a build summary object (paths, rule count, fragment count and size, warnings). Switch `-SkipCollisionRule` writes the harness copy without a GUI-only serializer. Deterministic: the same spec must produce byte-identical output.

### 10.3 `Test-RnpPreset.ps1` (validator / linter)
Errors fail the build; warnings go into the report. Two profiles: **`-Profile Strict`** (default; every generated preset) and **`-Profile Legacy`** (decoded existing presets in the explain/modify flows): checks 1, 3, 4, 6, 7, 8 and 14 drop to warnings (older presets can lack `Comment=` lines, which only exist since 7.6.0.1, and may use legacy values or key orders), so Jay's presets can be explained and edited, while rules the skill adds or changes must still pass Strict.

| # | Check | Level |
|---|---|---|
| 1 | Sections `[Rule0..N]` contiguous; each has ID/Config/Marked/Comment; CRLF; no BOM; trailing CRLF | error |
| 2 | `ID` ∈ the 18 IDs (an unknown ID is **silently skipped** by ReNamer ✓) | error |
| 3 | Config keys exactly equal the canonical set for that ID, in canonical order (`rnp-format.md` §4), uppercase | error |
| 4 | Enum values valid; legacy values rejected: Insert `WHERE=3`, Serialize `WHERE=3`, Case `WHAT=6`, ReformatDate `ADJUSTTIMEPART=0`, Serialize `TYPE=2` | error |
| 5 | Every value round-trips through decode(encode(v)); no raw `;` `:` inside values | error |
| 6 | Lowercase-extension guarantee (§7.1): last Case rule sets ext-lowercase; only `SKIPEXTENSION=1` rules or the `[fm-collision]` script after it; `EXTENSIONALWAYSUPPERCASE=0` everywhere | error |
| 7 | `[Filters]` present and equal to the variant block (+ declared mask overrides); masks not percent-encoded | error |
| 8 | File name is `FILE <Name>.rnp` or `CONTENTS <Name>.rnp` (§6.1) and Windows-valid | error |
| 9 | `EXTENSION` without a leading dot; ReformatDate `TARGETFORMAT` without filename-illegal chars | error |
| 10 | Fragments: no empty/duplicate (case-insensitive) entries, no commas, no minor-word/dictionary clashes; report count and size | warn |
| 11 | RegEx: empty alternation `(?:)` (e.g. an empty `<LC>`) → error; `\E` in `REPLACE`, case-dependent `EXPRESSION` with `CASESENSITIVE=0`, and a `$` in `REPLACE` not followed by a digit or `{` (literal `$` must be `\$`) → warn | error / warn |
| 12 | Pascal: BOM present; dialog calls (→ GUI-only); `{$INCLUDE}`; `and`/`or` next to `[` index access (short-circuit hazard) | warn |
| 13 | Order-dependent rules (Serialize, UserInput) → warn; ✗-unresolved features (multi-row Mapping, multi-line UserInput) → error | warn / error |
| 14 | `[fm-collision]` script present but not last, or more than one | error |
| 15 | Every rule has a non-empty comment | warn |

### 10.4 `Invoke-RnpProbe.ps1` (provided) + test runs
Already built and tested (see its help). It asserts both the resulting names and the exit code, because a preset that fails to load leaves every name unchanged, so an "unchanged" expectation alone would pass a broken preset. Extend it with `-Preset <path> -Tests <json>` so it runs preset-spec `tests` directly (one isolated folder per test; `files`/`inputs`/`expect`/`expectExit` map to `Files`/`Inputs`/`Expect`/`ExpectExit`). Keep its safety behaviour: `%TEMP%` only, Settings.ini snapshot/restore, Presets drift report, non-zero exit on any failure.

### 10.5 `ConvertFrom-Rnp.ps1`
Decodes a `.rnp` into (a) a preset-spec (`casing.mode: "verbatim"`, `collisions: "none"`, each rule's `marked`, config keys in file order, `filters` verbatim or `null` when absent) and (b) a Markdown explanation with one human sentence per rule. Lossless: rebuilding must be byte-identical. If a preset contains anything the spec can't represent, fail loudly instead of approximating. Used by the explain and modify flows.

---

## 11. Acceptance suite (evals)
Turn each row into `tests/acceptance/<id>.json`: a preset-spec with `casing.mode` and `collisions` pinned as in the table, `rules` left empty for the skill to design, and the fixtures as `tests`. The skill passes when every generated preset validates, its tests pass in the harness, and its rule count is ≤ "Max rules" (counting every rule in the built preset, including the casing tail and the collision script). Every budget has been proven achievable by `acceptance-reference.probes.psd1`.

| id | Request (as Jay might phrase it) | casing / collisions | Fixtures (in → out) | Max rules | Expected design |
|---|---|---|---|---|---|
| T1 | "Prefix files with their folder name" | none / none | `Icons\home.SVG` → `Icons\Icons home.svg` | 2 | Insert `:File_FolderName: ` + ext Case |
| T2 | "Strip Envato timestamps" | none / none | `Retro Pack-2024-05-01-10-20-30-utc.zip` → `Retro Pack.zip`; `Film LUT 2024 05 01 10 20 30 UTC.CUBE` → `Film LUT.cube` | 2 | One anchored RegEx (below) + ext Case |
| T3 | "Kebab-case everything" | kebab / none | `My Cool_File v2.PNG` → `my-cool-file-v2.png`; `already-kebab.svg` → unchanged | 3 | The kebab tail (§7.3) |
| T4 | "APA title case with my dictionary" | title / none | `the ultimate guide to javascript and typescript apis.pdf` → `The Ultimate Guide to JavaScript and TypeScript APIs.pdf`; `iphone photography - a guide for beginners.PDF` → `iPhone Photography - A Guide for Beginners.pdf` | 4 | §7.3 title pipeline |
| T5 | "Fix brand casing only, touch nothing else" | preserve / none | `learn github and node.js basics.md` → `learn GitHub and Node.js basics.md` | 1 | preserve tail |
| T6 | "Turn spaced version numbers into v-dotted" | none / none | `Blender 4 2 1 Setup.exe` → `Blender v4.2.1 Setup.exe`; `Tool 2 0 1 5.zip` → `Tool v2.0.1.5.zip`; `Wallpaper 1920 1080.jpg` → unchanged | 3 | Guarded RegEx per group count (below; Jay's model) + ext Case |
| T7 | "Number files per folder, 2-digit, after the folder name" (CONTENTS only) | none / none | `Textures\a.jpg`, `Textures\b.jpg` → `Textures\Textures 01.jpg`, `Textures\Textures 02.jpg` | 4 | Delete whole base name (pos 1 till end) → Insert folder → Serialize (suffix, reset per folder, pad 2) → ext Case |
| T8 | "US dates to ISO" | none / none | `Invoice 12-31-2025.pdf` → `Invoice 2025-12-31.pdf` | 2 | Reformat Date `mm-dd-yyyy` → `yyyy-mm-dd` + ext Case |
| T9 | "Clean YouTube download names" | none / none | `Song_Name%20(Official Video) [HD].MP4` → `Song Name.mp4` | 2 | CleanUp (brackets, `_`, `%20`, fix spaces) + ext Case |
| T10 | "Split CamelCase but keep brands" | none / none, `camelCaseRejoin.enabled` | `MyGitHubProjectHTMLExport.zip` → `My GitHub Project HTML Export.zip` | 3 | CleanUp split + one Replace of `kind=brand` rejoin pairs (§7.5) + ext Case |
| T11 | "Swap 'Artist - Title' to 'Title - Artist'" | none / none | `Daft Punk - One More Time.mp3` → `One More Time - Daft Punk.mp3` | 2 | Rearrange, exact pattern, delimiter ` - `, pattern `$2 - $1` |
| T12 | "Normalise .jpeg/.jpe to .jpg" | none / none | `photo.JPEG` → `photo.jpg`; `scan.jpe` → `scan.jpg`; `doc.pdf` unchanged | 2 | RegEx on the extension (below) + ext Case; no masks needed |
| T13 | "Explain and round-trip `CONTENTS 00 Clean Up Filename.rnp`" | verbatim / none | Decode → rebuild is byte-identical; explanation lists all 26 rules | — | `ConvertFrom-Rnp` + `Build-RnpPreset` |
| T14 | "Remove the download counter and serialize duplicates" | none / nopad | Batch `Save (2).svg`, `Save-3.svg`, `save.svg` → exit 1, nothing renamed; each alone → `Save.svg`; GUI with serializer → `Save 1.svg`, `Save 2.svg`, `Save 3.svg` | 3 | RegEx (below) → Case capitalize (its ext-lowercase satisfies §7.1) → serializer `nopad`, last |

**Reference patterns** (verified; copy from here, not from a table):
```text
T2   EXPRESSION  [-\s]\d{4}(?:[-\s]\d{2}){5}[-\s]utc$                    REPLACE  (empty)         CASESENSITIVE=0
T6   EXPRESSION  (^|\s)(\d{1,4}) (\d{1,5}) (\d{1,5}) (\d{1,5})(?=\s|$)   REPLACE  $1v$2.$3.$4.$5  (4 groups, runs first)
     EXPRESSION  (^|\s)(\d{1,4}) (\d{1,5}) (\d{1,5})(?=\s|$)             REPLACE  $1v$2.$3.$4     (3 groups)
T12  EXPRESSION  \.jpe(?:g)?$                                            REPLACE  .jpg            SKIPEXTENSION=0, CASESENSITIVE=0
T14  EXPRESSION   *(\(\d+\)|-\d+)$                                       REPLACE  (empty)         (the pattern starts with a space)
```

**Reference probes** (`acceptance-reference.probes.psd1`, 22, all pass): T1–T9, T11, T12 and T14 as specified, plus **T4b** (title pipeline with the full default dictionary and 163-term `<LC>`), **T5b** (preserve with the full 2,444-term default), **T10a** (negative: CleanUp alone gives `My Git Hub …`), **T10b** (3 hand-picked rejoin pairs), **T10c** (all 419 brand pairs), **T10d** (rejoin + digit-capital repair, in order), **T10e** (the §7.5 limits, asserted as they are) and **T14a–c** (each colliding input alone, §8). T13 has no probe: it is checked by rebuilding.

---

## 12. Open items

**Calibration (Jay, ~2 minutes in the GUI):**
- ~~**C1:** Save one throwaway preset containing a two-row Mapping and a two-line User Input.~~ **Closed 2026-09-28.** Both presets were saved from the GUI into `_spec\calibration\` (`C1 Calibration Mapping UserInput.rnp`, `C1b Calibration Special Chars.rnp`) and probed (`_spec\calibration\c1-probes.psd1`). Mapping rows are encoded one by one and joined with a raw `|`; User Input lines are joined with a bare CR (`%0D`). The skill's `references/rnp-format.md` §1.2 and §3.17–3.18 hold the verified format, and `tests/rule-semantics.probes.psd1` now asserts all 155 cases.

**Decisions (defaults already applied; change any):**

| # | Decision | Default in this spec |
|---|---|---|
| D1 | Script language | PowerShell 7.4+ throughout |
| D2 | Emit both FILE and CONTENTS variants by default | Yes |
| D3 | Where presets are written | Staging → `C:\Tools\den4b Renamer\Presets\` after confirmation; backups to `%TEMP%\rnp-backups` |
| D4 | Capitalize the last word in title case (Chicago rule) | Yes (your v1 rule) |
| D5 | Meaning of the `UI` prefix | "Template to edit before running": skill asks before using it |
| D6 | Dictionary default | Sources `base` + `added`; tiers `core` + `proper` for preserve/sentence, `core` for title; legacy packs opt-in |
| D7 | Default serializer padding when unattended | `nopad` |
| D8 | CamelCase rejoin default | `kind=brand` rows only; `review` rows via `camelCaseRejoin.includeReview` |

---

## Appendix A — Corrections to v1 (why v2 exists)

| v1 claim | Reality (verified on 7.10) |
|---|---|
| Values URL-encoded with `%20` for spaces | ReNamer writes **`+`** for spaces and `%XX` for **every** non-alphanumeric byte, including `- _ .` |
| "All Config variables require SKIPEXTENSION or RIGHTTOLEFT" | Keys differ per rule; Extension has no SKIPEXTENSION; RIGHTTOLEFT exists only on Insert, Delete, Rearrange |
| Insert `WHERE` 0 = prefix … 4 = before text | **1** prefix, **2** suffix, 4 position, 5 after text, 6 before text, 7 replace name (3 = legacy) |
| Delete `FROM_POS / TILL / TILL_POS / TILL_END` | `FROM, UNTIL, FROMPOSITION, UNTILCOUNT, FROMDELIMITER, UNTILDELIMITER, DELETECURRENTNAME, LEAVEDELIMITER` |
| Remove `CASE_SENSITIVE / REMOVE_ALL` | `TEXT, WHICH (1/2/3), CASESENSITIVE, USEWILDCARDS, WHOLEWORDSONLY` |
| Replace `FIND / REPLACE / REPLACE_ALL / WHOLE_WORDS` | `TEXTWHAT, TEXTWITH, WHICH, CASESENSITIVE, USEWILDCARDS, WHOLEWORDSONLY` |
| Rearrange `REARRANGE_BY / DELIMITER / POSITIONS / NEW_ORDER` | `DELIMITERTYPE (0/1/2), DELIMETERS` *(sic)*, `NEWPATTERN`; three split modes, `$-n` supported |
| Strip `DIGITS / SYMBOLS / BRACKETS / CHARS / INVERT` | `CHECK*` flags, `TEXTUSERDEFINED`, `TEXTUNICODERANGE`, `WHERE`, `STRIPALLEXCEPTSELECTED` |
| Case `TYPE 0–5`, newline-separated `FRAGMENTS` | `WHAT 0–7` (0 = none … 7 = sentence), **comma-only** `FRAGMENTSTEXT` (newline is not a separator ✓) |
| Serialize `TYPE 0–3` (incl. Roman), `RESET`, `PAD`, `WHERE 0–2` | `TYPE=1`; numeral system via `NUMERALSYSTEM 1–7`; `PADTOLENGTH(+VALUE)`; `RESETIF*`; `WHERE` 1/2/4/7 |
| Randomize `TYPE / CHARS` | `USEDIGITS, USEENGLISHLETTERS, USEUSERDEFINED, USERDEFINEDCHARS`, `WHERE` |
| Padding `TYPE / PAD_TO / CHAR / DIRECTION` | `NUMBERPADDING (0/1/2)`, `NUMBERPADDINGLENGTH`, `TEXTPADDING*` (position 1 left / 2 right) |
| Clean Up `STRIP_SPACES / FIX_INVERSIONS / STRIP_UNICODE / CAP_SHIFTS / SHAREPOINT` | 17 real keys (rnp-format §3.12); "fix inversions" doesn't exist |
| Translit `MAP` = map name, `REVERSE` | `ALPHABET` = the full map **text**; `DIRECTION` 1/2; `ADJUSTCASE` |
| RegEx `ID=RegularExpressions`, `EXPR` | `ID=RegEx`, `EXPRESSION` |
| Pascal `SCRIPT` | `SOURCEUTF8` |
| Meta tags like `<File Size>` | `:File_Size:` style |
| `[Filters]` masks are URL-encoded; "Default" column | Filter values are **raw** ✓ (encoded masks match nothing); defaults column dropped |
| Extension, Reformat Date, User Input, Mapping rules | Missing from v1; now fully documented |
| APA minor words (17) | APA lists 22 (adds `as, if, off, per, via`); "capitalize the last word" is Chicago/AP, not APA |
| Put APA minor words into Case fragments | Fragments also lowercase the **first and last** word (✓ reproduced), so fix-ups are required (§7.3) |
| Serialize-duplicate scripts: just append | GUI-only, preview twice, shared tally file, BOM must be stripped |

## Appendix B — Issues found in Jay's current presets
1. **`FILE CASE Capitalize All Preserve`, `CONTENTS CASE Capitalize All Preserve`, `FILE CASE Capitalize All`, `CONTENTS CASE Capitalize All`**: the second Case rule (`WHAT=5`, `PRESERVECASE=0`) re-lowercases everything after the first letter. "the lord of the rings with a guide" → **"The lord of the rings with a guide"** (✓ reproduced). *Jay fixed the two CONTENTS presets on 2026-09-27 (rule 2 now `PRESERVECASE=1`); the FILE twins exist only as the misnamed `Presets 02.rnp` / `Presets 03.rnp`.* Minimal fix: set `PRESERVECASE=1` on rule 2, which gives "The Lord of the Rings with a Guide" (the fragment list still lowercases `with` and `is`, which APA capitalizes). Better: replace both presets with the §7.3 title pipeline.
2. **`00 Clean Up Filename` → "Main Case"** contains `and`, so a name starting with "And …" is forced to "and …". Removed from the dictionary in v2.
3. Main dictionary had 3 duplicates (`TailwindCSS`, `FSharp`, `AirAsia`) and 84 collision-prone terms (see `casing-dictionary-review.md`).
4. **Retired 2026-09-27 (sent to the Recycle Bin; no preset embedded them):** `Scripts\00 CamelCase Separation with Exceptions.pas` checked `S[I + 1]` in the same `and` as its bounds check, and Pascal Script doesn't short-circuit, so a name ending in a capital after a digit or capital (`Test2A`, or any uppercase extension such as `logo.PNG`, since it ran on the extension too) raised "Out of string range". It knew 3 terms. `Scripts\CamelCaseSeparationWithExceptions.pas` never compiled: it called undefined `DoSomething`/`DoAnother`. §7.5 replaces both. `Seperate CamelCase with Whitelist.pas` (2023) was recycled the same day for the same reason.
