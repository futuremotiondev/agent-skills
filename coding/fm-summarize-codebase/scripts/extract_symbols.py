#!/usr/bin/env python3
"""
Inventory every function, method, constructor, and other callable in a codebase.

This is the ground truth the summary is built on: the report's function count,
its one-line index, and its detailed reference are all generated from this
inventory, and check_report.py fails if any inventoried callable is missing.

Extractors, best first:
  exact      Python via the `ast` module (also Jupyter code cells).
  heuristic  Everything else: comment/string-masked text, keyword or
             declaration-prefix recognition, brace / end-keyword / indent
             matching for extents. ~40 languages. Verify while reading.

What counts as a callable: named functions, methods, constructors, destructors,
property accessors with parameter lists, operators, local (nested) functions,
functions assigned to names (JS/TS arrow functions, Lua/R assignments), and
abstract/interface/trait method declarations (flagged `abstract`). Anonymous
lambdas and callbacks are NOT counted. Types (classes, structs, interfaces,
enums, traits, modules) are inventoried separately under "types".

Also recorded per callable: signature, parameters, return type (best effort),
modifiers, decorators/attributes, visibility, leading doc comment or docstring,
extent (line..end_line), test flag, and a heuristic call graph (calls /
called_by) built by matching call sites against unique callable names.

Usage:
  python extract_symbols.py <root>                        # summary to stdout
  python extract_symbols.py <root> -o symbols.json        # full inventory
  python extract_symbols.py <root> --list                 # one line per callable
  python extract_symbols.py <root> --exclude "docs/*" --no-tests

Exit codes: 0 = ok, 2 = root not found.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from _common import (LANGUAGES, MAX_PARSE_BYTES, SCHEMA_VERSION, TOOL_NAME, ScanResult, dump_json,
                     list_files, match_brace, now_iso, read_text, scan, utf8_stdio)

# ── Data model ───────────────────────────────────────────────────────────────


@dataclass
class Sym:
    name: str
    kind: str
    file: str
    language: str
    line: int
    end_line: int | None = None
    container: str | None = None
    container_kind: str | None = None
    parent_callable: str | None = None
    signature: str = ""
    params: list = field(default_factory=list)
    returns: str | None = None
    modifiers: list = field(default_factory=list)
    decorators: list = field(default_factory=list)
    visibility: str = "unknown"
    doc: str = ""
    abstract: bool = False
    is_test: bool = False
    confidence: str = "heuristic"
    cell: int | None = None
    hash: str | None = None
    code_lines: int | None = None      # non-blank, non-comment lines in the extent
    # internal
    body: tuple | None = None           # (start, end) offsets in the masked text
    called_names: set = field(default_factory=set)

    @property
    def qualname(self) -> str:
        if self.parent_callable:
            return f"{self.parent_callable}.{self.name}"
        if self.container:
            return f"{self.container}.{self.name}"
        return self.name


@dataclass
class TypeDecl:
    name: str
    kind: str
    file: str
    language: str
    line: int
    end_line: int | None = None
    container: str | None = None
    doc: str = ""
    start: int = 0
    open: int = -1
    close: int = -1


STATEMENT_KEYWORDS = {
    "if", "for", "while", "switch", "catch", "return", "sizeof", "typeof", "new", "delete", "throw",
    "else", "do", "case", "using", "lock", "fixed", "foreach", "with", "await", "yield", "function",
    "elif", "when", "match", "loop", "unless", "until", "assert", "not", "and", "or", "in", "is",
    "as", "super", "this", "self", "base", "typeid", "alignof", "decltype", "static_assert",
    "noexcept", "co_await", "co_return", "co_yield", "defer", "go", "select", "try", "finally",
    "synchronized", "guard", "repeat", "checked", "unchecked", "nameof", "default", "goto",
    "require", "import", "export", "from", "print", "echo", "elseif", "then", "instanceof",
    "void", "var", "let", "const", "static_cast", "dynamic_cast", "reinterpret_cast",
    "const_cast", "__attribute__", "__declspec", "alignas", "va_arg", "offsetof", "defined",
    "_Pragma", "__pragma", "stackalloc",
}
TYPE_DECL_WORDS = {"class", "struct", "interface", "enum", "record", "namespace", "delegate",
                   "event", "union", "typedef", "trait", "module", "object", "protocol", "extension",
                   "package", "import", "using", "template"}

MODIFIERS = {
    "C#": {"public", "private", "protected", "internal", "static", "virtual", "override", "abstract",
           "sealed", "async", "extern", "unsafe", "new", "partial", "readonly", "file", "required",
           "implicit", "explicit", "volatile", "ref", "scoped"},
    "Java": {"public", "private", "protected", "static", "final", "abstract", "synchronized",
             "native", "strictfp", "default", "transient", "sealed", "non-sealed"},
    "C": {"static", "inline", "extern", "__inline", "__inline__", "__forceinline", "_Noreturn",
          "__stdcall", "__cdecl", "__fastcall", "WINAPI", "CALLBACK", "APIENTRY", "__device__",
          "__global__", "__host__", "register", "__attribute__"},
    "Dart": {"static", "external", "factory", "abstract", "late", "final", "const", "covariant",
             "async", "sync", "override"},
    "Groovy": {"public", "private", "protected", "static", "final", "abstract", "synchronized", "def"},
}
MODIFIERS["C++"] = MODIFIERS["C"] | {"virtual", "explicit", "constexpr", "consteval", "constinit",
                                     "friend", "public:", "private:", "protected:", "mutable"}
MODIFIERS["CUDA"] = MODIFIERS["C++"]
MODIFIERS["Objective-C"] = MODIFIERS["C"]
MODIFIERS["GLSL"] = MODIFIERS["HLSL"] = {"inline", "static", "precise", "uniform", "highp",
                                          "mediump", "lowp"}
TYPED_LANGS = {"C#", "Java", "C", "C++", "CUDA", "Dart", "Groovy", "GLSL", "HLSL", "Objective-C"}

VISIBILITY_WORDS = {"public": "public", "pub": "public", "export": "public", "open": "public",
                    "private": "private", "fileprivate": "private", "protected": "protected",
                    "internal": "internal", "hidden": "private"}


# ── Rules ────────────────────────────────────────────────────────────────────

@dataclass
class Rule:
    kind: str
    rx: re.Pattern
    scope: str = "any"             # any | class | top | interface
    body: str = "brace"            # brace | end | indent | next-decl | none | vb | batch
    require_arrow: bool = False
    allow_decl: bool = False       # keep bodyless declarations (as abstract)
    require_body: bool = True
    keyword_led: bool = True       # a declaration keyword (def/fn/func/function) precedes the name,
    #                                so the name can't be a statement keyword like `if`


def R(p: str, flags: int = re.M) -> re.Pattern:
    return re.compile(p, flags)


JS_IDENT = r"[A-Za-z_$][\w$]*"
JS_RULES = [
    # Immediately-invoked function expressions: the file's de facto main function.
    Rule("iife", R(r"^[ \t]*[;!+~]?\s*\(\s*(?P<mods>async\s+)?function\s*\*?\s*(?P<name>" + JS_IDENT +
                   r")?\s*\(")),
    Rule("iife", R(r"^[ \t]*[;!+~]?\s*\(\s*(?P<mods>async\s*)?\("), require_arrow=True),
    Rule("function", R(r"^[ \t]*(?P<mods>(?:export\s+(?:default\s+)?|declare\s+|async\s+)*)function\s*\*?"
                       rf"\s*(?P<name>{JS_IDENT})\s*(?:<[^>(]*>)?\s*\(")),
    Rule("function", R(r"^[ \t]*(?P<mods>(?:export\s+(?:default\s+)?|declare\s+)*)(?:const|let|var)\s+"
                       rf"(?P<name>{JS_IDENT})\s*(?::[^=\n]+?)?=\s*(?:async\s+)?function\b\s*\*?\s*"
                       rf"(?:{JS_IDENT})?\s*(?:<[^>(]*>)?\s*\(")),
    Rule("function", R(r"^[ \t]*(?P<mods>(?:export\s+(?:default\s+)?|declare\s+)*)(?:const|let|var)\s+"
                       rf"(?P<name>{JS_IDENT})\s*(?::[^=\n]+?)?=\s*(?:async\s+)?(?:<[^>(=]*>\s*)?\("),
         require_arrow=True),
    Rule("function", R(r"^[ \t]*(?P<mods>(?:export\s+(?:default\s+)?)*)(?:const|let|var)\s+"
                       rf"(?P<name>{JS_IDENT})\s*=\s*(?:async\s+)?(?P<arrowparam>{JS_IDENT})\s*=>"),
         require_body=False),
    Rule("method", R(r"^[ \t]*(?P<recv>(?:module\.)?exports|" + JS_IDENT + r"(?:\.prototype)?)\."
                     rf"(?P<name>{JS_IDENT})\s*=\s*(?:async\s+)?function\b\s*\*?\s*(?:{JS_IDENT})?\s*\(")),
    Rule("method", R(r"^[ \t]*(?P<recv>(?:module\.)?exports|" + JS_IDENT + r"(?:\.prototype)?)\."
                     rf"(?P<name>{JS_IDENT})\s*=\s*(?:async\s+)?\("), require_arrow=True),
    Rule("method", R(rf"^[ \t]*(?P<name>{JS_IDENT})\s*:\s*(?:async\s+)?function\b\s*\*?\s*(?:{JS_IDENT})?\s*\(")),
    Rule("method", R(rf"^[ \t]*(?P<name>{JS_IDENT})\s*:\s*(?:async\s+)?\("), require_arrow=True),
    # Class members and object-literal shorthand methods: name(...) { ... }
    Rule("method", R(r"^[ \t]*(?P<mods>(?:(?:public|private|protected|static|async|readonly|override|"
                     r"abstract|declare|accessor|get|set)\s+)*)(?:\*\s*)?(?P<name>#?" + JS_IDENT +
                     r"|\[[^\]\n]+\])\s*[?!]?\s*(?:<[^>(\n]*>)?\s*\("), allow_decl=True, keyword_led=False),
    Rule("method", R(r"^[ \t]*(?P<mods>(?:(?:public|private|protected|static|readonly|override)\s+)*)"
                     r"(?P<name>#?" + JS_IDENT + r")\s*[?!]?\s*(?::[^=\n]+?)?=\s*(?:async\s+)?(?:<[^>(=]*>\s*)?\("),
         scope="class", require_arrow=True, keyword_led=False),
]

RULES: dict[str, list[Rule]] = {
    "JavaScript": JS_RULES,
    "TypeScript": JS_RULES,
    "Go": [
        Rule("function", R(r"^[ \t]*func[ \t]*(?:\((?P<recv>[^)]*)\)[ \t]*)?(?P<name>[A-Za-z_]\w*)[ \t]*"
                           r"(?:\[[^\]]*\])?[ \t]*\(")),
        Rule("method", R(r"^[ \t]*(?P<name>[A-Za-z_]\w*)\s*\("), scope="interface", allow_decl=True,
             keyword_led=False),
    ],
    "Rust": [Rule("function", R(r"^[ \t]*(?P<mods>(?:pub(?:\s*\([^)]*\))?\s+|default\s+|const\s+|async\s+|"
                                r"unsafe\s+|extern\s+(?:\"[^\"]*\"\s+)?)*)fn\s+(?P<name>[A-Za-z_]\w*)\s*"
                                r"(?:<[^{;]*?>)?\s*\("), allow_decl=True)],
    "Kotlin": [
        Rule("function", R(r"^[ \t]*(?P<mods>(?:(?:@\w+(?:\([^)]*\))?\s+)|(?:public|private|protected|"
                           r"internal|open|override|abstract|final|suspend|inline|infix|operator|"
                           r"tailrec|external|actual|expect)\s+)*)fun\s+(?:<[^>]*>\s*)?"
                           r"(?:(?P<recv>[\w.<>?, ]+?)\.)?(?P<name>`?[A-Za-z_]\w*`?)\s*\("), allow_decl=True),
        Rule("constructor", R(r"^[ \t]*(?P<mods>(?:(?:public|private|protected|internal)\s+)*)"
                              r"(?P<name>constructor)\s*\("), scope="class"),
    ],
    "Scala": [Rule("function", R(r"^[ \t]*(?P<mods>(?:(?:private|protected|override|final|implicit|lazy|"
                                 r"inline|abstract)(?:\[[^\]]*\])?\s+)*)def\s+(?P<name>[A-Za-z_]\w*|"
                                 r"[^\s\w\[(:]+)\s*(?:\[[^\]]*\])?\s*[(:=\[{]"), allow_decl=True)],
    "Swift": [
        Rule("function", R(r"^[ \t]*(?P<mods>(?:@\w+(?:\([^)]*\))?\s+|(?:public|private|fileprivate|"
                           r"internal|open|static|class|final|override|mutating|nonmutating|"
                           r"convenience|required|dynamic|nonisolated|isolated)\s+)*)func\s+"
                           r"(?P<name>[A-Za-z_]\w*|[^\s\w(<]+)\s*(?:<[^{(]*?>)?\s*\("), allow_decl=True),
        Rule("constructor", R(r"^[ \t]*(?P<mods>(?:@\w+\s+|(?:public|private|fileprivate|internal|open|"
                              r"convenience|required|override)\s+)*)(?P<name>init)\s*[?!]?\s*"
                              r"(?:<[^{(]*?>)?\s*\("), allow_decl=True),
        Rule("destructor", R(r"^[ \t]*(?P<name>deinit)\s*(?=\{)")),
        Rule("operator", R(r"^[ \t]*(?P<mods>(?:(?:public|private|internal|static|override)\s+)*)"
                           r"(?P<name>subscript)\s*(?:<[^{(]*?>)?\s*\("), allow_decl=True),
    ],
    "PHP": [Rule("function", R(r"^[ \t]*(?P<mods>(?:(?:public|private|protected|static|abstract|final|"
                               r"readonly)\s+)*)function\s+&?\s*(?P<name>[A-Za-z_]\w*)\s*\("), allow_decl=True)],
    "Zig": [Rule("function", R(r"^[ \t]*(?P<mods>(?:pub\s+|export\s+|extern\s+(?:\"[^\"]*\"\s+)?|inline\s+|"
                               r"noinline\s+)*)fn\s+(?P<name>[A-Za-z_]\w*)\s*\("), allow_decl=True)],
    "WGSL": [Rule("function", R(r"^[ \t]*(?:@\w+(?:\([^)]*\))?\s*)*fn\s+(?P<name>[A-Za-z_]\w*)\s*\("))],
    "Solidity": [
        Rule("function", R(r"^[ \t]*function\s+(?P<name>[A-Za-z_]\w*)\s*\("), allow_decl=True),
        Rule("constructor", R(r"^[ \t]*(?P<name>constructor)\s*\(")),
        Rule("modifier", R(r"^[ \t]*modifier\s+(?P<name>[A-Za-z_]\w*)\s*(?:\(|(?=\{))")),
        Rule("function", R(r"^[ \t]*(?P<name>fallback|receive)\s*\(")),
    ],
    "PowerShell": [
        Rule("function", R(r"^[ \t]*(?P<kw>function|filter|workflow)\s+(?P<name>[\w:.\-]+)\s*(?=[({\n]|$)",
                           re.M | re.I)),
        Rule("method", R(r"^[ \t]*(?P<mods>(?:(?:static|hidden)\s+)*)(?:\[[^\]\n]+\]\s*)?"
                         r"(?P<name>[A-Za-z_]\w*)\s*\(", re.M | re.I), scope="class", keyword_led=False),
        # Named script blocks: $newRule = { param($x) ... } — PowerShell's lambdas.
        Rule("script block", R(r"^[ \t]*(?:\[scriptblock\]\s*)?(?P<name>\$(?:script:|global:|local:|private:)?"
                               r"[A-Za-z_]\w*)\s*=\s*(?=\{)", re.M | re.I)),
    ],
    "Shell": [Rule("function", R(r"^[ \t]*(?:function\s+(?P<name>[\w:.\-]+)(?:\s*\(\s*\))?|"
                                 r"(?P<name2>[A-Za-z_][\w:.\-]*)\s*\(\s*\))\s*(?=\{|\(|\n|$)"),
                   keyword_led=False)],
    "Fish": [Rule("function", R(r"^[ \t]*function\s+(?P<name>[\w:.\-]+)"), body="end")],
    "Perl": [Rule("function", R(r"^[ \t]*sub\s+(?P<name>[\w:]+)\s*(?:\([^)]*\)\s*)?(?=\{)"))],
    "Lua": [
        Rule("function", R(r"^[ \t]*(?P<mods>local\s+)?function\s+(?P<name>[\w.:]+)\s*\("), body="end"),
        Rule("function", R(r"^[ \t]*(?P<mods>local\s+)?(?P<name>[\w.:]+(?:\[[^\]\n]+\])?)\s*=\s*"
                           r"function\s*\("), body="end"),
    ],
    "Ruby": [Rule("method", R(r"^[ \t]*def\s+(?P<recv>self\.|[\w:]+\.)?(?P<name>[\w?!=\[\]+\-*/<>%~^|&`]+)"),
                  body="end", require_body=False)],
    "Crystal": [Rule("method", R(r"^[ \t]*(?:(?:private|protected|abstract)\s+)*def\s+(?P<recv>self\.)?"
                                 r"(?P<name>[\w?!=\[\]+\-*/<>%~^|&]+)"), body="end", require_body=False)],
    "Elixir": [Rule("function", R(r"^[ \t]*(?P<kw>def|defp|defmacro|defmacrop|defguard|defguardp|"
                                  r"defdelegate|defn|defnp)\s+(?P<name>[\w?!]+)"), body="end", require_body=False)],
    "Julia": [
        Rule("function", R(r"^[ \t]*(?:function|macro)\s+(?P<name>[\w.!]+(?:\{[^}\n]*\})?)\s*\("), body="end"),
        Rule("function", R(r"^(?P<name>[A-Za-z_][\w.!]*)\s*\([^)\n]*\)\s*(?:where\s+[^=\n]+)?=(?!=)"),
             body="none", require_body=False),
    ],
    "R": [Rule("function", R(r"^[ \t]*(?P<name>[\w.]+)\s*(?:<-|<<-|=)\s*function\s*\("))],
    "MATLAB": [Rule("function", R(r"^[ \t]*function\s+(?:(?:\[[^\]\n]*\]|\w+)\s*=\s*)?(?P<name>[\w.]+)"),
                    body="next-decl", require_body=False)],
    "Visual Basic .NET": [Rule("method", R(r"^[ \t]*(?P<mods>(?:(?:Public|Private|Protected|Friend|Shared|"
                                           r"Overrides|Overridable|MustOverride|NotOverridable|Overloads|"
                                           r"Shadows|Async|Iterator|Static|Partial|Default|ReadOnly|"
                                           r"WriteOnly)\s+)*)(?P<kw>Function|Sub|Operator)\s+(?P<name>[\w\[\]]+)",
                                           re.M | re.I), body="vb", require_body=False)],
    "F#": [
        Rule("function", R(r"^[ \t]*(?:let|and)\s+(?:(?:rec|inline|private|internal|public)\s+)*"
                           r"(?P<name>[a-zA-Z_]\w*'?)\s+(?P<fsparams>[a-zA-Z_(\[][^=\n]*?)\s*(?::\s*[^=\n]+)?=(?!=)"),
             body="indent", require_body=False),
        Rule("method", R(r"^[ \t]*(?P<mods>(?:(?:override|default|abstract|static)\s+)*)member\s+"
                         r"(?:[\w]+\.)?(?P<name>\w+)"), body="indent", require_body=False),
    ],
    "Haskell": [Rule("function", R(r"^(?P<name>[a-z_][\w']*)\s*(?:,\s*[a-z_][\w']*\s*)*::"),
                     body="none", require_body=False)],
    "OCaml": [Rule("function", R(r"^[ \t]*(?:let|and)\s+(?:rec\s+)?(?P<name>[a-z_][\w']*)\s+[a-z_(~?][^=\n]*="),
                   body="none", require_body=False)],
    "Clojure": [Rule("function", R(r"^\s*\((?P<kw>defn-?|defmacro|defmulti|defmethod)\s+\^?[\w:]*\s*"
                                   r"(?P<name>[^\s()\[\]{}]+)"), body="none", require_body=False)],
    "Emacs Lisp": [Rule("function", R(r"^\s*\((?:defun|defmacro|cl-defun|cl-defmethod|defsubst)\s+"
                                      r"(?P<name>[^\s()]+)"), body="none", require_body=False)],
    "Common Lisp": [Rule("function", R(r"^\s*\((?:defun|defmacro|defgeneric|defmethod)\s+(?P<name>[^\s()]+)",
                                       re.M | re.I), body="none", require_body=False)],
    "Scheme": [Rule("function", R(r"^\s*\((?:define|define-syntax)\s+\((?P<name>[^\s()]+)"),
                    body="none", require_body=False)],
    "Erlang": [Rule("function", R(r"^(?P<name>[a-z]\w*)\s*\([^)\n]*\)\s*(?:when\s+[^\n]*?)?->"),
                    body="none", require_body=False)],
    "Nim": [Rule("function", R(r"^[ \t]*(?P<kw>proc|func|method|iterator|macro|template|converter)\s+"
                               r"(?P<name>`[^`]+`|\w+)\*?\s*(?:\[[^\]]*\])?\s*\("), body="indent",
                 require_body=False)],
    "GDScript": [Rule("function", R(r"^[ \t]*(?P<mods>static\s+)?func\s+(?P<name>\w+)\s*\("), body="indent",
                      require_body=False)],
    "SQL": [Rule("procedure", R(r"^[ \t]*CREATE\s+(?:OR\s+(?:REPLACE|ALTER)\s+)?(?:DEFINER\s*=\s*\S+\s+)?"
                                r"(?:TEMP(?:ORARY)?\s+)?(?P<kw>FUNCTION|PROCEDURE|PROC|TRIGGER)\s+"
                                r"(?:IF\s+NOT\s+EXISTS\s+)?(?P<name>[\w.\[\]\"`]+)", re.M | re.I),
                 body="none", require_body=False)],
    "Batchfile": [Rule("subroutine", R(r"^:(?P<name>[A-Za-z_][\w.\-]*)[ \t]*$"), body="batch",
                       require_body=False)],
    "CMake": [Rule("function", R(r"^[ \t]*(?P<kw>function|macro)\s*\(\s*(?P<name>[\w.\-]+)", re.M | re.I),
                   body="none", require_body=False)],
    "Pascal": [Rule("function", R(r"^[ \t]*(?:class\s+)?(?P<kw>procedure|function|constructor|destructor)\s+"
                                  r"(?P<name>[\w.]+)", re.M | re.I), body="next-decl", require_body=False)],
    "Fortran": [Rule("function", R(r"^[ \t]*(?:(?:pure|elemental|recursive|impure|module)\s+)*"
                                   r"(?:[\w()*,=\s]+?\s+)?(?P<kw>subroutine|function)\s+(?P<name>\w+)",
                                   re.M | re.I), body="none", require_body=False)],
    "AppleScript": [Rule("function", R(r"^[ \t]*(?:on|to)\s+(?P<name>\w+)\s*\("), body="none",
                         require_body=False)],
    "AutoHotkey": [Rule("function", R(r"^(?P<name>[A-Za-z_]\w*)\s*\("), keyword_led=False)],
    "Groovy": [Rule("function", R(r"^[ \t]*(?P<mods>(?:(?:public|private|protected|static|final|"
                                  r"synchronized)\s+)*)def\s+(?P<name>[A-Za-z_]\w*)\s*\("))],
    "Objective-C": [Rule("method", R(r"^[ \t]*(?P<mods>[-+])\s*\([^)\n]*\)\s*(?P<name>\w+)"),
                         require_body=True)],
}
RULES["Python"] = [Rule("function", R(r"^[ \t]*(?:async\s+)?def\s+(?P<name>\w+)\s*\("), body="indent",
                        require_body=False)]

CONTAINER_RULES: dict[str, list[tuple[str, re.Pattern]]] = {
    "brace-generic": [("class", R(r"^[ \t]*(?:\[[^\]\n]*\]\s*)*(?:(?:public|private|protected|internal|"
                                  r"static|abstract|sealed|partial|final|export|default|declare|readonly|"
                                  r"file|data|open|inner|value|non-sealed|strictfp|case|implicit|"
                                  r"unsafe|ref|readonly)\s+)*"
                                  r"(?P<kind>class|struct|interface|enum|record(?:\s+(?:class|struct))?|"
                                  r"trait|object|protocol|extension|actor|mixin|namespace|union|"
                                  r"contract|library|@interface|annotation\s+class|enum\s+class)\s+"
                                  r"(?P<name>[A-Za-z_$][\w$.]*)"))],
    "Rust": [("impl", R(r"^[ \t]*(?:unsafe\s+)?impl\s*(?:<[^{]*?>)?\s*(?:(?P<trait>[\w:<>, ]+?)\s+for\s+)?"
                        r"(?P<name>[\w:]+)")),
             ("trait", R(r"^[ \t]*(?:pub(?:\([^)]*\))?\s+)?(?:unsafe\s+)?trait\s+(?P<name>\w+)")),
             ("struct", R(r"^[ \t]*(?:pub(?:\([^)]*\))?\s+)?(?P<kind>struct|enum|union)\s+(?P<name>\w+)")),
             ("module", R(r"^[ \t]*(?:pub(?:\([^)]*\))?\s+)?mod\s+(?P<name>\w+)\s*(?=\{)"))],
    "Go": [("struct", R(r"^[ \t]*type\s+(?P<name>\w+)(?:\[[^\]]*\])?\s+(?P<kind>struct|interface)\b"))],
    "PowerShell": [("class", R(r"^[ \t]*(?P<kind>class|enum)\s+(?P<name>\w+)", re.M | re.I))],
    "Zig": [("struct", R(r"^[ \t]*(?:pub\s+)?const\s+(?P<name>\w+)\s*=\s*(?:extern\s+|packed\s+)?"
                         r"(?P<kind>struct|enum|union|opaque)\b"))],
    "Ruby": [("class", R(r"^[ \t]*(?P<kind>class|module)\s+(?!<<)(?P<name>[\w:]+)"))],
    "Crystal": [("class", R(r"^[ \t]*(?:abstract\s+)?(?P<kind>class|module|struct)\s+(?P<name>[\w:]+)"))],
    "Elixir": [("module", R(r"^[ \t]*(?P<kind>defmodule|defprotocol|defimpl)\s+(?P<name>[\w.]+)"))],
    "Julia": [("module", R(r"^[ \t]*(?:mutable\s+)?(?P<kind>module|struct)\s+(?P<name>\w+)"))],
    "Python": [("class", R(r"^[ \t]*class\s+(?P<name>\w+)"))],
    "GDScript": [("class", R(r"^[ \t]*class\s+(?P<name>\w+)"))],
    "Nim": [("type", R(r"^[ \t]*(?P<name>\w+)\*?\s*=\s*(?:ref\s+)?(?P<kind>object|enum)\b"))],
    "F#": [("type", R(r"^[ \t]*type\s+(?P<name>\w+)"))],
    "Visual Basic .NET": [("class", R(r"^[ \t]*(?:(?:Public|Private|Friend|Protected|Partial|MustInherit|"
                                      r"NotInheritable|Shared)\s+)*(?P<kind>Class|Module|Structure|Interface|"
                                      r"Namespace|Enum)\s+(?P<name>\w+)", re.M | re.I))],
    "SQL": [("view", R(r"^[ \t]*CREATE\s+(?:OR\s+REPLACE\s+)?(?:MATERIALIZED\s+)?(?P<kind>VIEW|TABLE|TYPE)\s+"
                       r"(?:IF\s+NOT\s+EXISTS\s+)?(?P<name>[\w.\[\]\"`]+)", re.M | re.I))],
    "Solidity": [("contract", R(r"^[ \t]*(?:abstract\s+)?(?P<kind>contract|interface|library|struct)\s+"
                                r"(?P<name>\w+)"))],
}
BRACE_CONTAINER_LANGS = {"C#", "Java", "Kotlin", "Scala", "Swift", "Dart", "TypeScript", "JavaScript",
                         "PHP", "C++", "CUDA", "Groovy", "Objective-C", "HLSL", "C"}
NO_CALLABLES = {"Makefile", "Dockerfile", "HCL", "Nix", "Jupyter Notebook"}
EMBEDDED_SCRIPT_LANGS = {"Vue", "Svelte", "HTML", "Astro"}

TEST_ATTR = re.compile(r"\[(?:Fact|Theory|Test|TestMethod|TestCase|DataTestMethod|UITestMethod)\b|"
                       r"@(?:Test|ParameterizedTest|RepeatedTest|TestFactory)\b|#\[(?:\w+::)?test\b|"
                       r"@pytest\.|@unittest", re.I)
TEST_NAME = {
    "Python": re.compile(r"^test_?"), "Go": re.compile(r"^(Test|Benchmark|Example|Fuzz)[A-Z_]?"),
    "PowerShell": re.compile(r"^(Describe|It|Context)$"),
}

# ── Helpers ──────────────────────────────────────────────────────────────────

TS_TYPE_BODY = re.compile(r"\s*(?:void|string|number|boolean|any|unknown|never|null|undefined|object|"
                          r"bigint|symbol|this|[A-Z][\w.]*(?:<[^;\n]*>)?(?:\[\])*)\s*(?:\|\s*[\w.<>\[\]]+\s*)*"
                          r"[;,]?\s*$")
WS_RE = re.compile(r"\s+")
IDENT_CALL = re.compile(r"(?<![\w$])([A-Za-z_$][\w$]*)\s*(?:<[^;{}()<>]*>)?\s*\(")
ATTR_PREFIX = re.compile(r"^\s*(?:\[[^\]]*\]\s*|@[\w.]+(?:\s*\([^)]*\))?\s+|#\[[^\]]*\]\s*)+")


def collapse(s: str, limit: int = 240) -> str:
    s = WS_RE.sub(" ", s).strip()
    return s if len(s) <= limit else s[: limit - 1] + "…"


def line_bounds(text: str, pos: int) -> tuple[int, int]:
    a = text.rfind("\n", 0, pos) + 1
    b = text.find("\n", pos)
    return a, (len(text) if b < 0 else b)


def split_top_level(s: str, sep: str = ",") -> list[str]:
    parts, depth, cur = [], 0, []
    for ch in s:
        if ch in "([{<":
            depth += 1
        elif ch in ")]}>":
            depth = max(0, depth - 1)
        if ch == sep and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        parts.append("".join(cur))
    return parts


NAME_LAST = {"C", "C++", "CUDA", "C#", "Java", "Dart", "Groovy", "GLSL", "HLSL", "Objective-C"}
PARAM_IDENT = re.compile(r"[$@&*]*[A-Za-z_][\w$]*")


def parse_params(params_text: str, lang: str) -> list[str]:
    names = []
    if lang == "Dart":
        params_text = re.sub(r"[{}\[\]]", ",", params_text)   # named/optional parameter groups
    for part in split_top_level(params_text):
        if lang in ("PowerShell", "C#"):
            part = strip_attributes(part)             # [Parameter(ParameterSetName = 'x')] holds '='
        p = part.split("=", 1)[0].strip()
        if not p or p in ("void", "..."):
            continue
        p = re.sub(r"^\s*(?:\[[^\]]*\]\s*|@\w+(?:\([^)]*\))?\s*)+", "", p)   # attributes/annotations
        if lang in ("PowerShell", "PHP"):
            m = re.search(r"\$[\w:]+", p)
            if m:
                names.append(m.group(0))
        elif lang in NAME_LAST:
            p = re.sub(r"\[[^\]]*\]$", "", p.strip())
            toks = PARAM_IDENT.findall(p)
            if toks:
                names.append(toks[-1].lstrip("*&"))
        elif lang == "Go":
            toks = p.split()
            names.append(toks[0] if toks else p)
        elif lang == "Swift":
            m = re.match(r"\s*(\w+)(?:\s+(\w+))?\s*:", p)     # external label, internal name
            if m:
                names.append(m.group(2) or m.group(1))
        else:
            p = re.sub(r"^(?:(?:public|private|protected|readonly|override|mut|ref|out|in|val|var|inout|"
                       r"let|const|final)\s+)+", "", p.strip())
            toks = PARAM_IDENT.findall(p)
            if toks:
                names.append(toks[0])
    return names


RETURN_ARROW = {"Rust", "Swift", "Python", "Julia"}          # -> T
RETURN_COLON = {"TypeScript", "JavaScript", "Kotlin", "Scala", "PHP", "Nim", "GDScript", "F#",
                "Vue (TypeScript)"}                           # : T


def return_from_tail(tail: str, lang: str) -> str | None:
    """Declared return type from the text between ')' and the body."""
    t = collapse(tail, 160)
    t = re.split(r"\bwhere\b|\bthrows\b|\brequires\b", t)[0].strip()
    t = re.sub(r"\s*(?:=>|=)\s*$", "", t)
    if lang in RETURN_ARROW:
        m = re.match(r"(?:.*?)->\s*(.+)$", t)
        return m.group(1).strip() if m else None
    if lang in RETURN_COLON:
        m = re.match(r":\s*(.+)$", t)
        return m.group(1).strip().rstrip("=").strip() or None if m else None
    if lang == "Go":
        return t or None
    return None


# ── Body detection for brace languages ───────────────────────────────────────

CONTINUE_END = (",", ":", "->", "=>", "(", "<", "|", "&", "extends", "implements", "throws", "where", "with",
                "async", "override", "const", "noexcept", "final")
# Only tokens that can't begin a new declaration: `override fun` / `final int` / `const x`
# on the next line start a new member, not the tail of this one.
CONTINUE_START = ("{", ":", "->", "=>", "where", "throws", "extends", "implements", "with", "=", "requires")


def find_body(m: str, pos: int, lang: str, expr_eq: bool = False) -> tuple[str, int, int, str]:
    """From just after a parameter list, locate the body.

    Returns (kind, open_offset, end_offset, tail_text):
      kind "block" – { ... };  "expr" – => expr / = expr;  "decl" – bodyless (;),
      "pure" – C++ `= 0`;  "none" – nothing recognizable.
    """
    n = len(m)
    i = pos
    depth = 0
    limit = min(n, pos + 600)
    while i < limit:
        c = m[i]
        if c in "([":
            depth += 1
        elif c in ")]":
            if depth == 0:
                return "none", -1, -1, m[pos:i]
            depth -= 1
        elif depth == 0:
            if c == "{":
                word = re.search(r"(interface|struct)\s*$", m[pos:i])
                if word and i + 1 < n and m[i + 1] == "}":
                    i += 2                  # Go `interface{}` / `struct{}` in a return type
                    continue
                if lang in ("C++", "CUDA") and re.match(r"\s*:", m[pos:i]) and (m[i - 1].isalnum() or
                                                                               m[i - 1] == "_"):
                    close = match_brace(m, i)   # brace-init in a constructor initializer list
                    if close > 0:
                        i = close + 1
                        continue
                close = match_brace(m, i)
                return "block", i, (close if close >= 0 else n - 1), m[pos:i]
            if c == ";":
                tail = m[pos:i]
                if re.search(r"=\s*0\s*$", tail):
                    return "pure", i, i, tail
                return "decl", i, i, tail
            if c == "}":
                return "decl", i, i, m[pos:i]
            if c == "=" and m[i + 1:i + 2] == ">":
                return "expr", i, expr_end(m, i + 2), m[pos:i]
            if c == "=" and m[i + 1:i + 2] != "=" and (i == 0 or m[i - 1] not in "!<>="):
                tail = m[pos:i]
                rest = m[i + 1:i + 12].strip()
                if lang == "C++" and re.match(r"(0|default|delete)\b", rest):
                    k = m.find(";", i)
                    return ("pure" if rest.startswith("0") else "decl"), i, (k if k >= 0 else i), tail
                if expr_eq:
                    return "expr", i, expr_end(m, i + 1, newline_ends=True), tail
                return "none", -1, -1, tail
            if c == "\n":
                # A declaration continues onto the next line only when this line ends with a
                # continuation token or the next non-blank line starts with one (Allman braces,
                # `where`/`throws` clauses, `: base(...)` initializers).
                prev_nl = m.rfind("\n", pos, i)
                last = m[(prev_nl + 1 if prev_nl >= 0 else pos):i].strip()
                a = i + 1
                nxt = ""
                while a < limit:
                    b = m.find("\n", a)
                    b = n if b < 0 else b
                    nxt = m[a:b].strip()
                    if nxt:
                        break
                    a = b + 1
                if not (last.endswith(CONTINUE_END) or nxt.startswith(CONTINUE_START)):
                    return "decl", i, i, m[pos:i]
        i += 1
    return "none", -1, -1, m[pos:limit]


def expr_end(m: str, pos: int, newline_ends: bool = False) -> int:
    depth = 0
    n = len(m)
    i = pos
    while i < n:
        c = m[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return i - 1
            depth -= 1
        elif depth == 0 and c in ";,":
            return i
        elif depth == 0 and c == "\n" and newline_ends:
            nxt = m[i + 1:i + 80].lstrip(" \t")
            if not nxt.startswith((".", "?", ":", "+", "-", "*", "/", "|", "&", "=")):
                return i
        i += 1
    return n - 1


# ── End-keyword and indent extents ───────────────────────────────────────────

WORD_RE = re.compile(r"[A-Za-z_][\w?!]*|[\[\]]")


def end_blocks(m: str, lang: str) -> list[tuple[int, int]]:
    """(opener_offset, closer_offset) pairs for end-terminated languages."""
    stack: list[int] = []
    pairs: list[tuple[int, int]] = []
    bracket = 0
    loop_line = -1
    for mt in WORD_RE.finditer(m):
        w = mt.group(0)
        pos = mt.start()
        if w == "[":
            bracket += 1
            continue
        if w == "]":
            bracket = max(0, bracket - 1)
            continue
        if pos > 0 and m[pos - 1] in ".:$@" and not (m[pos - 1] == ":" and pos > 1 and m[pos - 2] == ":"):
            continue            # obj.end, :end symbol, @end ivar
        opener = False
        line_a, _ = line_bounds(m, pos)
        before = m[line_a:pos].rstrip()
        if lang in ("Ruby", "Crystal"):
            if w in ("class", "module", "def", "case", "begin"):
                opener = not (w == "def" and re.match(r"def\s+(?:self\.)?[\w?!]+(?:\([^)]*\))?\s+=\s",
                                                      m[pos:pos + 200]))
                if w == "class" and before.endswith("."):
                    opener = False
            elif w in ("if", "unless", "while", "until", "for"):
                # `x = if c` opens a block; `return if c` / `save if valid?` are modifiers.
                opener = before == "" or (before[-1] in "=([{,;|&!?:" and not before.endswith("return"))
                if opener and w in ("while", "until", "for"):
                    loop_line = line_a
            elif w == "do":
                opener = loop_line != line_a
        elif lang == "Lua":
            opener = w in ("function", "do", "if", "repeat")
        elif lang == "Elixir":
            opener = (w == "do" and not m[mt.end():mt.end() + 1] == ":") or w == "fn"
        elif lang == "Julia":
            if bracket:
                continue
            opener = w in ("function", "macro", "module", "baremodule", "struct", "quote", "begin", "let",
                           "if", "for", "while", "try", "do") or \
                (w in ("abstract", "primitive") and m[mt.end():mt.end() + 6].strip().startswith("type"))
        elif lang == "Fish":
            opener = w in ("function", "if", "for", "while", "switch", "begin")
        if opener:
            stack.append(pos)
            continue
        closes = w == "end" or (lang == "Lua" and w == "until")
        if closes and stack and not (lang == "Julia" and bracket):
            pairs.append((stack.pop(), pos + len(w)))
    return sorted(pairs)


def indent_of(line: str) -> int:
    return len(line.expandtabs(4)) - len(line.expandtabs(4).lstrip())


def indent_end(lines: list[str], code_flags: list[bool], start_line: int) -> int:
    """Last line (1-based) of an indented block whose header is on start_line."""
    base = indent_of(lines[start_line - 1])
    last = start_line
    depth = lines[start_line - 1].count("(") - lines[start_line - 1].count(")")
    k = start_line
    while k < len(lines):
        ln = lines[k]
        if depth > 0:
            depth += ln.count("(") - ln.count(")")
            last = k + 1
            k += 1
            continue
        if ln.strip() == "" or (k < len(code_flags) and not code_flags[k]):
            k += 1
            continue
        if indent_of(ln) <= base:
            break
        last = k + 1
        k += 1
    return last


# ── Doc comments ─────────────────────────────────────────────────────────────

DOC_STRIP = re.compile(r"^\s*(?:///?|//!|/\*\*?|\*/|\*|#+'?|--+-?|<#|#>|'{1,3}|;+|%+|!)\s?")
XML_TAG = re.compile(r"</?(?:summary|remarks|returns|para|c|see[^>]*|inheritdoc[^>]*)\s*/?>")


def leading_doc(lines: list[str], res: ScanResult, decl_line: int, lang: str) -> tuple[str, list[str]]:
    """Doc comment above a declaration, plus attribute/decorator lines skipped on the way."""
    k = decl_line - 2
    decorators = []
    while k >= 0:
        s = lines[k].strip()
        if res.comment_lines[k] and not res.code_lines[k]:
            break
        if s.startswith(("@", "[", "#[")) and res.code_lines[k] and not s.endswith(("{", ";")):
            decorators.append(s)
            k -= 1
            continue
        break
    collected = []
    while k >= 0 and res.comment_lines[k] and not res.code_lines[k]:
        collected.append(lines[k])
        k -= 1
    if not collected and k >= 0 and lang == "Elixir":
        one = re.match(r'\s*@doc\s+"(.*)"\s*$', lines[k])
        if one:
            return collapse(one.group(1), 300), decorators[::-1]
    if not collected and k >= 0 and lang in ("Julia", "Elixir") and lines[k].strip().endswith('"""'):
        j = k - 1
        while j >= 0 and '"""' not in lines[j]:
            j -= 1
        collected = [re.sub(r'@doc\s*"""|"""', "", ln) for ln in lines[max(j, 0):k + 1]][::-1]
    decorators.reverse()
    return clean_doc(list(reversed(collected))), decorators


def clean_doc(raw_lines: list[str]) -> str:
    text_lines = []
    for ln in raw_lines:
        s = DOC_STRIP.sub("", ln.rstrip())
        s = re.sub(r"\*/\s*$|#>\s*$|-->\s*$", "", s)
        s = XML_TAG.sub("", s).strip()
        if s and re.fullmatch(r"[-=*#/~_+.:|<>─━═┄┈\s]+", s):
            s = ""                                # banner rule lines: // ----------
        text_lines.append(s)
    # PowerShell comment-based help: prefer .SYNOPSIS, else .DESCRIPTION.
    joined = "\n".join(text_lines)
    help_m = re.search(r"^\s*\.(SYNOPSIS|DESCRIPTION)\s*\n(.*?)(?=^\s*\.[A-Z]+\b|\Z)", joined, re.M | re.S)
    if help_m:
        return collapse(help_m.group(2), 300)
    out = []
    for s in text_lines:
        if s.startswith(("@param", "@return", "@throws", "@example", "@see", "@since", "@type",
                         "@typedef", "@template", "@remarks", ":param", ":return", "Args:", "Returns:",
                         "<param", "<exception", "# Arguments", "# Returns", "# Examples", "Parameters")):
            break
        if not s and out:
            break
        if s:
            out.append(s)
    return collapse(" ".join(out), 300)


def ps_help_in_body(text: str, res: ScanResult, open_pos: int) -> str:
    """PowerShell comment-based help placed as the first thing inside a function body."""
    head = text[open_pos + 1: open_pos + 4000]
    m = re.match(r"\s*<#(.*?)#>", head, re.S)
    return clean_doc(m.group(1).split("\n")) if m else ""


# ── Python (exact) ───────────────────────────────────────────────────────────

def extract_python_ast(text: str, rel: str, res: ScanResult, cell: int | None = None,
                       line_offset: int = 0) -> tuple[list[Sym], list[TypeDecl]] | None:
    try:
        tree = ast.parse(text)
    except (SyntaxError, ValueError):
        return None
    syms: list[Sym] = []
    types: list[TypeDecl] = []

    def visit(node, class_stack: list[str], func_stack: list[str]):
        for child in ast.iter_child_nodes(node):
            if isinstance(child, ast.ClassDef):
                types.append(TypeDecl(child.name, "class", rel, "Python", child.lineno + line_offset,
                                      getattr(child, "end_lineno", None) and child.end_lineno + line_offset,
                                      ".".join(class_stack) or None,
                                      first_para(ast.get_docstring(child) or "")))
                visit(child, class_stack + [child.name], func_stack)
            elif isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                sym = py_sym(child, rel, class_stack, func_stack, res, cell, line_offset)
                syms.append(sym)
                visit(child, class_stack, func_stack + [sym.qualname])
            elif isinstance(child, ast.Assign) and isinstance(child.value, ast.Lambda) and \
                    len(child.targets) == 1 and isinstance(child.targets[0], ast.Name):
                # Named lambdas count wherever they are, like JS `const f = () => …`.
                end = getattr(child, "end_lineno", child.lineno)
                off_a = res.line_starts[child.lineno - 1] if child.lineno - 1 < len(res.line_starts) else 0
                off_b = res.line_starts[end] - 1 if end < len(res.line_starts) else len(res.masked)
                s = Sym(child.targets[0].id, "local function" if func_stack else
                        ("method" if class_stack else "function"), rel, "Python", child.lineno + line_offset,
                        end + line_offset,
                        container=None if func_stack else (".".join(class_stack) or None),
                        container_kind="class" if class_stack and not func_stack else None,
                        parent_callable=func_stack[-1] if func_stack else None,
                        signature=collapse(f"{child.targets[0].id} = lambda {ast.unparse(child.value.args)}"),
                        params=[a.arg for a in child.value.args.args], confidence="exact",
                        modifiers=["lambda"], cell=cell, body=(off_a, off_b))
                syms.append(s)
            else:
                visit(child, class_stack, func_stack)

    visit(tree, [], [])
    return syms, types


def first_para(doc: str) -> str:
    return collapse(doc.strip().split("\n\n")[0], 300) if doc else ""


def py_sym(node, rel, class_stack, func_stack, res: ScanResult, cell, line_offset) -> Sym:
    decos = ["@" + ast.unparse(d) for d in node.decorator_list]
    is_async = isinstance(node, ast.AsyncFunctionDef)
    if func_stack:
        kind = "local function"
    elif class_stack:
        kind = "method"
        if node.name in ("__init__", "__new__"):
            kind = "constructor"
        elif node.name == "__del__":
            kind = "destructor"
        elif any(d in ("@property", "@cached_property", "@functools.cached_property") for d in decos):
            kind = "getter"
        elif any(d.endswith((".setter", ".deleter")) for d in decos):
            kind = "setter"
    else:
        kind = "function"
    args = node.args
    params = [a.arg for a in getattr(args, "posonlyargs", [])] + [a.arg for a in args.args]
    if args.vararg:
        params.append("*" + args.vararg.arg)
    params += [a.arg for a in args.kwonlyargs]
    if args.kwarg:
        params.append("**" + args.kwarg.arg)
    ret = ast.unparse(node.returns) if node.returns else None
    sig = f"{'async ' if is_async else ''}def {node.name}({ast.unparse(args)})" + (f" -> {ret}" if ret else "")
    mods = (["async"] if is_async else []) + [d[1:] for d in decos if d in ("@staticmethod", "@classmethod",
                                                                           "@abstractmethod",
                                                                           "@abc.abstractmethod")]
    start = node.lineno
    end = getattr(node, "end_lineno", None)
    body = None
    if end:
        a = res.line_starts[start - 1] if start - 1 < len(res.line_starts) else 0
        b = res.line_starts[end] - 1 if end < len(res.line_starts) else len(res.masked)
        body = (a, b)
    name = node.name
    vis = "private" if name.startswith("_") and not (name.startswith("__") and name.endswith("__")) else "public"
    return Sym(name, kind, rel, "Python", start + line_offset, (end or start) + line_offset,
               container=None if func_stack else (".".join(class_stack) or None),
               container_kind="class" if class_stack and not func_stack else None,
               parent_callable=func_stack[-1] if func_stack else None, signature=collapse(sig), params=params,
               returns=ret, modifiers=mods, decorators=decos, visibility=vis,
               doc=first_para(ast.get_docstring(node) or ""),
               abstract=any("abstractmethod" in d for d in decos), confidence="exact", body=body, cell=cell)


# ── Generic extraction ───────────────────────────────────────────────────────

def find_containers(text: str, m: str, res: ScanResult, lang: str, rel: str) -> list[TypeDecl]:
    rules = CONTAINER_RULES.get(lang) or (CONTAINER_RULES["brace-generic"] if lang in BRACE_CONTAINER_LANGS
                                          else [])
    out: list[TypeDecl] = []
    lines = text.split("\n")
    blocks = end_blocks(m, lang) if lang in ("Ruby", "Crystal", "Elixir", "Julia") else None
    for default_kind, rx in rules:
        for mt in rx.finditer(m):
            name = mt.group("name").rstrip(".")
            kind = (mt.groupdict().get("kind") or default_kind).lower().split()[0]
            kind = {"@interface": "interface", "defmodule": "module", "defprotocol": "protocol",
                    "defimpl": "impl", "structure": "struct"}.get(kind, kind)
            if lang == "Rust" and default_kind == "impl" and mt.groupdict().get("trait"):
                kind = "impl"
            line = res.line_of(mt.start())
            td = TypeDecl(name, kind, rel, lang, line, start=mt.start())
            if blocks is not None:
                la, lb = line_bounds(m, mt.start())
                for a, b in blocks:
                    if la <= a < lb:
                        td.open, td.close = a, b
                        td.end_line = res.line_of(b)
                        break
            elif lang in ("Python", "GDScript", "Nim", "F#"):
                td.end_line = indent_end(lines, res.code_lines, line)
                td.open = mt.start()
                td.close = res.line_starts[td.end_line] - 1 if td.end_line < len(res.line_starts) else len(m)
            elif lang == "Visual Basic .NET":
                close = re.compile(rf"^[ \t]*End\s+{kind}\b", re.M | re.I).search(m, mt.end())
                if close:
                    td.open, td.close = mt.start(), close.end()
                    td.end_line = res.line_of(close.start())
            elif lang == "SQL":
                pass
            else:
                bkind, bopen, bend, _ = find_body(m, mt.end(), lang)
                if bkind == "block":
                    td.open, td.close = bopen, bend
                    td.end_line = res.line_of(bend)
            td.doc = leading_doc(lines, res, line, lang)[0]
            out.append(td)
    out.sort(key=lambda t: t.start)
    # Nest containers: a container inside another's body gets it as its container.
    for t in out:
        for o in out:
            if o is not t and o.open >= 0 and o.close >= 0 and o.open < t.start < o.close and \
                    o.kind not in ("namespace", "module", "impl"):
                t.container = o.name
    return out


def innermost(containers: list[TypeDecl], pos: int) -> TypeDecl | None:
    best = None
    for c in containers:
        if c.open >= 0 and c.close >= 0 and c.open < pos < c.close:
            if best is None or c.open > best.open:
                best = c
    return best


def typed_candidates(text: str, m: str, res: ScanResult, lang: str, containers: list[TypeDecl]):
    """Declarations in C-family typed languages, recognized by their line prefix."""
    mods = MODIFIERS.get(lang, set())
    for mt in re.finditer(r"(?<![\w$@])(~?[A-Za-z_]\w*(?:::~?[A-Za-z_]\w*)*|operator\s*(?:\(\)|\[\]|"
                          r"[^\s\w(]{1,3}|\w+))\s*(?:<[^;{}()]*?>)?\s*\(", m):
        name = mt.group(1)
        base_name = name.split("::")[-1]
        if base_name in STATEMENT_KEYWORDS or name in STATEMENT_KEYWORDS:
            continue
        la, _ = line_bounds(m, mt.start())
        prefix = m[la:mt.start()]
        if prefix.lstrip().startswith("#"):
            continue                              # preprocessor: #define F(x) ...
        before_char = m[mt.start() - 1] if mt.start() > 0 else ""
        dart_named_ctor = None
        qual = re.search(r"((?:[A-Za-z_]\w*::)+)$", prefix)
        if qual and before_char == ":":
            name = qual.group(1) + name           # Shape& Shape::operator=(...)
            base_name = name.split("::")[-1]
            prefix = prefix[:qual.start()]
        elif lang == "Dart" and prefix.rstrip().endswith("."):
            owner = re.search(r"(\w+)\.\s*$", prefix)
            cont = innermost(containers, mt.start())
            if owner and cont and owner.group(1) == cont.name:
                dart_named_ctor = name
                prefix = prefix[:owner.start()]
            else:
                continue
        elif before_char == "." or prefix.rstrip().endswith(("->", ".")):
            continue
        prefix = ATTR_PREFIX.sub("", prefix)
        # Judge the prefix with generics removed: `Map<String, ValStr<?>>` and `string?` are types.
        bare = prefix
        for _ in range(4):
            stripped = re.sub(r"<[^<>]*>", "", bare)
            if stripped == bare:
                break
            bare = stripped
        if re.search(r"[=;{}()\"]|\breturn\b|\bthrow\b|\belse\b|\bcase\b|\bgoto\b|\?\s*\S+\s*:", bare):
            if not ("operator" in name and "=" in name):
                continue
        if "," in bare:
            continue
        tokens = [t for t in re.split(r"[\s*&]+", prefix.strip()) if t]
        if any(t in TYPE_DECL_WORDS for t in tokens):
            continue
        type_tokens = [t for t in tokens if t not in mods and not t.startswith("[")]
        if any(not re.search(r"\w", t) for t in type_tokens):
            continue                              # `: member_(x)` initializer lines, stray punctuation
        cont = innermost(containers, mt.start())
        if cont is not None and cont.kind in ("namespace", "module"):
            cont = None                           # namespaces don't own methods
        is_ctor = bool(dart_named_ctor) or (cont is not None and base_name == cont.name.split(".")[-1]) or \
            bool(re.match(r"(?:\w+::)*(\w+)::~?\1$", name))
        is_dtor = base_name.startswith("~")
        if not type_tokens and not (is_ctor or is_dtor):
            gnu = False
            if lang in ("C", "C++", "CUDA") and not prefix.strip() and cont is None:
                prev_a = m.rfind("\n", 0, max(la - 1, 0))
                prev = m[prev_a + 1:la].strip()
                gnu = bool(prev) and bool(re.fullmatch(r"[\w\s*&:<>,]+", prev)) and \
                    not re.search(r"\b(return|else|case|goto)\b", prev)
                if gnu:
                    type_tokens = [prev]
            if not gnu and lang == "Dart" and not prefix.strip() and cont is None:
                type_tokens = ["dynamic"]
            if not gnu and not type_tokens:
                continue
        if type_tokens and type_tokens[0] in ("new",) and not is_ctor:
            continue
        yield mt, name, dart_named_ctor, tokens, type_tokens, is_ctor, is_dtor, cont


def extract_generic(text: str, lang_name: str, rel: str) -> tuple[list[Sym], list[TypeDecl]]:
    lang = LANGUAGES[lang_name]
    res = scan(text, lang)
    m = res.masked
    lines = text.split("\n")
    containers = find_containers(text, m, res, lang_name, rel)
    syms: list[Sym] = []
    seen: set[int] = set()
    blocks = end_blocks(m, lang_name) if lang_name in ("Ruby", "Crystal", "Elixir", "Julia", "Lua",
                                                       "Fish") else []

    def add(sym: Sym, start_off: int):
        if start_off in seen:
            return
        seen.add(start_off)
        doc, decos = leading_doc(lines, res, sym.line, lang_name)
        sym.doc = sym.doc or doc
        sym.decorators = decos + sym.decorators
        syms.append(sym)

    # Typed C-family declarations.
    if lang_name in TYPED_LANGS:
        for mt, name, dart_ctor, tokens, type_tokens, is_ctor, is_dtor, cont in \
                typed_candidates(text, m, res, lang_name, containers):
            open_paren = mt.end() - 1
            close_paren = match_brace(m, open_paren, "(", ")")
            if close_paren < 0:
                continue
            bkind, bopen, bend, tail = find_body(m, close_paren + 1, lang_name)
            mods = [t for t in tokens if t in MODIFIERS.get(lang_name, set())]
            in_iface = cont is not None and cont.kind in ("interface", "protocol", "trait")
            abstract = bkind == "pure" or (bkind == "decl" and (in_iface or "abstract" in mods or
                                                                "extern" in mods and lang_name == "C#"))
            # Dart constructors are complete without a body: `const Foo({this.x});`
            dart_ctor_decl = lang_name == "Dart" and is_ctor and bkind == "decl"
            if bkind == "none" or (bkind == "decl" and not abstract and not dart_ctor_decl):
                continue
            if bkind == "decl" and lang_name in ("C", "C++", "CUDA") and not in_iface and bkind != "pure":
                continue
            base = name.split("::")[-1]
            if is_dtor:
                kind = "destructor"
            elif is_ctor:
                kind = "constructor"
            elif base.startswith("operator"):
                kind = "operator"
            else:
                kind = "method" if (cont is not None or "::" in name) else "function"
            line = res.line_of(mt.start())
            start_off = line_bounds(m, mt.start())[0]
            container = cont.name if cont else None
            if "::" in name and not cont:
                container = name.rsplit("::", 1)[0]
                base = name.rsplit("::", 1)[1]
            sym_name = dart_ctor or base
            if dart_ctor:
                container = cont.name             # Counter.fromJson → container Counter, name fromJson
            if dart_ctor_decl:
                abstract = False
            sig_end = bopen if bkind in ("block", "expr", "decl", "pure") else close_paren + 1
            sym = Sym(sym_name, kind, rel, lang_name, line,
                      res.line_of(bend) if bend >= 0 else line,
                      container=container, container_kind=cont.kind if cont else None,
                      signature=collapse(text[start_off:sig_end]),
                      params=parse_params(m[open_paren + 1:close_paren], lang_name),
                      returns=" ".join(t for t in type_tokens if t not in ("dynamic",)) or None
                      if not (is_ctor or is_dtor) else None,
                      modifiers=mods, abstract=abstract,
                      body=(bopen, bend) if bkind in ("block", "expr") else None)
            add(sym, start_off)

    for rule in RULES.get(lang_name, []):
        for mt in rule.rx.finditer(m):
            gd = mt.groupdict()
            name = gd.get("name") or gd.get("name2") or ("(IIFE)" if rule.kind == "iife" else None)
            if not name or (not rule.keyword_led and name in STATEMENT_KEYWORDS):
                continue
            start_off = line_bounds(m, mt.start())[0]
            if start_off in seen:
                continue
            cont = innermost(containers, mt.start())
            if rule.scope == "class" and (cont is None or cont.kind in ("namespace", "module", "enum")):
                continue
            if rule.scope == "interface" and (cont is None or cont.kind != "interface"):
                continue
            if lang_name == "Go" and rule.scope != "interface" and cont is not None and cont.kind == "interface":
                continue
            line = res.line_of(mt.start())
            kind = rule.kind
            kw = (gd.get("kw") or "").lower()
            mods = [w for w in (gd.get("mods") or "").split() if w]
            params_text = ""
            bkind, bopen, bend = "none", -1, -1
            sig_end = mt.end()
            is_paren = m[mt.end() - 1] == "("
            if is_paren:
                open_paren = mt.end() - 1
                close_paren = match_brace(m, open_paren, "(", ")")
                if close_paren < 0:
                    continue
                params_text = m[open_paren + 1:close_paren]
                after = close_paren + 1
            else:
                after = mt.end()
                # def build(attrs = {}) / def add(cart, item) do — optional parens after the name.
                paren = re.compile(r"[ \t]*\(").match(m, after)
                if paren and lang_name in ("Ruby", "Crystal", "Elixir", "Scala", "MATLAB", "Fortran",
                                           "Pascal", "Visual Basic .NET", "SQL", "Batchfile"):
                    pclose = match_brace(m, paren.end() - 1, "(", ")")
                    if pclose > 0:
                        params_text = m[paren.end():pclose]
                        after = pclose + 1
            if gd.get("arrowparam"):
                params_text = gd["arrowparam"]
            if rule.body == "brace":
                if rule.require_arrow:
                    tail_m = re.match(r"\s*(?::\s*[^=;{}\n]+?)?\s*=>", m[after:after + 300])
                    if not tail_m:
                        continue
                    arrow = after + tail_m.end()
                    nxt = m[arrow:arrow + 200].lstrip()
                    if nxt.startswith("{"):
                        bopen = m.index("{", arrow)
                        bend = match_brace(m, bopen)
                        bkind = "block"
                    else:
                        bkind, bopen, bend = "expr", arrow, expr_end(m, arrow, newline_ends=True)
                        # `onClick: (e: Event) => void;` in an interface or type literal is a
                        # function *type*, not a function.
                        if lang_name == "TypeScript" and TS_TYPE_BODY.match(m[arrow:bend + 1]):
                            continue
                    if lang_name == "TypeScript" and cont is not None and cont.kind == "interface":
                        continue
                    sig_end = arrow
                elif gd.get("arrowparam"):
                    arrow = m.find("=>", mt.start())
                    nxt = m[arrow + 2:arrow + 200].lstrip()
                    if nxt.startswith("{"):
                        bopen = m.index("{", arrow)
                        bkind, bend = "block", match_brace(m, bopen)
                    else:
                        bkind, bopen, bend = "expr", arrow, expr_end(m, arrow + 2, newline_ends=True)
                    sig_end = arrow + 2
                else:
                    if lang_name in ("PowerShell", "Shell") and rule.kind == "function" and not is_paren:
                        # function Name { }  |  function Name($a) { }  |  name() ( subshell )
                        k = mt.end()
                        while k < len(m) and m[k] in " \t":
                            k += 1
                        if lang_name == "PowerShell" and m[k:k + 1] == "(":
                            pclose = match_brace(m, k, "(", ")")
                            if pclose > 0:
                                params_text = m[k + 1:pclose]
                                k = pclose + 1
                        opener = re.compile(r"\s*([{(])").match(m, k)
                        if opener:
                            ch = opener.group(1)
                            bopen = opener.start(1)
                            bend = match_brace(m, bopen, ch, "}" if ch == "{" else ")")
                            bkind = "block" if bend > 0 else "none"
                        else:
                            bkind, bopen, bend = "none", -1, -1
                    else:
                        bkind, bopen, bend, _tail = find_body(m, after, lang_name,
                                                              expr_eq=lang_name in ("Kotlin", "Scala"))
                    in_iface = cont is not None and cont.kind in ("interface", "protocol", "trait")
                    if bkind in ("decl", "pure"):
                        ctor_decl = rule.kind == "constructor" and lang_name in ("Kotlin",)
                        if not (rule.allow_decl and (in_iface or "abstract" in mods)) and not ctor_decl:
                            continue
                    elif bkind == "none" and rule.require_body:
                        continue
                    if lang_name == "Kotlin" and rule.kind == "constructor" and bkind == "decl":
                        bkind = "ctor-decl"
                    if bopen >= 0:
                        sig_end = bopen
                if bkind in ("block", "expr") and bend < 0:
                    bend = len(m) - 1
            elif rule.body == "end":
                la, lb = line_bounds(m, mt.start())
                # The block must open on the declaration's own line. Elixir `def f(x), do: expr`
                # and Ruby endless `def f = expr` have no block and end on this line.
                one_liner = lang_name == "Elixir" and re.search(r"\bdo:", m[mt.start():lb])
                for a, b in blocks:
                    if not one_liner and mt.start() - 1 <= a < lb:
                        bkind, bopen, bend = "block", a, b
                        break
                if bkind == "none":
                    bend = lb
                sig_end = after                   # includes an optional parameter list
            elif rule.body == "indent":
                end_line = indent_end(lines, res.code_lines, line)
                bkind = "block"
                bopen = mt.end()
                bend = res.line_starts[end_line] - 1 if end_line < len(res.line_starts) else len(m) - 1
                sig_end = line_bounds(m, mt.start())[1]
                if is_paren:
                    sig_end = max(sig_end, after)
            elif rule.body == "vb":
                close = re.compile(rf"^[ \t]*End\s+{kw}\b", re.M | re.I).search(m, mt.end())
                if close:
                    bkind, bopen, bend = "block", mt.end(), close.end()
                sig_end = line_bounds(m, mt.start())[1]
                if "mustoverride" in [x.lower() for x in mods]:
                    bkind = "decl"
            else:
                sig_end = line_bounds(m, mt.start())[1]
            end_line = res.line_of(bend) if bend >= 0 else None
            # Kind refinement.
            if rule.kind in ("function", "method"):
                if gd.get("recv"):
                    kind = "method"
                elif cont is not None and cont.kind not in ("namespace", "module") and \
                        lang_name not in ("Go",):
                    kind = "method"
                if lang_name in ("JavaScript", "TypeScript"):
                    if name == "constructor" and cont is not None:
                        kind = "constructor"
                    elif "get" in mods:
                        kind = "getter"
                    elif "set" in mods:
                        kind = "setter"
                if lang_name == "PowerShell" and rule.scope == "class" and cont and name == cont.name:
                    kind = "constructor"
                if lang_name == "PHP" and name == "__construct":
                    kind = "constructor"
                if lang_name == "PHP" and name == "__destruct":
                    kind = "destructor"
                if lang_name in ("Ruby", "Crystal") and name == "initialize":
                    kind = "constructor"
                if lang_name == "Visual Basic .NET":
                    kind = "constructor" if name.lower() == "new" else ("operator" if kw == "operator" else
                                                                        ("method" if cont else "function"))
                if lang_name == "Pascal":
                    kind = "method" if "." in name else ("procedure" if kw == "procedure" else "function")
                    if kw in ("constructor", "destructor"):
                        kind = kw
            if lang_name == "SQL":
                kind = {"trigger": "trigger", "function": "function"}.get(kw, "procedure")
            container = cont.name if cont else None
            recv = (gd.get("recv") or "").strip()
            if recv == "self.":
                recv = ""                         # Ruby `def self.build` → class method of the container
                if "static" not in mods:
                    mods.append("static")
            if recv:
                if lang_name == "Go":
                    rm = re.search(r"\*?\s*([A-Za-z_]\w*)(?:\[[^\]]*\])?\s*$", recv)
                    container = rm.group(1) if rm else recv
                else:
                    container = recv.rstrip(".").replace(".prototype", "")
            if lang_name == "Lua" and re.search(r"[.:]", name):
                container, name = re.split(r"[.:](?=[^.:]*$)", name)
                kind = "method"
            if lang_name == "Pascal" and "." in name:
                container, name = name.rsplit(".", 1)
            abstract = bkind in ("decl", "pure")
            body = (bopen, bend) if bkind in ("block", "expr") and bopen >= 0 else None
            sig = collapse(text[start_off:max(sig_end, start_off)]) if sig_end > start_off else \
                collapse(lines[line - 1])
            if lang_name == "PowerShell" and body:
                # param() must be the first statement of the body (attributes and help may precede it).
                pm = PS_PARAM_START.match(m, bopen + 1)
                if pm:
                    pstart = pm.end() - 1
                    pclose = match_brace(m, pstart, "(", ")")
                    if pclose > 0:
                        params_text = m[pstart + 1:pclose]
            if kind in ("function", "method") and not re.match(r"[\w$#`]", name):
                kind = "operator"                 # Swift `static func ==`, Scala `def +`
            returns = None
            if (is_paren or params_text) and kind not in ("constructor", "destructor"):
                tail_end = bopen if bopen >= 0 else line_bounds(m, after)[1]
                returns = return_from_tail(m[after:tail_end], lang_name)
            sym = Sym(name, kind, rel, lang_name, line, end_line, container=container,
                      container_kind=cont.kind if cont else ("receiver" if recv else None),
                      signature=sig, params=parse_params(params_text, lang_name) if params_text else [],
                      returns=returns,
                      modifiers=mods + ([kw] if kw and kw not in ("function", "def", "sub") else []),
                      abstract=abstract, body=body)
            if lang_name == "F#" and gd.get("fsparams"):
                sym.params = [p for p in re.findall(r"[a-z_]\w*", gd["fsparams"]) if p not in ("unit",)][:12]
            if lang_name == "PowerShell" and body and not sym.doc:
                sym.doc = ps_help_in_body(text, res, bopen)
            if lang_name == "Python" and body:
                ds = re.match(r'\s*(?:[rubfRUBF]{0,2})("""|\'\'\')(.*?)\1', text[line_bounds(m, sig_end)[1]:
                                                                               line_bounds(m, sig_end)[1] + 3000],
                              re.S)
                if ds:
                    sym.doc = first_para(ds.group(2))
            add(sym, start_off)

    # Next-declaration extents (Batch labels, MATLAB, Pascal): a routine runs until the next one,
    # trimmed back over trailing blank and comment lines.
    if lang_name in ("Batchfile", "MATLAB", "Pascal") and (syms or lang_name == "Pascal"):
        if lang_name == "Pascal":
            impl = re.search(r"^\s*implementation\b", m, re.M | re.I)
            syms[:] = [s for s in syms if not (impl and line_start_off(res, s.line) < impl.start())
                       and not re.search(r"\bforward\s*;", lines[s.line - 1], re.I)]
            # The program's main block is the last column-0 `begin` before the final `end.` with no
            # routine-ending `end;` in between. It is what runs (ReNamer calls it once per file).
            final = None
            for final in re.finditer(r"^end\s*\.", m, re.M | re.I):
                pass
            if final:
                main_begin = None
                for b in re.finditer(r"^begin\b", m[:final.start()], re.M | re.I):
                    if not re.search(r"^end\s*;", m[b.start():final.start()], re.M | re.I):
                        main_begin = b
                        break
                if main_begin:
                    ml = res.line_of(main_begin.start())
                    syms.append(Sym("(main)", "main block", rel, "Pascal", ml, res.line_of(final.start()),
                                    signature="begin … end.", visibility="public"))
        syms.sort(key=lambda s: s.line)
        last_line = len(lines)
        while last_line > 1 and not lines[last_line - 1].strip():
            last_line -= 1
        for i, s in enumerate(syms):
            end = syms[i + 1].line - 1 if i + 1 < len(syms) else last_line
            if s.kind == "main block":
                close = re.compile(r"^\s*end\s*\.", re.M | re.I).search(m, line_start_off(res, s.line))
                end = res.line_of(close.start()) if close else end
            while end > s.line and (not lines[end - 1].strip() or
                                    (res.comment_lines[end - 1] and not res.code_lines[end - 1])):
                end -= 1
            s.end_line = end
            s.body = (line_start_off(res, s.line),
                      res.line_starts[end] - 1 if end < len(res.line_starts) else len(m) - 1)
        syms[:] = [s for s in syms if s.name.lower() != "eof"]
    # PowerShell scripts with a top-level param() block are commands: the file is a callable.
    if lang_name == "PowerShell" and rel.lower().endswith(".ps1"):
        script = powershell_script_symbol(text, m, res, rel)
        if script:
            syms.append(script)
    # Local (nested) callables.
    syms.sort(key=lambda s: (s.body[0] if s.body else 0))
    for s in syms:
        if not s.body:
            continue
        for o in syms:
            if o is s or not o.body:
                continue
            if o.body[0] < s.body[0] and s.body[1] <= o.body[1] and o.body[0] < line_start_off(res, s.line):
                if s.kind in ("function", "method") and not (o.kind in ("constructor",) and
                                                             lang_name in ("TypeScript", "JavaScript")):
                    s.kind = "local function"
                s.parent_callable = o.qualname
    return syms, containers


def line_start_off(res: ScanResult, line: int) -> int:
    return res.line_starts[line - 1] if 0 < line <= len(res.line_starts) else 0


PS_PARAM_START = re.compile(r"\s*(?:\[[^\]]*(?:\([^)]*\))?[^\]]*\]\s*)*param\s*\(", re.I)
PS_TOP_PARAM = re.compile(r"^[ \t]*param\s*\(", re.M | re.I)


def strip_attributes(text: str) -> str:
    """Remove PowerShell/C#-style [attributes], including nested ones like [OutputType([string])]."""
    while True:
        new = re.sub(r"\[[^\[\]]*\]", "", text)
        if new == text:
            return new
        text = new


def powershell_script_symbol(text: str, m: str, res: ScanResult, rel: str) -> Sym | None:
    """A .ps1 whose first statement is param(...) is invoked like a function: inventory it."""
    for pm in PS_TOP_PARAM.finditer(m):
        depth = m.count("{", 0, pm.start()) - m.count("}", 0, pm.start())
        if depth != 0:
            continue
        before = re.sub(r"(?im)^\s*using\s+\S.*$", "", strip_attributes(m[:pm.start()]))
        if before.strip():
            return None                           # code precedes param(): it's not the script's param block
        open_paren = m.index("(", pm.start())
        close = match_brace(m, open_paren, "(", ")")
        params = parse_params(m[open_paren + 1:close], "PowerShell") if close > 0 else []
        lines = text.split("\n")
        end = len(lines)
        while end > 1 and not lines[end - 1].strip():
            end -= 1
        start_line = res.line_of(pm.start())
        while start_line > 1 and lines[start_line - 2].strip().startswith("["):
            start_line -= 1                       # include [CmdletBinding()] / [OutputType()] lines
        help_m = re.search(r"<#(.*?)#>", text[:line_start_off(res, start_line)], re.S)
        name = rel.rsplit("/", 1)[-1]
        return Sym(name, "script", rel, "PowerShell", start_line, end, signature=collapse(
            text[line_start_off(res, start_line):(close + 1 if close > 0 else pm.end())]), params=params,
            doc=clean_doc(help_m.group(1).split("\n")) if help_m else "", visibility="public",
            body=(pm.start(), len(m) - 1))
    return None


SCRIPT_RE = re.compile(r"<script\b([^>]*)>(.*?)</script\s*>", re.S | re.I)
FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.S)


def extract_embedded(text: str, lang_name: str, rel: str) -> tuple[list[Sym], list[TypeDecl], str]:
    """Run the JS/TS extractor over <script> blocks (and Astro frontmatter)."""
    syms: list[Sym] = []
    types: list[TypeDecl] = []
    blocks = []
    for mt in SCRIPT_RE.finditer(text):
        attrs = mt.group(1).lower()
        if "src=" in attrs or re.search(r"type\s*=\s*[\"'](?!text/javascript|module|application/javascript)",
                                        attrs):
            continue
        sub = "TypeScript" if re.search(r"lang\s*=\s*[\"'](ts|typescript|tsx)", attrs) else "JavaScript"
        blocks.append((mt.start(2), mt.group(2), sub))
    if lang_name == "Astro":
        fm = FRONTMATTER_RE.match(text)
        if fm:
            blocks.append((fm.start(1), fm.group(1), "TypeScript"))
    used = ""
    for start, body, sub in blocks:
        offset = text.count("\n", 0, start)
        s, t = extract_generic(body, sub, rel)
        for sym in s:
            sym.line += offset
            if sym.end_line:
                sym.end_line += offset
            sym.language = f"{lang_name} ({sub})"
        for td in t:
            td.line += offset
            if td.end_line:
                td.end_line += offset
        syms += s
        types += t
        used = sub
    return syms, types, used


CALL_RE = re.compile(r"(?<![\w$])(?:(?P<recv>[A-Za-z_$][\w$]*)\s*(?:\?\.|\.|::|->)\s*)?"
                     r"(?P<name>[A-Za-z_$][\w$]*)\s*(?:<[^;{}()<>]*>)?\s*\(")
SELF_WORDS = {"self", "this", "cls", "Me", "$this", "base", "super"}
IDENT_RE = re.compile(r"(?<![\w$])[A-Za-z_$][\w$]*")


def called_names_for(sym: Sym, others: list[Sym], m: str) -> set:
    """(name, receiver) for every call site in the body, excluding nested callables' bodies.

    receiver is "" for a bare call, "self" for self/this/cls, else the identifier before the dot.
    """
    if not sym.body:
        return set()
    a, b = sym.body
    holes = sorted(o.body for o in others if o is not sym and o.body and a < o.body[0] and o.body[1] <= b)
    calls = set()
    pos = a
    segments = []
    for h0, h1 in holes:
        if h0 > pos:
            segments.append((pos, h0))
        pos = max(pos, h1)
    segments.append((pos, b + 1))
    lang = sym.language
    for s0, s1 in segments:
        for mt in CALL_RE.finditer(m, s0, s1):
            recv = mt.group("recv") or ""
            calls.add((mt.group("name"), "self" if recv in SELF_WORDS else recv))
        if lang == "PowerShell":                  # command syntax: Get-Thing -Arg x (no parentheses)
            for mt in PS_COMMAND.finditer(m, s0, s1):
                calls.add((mt.group(1), ""))
        elif lang in BARE_CALL_LANGS:             # Pascal/VB/Ruby: `Bump;` calls a parameterless routine
            for mt in BARE_CALL.finditer(m, s0, s1):
                calls.add((mt.group(1), ""))
    calls.discard((sym.name, ""))
    return calls


PS_COMMAND = re.compile(r"(?<![\w$.\-])([A-Za-z]+-[A-Za-z][\w]*)\b")
BARE_CALL = re.compile(r"^[ \t]*([A-Za-z_]\w*)[ \t]*(?:;|$)", re.M)
BARE_CALL_LANGS = {"Pascal", "Visual Basic .NET", "Ruby", "Crystal"}


# ── Driver ───────────────────────────────────────────────────────────────────

COMMON_NAMES = {"get", "set", "run", "main", "init", "log", "print", "push", "pop", "map", "filter", "call",
                "apply", "bind", "then", "catch", "add", "remove", "update", "render", "start", "stop",
                "open", "close", "read", "write", "send", "emit", "on", "off", "use", "new", "create",
                "delete", "load", "save", "parse", "format", "test", "setup", "teardown", "reset", "clear",
                "toString", "equals", "hashCode", "dispose", "Dispose", "Invoke", "invoke", "execute",
                "handle", "process", "next", "done", "resolve", "reject", "error", "info", "warn", "debug",
                "length", "size", "keys", "values", "items", "append", "extend", "join", "split", "strip",
                "replace", "find", "index", "count", "sort", "copy", "len", "str", "int", "float", "list",
                "dict", "tuple", "range", "type", "isinstance", "super", "require", "describe", "it", "expect",
                "enable", "disable", "connect", "disconnect", "wait", "sleep", "exists", "encode", "decode",
                "dumps", "loads", "fetch", "request", "json", "text", "evaluate", "click", "goto", "cleanup",
                "status", "result", "value", "name", "path", "id", "check", "validate", "build", "reload",
                "refresh", "flush", "reset", "toJSON", "valueOf", "equal", "compare", "hash", "exec", "eval"}


def _norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]", "", s.lower())


def extract_file(root: Path, entry, want_tests: bool) -> tuple[list[Sym], list[TypeDecl], dict]:
    rel = entry.path
    lang = entry.lang
    info = {"path": rel, "language": lang.name, "extractor": "none", "callables": 0, "types": 0,
            "is_test": entry.is_test}
    if entry.size > MAX_PARSE_BYTES:
        info["extractor"] = "skipped-large"
        return [], [], info
    try:
        text = read_text(root / rel)
    except OSError as exc:
        info["extractor"] = f"error: {exc}"
        return [], [], info
    syms: list[Sym] = []
    types: list[TypeDecl] = []
    masked = ""
    if lang.name == "Python":
        res = scan(text, lang)
        masked = res.masked
        got = extract_python_ast(text, rel, res)
        if got is not None:
            syms, types = got
            info["extractor"] = "python-ast"
        else:
            syms, types = extract_generic(text, "Python", rel)
            info["extractor"] = "regex (ast failed)"
    elif lang.name == "Jupyter Notebook":
        try:
            nb = json.loads(text)
        except ValueError:
            info["extractor"] = "error: invalid JSON"
            return [], [], info
        kernel = (nb.get("metadata", {}).get("kernelspec", {}) or {}).get("language", "python")
        if kernel != "python":
            info["extractor"] = f"unsupported notebook kernel: {kernel}"
            return [], [], info
        for ci, cell in enumerate(nb.get("cells", []), 1):
            if cell.get("cell_type") != "code":
                continue
            src = "".join(cell.get("source", [])) if isinstance(cell.get("source"), list) else cell.get("source", "")
            src = "\n".join("" if ln.lstrip().startswith(("%", "!")) else ln for ln in src.split("\n"))
            cres = scan(src, LANGUAGES["Python"])
            got = extract_python_ast(src, rel, cres, cell=ci)
            if got:
                for s in got[0]:
                    s.called_names = called_names_for(s, got[0], cres.masked)
                syms += got[0]
                types += got[1]
        info["extractor"] = "python-ast (notebook cells)"
        info["callables"], info["types"] = len(syms), len(types)
        return syms, types, info
    elif lang.name in EMBEDDED_SCRIPT_LANGS:
        syms, types, used = extract_embedded(text, lang.name, rel)
        info["extractor"] = f"regex (<script> as {used})" if used else "none (no script blocks)"
        # Call graph for embedded code is resolved against each block separately.
        for s in syms:
            s.body = None
        hash_symbols(syms, text)
        info["callables"], info["types"] = len(syms), len(types)
        return syms, types, info
    elif lang.name in RULES or lang.name in TYPED_LANGS:
        syms, types = extract_generic(text, lang.name, rel)
        info["extractor"] = "regex"
        res = scan(text, lang)
        masked = res.masked
    elif lang.name in NO_CALLABLES:
        info["extractor"] = "n/a"
        return [], [], info
    else:
        info["extractor"] = "unsupported"
        return [], [], info
    if masked:
        for s in syms:
            s.called_names = called_names_for(s, syms, masked)
            if s.end_line:
                s.code_lines = sum(1 for k in range(s.line - 1, min(s.end_line, len(res.code_lines)))
                                   if res.code_lines[k])
        info["_idents"] = Counter(IDENT_RE.findall(masked))
    if lang.name == "PowerShell" and rel.lower().endswith(".psm1"):
        apply_module_exports(syms, text)
    hash_symbols(syms, text)
    info["callables"], info["types"] = len(syms), len(types)
    return syms, types, info


EXPORT_RE = re.compile(r"Export-ModuleMember\b(?:[^\n`]|`\n)*?-Function(?:\s+|:)((?:[^\n`-]|`\n|-(?=\w+[,'\"\s]))+)",
                       re.I)


def apply_module_exports(syms: list[Sym], text: str) -> None:
    """In a .psm1 with Export-ModuleMember -Function, exported functions are public, the rest private."""
    import fnmatch as _fn
    patterns = []
    for m in EXPORT_RE.finditer(text):
        patterns += [p.strip().strip("'\"@()") for p in re.split(r"[,\s]+", m.group(1).replace("`\n", " "))
                     if p.strip().strip("'\"@()")]
    if not patterns:
        return
    for s in syms:
        if s.kind == "function" and not s.parent_callable:
            s.visibility = "public" if any(_fn.fnmatch(s.name.lower(), p.lower()) for p in patterns) else "private"


def hash_symbols(syms: list[Sym], text: str) -> None:
    """Content hash of each declaration's lines: lets a later run tell which entries are stale."""
    src_lines = text.split("\n")
    for s in syms:
        seg = "\n".join(src_lines[s.line - 1:(s.end_line or s.line)])
        s.hash = hashlib.sha1(seg.encode("utf-8", "replace")).hexdigest()[:12]


def family(lang: str) -> str:
    """Callers only reach callees in the same language (JS/TS and their embeddings share one)."""
    base = lang.split(" (")[-1].rstrip(")") if "(" in lang else lang
    return "JS" if base in ("JavaScript", "TypeScript") else base


IMPLICIT_THIS = {"Java", "C#", "C++", "Kotlin", "Swift", "Scala", "Dart", "Ruby", "Crystal", "Objective-C",
                 "Groovy", "Visual Basic .NET", "PHP"}


def resolve_call(i: int, name: str, recv: str, syms: list, by_name: dict) -> int | None:
    """Pick the callee of one call site, or None when the evidence is ambiguous."""
    s = syms[i]
    fam = family(s.language)
    cands = [c for c in by_name.get(name, ()) if family(syms[c].language) == fam and c != i]
    if not cands or name in COMMON_NAMES or len(name) < 3:
        return None
    owner = s.container
    if recv == "self":                            # self.x() / this.x(): a member of the caller's class
        own = [c for c in cands if syms[c].container and syms[c].container == owner]
        return own[0] if len(own) == 1 else None
    if recv:                                      # obj.x(): the receiver must name the class or module
        r = _norm(recv)
        hits = [c for c in cands if (syms[c].container and r and (_norm(syms[c].container) in r or
                                                                   r in _norm(syms[c].container)))
                or (not syms[c].container and _norm(Path(syms[c].file).stem) == r)]
        return hits[0] if len(hits) == 1 else None
    # Bare call: a free function, or (in implicit-this languages) a member of the caller's class.
    free = [c for c in cands if not syms[c].container or syms[c].kind == "local function"]
    if s.language in IMPLICIT_THIS and owner:
        own = [c for c in cands if syms[c].container == owner]
        if len(own) == 1:
            return own[0]
    if len(free) == 1:
        return free[0]
    same = [c for c in free if syms[c].file == s.file]
    return same[0] if len(same) == 1 else None


def finalize(syms: list[Sym], idents: dict | None = None) -> list[dict]:
    syms.sort(key=lambda s: (s.file, s.cell or 0, s.line))
    # Stable, readable ids: file::qualname, with @line for overloads/duplicates. Whitespace is
    # percent-encoded so an id is always one token inside an HTML-comment marker.
    def enc(text: str) -> str:
        return re.sub(r"\s", lambda m: f"%{ord(m.group(0)):02X}", text)

    base_ids = Counter(f"{s.file}::{s.qualname}" for s in syms)
    ids = []
    for s in syms:
        bid = f"{s.file}::{s.qualname}"
        if s.cell:
            bid = f"{s.file}::cell{s.cell}::{s.qualname}"
        ids.append(enc(bid if base_ids[f"{s.file}::{s.qualname}"] == 1 else f"{bid}@{s.line}"))
    # Heuristic call graph: receiver-aware matching of call sites to callables.
    by_name: dict[str, list[int]] = defaultdict(list)
    for i, s in enumerate(syms):
        by_name[s.name].append(i)
    calls: dict[int, set] = defaultdict(set)
    for i, s in enumerate(syms):
        for nm, recv in s.called_names:
            j = resolve_call(i, nm, recv, syms, by_name)
            if j is not None:
                calls[i].add(j)
    # References: how often the name occurs as an identifier elsewhere in same-language code
    # (callbacks, registrations, dispatch tables), minus its own definitions.
    defs = Counter((family(s.language), s.name) for s in syms)
    called_by: dict[int, set] = defaultdict(set)
    for i, js in calls.items():
        for j in js:
            called_by[j].add(i)
    out = []
    for i, s in enumerate(syms):
        vis = s.visibility
        if vis == "unknown":
            vis = next((VISIBILITY_WORDS[w] for w in s.modifiers if w in VISIBILITY_WORDS), "unknown")
            if vis == "unknown" and any(w.startswith("pub(") for w in s.modifiers):
                vis = "restricted"                # Rust pub(crate) / pub(super)
            if vis == "unknown":
                if s.language == "Go":
                    vis = "public" if s.name[:1].isupper() else "package"
                elif s.name.startswith("#"):
                    vis = "private"
                elif s.language in ("Rust",) and "pub" not in " ".join(s.modifiers):
                    vis = "private"
                elif s.language == "PowerShell" and s.kind == "function":
                    vis = "public" if re.match(r"^[A-Z][a-z]+-\w", s.name) else "unknown"
        if s.parent_callable and vis in ("unknown", "public", "private"):
            vis = "local"                         # nested callables are only reachable from their parent
        if s.decorators and TEST_ATTR.search(" ".join(s.decorators)):
            s.is_test = True
        tn = TEST_NAME.get(s.language)
        if tn and tn.search(s.name) and (s.is_test or s.language == "Go"):
            s.is_test = True
        rec = {
            "id": ids[i], "name": s.name, "qualname": s.qualname, "kind": s.kind, "file": s.file,
            "language": s.language, "line": s.line, "end_line": s.end_line,
            "lines": (s.end_line - s.line + 1) if s.end_line else None,
            "container": s.container, "container_kind": s.container_kind,
            "parent_callable": s.parent_callable, "signature": s.signature, "params": s.params,
            "returns": s.returns, "modifiers": s.modifiers, "decorators": s.decorators,
            "visibility": vis, "abstract": s.abstract, "is_test": s.is_test, "doc": s.doc,
            "confidence": s.confidence, "hash": s.hash, "code_lines": s.code_lines,
            "calls": sorted(ids[j] for j in calls.get(i, ()))[:40],
            "called_by": sorted(ids[j] for j in called_by.get(i, ()))[:40],
            "references": (max(0, idents.get(family(s.language), Counter())[s.name] -
                               defs[(family(s.language), s.name)]) if idents is not None else None),
        }
        if s.cell:
            rec["cell"] = s.cell
        out.append(rec)
    return out


def analyze(root: Path, exclude: list[str], include_vendored: bool, want_tests: bool) -> dict:
    listing = list_files(root, exclude, include_vendored)
    all_syms: list[Sym] = []
    all_types: list[TypeDecl] = []
    files = []
    unsupported = []
    idents: dict[str, Counter] = defaultdict(Counter)
    for entry in listing["files"]:
        if entry.status != "source" or entry.lang is None:
            continue
        if entry.lang.type not in ("programming", "markup") and entry.lang.name != "Jupyter Notebook":
            continue
        if entry.lang.type == "markup" and entry.lang.name not in EMBEDDED_SCRIPT_LANGS | {"Jupyter Notebook"}:
            continue
        if entry.is_test and not want_tests:
            continue
        syms, types, info = extract_file(root, entry, want_tests)
        for s in syms:
            s.is_test = s.is_test or entry.is_test
        all_syms += syms
        all_types += types
        idents[family(entry.lang.name)].update(info.pop("_idents", Counter()))
        files.append(info)
        if info["extractor"] in ("unsupported",) or info["extractor"].startswith("unsupported"):
            try:
                n_lines = read_text(root / entry.path).count("\n") + 1
            except OSError:
                n_lines = None
            unsupported.append({"path": entry.path, "language": entry.lang.name, "lines": n_lines})
    symbols = finalize(all_syms, idents)
    types_out = [{"name": t.name, "kind": t.kind, "file": t.file, "language": t.language, "line": t.line,
                  "end_line": t.end_line, "container": t.container, "doc": t.doc}
                 for t in sorted(all_types, key=lambda t: (t.file, t.line))]
    by_kind = Counter(s["kind"] for s in symbols)
    by_lang = Counter(s["language"] for s in symbols)
    by_conf = Counter(s["confidence"] for s in symbols)
    tests = sum(1 for s in symbols if s["is_test"])
    return {
        "tool": f"{TOOL_NAME}/extract_symbols",
        "schema": SCHEMA_VERSION,
        "generated": now_iso(),
        "root": str(root),
        "file_listing": listing["mode"],
        "counting_rule": ("Named callables: functions, methods, constructors, destructors, accessors with "
                          "parameter lists, operators, local functions, named arrow/lambda/script-block "
                          "assignments, abstract/interface declarations (abstract=true), and file-level "
                          "programs (JS IIFEs, PowerShell scripts with a param() block, Pascal main "
                          "blocks). Anonymous lambdas and callbacks are not counted. Types are listed "
                          "separately."),
        "summary": {
            "callables": len(symbols),
            "non_test_callables": len(symbols) - tests,
            "test_callables": tests,
            "abstract_declarations": sum(1 for s in symbols if s["abstract"]),
            "types": len(types_out),
            "files_scanned": len(files),
            "files_with_callables": sum(1 for f in files if f["callables"]),
            "by_kind": dict(by_kind.most_common()),
            "by_language": dict(by_lang.most_common()),
            "by_confidence": dict(by_conf.most_common()),
            "types_by_kind": dict(Counter(t["kind"] for t in types_out).most_common()),
            "unsupported_files": len(unsupported),
        },
        "files": files,
        "unsupported": unsupported,
        "types": types_out,
        "symbols": symbols,
    }


def main(argv: list[str] | None = None) -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default=".", help="codebase directory (default: .)")
    ap.add_argument("--exclude", action="append", default=[], metavar="GLOB",
                    help="skip paths matching this glob or directory prefix (repeatable)")
    ap.add_argument("--include-vendored", action="store_true", help="also scan vendored directories")
    ap.add_argument("--no-tests", action="store_true", help="skip test files entirely")
    ap.add_argument("--list", action="store_true", help="print one line per callable")
    ap.add_argument("-o", "--output", type=Path, help="write the JSON inventory to this file")
    args = ap.parse_args(argv)
    root = Path(args.root)
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 2
    data = analyze(root.resolve(), args.exclude, args.include_vendored, not args.no_tests)
    if args.output:
        dump_json(data, args.output)
    s = data["summary"]
    if args.list:
        for sym in data["symbols"]:
            flag = " [test]" if sym["is_test"] else ""
            print(f"{sym['file']}:{sym['line']}  {sym['kind']:<15} {sym['qualname']}{flag}")
        print()
    print(f"Callables: {s['callables']}  (non-test {s['non_test_callables']}, test {s['test_callables']}, "
          f"abstract {s['abstract_declarations']})   Types: {s['types']}")
    print("By kind:     " + ", ".join(f"{k} {v}" for k, v in s["by_kind"].items()))
    print("By language: " + ", ".join(f"{k} {v}" for k, v in s["by_language"].items()))
    print("Confidence:  " + ", ".join(f"{k} {v}" for k, v in s["by_confidence"].items()))
    if data["unsupported"]:
        print(f"Unsupported (read manually): {len(data['unsupported'])} files, e.g. "
              + ", ".join(u["path"] for u in data["unsupported"][:5]))
    if args.output:
        print(f"wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
