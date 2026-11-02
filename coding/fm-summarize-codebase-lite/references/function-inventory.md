# Function inventory

The inventory is the backbone of the report: a numbered list of every callable, built
before the descriptions it covers. The function count, the 1.6 index, and the
reference all come from it, and verification checks the report against it.

## Contents

- [Counting rule](#counting-rule)
- [IDs and the inventory record](#ids-and-the-inventory-record)
- [Building it](#building-it)
- [Per-language declaration patterns](#per-language-declaration-patterns)
- [Traps that cause miscounts](#traps-that-cause-miscounts)

## Counting rule

**Count:**

- named functions and methods, constructors, destructors, operators
- property accessors that have a parameter list (Python `@property`, JS/TS `get`/`set`)
- nested (local) functions
- named function values: JS/TS `const f = () => …` and `obj.f = function…`, Python
  `f = lambda …`, Lua `x = function…`, and PowerShell `$f = { param(…) … }`
- abstract, interface, trait, or protocol method declarations, marked *abstract*
- **file-level programs**: JS IIFEs `(function(){…})()`; PowerShell `.ps1` scripts whose
  first *statement* is `param(…)`, named after the file (comments, `#Requires`,
  comment-based help, `using` lines, and attribute lines such as `[CmdletBinding()]`
  may come before it); and Pascal main blocks, the `begin … end.` that runs, including
  script fragments like ReNamer PascalScript that are only `var … begin … end.`
- **named test functions**: Python `test_*`, Go `TestX`, Rust `#[test] fn`, JUnit/xUnit/
  NUnit test methods, and named helper functions in any test file
- a function stored on a property (`obj.fn = () => …`, `obj.fn = function…`): see
  [Kinds](#ids-and-the-inventory-record) for its kind and name

**Don't count:**

- anonymous lambdas and callbacks passed inline, **including test cases registered with
  a callback**: `test('title', t => …)` and `it(…)` in Jest, Vitest, Mocha, or AVA, and
  Pester `It` blocks. For 3.9, count the `test(`/`it(`/`It` call sites per file,
  modifiers included (`test.skip`, `it.only`, `test.serial`, `test.each` counts once);
  `describe` groups and assertion callbacks (`t.throws(() => …)`) aren't cases. Write it
  as "31 Vitest cases in `parser.test.ts`, covering …"
- properties without a parameter list (C# `{ get; set; }`, Kotlin `val`)
- macro definitions
- declarations whose body is elsewhere: C/C++ prototypes and headers, TypeScript
  overload signatures (count only the implementation), and **declaration files** such
  as `.d.ts` (describe their exported API in 3.6 instead)
- function *types* such as `onClick: (e: Event) => void`
- a Python `if __name__ == "__main__":` block. Describe it in the file's role sentence
  and in 1.5; if it holds real logic, not just a call to `main()`, describe that logic
  there too
- code inside strings, and commented-out code

**Types** (classes, structs, interfaces, enums, traits, records, type aliases, modules)
are listed separately in 3.5, not counted as callables.

## IDs and the inventory record

- Assign IDs in reading order: the `(root)` module (files at the top level) first, then
  the other modules alphabetically, files alphabetically within a module, declarations
  top to bottom within a file. Use `F001`, `F002`, … (four digits past 999: `F1000`).
  The same code always yields the same IDs, which is what makes resuming safe.
- Never renumber. A callable found later takes the next free ID. An item that turns
  out not to be a callable is *withdrawn*: its ID stays unused and is listed in
  Appendix B.
- Record for each: **ID · file · line (or range) · kind · qualified name**, plus the
  signature if it's handy. The qualified name is `Class.method`, `Outer.inner` for a
  nested function, or `module.function` when a bare name is ambiguous.
- Kinds: function, method, constructor, destructor, getter, setter, operator, local
  function, script, script block, main block, iife, procedure, and trigger. "abstract"
  and "test" are flags, not kinds.
- A named lambda or arrow, or a function stored on a property, takes its kind from
  where it lives:
  - at module level (`const parse = () => …`): *function*
  - on a class, prototype, or module-level object (`api.fetch = async () => …`):
    *method*, named `api.fetch`
  - inside a function, including on a local value (`makeTimer` builds `timer` and
    sets `timer.stop = () => …`): *local function*, named `makeTimer.timer.stop`

Working format, one row per callable, in ID order:

```markdown
| ID | File | Lines | Kind | Qualified name |
| --- | --- | --- | --- | --- |
| F001 | `src/parse.ts` | 5–13 | function | `tokenize` |
```

Keep it where it survives the whole job: in working notes, in the report file's 1.6
index (with summaries filled in later), or at the top of your first chat part. Files
with no callables get no row and no index table; they still appear in 3.1.

## Building it

1. **With content search** (grep-like tools or code search): run the patterns below
   for each language present, per module. Each hit is a *candidate*. Then open the
   file to confirm each one, and catch what patterns can't see (class members without
   keywords, nested functions, decorators).
2. **Without search:** read each file top to bottom and record declarations as you go.
   This is also the reading pass for step 6: once a file's inventory is complete, you
   may write its entries before opening the next file. Take the size estimate for
   scaling.md from the file listing instead.
3. **Check for generated files as you open each file.** A comment in the first few
   lines saying "generated", "auto-generated", or "do not edit" means the file is
   excluded: take it out of the inventory and the language counts, and list it in
   Appendix A.
4. **Per-file tally.** After each file, write down how many callables it has. The
   tallies must add up to the total, and verification uses them.
5. **Huge files** (thousands of lines): read them in consecutive chunks. Record
   declarations chunk by chunk and never skip a range.

Search patterns are line-oriented regular expressions. They find most declarations,
and reading confirms or rejects each hit.

## Per-language declaration patterns

| Language | Search pattern (candidates) | Also count while reading |
| --- | --- | --- |
| Python | `^\s*(async\s+)?def\s+\w+` · `^\s*\w+\s*=\s*lambda\b` | Kinds from context: `__init__` is a constructor, `@property` a getter, `@x.setter` a setter, a def inside a def a local function |
| JavaScript / TypeScript | `\bfunction\s*\*?\s*\w+\s*\(` · `\b(const\|let\|var)\s+\w+\s*(:[^=]+)?=\s*(async\s*)?(function\b\|\([^)]*\)\s*(:[^=]*)?=>\|\w+\s*=>)` · `^\s*[\w$]+(\.[\w$]+)+\s*=\s*(async\s*)?(function\b\|\([^)]*\)\s*=>\|[\w$]+\s*=>)` (property-assigned, including `exports.x`, `obj.fn`, `.prototype.x`) · `^\s*(module\.)?exports\.\w+\s*=` · `^\s*[;!]?\(\s*(async\s*)?(function\b\|\()` (IIFE) | Class members `name(…) {`, `get`/`set`/`static`/`async`/`#private` methods, `constructor`, class-property arrows `handler = (e) => {…}`, object-literal methods `list() {…}` and `create: async (x) => …`, `abstract` members, interface method signatures (abstract) |
| C# | `^\s*(\[.*\]\s*)*(public\|private\|protected\|internal\|static\|virtual\|override\|abstract\|async\|sealed\|extern\|partial\|new)[\w\s<>\[\],.?]*\s+~?\w+\s*(<[^>]*>)?\s*\(` | Constructors and destructors (`~Name()`), interface members (no modifiers; abstract), `operator +`, local functions inside methods, expression-bodied `=> …` members |
| Java | Same shape as C# with `final\|synchronized\|native\|default` | Package-private methods with no modifier (`Color next() {`), interface methods (abstract unless `default`), constructors, methods in anonymous classes and enums |
| Kotlin | `\bfun\s+(<[^>]*>\s*)?([\w.]+\.)?\w+\s*\(` | `constructor(…)`, extension functions (`fun String.x()`), interface members, `companion object` members |
| Swift | `\bfunc\s+` · `\binit\s*[?!]?\s*\(` · `\bdeinit\b` · `\bsubscript\s*\(` | Protocol requirements (abstract), `extension` members, operator funcs (`static func ==`) |
| Scala | `\bdef\s+\w+` | Trait members without a body (abstract), `case class` members |
| Go | `^func\s` | Methods have a receiver `func (s *Store) Get(…)`; interface method lines inside `type X interface {` (abstract) |
| Rust | `^\s*(pub(\([\w:]+\))?\s+)?(default\s+\|const\s+\|async\s+\|unsafe\s+\|extern\s+"\w*"\s+)*fn\s+\w+` | Trait methods without a body (abstract); `impl X` and `impl Trait for X` give the container; functions in `mod tests` are tests |
| C / C++ / CUDA | `^[\w:<>*&\s]+[\s*&](~?\w+(::~?\w+)*\|operator\S+)\s*\([^;]*$` (definitions spanning lines too) | Only **definitions** (with a body `{…}`) count, plus pure virtuals `= 0`. Out-of-class `Class::method(` definitions, constructors with initializer lists, GNU style (return type on the previous line), templates |
| PHP | `\bfunction\s+&?\s*\w+\s*\(` | `__construct`/`__destruct`, interface and abstract methods; closures `function ($x) use …` don't count |
| Ruby | `^\s*def\s+(self\.)?[\w?!=\[\]+\-*/<>%]+` | `initialize` is the constructor; endless defs `def x = …`; `def self.x` is a class method |
| Lua | `\bfunction\s+[\w.:]+\s*\(` · `[\w.:]+\s*=\s*function\s*\(` | `local function`; `M.f` and `M:f` belong to container `M` |
| Elixir | `^\s*(def\|defp\|defmacro\|defmacrop\|defguard)\s+[\w?!]+` | One-liners `def f(x), do: …` |
| PowerShell | `^\s*(function\|filter\|workflow)\s+[\w:.\-]+` · `^\s*(\[scriptblock\]\s*)?\$[\w:]+\s*=\s*(\[[^\]]+\]\s*)*\{` (script blocks, including casts like `$cmp = [Comparison[string]] {`) · `^\s*param\s*\(` (script-level) | Class methods `[string] Describe() {`, class constructors (name equals the class), a `.ps1` whose first statement is `param(` (a *script*, named after the file), functions defined inside `begin {}` blocks (local to the script) |
| Shell (bash/sh/zsh) | `^\s*(function\s+[\w:.\-]+\|[\w:.\-]+\s*\(\s*\))` | Subshell bodies `f() ( … )`; heredoc contents are *not* code |
| Batch | `^:\w+` | Labels used as subroutines (skip `:eof`) |
| Dart | Typed like Java, plus `^\s*\w+\s*\(.*\)\s*(async\s*)?(\{\|=>)` at top level | Named constructors `Counter.named(…)`, `factory` constructors, bodyless constructors `const Counter({this.x});` |
| Pascal / Delphi | `^\s*(class\s+)?(procedure\|function\|constructor\|destructor)\s+[\w.]+` | Program main block: the last column-0 `begin` before the final `end.`. Skip declarations in a unit's `interface` section and `forward;` declarations |
| SQL | `CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION\|PROCEDURE\|PROC\|TRIGGER)\s+` (case-insensitive) | Views and tables are types, not callables |
| Visual Basic .NET | `\b(Function\|Sub\|Operator)\s+\w+` (case-insensitive) | `Sub New` is the constructor; `MustOverride` members are abstract |
| F# · Haskell · OCaml | `let\s+(rec\s+\|inline\s+)*\w+\s+\w` · `^\w+\s*::` (type signatures) · `let\s+(rec\s+)?\w+\s+\w+.*=` | `member` definitions (F#); count Haskell functions by their signatures |
| Clojure · Lisp | `\((defn-?\|defmacro\|defmethod\|defun\|define)\s` | |
| Julia · R · MATLAB | `^\s*function\s+[\w.!]+` · `[\w.]+\s*(<-\|=)\s*function\s*\(` · `^\s*function\s+.*=?\s*\w+` | Julia short form `f(x) = …` |
| Zig · Nim · GDScript · Solidity | `\bfn\s+\w+` · `^\s*(proc\|func\|method\|iterator\|template\|macro)\s+\w+` · `^\s*(static\s+)?func\s+\w+` · `\b(function\|modifier\|constructor)\s*\w*\s*\(` | |
| Vue · Svelte · HTML | JS/TS patterns inside `<script>` blocks | Line numbers are the file's, not the block's |

(In the table, `\|` stands for the regex alternation `|`.)

## Traps that cause miscounts

These all came up in real codebases. Check for them whenever the language appears.

- **Keywords as method names.** Rust `fn new`, Go `func init`, and JS methods named
  `get`, `add`, or `remove` are real callables. Don't drop them because they look like
  keywords.
- **Function types aren't functions.** In TypeScript interfaces and type literals,
  `onClick: (e: MouseEvent) => void;` and `private cb: (x: number) => void;` declare
  types. Only a property whose value *is* an arrow function (`handler = (e) => {…}`)
  counts.
- **Overloads.** TypeScript overload signatures without a body don't count; the
  implementation does. In C#, Java, and C++, each overload with a body is its own
  callable, with its own ID.
- **Prototypes versus definitions (C/C++).** `int foo(int);` in a header, and
  `Shape& operator=(const Shape&);` inside a class, are declarations. Count the
  definition wherever it lives (`Shape& Shape::operator=(…) {`).
- **Calls that look like declarations.** `foo(x) {` doesn't exist in C-family code,
  but `if (…) {`, `for (…)`, `switch (…)`, `catch (…)`, `using (…)`, `lock (…)`,
  `synchronized (…)`, and macros like `TEST(Suite, Name) {` do. A statement starting
  with `return`, `throw`, `new`, or `await`, or one containing `=` before the name, is
  a call, not a declaration.
- **Annotations and attributes.** `@Override`, `[HttpGet("x")]`, and
  `#[derive(Debug)]` sit above declarations. They aren't callables themselves.
- **Records and delegates are types.** C# `record Point(int X, int Y);` and
  `delegate void Handler(…)`, Kotlin `data class User(…)`, and Scala `case class`
  parameter lists are types, not constructors to count.
- **Code inside strings.** Rust raw strings `r#"…"#`, Python triple-quoted strings,
  template literals, SQL in strings, and shell heredocs can contain text that looks
  like functions. It isn't code of this project.
- **Ruby modifier `if`/`unless`.** `return unless x` and `save if valid?` don't open
  blocks. Use `end` matching only for `def`, `class`, `module`, `do`, and statement-
  start `if`/`unless`/`while`/`case` when working out where a method ends.
- **PowerShell nested attributes.** `[OutputType([pscustomobject])]` and
  `[Parameter(Mandatory, ParameterSetName = 'Path')]` sit above or inside `param(`.
  The parameters are the `$names`.
- **Pascal procedure bodies.** Every procedure's `begin` is usually at column 0. Only
  the one before the final `end.` is the main block.
- **JS test files.** `test('…', t => {…})`, `it(…)`, and `describe(…)` register
  anonymous callbacks. They aren't callables; count the `test`/`it` cases (not the
  `describe` groups) for 3.9. A named helper function inside a test file *is* a
  callable.
- **Declaration files.** `.d.ts` files and C/C++ headers only declare functions
  implemented elsewhere. They add no inventory items, but they document the public API
  for 3.6, including overloads and option types.
- **Dart and Kotlin constructors without bodies** (`const Foo({this.x});`,
  `constructor() : this(Db())`) are complete constructors, not abstract declarations.
- **Generated or vendored files that slipped through** (a copied library, a bundled
  minified file). Exclude them from the inventory and note them in Appendix A.
- **Jupyter notebooks.** Inventory the code cells and cite locations as "cell N,
  line M".
