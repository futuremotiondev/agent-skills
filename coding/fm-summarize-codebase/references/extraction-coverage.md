# Extraction coverage

What `extract_symbols.py` counts, how well it handles each language, and what to check
by hand.

## Contents

- [Counting rule](#counting-rule)
- [How extraction works](#how-extraction-works)
- [Language support](#language-support)
- [Known blind spots](#known-blind-spots)
- [Unsupported languages](#unsupported-languages)
- [Files that are never inventoried](#files-that-are-never-inventoried)

## Counting rule

**Counted:** named functions, methods, constructors, destructors, operators, property
accessors with parameter lists (Python `@property`, JS/TS `get`/`set`), local (nested)
functions, and abstract, interface, trait, or protocol method declarations (flagged
`abstract`). Named function values count wherever they are defined: JS/TS
`const f = () => …` and `M.f = function…`, Python `f = lambda …`, Lua
`x = function…`, and PowerShell `$f = { param(…) … }` (kind `script block`).

**File-level programs count too**, because they're invoked like functions and are often
a file's most important unit: JS IIFEs (`(IIFE)`), PowerShell `.ps1` scripts whose
first statement is `param(…)` (kind `script`, named after the file), and Pascal/Delphi
program main blocks `begin … end.` (`(main)`). Functions defined inside a script's
body become its local functions.

**Not counted:** anonymous lambdas and callbacks passed inline, C# and Kotlin properties
without parameter lists, macro definitions, forward declarations and header prototypes
whose body is elsewhere (C/C++), TypeScript overload signatures (only the
implementation counts), and function *types* (`onClick: (e) => void`).

Types (classes, structs, interfaces, enums, traits, records, modules, impl blocks) are
inventoried separately.

## How extraction works

- **Python:** the `ast` module, which is exact. It falls back to a regex pass for files
  that don't parse (Python 2) and is marked `regex (ast failed)`. Jupyter notebooks are
  parsed cell by cell.
- **Everything else:** comments and string contents are masked (offsets preserved), then
  declarations are found either by their keyword (`fn`, `func`, `fun`, `def`,
  `function`, `sub`, `proc`, …) or, for C-family languages, by classifying the line
  prefix before each `name(`. Extents come from brace matching, `end` matching (Ruby,
  Lua, Elixir, Julia, Fish, VB), or indentation (Python fallback, Nim, GDScript, F#).
- **Embedded code:** `<script>` blocks in Vue, Svelte, HTML, and Astro frontmatter go
  through the JS/TS rules.
- **Call graph:** call sites inside a body are matched by name *and receiver*, within
  the same language:
  - `self.x()` / `this.x()` resolves to the caller's own class;
  - `obj.x()` resolves only when `obj` names the callee's class or module
    (`debug_logger.record` → `DebugLogger.record`);
  - a bare `x()` resolves to a unique free function, a same-class member (in
    implicit-`this` languages), or a unique same-file match.

  PowerShell command syntax (`Get-Thing -Arg x`) and Pascal/VB/Ruby parameterless
  statements (`Bump;`) count as calls. Common names (`get`, `run`, `enable`, `parse`, …)
  are skipped. Treat edges as leads to verify.
- **References:** how often each callable's name appears as an identifier elsewhere in
  same-language code, minus its definitions. A callable with no callers but with
  references is passed around (callbacks, signal handlers, dispatch tables), not dead.
  Names used only inside strings (`getattr(obj, "name")`, route tables keyed by text)
  are invisible to this count.

## Language support

| Language | Extractor | Notes |
| --- | --- | --- |
| Python, Jupyter | exact (`ast`) | Nested functions, lambdas assigned at module or class level, property getters and setters |
| JavaScript, TypeScript (+ JSX/TSX, Vue, Svelte, HTML, Astro) | heuristic | Functions, arrows, class members, object-literal methods, `exports.x =`, `X.prototype.y =`, IIFEs, interface and abstract members |
| C#, Java, Dart, Groovy | heuristic (prefix classification) | Constructors, destructors, operators, local functions, expression bodies, interface and abstract members, Dart named and factory constructors |
| C, C++, CUDA, Objective-C, GLSL, HLSL | heuristic (prefix classification) | Out-of-class `A::b` definitions, GNU-style return types on the previous line, pure virtuals, gtest/Catch-style `TEST(...)` is **not** counted |
| Go | heuristic | Receivers become containers; interface methods are abstract; generics |
| Rust | heuristic | `impl X` / `impl T for X` containers, trait methods (abstract without a default body), `pub(crate)`, raw strings and lifetimes handled |
| Kotlin, Scala, Swift | heuristic | Extension functions, secondary constructors, `init`/`deinit`/`subscript`, operator funcs, expression bodies |
| PHP | heuristic | Visibility, abstract and interface members, `__construct` |
| Ruby, Crystal | heuristic | `def self.x`, endless defs, modifier `if`/`unless` aware `end` matching |
| Lua | heuristic | `M.f`, `M:f`, `local function`, `x = function` |
| Elixir | heuristic | `def`/`defp`/`defmacro`, `do:` one-liners, `@doc` |
| PowerShell | heuristic | `function`/`filter`/`workflow`, scripts with a top-level `param()` (nested attributes like `[OutputType([string])]` handled), named script blocks, `param()` blocks, comment-based help `.SYNOPSIS`, class methods and constructors, `Export-ModuleMember` visibility in `.psm1` |
| Pascal / Delphi / PascalScript | heuristic | `procedure`/`function`/`constructor`/`destructor`, `Class.Method`, program main block, extents up to the next routine, `interface`-section and `forward` declarations skipped |
| Shell, Fish, Batch | heuristic | `f() {}`, `function f`, subshell bodies; Batch `:labels` as subroutines |
| SQL | heuristic | `CREATE FUNCTION/PROCEDURE/TRIGGER`; views and tables as types |
| Visual Basic .NET, F#, Julia, R, MATLAB, Perl, Zig, Nim, GDScript, Solidity, Haskell, OCaml, Clojure, Lisp/Scheme, Erlang, Fortran, CMake, AppleScript, AutoHotkey, WGSL | heuristic (keyword) | Declarations found; extents approximate where `end` isn't tracked |

## Known blind spots

Check for these while reading. The first three are the most common.

- **Functions built dynamically:** decorators or factories returning functions,
  `setattr`, metaprogramming, `define_method`, and route tables mapping strings to
  lambdas. Describe them where they are registered. If they matter as units, add manual
  entries.
- **Declarations split unusually across lines:** a return type alone on one line with
  modifiers on another, or a name on a different line than its `(`. They're rare but
  can be missed. Watch the file's entry count against what you read.
- **Code inside strings:** SQL, JS, or shell embedded in string literals is masked and
  never inventoried. That's correct, but mention it when it matters (for example, a JS
  payload injected by a Python tool).
- **Macro-heavy C/C++:** functions defined through macros (`DEFINE_HANDLER(x) {…}`,
  gtest `TEST`) aren't counted. Add manual entries if they're the codebase's main units.
- **Heredocs in shell:** their content isn't masked, so a function-like line inside one
  could be reported. Drop it if so.
- **JSX text with apostrophes** (`Don't`) can confuse brace matching in rare cases,
  which shows up as a wrong extent. Fix the extent in the entry text.

## Unsupported languages

Files in programming languages without an extractor (Assembly, and some rarer
languages) are listed in `symbols.json` → `unsupported` and in Appendix A. Read them,
and for each named routine or procedure add manual entries (see
[function-entries.md](function-entries.md#corrections)). Make/Docker/Nix/HCL files have
no callables and are described in 3.7 instead.

Shell and batch scripts whose top level *is* the program (no functions, or a few
helpers plus top-level code) have no callable for that top-level code. If such a script
is a primary entry point, add a manual entry named after the file (kind `script`) that
describes what it runs.

## Files that are never inventoried

- **Vendored:** `node_modules/`, `vendor/`, `third_party/`, virtualenvs, anything marked
  `linguist-vendored`, and (walked trees only) `packages/`, `deps/`, `external/`.
- **Generated:** build output directories, lockfiles, minified bundles, protobuf and
  designer output, files whose first lines carry a "generated / DO NOT EDIT" banner, and
  anything marked `linguist-generated`.
- **Binary** and **oversized** files (over 2 MB are counted but not parsed; over 10 MB
  are excluded).
- Anything the user excluded with `--exclude`.

Appendix A lists every exclusion category with examples. If an exclusion is wrong (for
example, a `generated/` folder of hand-written code), re-run with a narrower scope, or
read those files and add manual entries.
