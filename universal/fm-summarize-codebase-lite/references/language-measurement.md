# Language measurement

How to build section 1.3: which files count, which language each belongs to, how to
measure them without scripts, and how to turn the measurements into percentages that
sum to exactly 100.0.

## Contents

- [What to exclude](#what-to-exclude)
- [Language map](#language-map)
- [Methods](#methods)
- [Percentage arithmetic](#percentage-arithmetic)
- [The 1.3 table](#the-13-table)

## What to exclude

Leave these files out of every count and list them, by category and with examples,
in Appendix A.

- **Vendored:** anything under `node_modules/`, `vendor/`, `third_party/`,
  `bower_components/`, `Pods/`, `.venv/`, `venv/`, `site-packages/`, `.yarn/`, and
  anything `.gitattributes` marks `linguist-vendored`.
- **Generated:**
  - Build output: `dist/`, `build/`, `out/`, `target/`, `bin/`, `obj/`, `.next/`,
    `.nuxt/`, `coverage/`, `__pycache__/`. When one of these is *tracked* in git and
    holds hand-written code, keep it (Rust `src/bin/`, `bin/cli.js` launchers).
  - Lockfiles (`*-lock.json`, `*.lock`, `go.sum`), minified bundles (`*.min.js`,
    `*.min.css`), source maps (`*.map`), protobuf output (`*_pb2.py`, `*.pb.go`),
    designer files (`*.Designer.cs`, `*.g.cs`).
  - Any file whose first lines carry a comment like "@generated", "auto-generated", or
    "DO NOT EDIT", and anything marked `linguist-generated`.
- **Binary:** images, fonts, archives, executables, PDFs, and databases.
- **Version-control internals:** everything under `.git/`, `.hg/`, and `.svn/`. Read
  `.git/` for metadata (metadata-sources.md), but never count or inventory its files:
  `.git/hooks/*.sample` are git's own scripts, not the project's.
- **The summary itself:** `CODEBASE_SUMMARY.md` and `codebase-summary/` from an earlier
  run.

Tests and examples are **not** excluded. They are code; section 3.9 says how much of
the codebase they make up.

## Language map

Each language has a type. **Programming** and **markup** languages make up the
percentages. **Data** and **prose** are listed separately, so a large README or a
folder of JSON fixtures can't masquerade as the main language.

| Language | Type | Extensions and files |
| --- | --- | --- |
| Python | programming | `.py` `.pyw` `.pyi`, `#!…python` |
| JavaScript | programming | `.js` `.mjs` `.cjs` `.jsx` |
| TypeScript | programming | `.ts` `.mts` `.cts` `.tsx` |
| C# | programming | `.cs` `.csx` |
| Java · Kotlin · Scala · Groovy | programming | `.java` · `.kt` `.kts` · `.scala` `.sc` · `.groovy` `.gradle` |
| Go · Rust · Zig | programming | `.go` · `.rs` · `.zig` |
| C · C++ | programming | `.c` · `.cpp` `.cc` `.cxx` `.hpp` `.hh` `.hxx`; a bare `.h` is C++ if the repo has C++ sources, otherwise C |
| Objective-C · Swift · Dart | programming | `.m` (with `#import`/`@interface`) `.mm` · `.swift` · `.dart` |
| Ruby · PHP · Perl · Lua | programming | `.rb` `.rake` `.gemspec`, `Rakefile`, `Gemfile` · `.php` · `.pl` `.pm` · `.lua` |
| R · Julia · MATLAB | programming | `.r` `.R` · `.jl` · `.m` (without Objective-C markers) |
| Elixir · Erlang · Haskell · OCaml · F# · Clojure | programming | `.ex` `.exs` · `.erl` · `.hs` · `.ml` · `.fs` `.fsx` · `.clj` `.cljs` |
| PowerShell | programming | `.ps1` `.psm1` (`.psd1` data files and module manifests are **data**) |
| Shell · Batch | programming | `.sh` `.bash` `.zsh`, `#!…sh` · `.bat` `.cmd` |
| SQL | programming | `.sql` |
| Visual Basic .NET · Pascal · Fortran | programming | `.vb` · `.pas` `.pp` `.dpr` · `.f90` `.f` |
| Shaders | programming | `.glsl` `.vert` `.frag` `.hlsl` `.wgsl` |
| Build scripts | programming | `Makefile` `*.mk`, `CMakeLists.txt` `*.cmake`, `Dockerfile`, `*.nix`, `*.tf` (HCL) |
| HTML · CSS · SCSS · Less | markup | `.html` `.htm` · `.css` · `.scss` `.sass` · `.less` |
| Vue · Svelte · Astro · XAML · Razor | markup | `.vue` · `.svelte` · `.astro` · `.xaml` `.axaml` · `.cshtml` `.razor` |
| JSON · YAML · TOML · XML · INI · CSV/TSV · SVG · PowerShell data | data | `.json` · `.yml` `.yaml` · `.toml` · `.xml` `.csproj` `.props` · `.ini` `.cfg` `.editorconfig` · `.csv` `.tsv` · `.svg` · `.psd1` |
| Tool configuration dotfiles | data | `.gitignore` `.gitattributes` `.dockerignore` `.npmrc` `.nvmrc` `.prettierrc` `.eslintrc` `.env.example` and similar |
| Markdown · reStructuredText · text | prose | `.md` `.mdx` · `.rst` · `.txt`, `LICENSE`, `README`, `CHANGELOG` |

File names and extensions match regardless of case (`license`, `Readme.MD`).

For anything unlisted, decide by content: a shebang or real code gives the language;
key–value, INI-like, pattern-list, or tabular content is **data** (for example a tool's
own preset format). List unrecognized extensions, and how you classified them, in
Appendix A.

Two cases count under their language but deserve a note under the 1.3 table when they
are a large share of it:

- a file in a programming language's extension that holds only data (a `.js` file
  that is a single exported object literal)
- hand-written TypeScript declaration files (`.d.ts`) in a JavaScript project: they
  count as TypeScript but add no callables ("TypeScript: type declarations only")

## Methods

Use the highest method your access allows, and say which one in 1.3 and Appendix A.

| Rank | Method | Basis | Precision |
| --- | --- | --- | --- |
| A | Hosting languages API: GitHub `GET /repos/{o}/{r}/languages`, GitLab `GET /projects/{id}/languages` | GitHub returns bytes per language; GitLab returns percentages | Exact for the default branch. GitHub's linguist already excludes vendored and generated files, but counts some data and prose languages; drop those (see below). |
| B | Shell count | Code lines (or bytes) | Exact, if the tool excludes comments and blanks |
| C | File listing with sizes | Bytes | Exact on the bytes basis, as long as every file is listed and classified |
| D | Line counts from a search tool's count mode, or from files read | Non-blank lines (total lines when counted by reading) | Exact when every file is counted (search count mode makes this cheap); approximate if sampled |

**Method A: drop non-programming entries.** The API may list JSON, Markdown, or other
data or prose languages, and on GitHub often HTML or CSS from docs. Keep markup
(HTML, CSS, Vue…) and remove data and prose, then recompute the percentages over what
remains. If the user asked for a specific branch or tag, method A describes the default
branch only; use B, C, or D for other refs.

**Method A: check it against the file listing.** Linguist silently skips some
hand-written files: TypeScript declaration files (`.d.ts`), files under `docs/`, and
anything a `.gitattributes` rule marks. Compare the API's languages with the extensions
in the tree. If real source files are missing from the API numbers, keep the API table
(it matches the GitHub language bar) and add a second, labelled table from method C
that includes them. Label the two tables "GitHub languages API" and "All hand-written
source (tree sizes)".

**Method B: shell commands.** Use a line counter if one is installed. Each of these
prints per-language code lines and handles comments:

```bash
cloc --vcs=git .
tokei .
scc .
```

Without one, count non-blank lines per extension over the tracked files (lines, not
code-only):

```bash
git ls-files | grep -E '\.(py|ts|js)$' | xargs cat | grep -cv '^\s*$'
```

Run that once per language, adjusting the extension list, and exclude vendored and
generated paths with `grep -v`.

**Method C: sizes from a file listing.** Many listing tools and the GitHub tree
endpoint report sizes. Sum the bytes per language over non-excluded files, working one
module at a time: write each module's subtotals down, then add the modules up, and
check that the module sums add up to the grand total before computing percentages. If
you have a code tool, do the sums there.

**Method D: count lines with a search tool, or while reading.**

- **With a content-search tool that can report match counts per file**, this is exact
  and cheap. Search the pattern `\S` (any non-whitespace character) in count mode over
  each language's files: every non-blank line matches once. Search `^` for total lines.
  Sum per language. If the tool also prints a grand total, check that your per-language
  sums add up to it.
- **Without search**, note each file's line count while reading it. A read tool that
  numbers lines gives the total at the last line. Counting blank lines by hand is slow
  and error-prone, so on this path use **total lines** for every file and name that
  basis ("lines, including blank"). Never mix bases in one table. If you read every
  file, the numbers are exact on that basis.
- If you sampled, say "approximate, from N of M files" and don't present decimals you
  don't have (round to whole percentages).

**Reliable listings.** Listing tools cap their results and may skip dotfiles. List each
top-level directory separately rather than the whole tree at once, list hidden entries
(`.github/`, `.gitattributes`, `.env*`) explicitly, and compare the number of files you
list with any total the tool reports. If the tool reports no total, treat a listing as
complete only when it ends without a truncation notice. If it lists one folder at a
time, walk every subfolder. A truncated listing means an incomplete inventory: re-list
in smaller pieces until nothing is cut off.

## Percentage arithmetic

1. Take the measurement for each programming and markup language, say
   Python 84,120 bytes, JavaScript 6,480, and HTML 3,700, for a total of 94,300.
2. Compute each share to one extra decimal: 84,120 ÷ 94,300 × 100 = 89.20, 6.87, 3.92.
3. **Largest-remainder rounding** to one decimal, so the column sums to exactly 100.0:
   round every value *down* to one decimal (89.2, 6.8, 3.9, which sum to 99.9), then
   add 0.1 to the languages with the largest discarded remainders until the sum is
   100.0. JavaScript had 0.07 discarded, the largest, so it becomes 6.9. The result is
   89.2 / 6.9 / 3.9 = 100.0.
4. State the basis in the table caption: "% of bytes" (methods A and C) or "% of
   non-blank lines" / "% of code lines" (B and D) / "% of lines, including blank" (D by
   reading).

Show both bases only when you actually measured both.

## The 1.3 table

```markdown
Measured with {method}; basis: {bytes | code lines | non-blank lines | lines, including blank}. Excludes vendored,
generated, and binary files. Data and prose files are listed separately.

| Language | Type | Files | {Bytes or Lines} | Share |
| --- | --- | ---: | ---: | ---: |
| Python | programming | 25 | 84,120 | 89.2% |
| JavaScript | programming | 7 | 6,480 | 6.9% |
| HTML | markup | 1 | 3,700 | 3.9% |
| **Total** | | **33** | **94,300** | **100.0%** |

Other files (not in the percentages): Markdown 17 files, YAML 7, JSON 3, TOML 1.
```

When method A doesn't give file counts, fill the Files column from the file listing.
If you have no listing, write "—".
