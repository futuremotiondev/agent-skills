# ReNamer `.rnp` preset format — verified reference

> **Status:** verified against **den4b ReNamer 7.10.0.0 (portable, `C:\Tools\den4b Renamer`)** on 2026-09-27.
> Evidence: (1) the 158 real presets in `Presets\` and `Presets Disabled\`, (2) the published property names of every
> `TRuleConfig*` class inside `ReNamer.exe`, and (3) **155 asserting probe cases, all passing**, run through `ReNamer.exe /silent /rename`
> (`../tests/rule-semantics.probes.psd1`, run with `../scripts/Invoke-RnpProbe.ps1`; each case asserts the resulting names *and* the exit code). The value encoder in §1.2
> reproduces **6,860 of 6,860** Config/Comment values from those 158 presets byte-for-byte (`../tests/Test-RnpEncoderRoundTrip.ps1`).
> Every value below is marked:
> **✓** = asserted by a probe · **◐** = key confirmed from real presets/binary, meaning from docs or observation only (not asserted) · **✗** = unresolved.
> Re-run the probe suite after every ReNamer update; if anything fails, this file is out of date.
>
> **Reading tables:** inside a Markdown table cell, `\|` is an escaped pipe. The real character is a single `|`: the Remove/Replace
> multi-find separator is the three characters `*|*`, and Rearrange/Reformat Date lists are separated by `|`.

---

## 1. File anatomy

```ini
[Rule0]
ID=Insert
Config=TEXT:%3AFile%5FFolderName%3A+;WHERE:1;POSITION:1;INSERTAFTERTEXT:;INSERTBEFORETEXT:;RIGHTTOLEFT:0;SKIPEXTENSION:1
Marked=1
Comment=Prefix+with+parent+folder+name

[Rule1]
ID=Case
Config=WHAT:0;PRESERVECASE:0;SKIPEXTENSION:1;EXTENSIONALWAYSLOWERCASE:1;EXTENSIONALWAYSUPPERCASE:0;FORCECASE:0;FRAGMENTSTEXT:
Marked=1
Comment=Extension+always+lower+case

[Filters]
AddFilesFromFolders=1
AddFoldersAsFiles=0
IncludeSubfolders=1
IncludeHidden=1
IncludeSystem=1
SkipRootFoldersAsFiles=0
MasksOnFileName=0
Masks=
MasksExclude=
```

| Aspect | What ReNamer writes (emit exactly this) | What the loader tolerates (don't rely on it) |
|---|---|---|
| Encoding | UTF-8 **without BOM**. Values are percent-encoded, so files are effectively ASCII. | — |
| Line endings | CRLF, file ends with CRLF, one blank line between sections. | LF. |
| Rule sections | `[Rule0]` … `[RuleN]`, contiguous from 0, in execution order. | ✓ Numbering may start at 1 or contain gaps; rules still run in ascending numeric order. |
| Keys per rule | `ID=`, `Config=`, `Marked=`, `Comment=` in that order. | ✓ Missing `Marked=` → treated as marked. |
| `ID=` | One of the 18 IDs in §3 (case-sensitive). | ✓ **An unknown ID is silently skipped** — the preset loads but the rule is missing. The validator must reject unknown IDs. |
| `Marked=` | `1` = enabled, `0` = disabled (kept but skipped ✓). | — |
| `Comment=` | Percent-encoded free text shown in the rules list (column since 7.6.0.1). Encoded like a Config value ✓. | Empty `Comment=` is fine. |
| `[Filters]` | Optional, last section. Present when the preset was saved with filter settings. Values are **raw, NOT percent-encoded** ✓ (a mask of `%2A.txt` matches nothing). | — |

### 1.1 `Config=` syntax

`Config=KEY:value;KEY:value;…`

- Keys are **UPPERCASE and case-sensitive** ✓ — `text:` is ignored and the rule falls back to defaults.
- Key order does not affect parsing ✓, but always emit the **canonical order** in §3. That is the order ReNamer writes, so presets diff cleanly against GUI-saved ones.
- Missing keys fall back to internal defaults ✓. Still emit every key: it keeps presets explicit and reviewable.
- Booleans are `0` / `1`. Integers are plain decimal. Negative values are allowed where they make sense (e.g. `ADJUSTTIMEBY:-2` ✓).

### 1.2 Value encoding (writer contract)

Encode the value's **UTF-8 bytes** one by one:

| Byte | Output |
|---|---|
| `A–Z`, `a–z`, `0–9` | literal |
| space (0x20) | `+` |
| **every other byte** — including `- _ . ~ * ( ) ' ! , ; : $ % + /` and all non-ASCII bytes | `%XX`, **uppercase** hex |

Examples: `Illustrator 2025 ` → `Illustrator+2025+` · `:MP3_Artist:` → `%3AMP3%5FArtist%3A` · `$2 - $1` → `%242+%2D+%241` · `é` → `%C3%A9` · CRLF → `%0D%0A`.

The reader is more lenient ✓: it also accepts `%20`, lowercase hex, and raw `- _ .` or spaces. Ignore that leniency. **`;` and `:` inside a value must always be encoded** (`%3B`, `%3A`), otherwise the Config line breaks. Multi-line Pascal source and Translit alphabets use CRLF (`%0D%0A`) between lines.

**Two list formats that differ** (verified from GUI-saved presets, 2026-09-28; the samples are in `_spec\calibration\`):
- **User Input `INPUT`:** lines are joined with a **bare CR** before encoding, so the file shows `%0D` between lines (`one+two%0Da%26b+%28c%29`). CRLF or LF between lines makes ReNamer refuse the whole batch ✓.
- **Mapping `SOURCE` / `TARGET`:** the **only exception to this encoder.** Each row is encoded on its own and the rows are joined with a **raw `|`**, never `%7C` ✓. An encoded `%7C` is read as a literal pipe, so it does not start a new row ✓. File names can't contain `|`, so the separator is unambiguous.
  ```text
  rows      SOURCE: a b-c.d , é&(1)        TARGET: x y_z , ok, 50%
  written   SOURCE:a+b%2Dc%2Ed|%C3%A9%26%281%29;TARGET:x+y%5Fz|ok%2C+50%25
  ```
  `ConvertTo-RnpConfigValue` in `../scripts/RnpCommon.psm1` implements this; the writer, the validator and the encoder test all use it.

**Reference implementation (PowerShell 7):**
```powershell
function ConvertTo-RnpValue([string] $Value) {
    $sb = [Text.StringBuilder]::new()
    foreach ($b in [Text.Encoding]::UTF8.GetBytes($Value)) {
        if (($b -ge 48 -and $b -le 57) -or ($b -ge 65 -and $b -le 90) -or ($b -ge 97 -and $b -le 122)) { [void]$sb.Append([char]$b) }
        elseif ($b -eq 32) { [void]$sb.Append('+') }
        else { [void]$sb.Append(('%{0:X2}' -f $b)) }
    }
    $sb.ToString()
}
# Decoding: [Uri]::UnescapeDataString($v.Replace('+', ' '))
```

---

## 2. `[Filters]` section

These settings apply to items added to ReNamer while the preset is loaded: drag-and-drop, the CLI, "Rename with preset" shortcuts and context-menu launches. They have no effect on files that were already in the table.

| Key | Meaning (✓ = probed) |
|---|---|
| `AddFilesFromFolders` | When a folder is added, add the files it contains ✓. |
| `AddFoldersAsFiles` | When a folder is added, add the folder itself as a renamable item ✓. |
| `IncludeSubfolders` | Recurse into subfolders when scanning an added folder ✓. |
| `IncludeHidden` / `IncludeSystem` | Include items with the Hidden / System attribute ◐. |
| `SkipRootFoldersAsFiles` | With `AddFoldersAsFiles=1` and `IncludeSubfolders=1`, skip the top-level folder and rename only its subfolders ◐. |
| `MasksOnFileName` | `1` = masks test the file name only ✓; `0` = masks test the full path ✓ (`*\sub\*` matches `sub\c.txt` only with `0`). Extension masks like `*.txt` behave the same either way ✓. |
| `Masks` / `MasksExclude` | `;`-separated wildcard lists, **raw** (e.g. `*.jpg;*.png`) ✓. Empty = no filtering. |

**Jay's two canonical blocks** (from his presets; these are the defaults the skill emits):

| Variant | AddFilesFromFolders | AddFoldersAsFiles | IncludeSubfolders | IncludeHidden | IncludeSystem | SkipRootFoldersAsFiles | MasksOnFileName |
|---|---|---|---|---|---|---|---|
| **`CONTENTS …`**: renames what is *inside* the passed folders (recursively) | 1 | 0 | 1 | 1 | 1 | 0 | 0 |
| **`FILE …`**: renames exactly the passed files *and* folders, never their contents ✓ | 0 | 1 | 0 | 1 | 1 | 0 | 0 |

Probe evidence: a CONTENTS block with `Masks=*.txt` renamed `a.txt` and `sub\c.txt` but not `b.png`. A FILE block renamed the passed folder `sub` → `x sub` and left `sub\c.txt` untouched.

---

## 3. Rule reference (all 18 rules)

Tables group related keys for readability; the **authoritative write order is the §4 template line** for each rule (it matches what ReNamer saves). The "Skill default" column is what the builder emits when a request doesn't specify the key. Those defaults are Jay's conventions, not necessarily ReNamer's GUI defaults. **"—" means required**: there is no default; the preset-spec must state the value explicitly (an explicit empty string is allowed where it makes sense, e.g. RegEx `REPLACE` or Replace `TEXTWITH`), and the builder errors if the key is missing.

### 3.1 Insert — `ID=Insert`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `TEXT` | str | Text to insert. May contain meta tags written as **`:Tag_Name:`** ✓ (e.g. `:File_FolderName:`), never `<Tag>`. | — |
| `WHERE` | enum | **1** prefix ✓ · **2** suffix ✓ (before the extension when `SKIPEXTENSION=1`, after it when `0` ✓) · **3** legacy, behaves as suffix-before-extension even with `SKIPEXTENSION=0` ✓ (**never emit**) · **4** at position ✓ · **5** after text ✓ (inserts after **every** occurrence) · **6** before text ✓ (also every occurrence: `a-b-c` → `aX-bX-c` ✓) · **7** replace current name ✓ · 0 = no-op | — |
| `POSITION` | int | 1-based ✓. With `RIGHTTOLEFT=1` it counts from the right: pos 3 on `hello world` → `hello worXld` ✓ | 1 |
| `INSERTAFTERTEXT` | str | Used by WHERE=5 | empty |
| `INSERTBEFORETEXT` | str | Used by WHERE=6 | empty |
| `RIGHTTOLEFT` | bool | Affects position counting | 0 |
| `SKIPEXTENSION` | bool | | 1 |

### 3.2 Delete — `ID=Delete`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `FROM` | enum | **1** from position ✓ · **2** from delimiter ✓ | 1 |
| `UNTIL` | enum | **1** count of characters ✓ · **2** till the end ✓ · **3** until delimiter ✓ | — |
| `FROMPOSITION` | int | 1-based; the character *at* this position is deleted ✓ | 1 |
| `UNTILCOUNT` | int | Number of characters to delete, counted from FROMPOSITION ✓ | 1 |
| `FROMDELIMITER` / `UNTILDELIMITER` | str | Any text, e.g. `-`, ` ` ✓ | empty |
| `DELETECURRENTNAME` | bool | Deletes the whole name ✓. Later rules can rebuild it (Jay uses this with Insert `:File_FolderName:`). | 0 |
| `RIGHTTOLEFT` | bool | Delete the last N chars (`UNTIL=1`) ✓ or the last word (`UNTIL=3` + delimiter) ✓ | 0 |
| `SKIPEXTENSION` | bool | | 1 |
| `LEAVEDELIMITER` | bool | 0 = delimiters are deleted with the range ✓ · 1 = delimiters are kept ✓ | 0 |

Probe table on `abc-def-ghi`: pos2+count3 → `adef-ghi` · pos2+till end → `a` · delim `-` to delim `-` → `abcghi` (with LEAVEDELIMITER=1 → `abc--ghi`) · RTL count 2 → `abc-def-g` · RTL until `-` → `abc-def`.

### 3.3 Remove — `ID=Remove`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `TEXT` | str | Several targets separated by `*\|*` | — |
| `WHICH` | enum | **1** first ✓ · **2** last ✓ · **3** all ✓ · 0 = no-op | 3 |
| `SKIPEXTENSION` | bool | | 1 |
| `CASESENSITIVE` | bool | | 0 |
| `USEWILDCARDS` | bool | `*` `?` `[a-z]`; `+` is literal (since 7.4.0.1) | 0 |
| `WHOLEWORDSONLY` | bool | Word boundaries: space/hyphen/punctuation are boundaries; **`_` and digits are word characters** ✓ | 0 |

### 3.4 Replace — `ID=Replace`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `TEXTWHAT` | str | Find text. Several finds separated by `*\|*` ✓ | — |
| `TEXTWITH` | str | Replacement. With `*\|*`, the n-th replacement pairs with the n-th find ✓. A single replacement applies to every find. May contain meta tags. | — |
| `WHICH` | enum | **1** first ✓ · **2** last ✓ · **3** all ✓ · 0 = no-op ✓ | 3 |
| `SKIPEXTENSION` | bool | | 1 |
| `CASESENSITIVE` | bool | | 0 |
| `USEWILDCARDS` | bool | ✓ `c*d` on `abc123def` → `ab_ef` | 0 |
| `WHOLEWORDSONLY` | bool | ✓ `cat` in `cat catalog cat-dog` → `dog catalog dog-dog` | 0 |

Batch many literal substitutions into **one** Replace rule with `*|*`. This is the single most effective way to keep presets small.

### 3.5 Rearrange — `ID=Rearrange`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `DELIMITERTYPE` | enum | **0** delimiters ✓ (any of the `\|`-separated delimiters) · **1** positions ✓ (`4\|7` = parts start at 1, 4, 7) · **2** exact pattern of delimiters ✓ (N delimiters → exactly N+1 parts) | 0 |
| `RIGHTTOLEFT` | bool | Split from the right | 0 |
| `DELIMETERS` | str | **Misspelled key, exactly as ReNamer writes it.** List separated by `\|` (encoded `%7C`) | — |
| `NEWPATTERN` | str | `$0` whole name, `$1…$n`, `$-1…` from the end ✓, literal text, meta tags. Parts you don't reference are dropped (watch out with DELIMITERTYPE=0). | — |
| `SKIPEXTENSION` | bool | | 1 |

### 3.6 Extension — `ID=Extension` (no SKIPEXTENSION key)
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `NEWEXTENSION` | bool | 1 = set a new extension ✓ | 1 |
| `EXTENSION` | str | **Without the leading dot** — `.md` produces `x..md` ✓ | — |
| `APPEND` | bool | 1 = append instead of replace (`x.txt.md`) ✓ | 0 |
| `USEBINSIGN` | bool | Detect the extension from the file's binary signature ◐ | 0 |
| `REMOVEDUPLICATES` | bool | `y.jpg.JPG` → `y.jpg` ✓ | 0 |
| `CASESENSITIVE` | bool | For duplicate detection | 0 |

### 3.7 Strip — `ID=Strip`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `CHECKENGLISHLETTERS` | bool | a–z | 0 |
| `CHECKDIGITS` | bool | 0–9 | 0 |
| `CHECKSYMBOLS` | bool | ``!"#$%&'*+,-./:;=?@^_`\|~`` (whole ASCII symbol range since 7.6.0.3) | 0 |
| `CHECKBRACKETS` | bool | `(){}[]<>`. Only the bracket characters are removed; to remove their content too, use CleanUp | 0 |
| `CHECKUSERDEFINED` + `TEXTUSERDEFINED` | bool + str | Custom character set ✓ | 0 / empty |
| `CHECKUNICODERANGE` + `TEXTUNICODERANGE` | bool + str | Hex code points, ranges with `-`, lists with `,` (e.g. `200B,200C,200D,FEFF`, `10000-10FFFF`) ✓ | 0 / empty |
| `WHERE` | enum | **0** everywhere ✓ · **1** leading ✓ · **2** trailing ✓ | 0 |
| `STRIPALLEXCEPTSELECTED` | bool | Invert: keep only the selected sets ✓ | 0 |
| `CASESENSITIVE` | bool | | 0 |
| `SKIPEXTENSION` | bool | | 1 |

Canonical order (differs from the grouping above): `CHECKENGLISHLETTERS;CHECKDIGITS;CHECKSYMBOLS;CHECKBRACKETS;CHECKUSERDEFINED;CHECKUNICODERANGE;TEXTUSERDEFINED;TEXTUNICODERANGE;WHERE;STRIPALLEXCEPTSELECTED;CASESENSITIVE;SKIPEXTENSION`.

### 3.8 Case — `ID=Case`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `WHAT` | enum | **0** (none of the above) ✓ · **1** all lower ✓ · **2** ALL UPPER ✓ · **3** Capitalize Every Word ✓ · **4** iNVERT cASE ✓ · **5** First letter capital ✓ · **6** legacy "capitalize and preserve", equivalent to 3 + PRESERVECASE=1 ✓ (`hello wORLD` → `Hello WORLD`; **never emit**, it only appears in pre-7.5 presets) · **7** Sentence case ✓ (capitalizes after `. ` too: with PRESERVECASE=1, `hello World. second PART` → `Hello World. Second PART` ✓) | 0 |
| `PRESERVECASE` | bool | Skip the lowercasing step for 3/5/7 ✓ (irrelevant for 0/1/2/4). Note: WHAT=3 still uppercases every word's first letter, so `iPhone` → `IPhone` and `macOS` → `MacOS` ✓. Forced fragments fix that. The casing modes in `casing.md` §3 set it explicitly. | 0 |
| `SKIPEXTENSION` | bool | | 1 |
| `EXTENSIONALWAYSLOWERCASE` | bool | ✓ | **1 (mandatory convention)** |
| `EXTENSIONALWAYSUPPERCASE` | bool | | **0 (never 1)** |
| `FORCECASE` | bool | Enable forced fragments | 0 |
| `FRAGMENTSTEXT` | str | **Comma-separated only** ✓. Newlines are NOT separators ✓. A trailing comma is OK ✓. A fragment can't contain a comma. | empty |

**Fragment matching rules (all ✓):**
1. Applied **after** the WHAT transformation, within the same rule.
2. Matching is **case-insensitive and whole-word**. Space, hyphen and punctuation are boundaries; **`_` and digits are word characters**, so `ios` in `app_ios` or `ios2` is *not* matched.
3. Multi-word and punctuated fragments work: `Visual Studio`, `.NET`, `C++`, `C#`, `ASP.NET`, `Node.js`, `Sci-Fi`, `B&W`.
4. Plurals are separate words: `API` does not match `apis`, so add `APIs` explicitly.
5. Overlapping fragments are applied in list order and **the later one wins** (✓ both orders probed: `Visual Studio Code` before `Visual Studio` yields `Visual Studio CODE` when the list says `VISUAL STUDIO CODE,Visual Studio`). Emit shorter or more general fragments first and longer phrases last.

**Capitalize Every Word (WHAT=3) word starts ✓:** a new word starts after a space, `_`, `-`, `.`, `(`, `[`. It does **not** start after an apostrophe (`O'neil`, `Rock'n'roll`) or inside a digit-led token (`3d`, `2nd` stay lowercase). Unicode letters are handled (`Élan`, `Ümlaut`).

### 3.9 Serialize — `ID=Serialize`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `TYPE` | enum | **1** incremental ✓ · 2 legacy random (deprecated since 6.6; use Randomize) ◐ (observed `n3078`; random, so not assertable; never emit) · 0 = no-op | 1 |
| `WHERE` | enum | **1** prefix ✓ · **2** suffix ✓ (after the extension if SKIPEXTENSION=0 ✓) · 3 legacy suffix-before-extension (never emit) · **4** position ✓ · 5/6 no-op · **7** replace current name ✓ | 2 |
| `POSITION` | int | For WHERE=4 | 1 |
| `INDEX` | int | Start value ✓ | 1 |
| `STEP` | int | Increment, may be negative ✓ | 1 |
| `REPEAT` | int | Repeat each index N times ✓ | 1 |
| `RESETIFFOLDERCHANGES` | bool | Restart the sequence per folder ✓ (`A\a, A\b, B\c` → `a1, b2, c1`) | 0 |
| `RESETIFFILENAMECHANGES` | bool | Restart when the (post-rule) name differs from the *previous* file ✓ (`aa.txt, aa.png, bb.txt` → `aa1, aa2, bb1`). Only groups **adjacent** files, and it numbers unique names too. | 0 |
| `RESETEVERY` + `RESETEVERYCOUNT` | bool + int | Restart every N files | 0 / 1 |
| `LENGTH`, `UNIQUE` | int, bool | Only used by legacy TYPE=2 | 1 / 1 |
| `PADTOLENGTH` + `PADTOLENGTHVALUE` | bool + int | Zero-pad ✓ (`000`, `010`) | 0 / 1 |
| `SKIPEXTENSION` | bool | | 1 |
| `NUMERALSYSTEM` | enum | **1** decimal ✓ · **2** English letters ✓ (5 → `e`) · **3** Roman ✓ · **4** Simplified Chinese ✓ · **5** custom alphabetic ✓ · **6** custom numeric ✓ · **7** music notes ✓ · 0/8 = no-op | 1 |
| `CUSTOMSYMBOLS` | str | Symbol set for 5/6 | empty |

⚠ Serialization follows the **file-table order**, which comes from the user's sort settings (Jay: natural sort, remembered column). State that assumption in the preset comment.

### 3.10 Randomize — `ID=Randomize`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `LENGTH` | int | | 8 |
| `UNIQUE` | bool | Try to avoid repeats | 1 |
| `WHERE` | enum | **1** prefix ✓ · **2** suffix ✓ · 3 no-op ✓ · **4** position ✓ · 5/6 no-op · **7** replace current name ✓ | 2 |
| `POSITION` | int | | 1 |
| `SKIPEXTENSION` | bool | | 1 |
| `USEDIGITS` / `USEENGLISHLETTERS` / `USEUSERDEFINED` + `USERDEFINEDCHARS` | bool… + str | Character pools ✓ | 1/0/0/empty |

### 3.11 Padding — `ID=Padding`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `NUMBERPADDING` | enum | 0 off · **1** add zero padding ✓ · **2** remove zero padding ✓ | — |
| `NUMBERPADDINGLENGTH` | int | Target digit count ✓. ⚠ Applies to **every** digit run (`a1 b22 c4444` → `a001 b022 c4444`), including years and version numbers. | 2 |
| `TEXTPADDING` | bool | Pad the whole name with custom chars | 0 |
| `TEXTPADDINGLENGTH` | int | Total target length ✓ | 1 |
| `TEXTPADDINGPOSITION` | enum | **1** left ✓ · **2** right ✓ · 0 = no-op | 1 |
| `TEXTPADDINGCHARS` | str | | empty |
| `SKIPEXTENSION` | bool | | 1 |

### 3.12 Clean Up — `ID=CleanUp`
| Key | Meaning (✓ = probed) |
|---|---|
| `BRACKETSROUND` / `BRACKETSSQUARE` / `BRACKETSCURVY` | Remove `(…)`, `[…]`, `{…}` **including their content** ✓ |
| `SPACESDOT` / `SPACESCOMMA` / `SPACESUNDERSCORE` / `SPACESPLUS` / `SPACESHYPHEN` | Replace `.` `,` `_` `+` `-` with spaces ✓ |
| `SPACESWEB` | Replace `%20` with a space ✓ |
| `SPACESSKIPVERSIONS` | Leave digit groups like `v1.2.3` intact when replacing dots ✓ |
| `SPACESFIX` | Collapse repeated spaces, trim ✓ |
| `SKIPEXTENSION` | |
| `PREPAREFORSHAREPOINT` | `{}`→`()`, drop `#%~&`, collapse consecutive dots ✓ (`a{b}#c~d&e%f..g` → `a(b)cdef.g`); also trims and drops control characters ◐ |
| `INSERTSPACEBEFORECAPITALS` | Split CamelCase, acronym-aware: `HTMLParser` → `HTML Parser` ✓ |
| `NORMALIZESPACES` | Map Unicode spaces to U+0020 ✓ (NBSP probed) |
| `STRIPUNICODEMARKS` | Strip diacritics ✓ (`café naïve Ñu` → `cafe naive Nu`). **Destructive**: enable only on request |
| `STRIPUNICODEEMOJI` | Strip emoji ✓ (`Happy😀Face 🎵` → `HappyFace`; the space left behind is trimmed too) |

Canonical order: `BRACKETSROUND;BRACKETSSQUARE;BRACKETSCURVY;SPACESDOT;SPACESCOMMA;SPACESUNDERSCORE;SPACESPLUS;SPACESHYPHEN;SPACESWEB;SPACESSKIPVERSIONS;SPACESFIX;SKIPEXTENSION;PREPAREFORSHAREPOINT;INSERTSPACEBEFORECAPITALS;NORMALIZESPACES;STRIPUNICODEMARKS;STRIPUNICODEEMOJI`.
Skill default (§4 template): everything 0 except `SPACESFIX=1; SKIPEXTENSION=1`. Turn on only the flags the request needs.
Observed in Jay's older "tidy" presets: `NORMALIZESPACES=1; STRIPUNICODEMARKS=1; STRIPUNICODEEMOJI=1` as well. Don't copy that by default: stripping diacritics rewrites accented names (`Café` → `Cafe`).

### 3.13 Translit — `ID=Translit`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `ALPHABET` | str | **The full map text**, one `src=dst` pair per line, lines joined with CRLF ✓. It is *not* a map name. Built-in maps are `.txt` files in `<ReNamer>\Translits\`; embed their content. Put longer sources first. | — |
| `DIRECTION` | enum | **1** forward (src→dst) ✓ · **2** backward ✓ · 0 = no-op | 1 |
| `ADJUSTCASE` | bool | 1 = case-insensitive matching plus output case follows input (`ÖL` → `OEL`, `Öl` → `Oel`) ✓ · 0 = literal, case-sensitive matching ✓ | 1 |
| `SKIPEXTENSION` | bool | | 1 |

### 3.14 Reformat Date — `ID=ReformatDate`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `SOURCEFORMATS` | str | One or more formats separated by `\|` ✓ | — |
| `TARGETFORMAT` | str | ✓ `dd mmm yyyy` → `31 Dec 2025` | — |
| `USECUSTOMSHORTMONTHS` / `USECUSTOMLONGMONTHS` | bool | | 0 |
| `CUSTOMSHORTMONTHS` / `CUSTOMLONGMONTHS` | str | Comma lists | empty |
| `WHOLEWORDSONLY` | bool | Match dates only at word boundaries (recommended) | 1 |
| `SKIPEXTENSION` | bool | | 1 |
| `ADJUSTTIME` | bool | | 0 |
| `ADJUSTTIMEBY` | int | May be negative ✓ | 0 |
| `ADJUSTTIMEPART` | enum | **1** years ✓ · **2** months ✓ · **3** days ✓ · **4** hours ✓ · **5** minutes ✓ · **6** seconds ✓ · **7** milliseconds ✓ · **0 makes the rule error out** when ADJUSTTIME=1 (CLI exit 1, nothing renamed) ✓. Always emit a valid part (1) even when ADJUSTTIME=0. | 1 |

Format tokens: `yyyy yy mmmm mmm mm m dddd ddd dd d hh h nn n ss s zzz am/pm a/p`, with `"quoted"` literals. ⚠ `mm`/`m` right after `hh`/`h` means **minutes**, so use `nn` for minutes to stay unambiguous. Don't emit `:` or other filename-illegal characters in TARGETFORMAT.

### 3.15 Regular Expressions — `ID=RegEx`
| Key | Type | Values / notes | Skill default |
|---|---|---|---|
| `EXPRESSION` | str | TRegExpr / FPC syntax (see `engine-notes.md` §1) | — |
| `REPLACE` | str | `$0`–`$n`, `${n}`, case modifiers `\U$n \L$n \u$n \l$n` (next group only) ✓, literal `$` = `\$` ✓ | — |
| `CASESENSITIVE` | bool | 0 = case-insensitive ✓. **Set 1** whenever the pattern depends on letter case (`\p{Lu}`, `[A-Z]`). | 0 |
| `SKIPEXTENSION` | bool | 0 = the pattern sees `.ext` too ✓ | 1 |

Replacement is global (every match). Rule ID is **`RegEx`**, not `RegularExpressions`.

### 3.16 Pascal Script — `ID=PascalScript`
| Key | Type | Notes |
|---|---|---|
| `SOURCEUTF8` | str | Complete script source, UTF-8, lines joined with CRLF, encoded per §1.2 ✓. Unicode literals work ✓. **Strip the UTF-8 BOM** from `.pas` files before embedding (Jay's `.pas` files have one). Legacy presets from ReNamer < 7 used `SOURCE` (ANSI). Never emit it. |

### 3.17 User Input — `ID=UserInput`
| Key | Type | Values / notes |
|---|---|---|
| `INPUT` | str | New names, one per line, lines joined with a **bare CR** (written `%0D`, see §1.2) ✓. Line *n* names file *n* in file-table order ✓. A list shorter than the batch leaves the extra files unchanged (exit 0) ✓; a trailing CR is harmless ✓. **CRLF or LF between lines makes ReNamer refuse the whole batch** (exit 1, nothing renamed) ✓. Spaces and punctuation in lines are encoded normally ✓. |
| `ACTION` | enum | **0** replace name ✓ · **1** insert in front ✓ · **2** insert after ✓ |
| `SKIPEXTENSION` | bool | |

### 3.18 Mapping — `ID=Mapping` (added in 7.7)
| Key | Type | Values / notes |
|---|---|---|
| `ALLOWREUSE` | bool | 0 = each row is used once per run: a second file with the same name keeps its name ✓ · 1 = a row can map several files ✓ |
| `PARTIALMATCH` | bool | ✓ A partial match **replaces the whole name**: `foo aa bar` + `aa→xx` → `xx` |
| `INVERSEMAPPING` | bool | ✓ Maps TARGET back to SOURCE (`xx.txt` → `aa.txt`) |
| `CASESENSITIVE` | bool | 0 = rows match in any case (`AA.txt` matches `aa`) ✓ |
| `SKIPEXTENSION` | bool | 1 = rows match and replace the base name only ✓ |
| `SOURCE` / `TARGET` | str | The lookup table, one row per file name, rows joined with a **raw `\|`** and each row encoded on its own (§1.2) ✓. Row *n* of SOURCE maps to row *n* of TARGET ✓. Spaces, punctuation and Unicode work ✓. **Both must have the same number of rows:** with fewer TARGET rows, a file matching an unpaired SOURCE row is renamed to an **empty name** (`bb.txt` → `.txt`) ✓, so the builder and validator reject a mismatch. |

**When to use Mapping:** an explicit old name → new name list where each file is named in full (e.g. a vendor's asset list). It matches whole names (base names with `SKIPEXTENSION=1`), so it's safer than Replace for full-name lists; for substrings inside names, use Replace with `*\|*` pairs.

---

## 4. Copy-paste templates (canonical order, skill defaults)

These lines are the **authoritative key order** for each rule. An empty value here is either a genuinely empty default or a required value ("—" in §3), which the builder must take from the preset-spec; it never fills a required key from this template.

```ini
ID=Insert        Config=TEXT:;WHERE:;POSITION:1;INSERTAFTERTEXT:;INSERTBEFORETEXT:;RIGHTTOLEFT:0;SKIPEXTENSION:1
ID=Delete        Config=FROM:1;UNTIL:;FROMPOSITION:1;UNTILCOUNT:1;FROMDELIMITER:;UNTILDELIMITER:;DELETECURRENTNAME:0;RIGHTTOLEFT:0;SKIPEXTENSION:1;LEAVEDELIMITER:0
ID=Remove        Config=TEXT:;WHICH:3;SKIPEXTENSION:1;CASESENSITIVE:0;USEWILDCARDS:0;WHOLEWORDSONLY:0
ID=Replace       Config=TEXTWHAT:;TEXTWITH:;WHICH:3;SKIPEXTENSION:1;CASESENSITIVE:0;USEWILDCARDS:0;WHOLEWORDSONLY:0
ID=Rearrange     Config=DELIMITERTYPE:0;RIGHTTOLEFT:0;DELIMETERS:;NEWPATTERN:;SKIPEXTENSION:1
ID=Extension     Config=NEWEXTENSION:1;EXTENSION:;APPEND:0;USEBINSIGN:0;REMOVEDUPLICATES:0;CASESENSITIVE:0
ID=Strip         Config=CHECKENGLISHLETTERS:0;CHECKDIGITS:0;CHECKSYMBOLS:0;CHECKBRACKETS:0;CHECKUSERDEFINED:0;CHECKUNICODERANGE:0;TEXTUSERDEFINED:;TEXTUNICODERANGE:;WHERE:0;STRIPALLEXCEPTSELECTED:0;CASESENSITIVE:0;SKIPEXTENSION:1
ID=Case          Config=WHAT:0;PRESERVECASE:0;SKIPEXTENSION:1;EXTENSIONALWAYSLOWERCASE:1;EXTENSIONALWAYSUPPERCASE:0;FORCECASE:0;FRAGMENTSTEXT:
ID=Serialize     Config=TYPE:1;WHERE:2;POSITION:1;INDEX:1;STEP:1;REPEAT:1;RESETIFFOLDERCHANGES:0;RESETIFFILENAMECHANGES:0;RESETEVERY:0;RESETEVERYCOUNT:1;LENGTH:1;UNIQUE:1;PADTOLENGTH:0;PADTOLENGTHVALUE:1;SKIPEXTENSION:1;NUMERALSYSTEM:1;CUSTOMSYMBOLS:
ID=Randomize     Config=LENGTH:8;UNIQUE:1;WHERE:2;POSITION:1;SKIPEXTENSION:1;USEDIGITS:1;USEENGLISHLETTERS:0;USEUSERDEFINED:0;USERDEFINEDCHARS:
ID=Padding       Config=NUMBERPADDING:;NUMBERPADDINGLENGTH:2;TEXTPADDING:0;TEXTPADDINGLENGTH:1;TEXTPADDINGPOSITION:1;TEXTPADDINGCHARS:;SKIPEXTENSION:1
ID=CleanUp       Config=BRACKETSROUND:0;BRACKETSSQUARE:0;BRACKETSCURVY:0;SPACESDOT:0;SPACESCOMMA:0;SPACESUNDERSCORE:0;SPACESPLUS:0;SPACESHYPHEN:0;SPACESWEB:0;SPACESSKIPVERSIONS:0;SPACESFIX:1;SKIPEXTENSION:1;PREPAREFORSHAREPOINT:0;INSERTSPACEBEFORECAPITALS:0;NORMALIZESPACES:0;STRIPUNICODEMARKS:0;STRIPUNICODEEMOJI:0
ID=Translit      Config=ALPHABET:;DIRECTION:1;ADJUSTCASE:1;SKIPEXTENSION:1
ID=ReformatDate  Config=SOURCEFORMATS:;TARGETFORMAT:;USECUSTOMSHORTMONTHS:0;USECUSTOMLONGMONTHS:0;CUSTOMSHORTMONTHS:;CUSTOMLONGMONTHS:;WHOLEWORDSONLY:1;SKIPEXTENSION:1;ADJUSTTIME:0;ADJUSTTIMEBY:0;ADJUSTTIMEPART:1
ID=RegEx         Config=EXPRESSION:;REPLACE:;CASESENSITIVE:0;SKIPEXTENSION:1
ID=PascalScript  Config=SOURCEUTF8:
ID=UserInput     Config=INPUT:;ACTION:0;SKIPEXTENSION:1
ID=Mapping       Config=ALLOWREUSE:0;PARTIALMATCH:0;INVERSEMAPPING:0;CASESENSITIVE:0;SKIPEXTENSION:1;SOURCE:;TARGET:
```
