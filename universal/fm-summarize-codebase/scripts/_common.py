"""
Shared helpers for the fm-summarize-codebase scripts (stdlib only, Python 3.9+).

  - LANGUAGES / detect_language(): extension, filename, and shebang language map
    with a linguist-style type (programming, markup, data, prose).
  - list_files(): the codebase's file set. Uses git (tracked + untracked-but-not-
    ignored) when the root is inside a work tree, else a directory walk with
    default excludes. Classifies vendored, generated, binary, and oversized files.
  - scan(): a comment/string masking scanner. Returns the text with comment and
    string contents blanked (offsets and newlines preserved) plus per-line
    code/comment flags. Line counting and symbol extraction both build on it.
"""

from __future__ import annotations

import fnmatch
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

TOOL_NAME = "fm-summarize-codebase"
SCHEMA_VERSION = 1

MAX_PARSE_BYTES = 2_000_000   # larger files are counted but not parsed for symbols
BINARY_SNIFF_BYTES = 8192


def utf8_stdio() -> None:
    """Windows consoles default to a legacy code page; never crash on output."""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
        except (AttributeError, ValueError):
            pass


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def dump_json(data, path: Path | None) -> None:
    text = json.dumps(data, indent=2, ensure_ascii=False)
    if path is None:
        print(text)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text + "\n", encoding="utf-8")


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


# Directories that only hold other modules; the module is the directory beneath them.
MODULE_CONTAINERS = {"src", "lib", "libs", "app", "apps", "packages", "crates", "modules", "internal", "pkg",
                     "cmd", "source", "sources", "Sources", "projects", "services", "plugins", "extensions",
                     "components", "addons", "tools"}


def module_of(path: str) -> str:
    """Group a file into a module: its first directory, or two levels under container dirs.

    src/server.py → src · src/js/x.js → src/js · crates/fff-core/src/lib.rs → crates/fff-core
    tests/unit/test_x.py → tests · README.md → (root)
    """
    parts = path.split("/")
    if len(parts) == 1:
        return "(root)"
    if parts[0] in MODULE_CONTAINERS and len(parts) >= 3:
        return f"{parts[0]}/{parts[1]}"
    return parts[0]


def slug(text: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-").lower()
    return s or "root"


PAGE_LIMIT = 150      # a module with more callables gets one reference page per file
FILE_CHUNK = 60       # a file with more than 1.5x this many callables is split into parts of this size


def reference_pages(symbols: list[dict]) -> dict[str, str]:
    """symbol id -> reference page slug.

    Small modules share a page, big modules get a page per file, and very large
    files are split into parts. Pages are the unit of ownership when several
    agents fill the reference in parallel, so no page is ever shared.
    """
    from collections import Counter, defaultdict
    per_module = Counter(module_of(s["file"]) for s in symbols)
    by_file = defaultdict(list)
    for s in symbols:
        by_file[s["file"]].append(s)
    pages = {}
    for f, items in by_file.items():
        items = sorted(items, key=lambda s: (s.get("cell") or 0, s["line"]))
        if len(items) > FILE_CHUNK * 1.5:
            for k, s in enumerate(items):
                pages[s["id"]] = f"{slug(f)}-part-{k // FILE_CHUNK + 1}"
        else:
            page = slug(f) if per_module[module_of(f)] > PAGE_LIMIT else slug(module_of(f))
            for s in items:
                pages[s["id"]] = page
    return pages


# ── Language table ───────────────────────────────────────────────────────────
# Comment styles: "c" = // and /* */, "hash" = #, and the named ones below.
# `strings` lists the quote characters that open string literals; `char_quote`
# marks languages where ' opens a short char literal only (C, Rust, Go, ...),
# so Rust lifetimes and apostrophes don't swallow the rest of the line.

@dataclass(frozen=True)
class Lang:
    name: str
    type: str                       # programming | markup | data | prose
    exts: tuple = ()
    filenames: tuple = ()
    line: tuple = ()                # line-comment tokens
    block: tuple = ()               # (open, close) block-comment pairs
    strings: tuple = ('"', "'")
    char_quote: bool = False
    triple: bool = False            # Python-style """ and '''
    backtick: bool = False          # ` opens a (multi-line) string
    escape: str = "\\"
    nested_block: bool = False      # Rust, Swift, Kotlin, Haskell nest block comments
    regex_literals: bool = False    # JS-family /regex/ literals
    shebangs: tuple = ()


C_LINE, C_BLOCK = ("//",), (("/*", "*/"),)
HASH = ("#",)
XML_BLOCK = (("<!--", "-->"),)

_LANG_LIST = [
    # programming ─────────────────────────────────────────────────────────────
    Lang("Python", "programming", (".py", ".pyw", ".pyi"), ("SConstruct", "SConscript"),
         HASH, strings=('"', "'"), triple=True, shebangs=("python",)),
    Lang("JavaScript", "programming", (".js", ".mjs", ".cjs", ".jsx"), ("Jakefile",),
         C_LINE, C_BLOCK, backtick=True, regex_literals=True, shebangs=("node", "deno", "bun")),
    Lang("TypeScript", "programming", (".ts", ".mts", ".cts", ".tsx"), (),
         C_LINE, C_BLOCK, backtick=True, regex_literals=True, shebangs=("ts-node", "tsx")),
    Lang("C#", "programming", (".cs", ".csx"), (), C_LINE, C_BLOCK, char_quote=True),
    Lang("F#", "programming", (".fs", ".fsi", ".fsx"), (), C_LINE, (("(*", "*)"),)),
    Lang("Visual Basic .NET", "programming", (".vb",), (), ("'",), strings=('"',), escape=""),
    Lang("Java", "programming", (".java",), (), C_LINE, C_BLOCK, char_quote=True),
    Lang("Kotlin", "programming", (".kt", ".kts"), (), C_LINE, C_BLOCK, char_quote=True,
         nested_block=True),
    Lang("Scala", "programming", (".scala", ".sc"), (), C_LINE, C_BLOCK, char_quote=True),
    Lang("Groovy", "programming", (".groovy", ".gradle", ".gvy"), ("Jenkinsfile",), C_LINE, C_BLOCK),
    Lang("Go", "programming", (".go",), (), C_LINE, C_BLOCK, strings=('"',), char_quote=True,
         backtick=True),
    Lang("Rust", "programming", (".rs",), (), C_LINE, C_BLOCK, strings=('"',), char_quote=True,
         nested_block=True),
    Lang("C", "programming", (".c",), (), C_LINE, C_BLOCK, strings=('"',), char_quote=True),
    Lang("C++", "programming", (".cpp", ".cc", ".cxx", ".c++", ".hpp", ".hh", ".hxx", ".h++",
                                ".ipp", ".tpp", ".inl", ".ixx", ".cppm"), (),
         C_LINE, C_BLOCK, strings=('"',), char_quote=True),
    Lang("C/C++ Header", "programming", (".h",), (), C_LINE, C_BLOCK, strings=('"',), char_quote=True),
    Lang("Objective-C", "programming", (".mm",), (), C_LINE, C_BLOCK, strings=('"',), char_quote=True),
    Lang("CUDA", "programming", (".cu", ".cuh"), (), C_LINE, C_BLOCK, strings=('"',), char_quote=True),
    Lang("Swift", "programming", (".swift",), (), C_LINE, C_BLOCK, strings=('"',), nested_block=True,
         triple=True),
    Lang("Dart", "programming", (".dart",), (), C_LINE, C_BLOCK, triple=True),
    Lang("Ruby", "programming", (".rb", ".rake", ".gemspec", ".ru"),
         ("Rakefile", "Gemfile", "Guardfile", "Podfile", "Fastfile", "Vagrantfile"),
         HASH, (("=begin", "=end"),), shebangs=("ruby",)),
    Lang("Crystal", "programming", (".cr",), (), HASH),
    Lang("PHP", "programming", (".php", ".phtml", ".php8"), (), ("//", "#"), C_BLOCK,
         shebangs=("php",)),
    Lang("Perl", "programming", (".pl", ".pm", ".t"), (), HASH, (("=pod", "=cut"),),
         shebangs=("perl",)),
    Lang("Lua", "programming", (".lua",), (), ("--",), (("--[[", "]]"),), shebangs=("lua",)),
    Lang("R", "programming", (".r", ".R", ".rmd"), (), HASH, shebangs=("Rscript",)),
    Lang("Julia", "programming", (".jl",), (), HASH, (("#=", "=#"),), triple=True),
    Lang("Elixir", "programming", (".ex", ".exs"), (), HASH, triple=True),
    Lang("Erlang", "programming", (".erl", ".hrl"), (), ("%",), strings=('"',)),
    Lang("Haskell", "programming", (".hs", ".lhs"), (), ("--",), (("{-", "-}"),), strings=('"',),
         nested_block=True),
    Lang("OCaml", "programming", (".ml", ".mli"), (), (), (("(*", "*)"),), strings=('"',),
         nested_block=True),
    Lang("Clojure", "programming", (".clj", ".cljs", ".cljc"), (), (";",), strings=('"',)),
    Lang("Emacs Lisp", "programming", (".el",), (), (";",), strings=('"',)),
    Lang("Common Lisp", "programming", (".lisp", ".lsp"), (), (";",), (("#|", "|#"),), strings=('"',)),
    Lang("Scheme", "programming", (".scm", ".ss", ".rkt"), (), (";",), strings=('"',)),
    Lang("Zig", "programming", (".zig",), (), C_LINE, (), strings=('"',), char_quote=True),
    Lang("Nim", "programming", (".nim", ".nims"), (), HASH, (("#[", "]#"),), triple=True),
    Lang("Solidity", "programming", (".sol",), (), C_LINE, C_BLOCK),
    Lang("GDScript", "programming", (".gd",), (), HASH, triple=True),
    Lang("PowerShell", "programming", (".ps1", ".psm1", ".psd1"), (), HASH, (("<#", "#>"),),
         escape="`", shebangs=("pwsh", "powershell")),
    Lang("Shell", "programming", (".sh", ".bash", ".zsh", ".ksh", ".bats"),
         (".bashrc", ".zshrc", ".profile", ".bash_profile"), HASH,
         shebangs=("sh", "bash", "zsh", "ksh", "dash", "ash")),
    Lang("Fish", "programming", (".fish",), (), HASH, shebangs=("fish",)),
    Lang("Batchfile", "programming", (".bat", ".cmd"), (), ("::", "REM ", "rem ", "@REM ", "@rem "),
         strings=('"',), escape="^"),
    Lang("AutoHotkey", "programming", (".ahk",), (), (";",), C_BLOCK, strings=('"',), escape="`"),
    Lang("AppleScript", "programming", (".applescript", ".scpt"), (), ("--", "#"), (("(*", "*)"),),
         strings=('"',)),
    Lang("SQL", "programming", (".sql", ".psql", ".pgsql"), (), ("--",), C_BLOCK, strings=("'", '"')),
    Lang("GLSL", "programming", (".glsl", ".vert", ".frag", ".geom", ".comp", ".tesc", ".tese"), (),
         C_LINE, C_BLOCK, strings=('"',)),
    Lang("HLSL", "programming", (".hlsl", ".fx", ".fxh", ".shader", ".cginc"), (),
         C_LINE, C_BLOCK, strings=('"',)),
    Lang("WGSL", "programming", (".wgsl",), (), C_LINE, C_BLOCK, strings=('"',)),
    Lang("Assembly", "programming", (".asm", ".s", ".S", ".nasm"), (), (";", "#"), C_BLOCK,
         strings=('"',)),
    Lang("MATLAB", "programming", (), (), ("%",), (("%{", "%}"),), strings=("'", '"'), escape=""),
    Lang("Fortran", "programming", (".f", ".for", ".f90", ".f95", ".f03", ".f08"), (), ("!",),
         strings=("'", '"')),
    Lang("Pascal", "programming", (".pas", ".pp", ".dpr", ".lpr"), (), ("//",),
         (("{", "}"), ("(*", "*)")), strings=("'",), escape=""),
    Lang("Makefile", "programming", (".mk", ".mak"), ("Makefile", "makefile", "GNUmakefile"), HASH),
    Lang("CMake", "programming", (".cmake",), ("CMakeLists.txt",), HASH, (("#[[", "]]"),),
         strings=('"',)),
    Lang("Dockerfile", "programming", (".dockerfile",), ("Dockerfile", "Containerfile"), HASH),
    Lang("Nix", "programming", (".nix",), (), HASH, C_BLOCK, strings=('"',)),
    Lang("HCL", "programming", (".tf", ".tfvars", ".hcl"), (), ("#", "//"), C_BLOCK, strings=('"',)),
    Lang("Jupyter Notebook", "markup", (".ipynb",), (), (), (), strings=()),
    # markup ──────────────────────────────────────────────────────────────────
    Lang("HTML", "markup", (".html", ".htm", ".xhtml", ".shtml"), (), (), XML_BLOCK, strings=()),
    Lang("CSS", "markup", (".css",), (), (), C_BLOCK),
    Lang("SCSS", "markup", (".scss",), (), C_LINE, C_BLOCK),
    Lang("Sass", "markup", (".sass",), (), C_LINE, C_BLOCK),
    Lang("Less", "markup", (".less",), (), C_LINE, C_BLOCK),
    Lang("Stylus", "markup", (".styl",), (), C_LINE, C_BLOCK),
    Lang("Vue", "markup", (".vue",), (), (), XML_BLOCK, strings=()),
    Lang("Svelte", "markup", (".svelte",), (), (), XML_BLOCK, strings=()),
    Lang("Astro", "markup", (".astro",), (), (), XML_BLOCK, strings=()),
    Lang("XAML", "markup", (".xaml", ".axaml"), (), (), XML_BLOCK, strings=()),
    Lang("Razor", "markup", (".cshtml", ".razor"), (), (), (("@*", "*@"), ("<!--", "-->")), strings=()),
    Lang("Handlebars", "markup", (".hbs", ".handlebars", ".mustache"), (), (), (("{{!--", "--}}"),),
         strings=()),
    Lang("Pug", "markup", (".pug", ".jade"), (), ("//",), strings=()),
    Lang("EJS", "markup", (".ejs",), (), (), XML_BLOCK, strings=()),
    Lang("Liquid", "markup", (".liquid",), (), (), (("{% comment %}", "{% endcomment %}"),), strings=()),
    Lang("Twig", "markup", (".twig",), (), (), (("{#", "#}"),), strings=()),
    Lang("TeX", "markup", (".tex", ".sty", ".cls", ".bib"), (), ("%",), strings=()),
    # data ────────────────────────────────────────────────────────────────────
    Lang("JSON", "data", (".json", ".jsonc", ".json5", ".webmanifest", ".har"),
         (".babelrc", ".eslintrc", ".prettierrc"), C_LINE, C_BLOCK, strings=('"',)),
    Lang("YAML", "data", (".yml", ".yaml"), (".clang-format",), HASH),
    Lang("TOML", "data", (".toml",), ("Pipfile",), HASH, triple=True),
    Lang("XML", "data", (".xml", ".xsd", ".xsl", ".xslt", ".plist", ".resx", ".manifest", ".nuspec",
                         ".storyboard", ".xib", ".config", ".wxs"), (), (), XML_BLOCK, strings=()),
    Lang("MSBuild", "data", (".csproj", ".vbproj", ".fsproj", ".vcxproj", ".props", ".targets",
                             ".proj", ".sqlproj"), (), (), XML_BLOCK, strings=()),
    Lang("Solution", "data", (".sln", ".slnx", ".slnf"), (), (), (), strings=()),
    Lang("INI", "data", (".ini", ".cfg", ".conf", ".editorconfig", ".properties", ".prefs"),
         (".gitconfig", ".npmrc", ".flake8"), (";", "#"), strings=()),
    Lang("CSV", "data", (".csv", ".psv"), (), (), (), strings=()),
    Lang("TSV", "data", (".tsv", ".tab"), (), (), (), strings=()),
    Lang("SVG", "data", (".svg",), (), (), XML_BLOCK, strings=()),
    Lang("GraphQL", "data", (".graphql", ".gql", ".graphqls"), (), HASH, strings=('"',)),
    Lang("Protocol Buffers", "data", (".proto",), (), C_LINE, C_BLOCK, strings=('"',)),
    Lang("Env", "data", (".env",), (".env", ".env.example", ".env.local", ".env.sample"), HASH,
         strings=()),
    Lang("Ignore List", "data", (), (".gitignore", ".dockerignore", ".npmignore", ".prettierignore",
                                   ".eslintignore", ".gitattributes", ".gitmodules"), HASH, strings=()),
    # prose ───────────────────────────────────────────────────────────────────
    Lang("Markdown", "prose", (".md", ".markdown", ".mdx", ".mdown"), (), (), XML_BLOCK, strings=()),
    Lang("reStructuredText", "prose", (".rst",), (), (), (), strings=()),
    Lang("AsciiDoc", "prose", (".adoc", ".asciidoc"), (), ("//",), strings=()),
    Lang("Org", "prose", (".org",), (), ("#",), strings=()),
    Lang("Text", "prose", (".txt", ".text"), ("LICENSE", "LICENCE", "COPYING", "NOTICE", "AUTHORS",
                                              "CONTRIBUTORS", "CHANGELOG", "README"), (), strings=()),
]

LANGUAGES: dict[str, Lang] = {lang.name: lang for lang in _LANG_LIST}
_BY_EXT: dict[str, Lang] = {}
_BY_NAME: dict[str, Lang] = {}
for _lang in _LANG_LIST:
    for _ext in _lang.exts:
        _BY_EXT.setdefault(_ext.lower(), _lang)
        _BY_EXT.setdefault(_ext, _lang)
    for _fn in _lang.filenames:
        _BY_NAME[_fn] = _lang
_BY_EXT[".R"] = LANGUAGES["R"]

TEXT_NAME_PREFIXES = ("LICENSE", "LICENCE", "COPYING", "README", "CHANGELOG", "CHANGES", "NOTICE",
                      "AUTHORS", "CONTRIBUTORS", "VERSION", "CODEOWNERS", "HISTORY", "SECURITY")
for _name, _lname in ((".gitkeep", "Ignore List"), (".keep", "Ignore List"), (".nixignore", "Ignore List"),
                      (".luacheckrc", "Lua"), (".nvmrc", "Text"), (".python-version", "Text"),
                      (".tool-versions", "Text"), ("Brewfile", "Ruby"), ("justfile", "Makefile"),
                      ("Justfile", "Makefile"), ("Procfile", "YAML"), (".prettierrc", "JSON"),
                      (".stylelintrc", "JSON"), (".swcrc", "JSON"), ("tsconfig.json", "JSON")):
    _BY_NAME[_name] = LANGUAGES[_lname]

OBJC_HINT = re.compile(r"^\s*(#import|@interface|@implementation|@protocol|@end)\b", re.M)
MATLAB_HINT = re.compile(r"^\s*(function\b|%|end\b)", re.M)


def detect_language(rel_path: str, head: str | None = None) -> Lang | None:
    """Language for a path; `head` (first ~2 KB of text) resolves shebangs and .m files."""
    name = rel_path.rsplit("/", 1)[-1]
    if name in _BY_NAME:
        return _BY_NAME[name]
    if name.startswith("Dockerfile") or name.endswith(".Dockerfile"):
        return LANGUAGES["Dockerfile"]
    if name.startswith(".env"):
        return LANGUAGES["Env"]
    if name.startswith(".") and name.count(".") == 1 and name in _BY_EXT:
        return _BY_EXT[name]              # .editorconfig, .babelrc, ...
    upper = name.upper()
    if "." not in name and upper.startswith(TEXT_NAME_PREFIXES):
        return LANGUAGES["Text"]          # LICENSE-MIT, README, VERSION, CODEOWNERS
    ext = os.path.splitext(name)[1]
    if ext == ".m":
        if head is not None and OBJC_HINT.search(head):
            return LANGUAGES["Objective-C"]
        return LANGUAGES["MATLAB"]
    if ext:
        lang = _BY_EXT.get(ext) or _BY_EXT.get(ext.lower())
        if lang:
            return lang
    if head and head.startswith("#!"):
        first = head.splitlines()[0]
        interp = first.split("/")[-1].split()
        if interp and interp[0] == "env" and len(interp) > 1:
            interp = interp[1:]
            while interp and interp[0].startswith("-"):
                interp = interp[1:]
        if interp:
            prog = re.sub(r"[\d.]+$", "", interp[0])
            for lang in _LANG_LIST:
                if prog in lang.shebangs:
                    return lang
    return None


# ── File discovery ───────────────────────────────────────────────────────────

VENDOR_DIRS = {
    "node_modules", "bower_components", "jspm_packages", "vendor", "vendors", "third_party",
    "third-party", "thirdparty", "external", "externals", "deps", "_deps", "Pods", "Carthage",
    "packages", "site-packages", "dist-packages", ".venv", "venv", "env", ".tox", ".nox",
    ".eggs", "__pypackages__", ".yarn", ".pnpm-store", ".bundle", "elm-stuff", ".cargo",
}
GENERATED_DIRS = {
    "dist", "build", "out", "bin", "obj", "target", "coverage", ".next", ".nuxt", ".svelte-kit",
    ".output", ".turbo", ".parcel-cache", ".cache", "__pycache__", ".pytest_cache", ".mypy_cache",
    ".ruff_cache", "htmlcov", ".gradle", "DerivedData", ".angular", "storybook-static",
    "__generated__", "generated", "gen", ".docusaurus", ".expo", "cmake-build-debug",
    "cmake-build-release", ".terraform", "artifacts", "codebase-summary",
}
# Tracked files under these names are usually real sources (Rust src/bin, bin/cli.js
# launchers, build/ tooling scripts), so git-listed trees only treat the rest as output.
GIT_SAFE_GENERATED_DIRS = GENERATED_DIRS - {"bin", "build", "out", "target", "gen", "artifacts", "obj"}
ALWAYS_SKIP_DIRS = {".git", ".hg", ".svn", ".idea", ".vs", ".DS_Store"}
# `packages` and `env` are too generic to treat as vendored when tracked by git
# (monorepos keep their own code in packages/). They only apply to walked trees.
GIT_SAFE_VENDOR_DIRS = VENDOR_DIRS - {"packages", "env", "external", "externals", "deps", ".cargo"}

GENERATED_FILE_PATTERNS = (
    "*.min.js", "*.min.css", "*.min.mjs", "*.bundle.js", "*.chunk.js", "*.map", "*.pb.go",
    "*_pb2.py", "*_pb2_grpc.py", "*.pb.cc", "*.pb.h", "*.g.cs", "*.g.i.cs", "*.designer.cs",
    "*.Designer.cs", "*.Designer.vb", "*.generated.*", "*.gen.go", "*_generated.go",
    "package-lock.json", "npm-shrinkwrap.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb",
    "bun.lock", "Cargo.lock", "poetry.lock", "Pipfile.lock", "uv.lock", "composer.lock",
    "Gemfile.lock", "go.sum", "packages.lock.json", "flake.lock", "pubspec.lock", "mix.lock",
    "Podfile.lock", "*.lock",
    "CODEBASE_SUMMARY.md",                        # this skill's own output, on a re-run
)
GENERATED_HEADER = re.compile(
    r"@generated|<auto-generated|auto-generated|autogenerated|DO NOT EDIT|do not edit by hand|"
    r"Code generated .* DO NOT EDIT|This file was automatically generated|generated by (?:the )?protoc",
    re.IGNORECASE)
COMMENT_START = re.compile(r"^\s*(//|#|/\*|\*|<!--|--|;|'|%|\(\*|\{-|@?rem\s)", re.IGNORECASE)


def has_generated_header(head_text: str) -> bool:
    """A generated-file banner is a comment in the first five non-empty lines."""
    lines = [ln for ln in head_text.splitlines() if ln.strip()][:5]
    return any(COMMENT_START.match(ln) and GENERATED_HEADER.search(ln) for ln in lines)

TEST_PATH = re.compile(
    r"(^|/)(tests?|__tests__|spec|specs|testing|test_?data|fixtures|e2e|cypress|playwright)(/|$)|"
    r"(^|/)test_[^/]+\.py$|_test\.(py|go|rb|exs|dart|cpp|cc|c)$|(^|/)conftest\.py$|"
    r"\.(test|spec|e2e)\.[cm]?[jt]sx?$|Tests?\.(cs|java|kt|swift|vb|fs)$|\.Tests?\.ps1$|"
    r"_spec\.rb$|Spec\.(scala|kt|groovy)$|_test\.exs$|\.bats$", re.IGNORECASE)


@dataclass
class FileEntry:
    path: str                   # POSIX path relative to the analysis root
    size: int
    lang: Lang | None
    status: str = "source"      # source | vendored | generated | binary | large | unknown
    reason: str = ""
    tracked: bool = True
    is_test: bool = False


def run_git(args: list[str], cwd: Path) -> str | None:
    try:
        proc = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout.decode("utf-8", errors="replace")


def git_toplevel(root: Path) -> Path | None:
    out = run_git(["rev-parse", "--show-toplevel"], root)
    return Path(out.strip()) if out and out.strip() else None


def _git_file_list(root: Path) -> tuple[list[str], set[str]] | None:
    tracked = run_git(["ls-files", "-z", "--cached", "--", "."], root)
    if tracked is None:
        return None
    untracked = run_git(["ls-files", "-z", "--others", "--exclude-standard", "--", "."], root) or ""
    t = [p for p in tracked.split("\0") if p]
    u = [p for p in untracked.split("\0") if p]
    return sorted(set(t) | set(u)), set(t)


def _walk_file_list(root: Path) -> list[str]:
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames
                       if d not in ALWAYS_SKIP_DIRS and d not in VENDOR_DIRS and d not in GENERATED_DIRS
                       and not (d.startswith(".") and d not in {".github", ".gitlab", ".circleci",
                                                                ".claude", ".claude-plugin", ".vscode",
                                                                ".devcontainer", ".husky"})]
        for fn in filenames:
            rel = os.path.relpath(os.path.join(dirpath, fn), root).replace(os.sep, "/")
            files.append(rel)
    return sorted(files)


def _gitattributes_rules(root: Path) -> list[tuple[str, str]]:
    """(pattern, flag) pairs for linguist-vendored / -generated / -documentation."""
    rules = []
    ga = root / ".gitattributes"
    if not ga.is_file():
        return rules
    for raw in ga.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        for attr in parts[1:]:
            for flag in ("linguist-vendored", "linguist-generated", "linguist-documentation"):
                if attr in (flag, f"{flag}=true", f"{flag}=set"):
                    rules.append((parts[0], flag))
    return rules


def _match_attr(rel: str, pattern: str) -> bool:
    pat = pattern.lstrip("/")
    if pat.endswith("/**"):
        return rel.startswith(pat[:-3] + "/")
    if "/" not in pat:
        return fnmatch.fnmatch(rel.rsplit("/", 1)[-1], pat) or fnmatch.fnmatch(rel, f"*/{pat}")
    return fnmatch.fnmatch(rel, pat) or fnmatch.fnmatch(rel, pat + "/*")


def read_head(path: Path, n: int = BINARY_SNIFF_BYTES) -> bytes:
    try:
        with open(path, "rb") as fh:
            return fh.read(n)
    except OSError:
        return b""


def read_text(path: Path) -> str:
    data = path.read_bytes()
    if data.startswith(b"\xef\xbb\xbf"):
        data = data[3:]
    elif data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16", errors="replace")
    return data.decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")


def list_files(root: Path, exclude: Iterable[str] = (), include_vendored: bool = False) -> dict:
    """The codebase's files, classified. Returns {"mode", "files": [FileEntry], "git_root"}."""
    root = root.resolve()
    git_root = git_toplevel(root)
    listed = _git_file_list(root) if git_root else None
    if listed is not None:
        rel_paths, tracked = listed
        mode = "git"
        vendor_dirs, generated_dirs = GIT_SAFE_VENDOR_DIRS, GIT_SAFE_GENERATED_DIRS
    else:
        rel_paths, tracked, mode = _walk_file_list(root), set(), "walk"
        vendor_dirs, generated_dirs = VENDOR_DIRS, GENERATED_DIRS
    attr_rules = _gitattributes_rules(root)
    excludes = list(exclude)
    entries: list[FileEntry] = []
    for rel in rel_paths:
        if any(fnmatch.fnmatch(rel, pat) or rel.startswith(pat.rstrip("/") + "/") for pat in excludes):
            continue
        full = root / rel
        if not full.is_file():
            continue          # deleted-but-tracked, submodule gitlink, or broken symlink
        try:
            size = full.stat().st_size
        except OSError:
            continue
        parts = rel.split("/")
        name = parts[-1]
        entry = FileEntry(rel, size, None, tracked=(rel in tracked) if mode == "git" else True)
        entry.is_test = bool(TEST_PATH.search(rel))
        head = read_head(full)
        if b"\0" in head:
            entry.status, entry.reason = "binary", "NUL byte in header"
            entries.append(entry)
            continue
        head_text = head[:2048].decode("utf-8", errors="replace")
        entry.lang = detect_language(rel, head_text)
        dirs = parts[:-1]
        if not include_vendored and any(d in vendor_dirs for d in dirs):
            entry.status, entry.reason = "vendored", "vendored directory"
        elif any(d in generated_dirs for d in dirs):
            entry.status, entry.reason = "generated", "build-output directory"
        elif any(fnmatch.fnmatch(name, pat) for pat in GENERATED_FILE_PATTERNS):
            entry.status, entry.reason = "generated", "generated/lock file pattern"
        elif has_generated_header(head_text):
            entry.status, entry.reason = "generated", "generated-file header"
        for pattern, flag in attr_rules:
            if _match_attr(rel, pattern):
                if flag == "linguist-vendored" and not include_vendored:
                    entry.status, entry.reason = "vendored", ".gitattributes linguist-vendored"
                elif flag == "linguist-generated":
                    entry.status, entry.reason = "generated", ".gitattributes linguist-generated"
                elif flag == "linguist-documentation" and entry.lang and entry.lang.type == "programming":
                    entry.lang = LANGUAGES["Text"]
        if entry.status == "source" and entry.lang is None:
            entry.status, entry.reason = "unknown", "unrecognized extension"
        entries.append(entry)
    _resolve_headers(entries)
    return {"mode": mode, "files": entries, "git_root": str(git_root) if git_root else None}


def _resolve_headers(entries: list[FileEntry]) -> None:
    """A bare .h belongs to C++ when the codebase has C++ sources, else to C."""
    has_cpp = any(e.lang and e.lang.name in ("C++", "CUDA", "Objective-C") for e in entries)
    target = LANGUAGES["C++"] if has_cpp else LANGUAGES["C"]
    for e in entries:
        if e.lang and e.lang.name == "C/C++ Header":
            e.lang = target


# ── Comment / string masking scanner ─────────────────────────────────────────

REGEX_PRECEDERS = set("(,=:[!&|?{};+-*%<>~^") | {""}
REGEX_KEYWORDS = {"return", "typeof", "instanceof", "in", "of", "new", "delete", "void", "throw",
                  "case", "do", "else", "yield", "await"}
# In these languages '#' only opens a comment at a word boundary: ${#arr[@]} and
# $#array are not comments.
HASH_NEEDS_BOUNDARY = {"Shell", "Fish", "Perl", "YAML", "Env", "Ignore List", "Dockerfile", "Makefile"}
CHAR_LITERAL = re.compile(r"'(?:\\(?:u\{[0-9A-Fa-f]{1,6}\}|x[0-9A-Fa-f]{2}|.)|[^'\\\n]{1,2})'")


@dataclass
class ScanResult:
    masked: str                                  # comments and string bodies blanked
    code_lines: list = field(default_factory=list)      # bool per line
    comment_lines: list = field(default_factory=list)   # bool per line
    line_starts: list = field(default_factory=list)     # offset of each line start
    comment_spans: list = field(default_factory=list)   # (start, end) offsets of every comment

    def line_of(self, offset: int) -> int:
        """1-based line number for a character offset."""
        lo, hi = 0, len(self.line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.line_starts[mid] <= offset:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1


def scan(text: str, lang: Lang | None) -> ScanResult:
    """Blank comments and string contents, keeping offsets; flag code/comment per line."""
    n = len(text)
    out = list(text)
    line_starts = [0] + [i + 1 for i, ch in enumerate(text) if ch == "\n"]
    nlines = len(line_starts)
    code = [False] * nlines
    comment = [False] * nlines
    if lang is None:
        for i, start in enumerate(line_starts):
            end = line_starts[i + 1] - 1 if i + 1 < nlines else n
            code[i] = bool(text[start:end].strip())
        return ScanResult(text, code, comment, line_starts)

    line_toks = tuple(sorted(lang.line, key=len, reverse=True))
    blocks = tuple(sorted(lang.block, key=lambda p: len(p[0]), reverse=True))
    quotes = set(lang.strings)
    if lang.backtick:
        quotes.add("`")
    esc = lang.escape
    ln = 0
    i = 0
    prev_sig = ""        # previous significant char (for regex-literal detection)
    prev_word = ""
    spans: list[tuple[int, int]] = []

    def blank(a: int, b: int, as_comment: bool) -> None:
        nonlocal ln
        if as_comment:
            spans.append((a, b))
        for k in range(a, b):
            ch = text[k]
            if ch == "\n":
                ln += 1
                continue
            if as_comment:
                if not ch.isspace():
                    comment[ln] = True
            else:
                if not ch.isspace():
                    code[ln] = True
            out[k] = " "

    while i < n:
        ch = text[i]
        if ch == "\n":
            ln += 1
            i += 1
            continue
        if ch in " \t\f\v":
            i += 1
            continue
        # Block comments (PowerShell <# must win over # line comment, Lua --[[ over --).
        matched = False
        for open_tok, close_tok in blocks:
            if text.startswith(open_tok, i):
                if open_tok in ("=begin", "=pod") and not (i == 0 or text[i - 1] == "\n"):
                    continue
                depth, j = 1, i + len(open_tok)
                while j < n and depth:
                    if lang.nested_block and text.startswith(open_tok, j):
                        depth += 1
                        j += len(open_tok)
                    elif text.startswith(close_tok, j):
                        depth -= 1
                        j += len(close_tok)
                    else:
                        j += 1
                blank(i, j, True)
                i = j
                matched = True
                break
        if matched:
            continue
        for tok in line_toks:
            if text.startswith(tok, i):
                if tok == "#" and lang.name in HASH_NEEDS_BOUNDARY and i > 0 and                         not text[i - 1].isspace() and text[i - 1] not in ";(|&":
                    continue
                if lang.name == "Batchfile" and tok.strip().upper() in ("REM", "@REM"):
                    line_start = text.rfind("\n", 0, i) + 1
                    if text[line_start:i].strip():
                        continue
                j = text.find("\n", i)
                j = n if j < 0 else j
                blank(i, j, True)
                i = j
                matched = True
                break
        if matched:
            continue
        # Python/Swift/Dart/TOML triple-quoted strings (docstrings count as comments).
        if lang.triple and text.startswith(('"""', "'''"), i):
            q = text[i:i + 3]
            j = text.find(q, i + 3)
            j = n if j < 0 else j + 3
            line_start = text.rfind("\n", 0, i) + 1
            is_doc = lang.name == "Python" and not text[line_start:i].strip()
            flags = comment if is_doc else code
            flags[ln] = True
            blank(i + 3, max(i + 3, j - 3), is_doc)
            flags[ln] = True
            i = j
            prev_sig = '"'
            continue
        # PowerShell here-strings @' '@ / @" "@.
        if lang.name == "PowerShell" and text.startswith(("@'", '@"'), i) and \
                text[i + 2:i + 3] in ("\n", "\r"):
            closer = "\n" + text[i + 1] + "@"
            j = text.find(closer, i)
            j = n if j < 0 else j + len(closer)
            code[ln] = True
            blank(i + 2, max(i + 2, j - 2), False)
            code[ln] = True
            i = j
            prev_sig = '"'
            continue
        # C# verbatim/raw strings.
        if lang.name == "C#" and text.startswith('"""', i):
            j = text.find('"""', i + 3)
            j = n if j < 0 else j + 3
            code[ln] = True
            blank(i + 3, max(i + 3, j - 3), False)
            code[ln] = True
            i = j
            prev_sig = '"'
            continue
        if lang.name == "C#" and text[i] in "@$" and text.startswith(('@"', '$@"', '@$"'), i):
            k = text.index('"', i)
            j = k + 1
            while j < n:
                if text[j] == '"':
                    if j + 1 < n and text[j + 1] == '"':
                        j += 2
                        continue
                    break
                j += 1
            code[ln] = True
            blank(k + 1, j, False)
            code[ln] = True
            i = j + 1
            prev_sig = '"'
            continue
        # Rust raw strings r"..." / r#"..."#.
        if lang.name == "Rust" and ch == "r" and re.match(r'r#*"', text[i:i + 10]) and \
                (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_")):
            m = re.match(r'r(#*)"', text[i:i + 10])
            closer = '"' + m.group(1)
            k = i + len(m.group(0))
            j = text.find(closer, k)
            j = n if j < 0 else j
            code[ln] = True
            blank(k, j, False)
            i = j + len(closer)
            prev_sig = '"'
            continue
        # Char literals where ' is not a general string quote.
        if ch == "'" and lang.char_quote:
            m = CHAR_LITERAL.match(text, i)
            code[ln] = True
            if m:
                blank(i + 1, m.end() - 1, False)
                i = m.end()
            else:
                i += 1        # lifetime ('a), apostrophe in a macro, etc.
            prev_sig = "'"
            continue
        if ch in quotes:
            multi = ch == "`"
            j = i + 1
            while j < n:
                c = text[j]
                if esc and c == esc and j + 1 < n:
                    j += 2
                    continue
                if c == ch:
                    break
                if c == "\n" and not multi and lang.name not in ("Shell", "Fish", "PowerShell"):
                    break
                j += 1
            code[ln] = True
            blank(i + 1, j, False)
            code[ln] = True
            i = j + 1
            prev_sig = '"'
            continue
        # JS-family regex literals.
        if lang.regex_literals and ch == "/" and text[i + 1:i + 2] not in ("/", "*") and \
                (prev_sig in REGEX_PRECEDERS or prev_word in REGEX_KEYWORDS):
            j, in_class = i + 1, False
            while j < n and text[j] != "\n":
                c = text[j]
                if c == "\\":
                    j += 2
                    continue
                if c == "[":
                    in_class = True
                elif c == "]":
                    in_class = False
                elif c == "/" and not in_class:
                    break
                j += 1
            if j < n and text[j] == "/":
                code[ln] = True
                blank(i + 1, j, False)
                i = j + 1
                prev_sig = "/"
                continue
        code[ln] = True
        if ch.isalnum() or ch == "_" or ch == "$":
            j = i
            while j < n and (text[j].isalnum() or text[j] in "_$"):
                j += 1
            prev_word = text[i:j]
            prev_sig = "a"
            i = j
            continue
        prev_sig = ch
        prev_word = ""
        i += 1
    return ScanResult("".join(out), code, comment, line_starts, spans)


def match_brace(masked: str, open_pos: int, open_ch: str = "{", close_ch: str = "}") -> int:
    """Offset of the bracket closing the one at `open_pos`, or -1."""
    depth = 0
    for k in range(open_pos, len(masked)):
        c = masked[k]
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return k
    return -1
