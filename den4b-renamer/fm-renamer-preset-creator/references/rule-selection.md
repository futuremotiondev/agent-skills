# Rule selection guide

> How to turn fixtures into the smallest readable rule stack. Exact keys, enums and defaults live in `rnp-format.md`;
> engine behaviour in `engine-notes.md`; casing in `casing.md`. ✓ = verified by probe on ReNamer 7.10 (the ID in
> brackets names the acceptance scenario or probe that proves it). ◐ = plausible but unverified: probe it before
> delivering. In Markdown tables, `\|` is an escaped `|`; patterns to copy exactly are in code blocks.

## 1. Pipeline order

Each stage is optional; rules chain in order and each sees the previous rule's output.

```text
1 normalise separators / whitespace   CleanUp, Replace
2 remove junk                          RegEx, Remove, CleanUp brackets
3 structural edits                     Insert, Delete, Rearrange, Reformat Date, Padding, Serialize, Extension
4 casing tail (builder)                its last Case rule lowercases the extension (casing.md §1)
5 collision script (builder)           always the very last rule (SKILL.md, collisions)
```

## 2. Which rule for which goal

| Goal | Preferred rule(s) | Use instead when… | Pitfalls |
|---|---|---|---|
| Literal find → replace (one or many) | **Replace**, many pairs in one rule¹, `WHICH=3` | Pattern-based → RegEx | The n-th find pairs with the n-th replacement; `WHOLEWORDSONLY` treats `_` and digits as word characters |
| Remove literal junk | **Remove**, many targets in one rule¹ | Variable content → RegEx or CleanUp brackets | — |
| Separators `_ . - + , %20` → spaces, collapse spaces | **CleanUp** (`SPACES*`, `SPACESFIX`, `SPACESSKIPVERSIONS` for `v1.2.3`) | Only one separator → Replace | CleanUp dots also hit version numbers unless SKIPVERSIONS |
| Remove `(…)` `[…]` `{…}` with content | **CleanUp** `BRACKETS*` | Keep content, drop brackets → Strip `CHECKBRACKETS` | — |
| Split CamelCase | **CleanUp** `INSERTSPACEBEFORECAPITALS` + `camelCaseRejoin` (casing.md §5) | Brand glued to digits (`iPhone15Pro`) → protected-split Pascal (future) | CleanUp alone splits brands (`GitHub` → `Git Hub`) |
| Prefix / suffix / insert at position | **Insert** (`WHERE` 1 prefix, 2 suffix, 4 position) | Around specific text → Insert `WHERE` 5/6 (every occurrence) or RegEx | Never `WHERE=3` (legacy) |
| Insert folder name, dates, tags | **Insert** with `:File_FolderName:` etc. | Needs formatting logic → Pascal `CalculateMetaTagFormat` | Meta tag syntax is `:Tag:`, never `<Tag>` |
| Delete by position, delimiter, first/last word | **Delete** (`RIGHTTOLEFT` for "last") | Conditional → RegEx | `LEAVEDELIMITER=0` also deletes the delimiter |
| Reorder parts (`A - B` → `B - A`) | **Rearrange** (`DELIMITERTYPE=2` exact pattern) | Irregular → RegEx with groups | Type 0 silently drops unreferenced parts |
| Reformat or shift dates | **Reformat Date** (several source formats¹) | Ambiguous date → RegEx with guards | `nn` = minutes; never `ADJUSTTIMEPART=0` |
| Zero-pad / unpad numbers | **Padding** | Only some numbers (track no., not year) → RegEx or Pascal | Padding hits **every** digit run |
| Numbering | **Serialize** (`RESETIFFOLDERCHANGES` for per-folder) | — | Depends on file-table order |
| Explicit old name → new name list | **Mapping** (`SOURCE`/`TARGET` as JSON arrays, same length) | Substrings inside names → Replace pairs | Whole-name match; rows must pair up (a missing TARGET row gives an empty name) |
| A typed list of new names, one per file | **User Input** (`INPUT` as a JSON array) | Names derivable from the old name → other rules | Line *n* → file *n* in file-table order; extra files keep their names |
| Change or append extension | **Extension** (no leading dot) | Only certain extensions → RegEx with `SKIPEXTENSION=0` | `.md` → `x..md` |
| Strip character classes / Unicode ranges | **Strip** | — | Brackets keep their content |
| Transliterate | **Translit** with the map *text* embedded | — | `ADJUSTCASE=1` for case-insensitive matching |
| Casing | The casing tail (`casing.mode`) | A one-off Case rule inside the user rules | casing.md |
| Duplicate names after cleanup | `collisions` (builder appends the serializer) | — | GUI-only unless `stock` |
| Conditional, stateful, cross-file or lookup logic | **Pascal Script** (`pascal-script.md`) | Anything a native rule can do | No short-circuit evaluation |

¹ Separators: Remove/Replace use the three characters `*|*` between targets; Reformat Date `SOURCEFORMATS` and
Rearrange `DELIMETERS` use a single `|`.

## 3. Composition principles

- **One readable RegEx beats five Replace rules; for literal finds, one Replace rule with many `*|*` pairs beats both.**
  This is the biggest lever for small presets.
- **Don't fight earlier rules.** If rule 7 undoes rule 3, redesign.
- **Anchor RegEx rules** (`^`, `$`, lookarounds) so they can't fire on unrelated parts of other files in the batch.
  With `SKIPEXTENSION=1`, `$` anchors before the extension ✓.
- **Guard numeric patterns** against resolutions (`1920 1080`), dates and versions. A pattern that turns spaced numbers
  into versions also turns a spaced date into one (`Invoice 2024 05 01` → `Invoice v2024.05.01`). Add a date guard
  (§5, pattern V2) unless the request says otherwise.
- **Prefer `SKIPEXTENSION=1` everywhere** unless the extension itself is the target.
- **Set `CASESENSITIVE=1`** on any RegEx whose pattern depends on letter case (`\p{Lu}`, `[A-Z]`); the default `0` makes
  letter classes match both cases (validator check 11).
- **Separator normalisation before casing:** `_` and digits glue words for Case fragments and `\b`.

## 4. Designing a stack (the method)

1. Write the fixtures first (SKILL.md, intake): 3–8 `before → after` pairs including awkward ones.
2. Draft the stack as a numbered list, one line of intent per rule, in the §1 order.
3. Walk every fixture through the list by hand, rule by rule.
4. **Deletion test:** for each user-designed rule, ask "if I remove it, does any fixture change?" If not, remove it.
   Builder-appended rules (casing tail, collision script) are exempt.
5. Look for merges: several Replace rules → one rule with `*|*` pairs; several similar RegEx rules → one alternation,
   if it stays readable.
6. Encode the stack as preset-spec `rules` (`preset-spec.md`) with a comment on every rule, then build, validate and
   run the fixtures in the harness.

## 5. Pattern library

Preset-spec rule objects (only non-default keys shown; the builder fills the rest). Copy the pattern, then prove it
with your own fixtures.

**P1 — prefix with the parent folder name ✓ [T01]** (`Icons\home.SVG` → `Icons\Icons home.svg`)
```json
{ "id": "Insert", "comment": "Prefix with parent folder name", "config": { "TEXT": ":File_FolderName: ", "WHERE": 1 } }
```

**P2 — strip a trailing timestamp, hyphen or space separated ✓ [T02]**
(`Retro Pack-2024-05-01-10-20-30-utc.zip` → `Retro Pack.zip`)
```json
{ "id": "RegEx", "comment": "Strip trailing Envato UTC timestamp",
  "config": { "EXPRESSION": "[-\\s]\\d{4}(?:[-\\s]\\d{2}){5}[-\\s]utc$", "REPLACE": "" } }
```

**P3 — strip browser duplicate counters ✓ [T14]** (`Save (2).svg`, `Save-3.svg` → `Save.svg`; pair with
`collisions`, because the results collide)
```json
{ "id": "RegEx", "comment": "Strip browser duplicate counters",
  "config": { "EXPRESSION": " *(\\(\\d+\\)|-\\d+)$", "REPLACE": "" } }
```

**V1 — spaced numbers to a dotted version ✓ [T06]** (`Blender 4 2 1 Setup.exe` → `Blender v4.2.1 Setup.exe`,
`Tool 2 0 1 5.zip` → `Tool v2.0.1.5.zip`, `Wallpaper 1920 1080.jpg` unchanged). The 4-group rule must run first.
```json
{ "id": "RegEx", "comment": "4-part version",
  "config": { "EXPRESSION": "(^|\\s)(\\d{1,4}) (\\d{1,5}) (\\d{1,5}) (\\d{1,5})(?=\\s|$)", "REPLACE": "$1v$2.$3.$4.$5" } },
{ "id": "RegEx", "comment": "3-part version",
  "config": { "EXPRESSION": "(^|\\s)(\\d{1,4}) (\\d{1,5}) (\\d{1,5})(?=\\s|$)", "REPLACE": "$1v$2.$3.$4" } }
```

**V2 — the same with a date guard ✓ [E02]** (keeps `Invoice 2024 05 01.pdf` and `Report 1999 12 31.pdf` as they are; `Build 2024 13 01` is
not a date, so it still becomes `v2024.13.01`). Replace the 3-group rule of V1 with:
```json
{ "id": "RegEx", "comment": "3-part version, not a y m d date",
  "config": { "EXPRESSION": "(^|\\s)(?!(?:19|20)\\d\\d (?:0?[1-9]|1[0-2]) (?:0?[1-9]|[12]\\d|3[01])(?=\\s|$))(\\d{1,4}) (\\d{1,5}) (\\d{1,5})(?=\\s|$)", "REPLACE": "$1v$2.$3.$4" } }
```

**S1 — number files per folder after the folder name ✓ [T07]** (CONTENTS; `Textures\a.jpg`, `Textures\b.jpg` →
`Textures 01.jpg`, `Textures 02.jpg`). Numbering follows the file-table sort order.
```json
{ "id": "Delete", "comment": "Delete the whole base name (pos 1 till end)", "config": { "UNTIL": 2 } },
{ "id": "Insert", "comment": "Folder name + space", "config": { "TEXT": ":File_FolderName: ", "WHERE": 1 } },
{ "id": "Serialize", "comment": "Number per folder, pad 2",
  "config": { "RESETIFFOLDERCHANGES": 1, "PADTOLENGTH": 1, "PADTOLENGTHVALUE": 2 } }
```

**D1 — US dates to ISO ✓ [T08]** (`Invoice 12-31-2025.pdf` → `Invoice 2025-12-31.pdf`)
```json
{ "id": "ReformatDate", "comment": "mm-dd-yyyy to yyyy-mm-dd",
  "config": { "SOURCEFORMATS": "mm-dd-yyyy", "TARGETFORMAT": "yyyy-mm-dd" } }
```

**C1 — clean download names ✓ [T09]** (`Song_Name%20(Official Video) [HD].MP4` → `Song Name.mp4`)
```json
{ "id": "CleanUp", "comment": "Drop bracketed junk, _ and %20 to spaces",
  "config": { "BRACKETSROUND": 1, "BRACKETSSQUARE": 1, "BRACKETSCURVY": 1, "SPACESUNDERSCORE": 1, "SPACESWEB": 1 } }
```

**C2 — split CamelCase, keep brands ✓ [T10, T10d]** (`MyGitHubProjectHTMLExport.zip` →
`My GitHub Project HTML Export.zip`): one CleanUp rule in `rules`, plus at the spec's top level
`"camelCaseRejoin": { "enabled": true }` (add `"repairDigitCapitals": true` for `Model3D`, `Render4K`).
```json
{ "id": "CleanUp", "comment": "Split CamelCase", "config": { "INSERTSPACEBEFORECAPITALS": 1 } }
```

**R1 — swap `Artist - Title` ✓ [T11]** (`Daft Punk - One More Time.mp3` → `One More Time - Daft Punk.mp3`).
`DELIMITERTYPE=2` only fires when the name has exactly that delimiter pattern.
```json
{ "id": "Rearrange", "comment": "Artist - Title to Title - Artist",
  "config": { "DELIMITERTYPE": 2, "DELIMETERS": " - ", "NEWPATTERN": "$2 - $1" } }
```

**E1 — normalise an extension family ✓ [T12]** (`photo.JPEG`, `scan.jpe` → `.jpg`; `doc.pdf` untouched; no masks
needed because the pattern only matches those extensions)
```json
{ "id": "RegEx", "comment": ".jpeg/.jpe to .jpg",
  "config": { "EXPRESSION": "\\.jpe(?:g)?$", "REPLACE": ".jpg", "SKIPEXTENSION": 0 } }
```

**K1 — capitalize words, keep existing capitals ✓ [T14]** (a one-off Case rule inside the user rules; its
ext-lowercase flag satisfies casing.md §1, so mode `none` appends nothing)
```json
{ "id": "Case", "comment": "Capitalize + extension lower", "config": { "WHAT": 3, "PRESERVECASE": 1 } }
```

**Delete reference ✓** (on `abc-def-ghi`, from `rnp-format.md` §3.2): position 2 + count 3 → `adef-ghi` · position 2 +
till end → `a` · from delimiter `-` to delimiter `-` → `abcghi` (with `LEAVEDELIMITER=1` → `abc--ghi`) · right-to-left
count 2 → `abc-def-g` · right-to-left until `-` → `abc-def` (delete the last word).

## 6. Choosing between near-equivalents

| Situation | Choose | Why |
|---|---|---|
| 1–3 literal substitutions | Replace with `*\|*` pairs | Readable in the GUI, no regex escaping |
| A pattern with variable digits or letters | RegEx | Replace wildcards can't capture and reinsert |
| Remove every bracket group | CleanUp `BRACKETS*` | One checkbox per bracket type, content included |
| Remove only `[HD]`-style tags | Remove with targets `[HD]*\|*[4K]` (literal) | Precise; CleanUp would also drop `(2019)` |
| Change case of one word only | RegEx with `\U$1` / `\L$1` and `CASESENSITIVE=1` | Case rules act on every word |
| Lookup table of old → new names | Mapping (whole names) or Replace pairs (parts of names) | Mapping replaces only exact whole-name matches, so an unexpected name is left alone |
