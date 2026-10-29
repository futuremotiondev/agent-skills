# Casing system

> How the builder handles letter case: the lowercase-extension guarantee, the casing dictionary, the casing modes (APA
> title case and friends) and the CamelCase rejoin. ✓ = verified by probe on ReNamer 7.10. The builder implements all of
> this; read this file to choose options, explain results, or reason about an edge case.
> In Markdown tables, `\|` is an escaped `|`. Every pattern that must be copied exactly is in a code block.

## 1. Lowercase-extension guarantee (validator check 6)

Jay's convention: every preset leaves the extension lowercase.

1. The **last active Case rule** in the stack has `EXTENSIONALWAYSLOWERCASE=1` and `EXTENSIONALWAYSUPPERCASE=0`.
2. After that rule only two kinds of rule may follow: (a) rules whose Config contains `SKIPEXTENSION=1` (the title-case
   RegEx fix-ups, the kebab Replace), and (b) the collision script, recognised by the `[fm-collision]` marker in its
   comment. Rules without a SKIPEXTENSION key (Extension, PascalScript) or with `SKIPEXTENSION=0` may not follow it.
3. **Append only when needed.** If the user rules plus the casing tail already satisfy 1–2, the builder appends nothing.
   Otherwise (e.g. mode `none` with no Case rule) it appends Jay's standard rule, comment `Extension always lower case`:
   ```text
   Case  WHAT=0  PRESERVECASE=0  SKIPEXTENSION=1  EXTENSIONALWAYSLOWERCASE=1  EXTENSIONALWAYSUPPERCASE=0  FORCECASE=0  FRAGMENTSTEXT=
   ```
4. With a collision script the order is: user rules → casing tail → collision script (always the very last rule).

Disabled rules (`Marked=0`) don't run, so the builder and validator ignore them for this check.

## 2. Dictionary selection (`data/casing-dictionary.tsv`)

**Tiers:** `core` = non-trivial casing that doesn't collide with ordinary words (`GitHub`, `iOS`, `.NET`) · `proper` =
plain capitalized names (`Google`, `Blender`), a no-op under Capitalize Every Word but meaningful in preserve and sentence
modes · `review` = collides with ordinary words (`Apple`, `Word`, `Spring`), opt-in only, by name.

**Sources:** `base` = Jay's old "Main Case" list (reviewed over years) · `added` = curated for this skill (acronym
plurals, AI/ML, dev, design, audio, media, formats, Apple) · `legacy` = auto-classified lists from Jay's old SMART
presets, never used by default; reachable through opt-in packs.

The preset-spec's `casing.dictionary` object drives this deterministic selection (implemented by
`Get-RnpDictionarySelection` in `scripts/RnpCommon.psm1`):

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

- **Why this sort:** overlapping fragments apply in list order and the later one wins ✓, so phrases (`Visual Studio
  Code`) must come after their parts (`Visual Studio`). The ordinal tie-break makes builds byte-reproducible.
- **Opt-in packs:** `audio`, `media`, `design`, `legacy-tech`, `brand`, `roman`, `code`, only when the request's domain
  calls for them (an audio-plugin folder → `audio`). Name every review-tier term used in the report.
- **Size and speed (verified at full scale ✓, dictionary expansion 2026-09-28):** title default = 8,199 terms + 22
  minor words ≈ 81 KB raw (preset ≈ 105 KB); preserve default = 11,299 terms ≈ 116 KB raw. ReNamer handles it, but the
  Case rule's cost grows linearly with the term count: ≈ 16 ms/file (title) and ≈ 19 ms/file (preserve), measured on
  1,000 files, versus ≈ 4 ms/file with the pre-expansion 1,892/2,444-term lists. Context-menu batches of a few dozen
  files stay under a second. For batches of thousands, build a lean selection instead: `"sources": ["base"]` plus the
  `optInPacks` the folder needs (e.g. `ai`, `dev`, `audio`); a pack opt-in adds that pack's rows from every source.
- **Known limits ✓:** underscores and digits glue words together (`app_ios`, `ios2` are not matched), so run separator
  normalisation (CleanUp/Replace) *before* the Case rule; plurals need their own entries (`API` ≠ `APIs`); fragments
  can't contain commas.

**Matching rules of Case fragments ✓** (from `rnp-format.md` §3.8): applied after the WHAT transformation in the same
rule; case-insensitive and whole-word; multi-word and punctuated fragments work (`Visual Studio`, `.NET`, `C++`,
`Node.js`); the later of two overlapping fragments wins.

## 3. Casing modes (`casing.mode`)

The builder appends the mode's rules **after** the user rules. Every Case rule it emits has `SKIPEXTENSION=1`,
`EXTENSIONALWAYSLOWERCASE=1`, `EXTENSIONALWAYSUPPERCASE=0`.

| mode | Rules appended | Default dictionary tiers | Notes |
|---|---|---|---|
| `none` | The standard ext-lowercase Case rule, only if §1 isn't already met | — | Stacks without casing (T01) or with their own Case rule (T14) |
| `preserve` *(default)* | 1 Case rule: `WHAT=0 PRESERVECASE=1 FORCECASE=1` + fragments | core, proper | Mirrors Jay's "Main Case": fixes brand casing, touches nothing else (T05 ✓) |
| `title` | 4 rules, see the block below | core | APA (T04 ✓) |
| `sentence` | 1 Case rule: `WHAT=7 PRESERVECASE=0 FORCECASE=1` + fragments | core, proper | Lowercases proper nouns, which is why `proper` matters here. Also capitalizes after `. ` ✓ |
| `lower` / `upper` | 1 Case rule: `WHAT=1` / `WHAT=2`, no fragments | — | — |
| `kebab` / `snake` | CleanUp (`_`, `-`, `%20` → space; fix spaces) → Case `WHAT=1` → Replace space → `-` / `_` | — | T03 ✓ |
| `verbatim` | Nothing | — | Explain/modify flows only: rules are written exactly as given |

**Title pipeline** (verified end-to-end ✓ with the full default dictionary):
```text
① Case   WHAT=3  PRESERVECASE=1  FORCECASE=1  FRAGMENTSTEXT=<minor words + dictionary, §2>
② RegEx  EXPRESSION  ^(?!(?:<LC>)\b)(\p{Ll})
         REPLACE     \U$1                                   first word of the title
③ RegEx  EXPRESSION  ( - | – | — )(?!(?:<LC>)\b)(\p{Ll})
         REPLACE     $1\U$2                                 first word of a subtitle
④ RegEx  EXPRESSION  (\s)(?!(?:<LC>)\b)(\p{Ll})(\p{L}*)$
         REPLACE     $1\U$2$3                               last word (lastWordRule, D4; false omits ④)
   ②–④ all use CASESENSITIVE=1 and SKIPEXTENSION=1.
   Empty <LC>: drop the whole (?!(?:<LC>)\b) group, giving  ^(\p{Ll})   ( - | – | — )(\p{Ll})   (\s)(\p{Ll})(\p{L}*)$
   (an empty alternation matches everywhere and would silently disable every fix-up; validator check 11 errors on it).
```

- **Why the fix-ups exist:** minor-word fragments also lowercase the *first* and *last* word of a title ✓ ("the" at the
  start becomes "the"), so ②–④ put the capitals back.
- `<LC>` = the selected **dictionary** terms (never the minor words, or ② would stop capitalizing a leading "the") that
  begin with a lowercase letter (`iPhone`, `npm`, `macOS`; 762 in the default title selection), each regex-escaped (a
  backslash before any of `\ ^ $ . | ? * + ( ) [ ] { }`), sorted by length ↓ then ordinal ↑, joined with `|` (≈ 7 KB since the 2026-09-28 expansion; T04 ✓).
  It keeps brand casing intact through the fix-ups. The builder warns if an `<LC>` term ends in a non-word character,
  where `\b` misbehaves (none do in the default selection).
- `casing.preserveCase: false` sets ① `PRESERVECASE=0`. Use it only when names arrive in ALL CAPS: it also destroys
  correct internal capitals the dictionary doesn't know.

**Worked results ✓** (default dictionary):

| Input | title | preserve |
|---|---|---|
| `the ultimate guide to javascript and typescript apis.pdf` | `The Ultimate Guide to JavaScript and TypeScript APIs.pdf` | — |
| `iphone photography - a guide for beginners.PDF` | `iPhone Photography - A Guide for Beginners.pdf` | — |
| `npm tips and tricks for beginners.txt` | `npm Tips and Tricks for Beginners.txt` | — |
| `working with macos.md` | `Working With macOS.md` | — |
| `learn github and node.js basics.md` | — | `learn GitHub and Node.js basics.md` |
| `blender to figma export.PNG` | — | `Blender to Figma export.png` |

## 4. APA notes

- Minor words (lowercase *inside* a title): `and as but for if nor or so yet · a an the · at by in of off on per to up
  via` (`data/apa-minor-words.txt`, 22 words).
- APA capitalizes the first word of the title and of any subtitle (after ` - `, ` – `, ` — `; colons can't occur in
  filenames), both halves of hyphenated major words (ReNamer does this ✓), and every word of four or more letters
  (`With`, `From`).
- **Last-word capitalization is Jay's stated rule, not APA** (it comes from Chicago/AP). It's the default (D4) and can be
  turned off with `lastWordRule: false`.
- Known limit: the pipeline can't tell a particle ("Set **Up** the Server") from a preposition ("Walk **up** the hill"),
  so `up` stays lowercase mid-title. A future Pascal APA rule could handle a phrasal-verb list (`pascal-script.md`).
- Capitalize Every Word word starts ✓: after a space, `_`, `-`, `.`, `(`, `[`; not after an apostrophe (`O'neil`) or
  inside a digit-led token (`3d`, `2nd` stay lowercase).

## 5. CamelCase rejoin (`data/camelcase-rejoin.tsv`)

- **Problem:** CleanUp `INSERTSPACEBEFORECAPITALS` is the best native splitter (acronym-aware: `HTMLParser` →
  `HTML Parser` ✓), but it also splits brands (`GitHub` → `Git Hub` ✓), and a Case fragment can't join two words.
- **Data:** for every core dictionary term that ReNamer splits, the TSV records the exact split ReNamer produced
  (observed, not predicted). `kind=brand` (1,131) = compound brands and technical terms never written apart (`GitHub`,
  `iPhone`, `APIs`, `macOS`, `SpaceX`): the default set (D8). `kind=review` (2,640) = names often written as separate words
  (`Google Drive`, `Adobe Photoshop`): include only rows the request names.
- **Emission** (`camelCaseRejoin.enabled`): the builder inserts one Replace rule immediately after the **first** user
  CleanUp rule with `INSERTSPACEBEFORECAPITALS=1` (error if there is none):
  ```text
  Replace  TEXTWHAT=<splits joined with *|*>   TEXTWITH=<terms joined with *|*, same order>
           WHICH=3  CASESENSITIVE=1  WHOLEWORDSONLY=1  USEWILDCARDS=0  SKIPEXTENSION=1
  pairs    kind=brand + the review rows named in camelCaseRejoin.includeReview (by term, e.g. GoogleDrive),
           sorted by token count ↓, then length ↓, then ordinal ↑
  ```
  Longest first, so a three-word split rejoins before a two-word split it contains. `CASESENSITIVE=1` because the split
  keeps the term's capitals exactly; `WHOLEWORDSONLY=1` so `Git Hub` inside `Git Hubs` is left alone.
- **Digit-capital repair** (`camelCaseRejoin.repairDigitCapitals`; use it when fixtures contain a letter+digit run
  followed by a capital). CleanUp also splits a capital off a digit (`Model3D` → `Model3 D`, `Render4K` → `Render4 K` ✓),
  which no dictionary pair can fix. One RegEx **after** the rejoin Replace repairs it:
  ```text
  RegEx  EXPRESSION  (\p{L}\d+) (\p{Lu})(?=\s|$)
         REPLACE     $1$2                CASESENSITIVE=1  SKIPEXTENSION=1
  ```
  It only rejoins a single capital that ends a word and follows letters+digits, so `Win10 Pro` and an already-spaced
  `Track 1 A` are left alone ✓.
- **Verified ✓:** all brand pairs on five names, including one whose base name must stay unchanged:
  `MyGitHubProjectHTMLExport.zip` → `My GitHub Project HTML Export.zip` (419 pairs originally, T10c; all 1,131 pairs
  ≈ 14 KB raw after the 2026-09-28 expansion, T10 ✓).
- **Limits ✓ — report them in the before → after table:** a brand glued to digits is not rejoined, because
  `WHOLEWORDSONLY` treats digits as word characters (`iPhone15ProReview` → `i Phone15 Pro Review`, `PowerShell7Guide` →
  `Power Shell7 Guide`), and neither is a lowercase word glued to the next capital (`BackupToiCloud` →
  `Backup Toi Cloud`). Closing them needs the protected-split Pascal script (`pascal-script.md`, future assets). Terms
  ReNamer doesn't split need no pair. **Coverage is the default dictionary only** (core tier, `base` + `added`, no
  spaces: 3,771 terms). CamelCase-style core terms in legacy packs have no pairs, so when a request combines opt-in
  packs with the CamelCase split, warn in the report.
- **Maintenance:** after dictionary changes, regenerate the TSV with the tools in `_spec\tools\camelcase-rejoin\`
  (`classify-rejoin.py make-probe` → run the probe with `scripts/Invoke-RnpProbe.ps1` and write the resulting names
  one per line to `splitmap-out.txt` → `classify-rejoin.py classify`). The tool's root is `_spec\`: it reads and
  writes `_spec\data\`, so copy both TSVs from `_spec\data\` to `data\` afterwards (never the other way round).
  A live run reproduces the shipped TSV byte-for-byte.

## 6. Data file formats

| File | Format |
|---|---|
| `data/casing-dictionary.tsv` | UTF-8, tab-separated, header row `term tier pack source note` (tab-separated), no comment lines. `tier` ∈ core/proper/review; `source` ∈ base/added/legacy; `pack` names a topic (general, dev, ai, design, audio, media, formats, apple, plural, legacy-tech, brand, roman, code; since 2026-09-28 also 3d, business, cloud, education, gaming, geo, hardware, internet, mobile, network, org, os, security, units, web). Rows are ordered by tier (core, proper, review), then pack, then term (case-insensitive). 15,528 rows. |
| `data/camelcase-rejoin.tsv` | UTF-8, tab-separated, header row `split term kind` (tab-separated). `split` = the exact text CleanUp produced; `kind` ∈ brand/review. 3,771 rows. |
| `data/apa-minor-words.txt` | One word per line, `#` lines are comments. The file order is the emission order. |

**Editing the dictionary** (Jay's call, never silently by the skill): add a row with the exact casing, `tier` `core`
for non-trivial casing or `proper` for a plain capitalized name, `source` `added`. Terms must not contain commas or
filename-illegal characters. A term that collides with an ordinary English word, a common word in Spanish, German,
French, Italian or Portuguese (song titles), or a common given name belongs in `review`. After editing,
regenerate the rejoin TSV (§5) if the new term is CamelCase. The curation history and open review items are in
`_spec\data\casing-dictionary-review.md`.
