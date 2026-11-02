#!/usr/bin/env python3
"""
Regression tests for the fm-summarize-codebase scripts (stdlib unittest).

  python tests/test_scripts.py            # from the skill folder
  python -m unittest discover -s tests    # equivalent

The polyglot fixtures each hold the traps that broke an earlier version of the
extractor (C++ initializer lists, Go interface{} returns, Rust lifetimes and raw
strings, TS function-typed members, Ruby modifier-if, PowerShell param() blocks,
Dart bodyless constructors, Elixir do: one-liners, ...).
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPTS = HERE.parent / "scripts"
FIXTURES = HERE / "fixtures" / "polyglot"
sys.path.insert(0, str(SCRIPTS))

import _common as C  # noqa: E402
import extract_symbols as E  # noqa: E402
import language_stats as L  # noqa: E402

EXPECTED = {
    "Canvas.swift": ["Drawable.draw", "Canvas.init", "Canvas.init", "Canvas.deinit", "Canvas.draw",
                     "Canvas.==", "Canvas.subscript", "Canvas.tapped", "Canvas.clear"],
    "Counter.vue": ["inc", "reset"],
    "Greeter.vb": ["Greeter.New", "Greeter.Greet", "Greeter.Log"],
    "Hello.php": ["Greeter.greet", "Base.tag", "Hello.__construct", "Hello.greet", "Hello.tag", "Hello.make",
                  "helper"],
    "Main.scala": ["Main.greet", "Main.size", "Main.helper", "Shape.area", "Circle.area"],
    "Repo.java": ["Repo.Repo", "Repo.Repo", "Repo.iterator", "Repo.max", "Repo.list", "Visitor.visit",
                  "Visitor.weight", "Color.next", "Base.name", "Base.helper"],
    "Sample.cs": ["IStore.GetAsync", "IStore.Save", "WidgetStore.WidgetStore", "WidgetStore.~WidgetStore",
                  "WidgetStore.GetAsync", "WidgetStore.Save", "WidgetStore.Get", "WidgetStore.Group",
                  "WidgetStore.Group.Local", "WidgetStore.operator +", "WidgetStore.Hook", "WidgetStore.Dispose"],
    "UserRepo.kt": ["Repo.find", "Repo.all", "UserRepo.constructor", "UserRepo.find", "UserRepo.load",
                    "UserRepo.create", "String.shout", "helper"],
    "Widgets.psm1": ["Get-Widget", "Set-Widget", "Where-Big", "Widget.Widget", "Widget.Describe",
                     "Widget.Create", "Widget.Reset"],
    "build.sh": ["usage", "cleanup", "build", "main"],
    "cart.ex": ["Shop.Cart.add", "Shop.Cart.total", "Shop.Cart.secret"],
    "counter.dart": ["Counter.Counter", "Counter.named", "Counter.fromJson", "Counter.createState",
                     "Counter.load", "Counter._helper", "main", "sum"],
    "legacy_py2.py": ["Old.method", "top"],
    "mathx.lua": ["M.add", "M.method", "helper", "helper.inner", "M.sub"],
    "run.bat": ["greet"],
    "schema.sql": ["get_users", "dbo.Archive", "trg_audit"],
    "service.py": ["Service.__init__", "Service.host", "Service.host", "Service.parse", "Service.parse.inner",
                   "Service.fetch", "Service._get", "square", "test_parse"],
    "shape.cpp": ["Shape.Shape", "Shape.area", "Shape.sides", "Shape.~Shape", "Shape.operator=", "Shape.ids",
                  "clamp", "legacy_c_style", "main"],
    "shapes.rs": ["Shape.area", "Shape.name", "Point.new", "Point.load", "Point.fmt", "callback",
                  "tests.it_works"],
    "store.go": ["Getter.Get", "Getter.Len", "NewStore", "Store.Get", "Store.Len", "Map", "weird", "TestStore"],
    "widget.rb": ["Widget.initialize", "Widget.build", "Widget.valid?", "Widget.to_s", "Widget.secret",
                  "Shop.helper"],
    "tool.ps1": ["tool.ps1", "tool.ps1.Get-Inner", "tool.ps1.$fmt"],
    "serial.pas": ["ZeroPad", "Bump", "(main)"],
    "calls.py": ["DebugLogger.enable", "DebugLogger.record_event", "DebugLogger._append_event", "Tab.activate_tab",
                 "Tab.record_event", "attach", "_on_signal", "install", "_unused_helper"],
    "widget.ts": ["Service.fetch", "Service.onEvent", "add", "multiply", "log", "double", "legacy",
                  "Widget.handler", "Widget.constructor", "Widget.fetch", "Widget.name", "Widget.name",
                  "Widget.#hidden", "Widget.overload", "Base.render", "Base.helper", "module.exports.run",
                  "Foo.bar", "list", "create", "remove"],
}


class ExtractorFixtures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = E.analyze(FIXTURES, [], False, True)
        cls.by_file: dict[str, list[dict]] = {}
        for s in cls.data["symbols"]:
            cls.by_file.setdefault(s["file"], []).append(s)

    def sym(self, file: str, qualname: str, nth: int = 0) -> dict:
        hits = [s for s in self.by_file.get(file, []) if s["qualname"] == qualname]
        self.assertTrue(hits, f"{file}: {qualname} not extracted")
        return hits[nth]

    def test_every_file_exact_inventory(self):
        for file, want in EXPECTED.items():
            with self.subTest(file=file):
                got = [s["qualname"] for s in sorted(self.by_file.get(file, []), key=lambda s: s["line"])]
                self.assertEqual(sorted(got), sorted(want))

    def test_total(self):
        self.assertEqual(self.data["summary"]["callables"], sum(len(v) for v in EXPECTED.values()))

    def test_ids_unique(self):
        ids = [s["id"] for s in self.data["symbols"]]
        self.assertEqual(len(ids), len(set(ids)))

    def test_abstract_declarations(self):
        for file, q in [("Sample.cs", "IStore.Save"), ("Sample.cs", "WidgetStore.Hook"), ("shape.cpp", "Shape.area"),
                        ("shapes.rs", "Shape.area"), ("store.go", "Getter.Get"), ("widget.ts", "Base.render"),
                        ("Hello.php", "Base.tag"), ("Main.scala", "Shape.area"), ("Repo.java", "Visitor.visit")]:
            self.assertTrue(self.sym(file, q)["abstract"], f"{file}: {q} should be abstract")
        for file, q in [("counter.dart", "Counter.Counter"), ("UserRepo.kt", "UserRepo.constructor")]:
            self.assertFalse(self.sym(file, q)["abstract"], f"{file}: bodyless ctor {q} is not abstract")

    def test_kinds(self):
        cases = {("Sample.cs", "WidgetStore.WidgetStore"): "constructor",
                 ("Sample.cs", "WidgetStore.~WidgetStore"): "destructor",
                 ("Sample.cs", "WidgetStore.Group.Local"): "local function",
                 ("Sample.cs", "WidgetStore.operator +"): "operator",
                 ("Canvas.swift", "Canvas.=="): "operator",
                 ("service.py", "Service.__init__"): "constructor",
                 ("widget.ts", "Widget.constructor"): "constructor",
                 ("widget.rb", "Widget.initialize"): "constructor",
                 ("Widgets.psm1", "Widget.Widget"): "constructor",
                 ("schema.sql", "trg_audit"): "trigger",
                 ("cart.ex", "Shop.Cart.add"): "function"}
        for (file, q), kind in cases.items():
            self.assertEqual(self.sym(file, q)["kind"], kind, f"{file}: {q}")
        self.assertEqual(self.sym("service.py", "Service.host", 0)["kind"], "getter")
        self.assertEqual(self.sym("service.py", "Service.host", 1)["kind"], "setter")

    def test_docs(self):
        cases = {("Sample.cs", "WidgetStore.WidgetStore"): "Creates the store.",
                 ("store.go", "NewStore"): "NewStore creates a store.",
                 ("shapes.rs", "Point.new"): "Creates a point.",
                 ("widget.ts", "add"): "Adds numbers.",
                 ("Widgets.psm1", "Get-Widget"): "Gets a widget by name.",
                 ("Widgets.psm1", "Set-Widget"): "Sets a widget.",
                 ("mathx.lua", "M.add"): "Adds two numbers.",
                 ("Greeter.vb", "Greeter.Greet"): "Says hi.",
                 ("Hello.php", "Hello.greet"): "Greets someone.",
                 ("widget.rb", "Widget.initialize"): "Creates a widget.",
                 ("build.sh", "usage"): "Prints usage.",
                 ("schema.sql", "get_users"): "Returns users."}
        for (file, q), doc in cases.items():
            self.assertEqual(self.sym(file, q)["doc"], doc, f"{file}: {q}")

    def test_params_and_returns(self):
        self.assertEqual(self.sym("Widgets.psm1", "Get-Widget")["params"], ["$Name", "$Count"])
        self.assertEqual(self.sym("Hello.php", "Hello.greet")["params"], ["$name"])
        self.assertEqual(self.sym("Canvas.swift", "Canvas.tapped")["params"], ["sender"])
        self.assertEqual(self.sym("widget.ts", "Widget.constructor")["params"], ["svc"])
        self.assertEqual(self.sym("service.py", "Service.parse")["params"], ["text", "*args", "sep", "**kw"])
        self.assertEqual(self.sym("store.go", "Store.Get")["returns"], "(int, bool)")
        self.assertEqual(self.sym("shapes.rs", "Point.fmt")["returns"], "fmt::Result")
        self.assertEqual(self.sym("widget.ts", "multiply")["returns"], "number")
        self.assertEqual(self.sym("Sample.cs", "WidgetStore.Group")["returns"], "Dictionary<string, List<int>>")

    def test_extents(self):
        for file, q, a, b in [("Sample.cs", "WidgetStore.GetAsync", 28, 33), ("shapes.rs", "Point.load", 16, 22),
                              ("widget.rb", "Widget.to_s", 20, 26), ("mathx.lua", "M.method", 8, 13),
                              ("cart.ex", "Shop.Cart.total", 9, 9), ("UserRepo.kt", "UserRepo.constructor", 11, 11),
                              ("Widgets.psm1", "Get-Widget", 6, 21)]:
            s = self.sym(file, q)
            self.assertEqual((s["line"], s["end_line"]), (a, b), f"{file}: {q}")

    def test_call_graph_same_language_only(self):
        self.assertIn("service.py::Service._get", self.sym("service.py", "Service.fetch")["calls"])
        self.assertEqual(self.sym("store.go", "Map")["calls"], [])        # Go builtin make() ≠ PHP make()

    def test_scripts_blocks_and_main(self):
        script = self.sym("tool.ps1", "tool.ps1")
        self.assertEqual(script["kind"], "script")
        self.assertEqual(script["params"], ["$Path", "$Force"])          # nested [OutputType([...])] attribute
        self.assertEqual(script["line"], 6)                              # starts at [CmdletBinding()]
        self.assertEqual(self.sym("tool.ps1", "tool.ps1.$fmt")["kind"], "script block")
        self.assertEqual(self.sym("tool.ps1", "tool.ps1.$fmt")["params"], ["$Value", "$Max"])
        self.assertEqual(self.sym("tool.ps1", "tool.ps1.Get-Inner")["visibility"], "local")
        main = self.sym("serial.pas", "(main)")
        self.assertEqual((main["kind"], main["line"], main["end_line"]), ("main block", 22, 25))
        self.assertEqual(self.sym("serial.pas", "Bump")["kind"], "procedure")
        self.assertEqual((self.sym("serial.pas", "ZeroPad")["line"], self.sym("serial.pas", "ZeroPad")["end_line"]),
                         (10, 15))
        self.assertEqual(self.sym("serial.pas", "ZeroPad")["doc"], "Left-pads Value with zeros to Width digits.")

    def test_receiver_aware_calls_and_references(self):
        calls = self.sym("calls.py", "attach")["calls"]
        self.assertIn("calls.py::DebugLogger.record_event", calls)
        self.assertNotIn("calls.py::Tab.record_event", calls)            # same name, wrong receiver
        self.assertIn("calls.py::DebugLogger._append_event", self.sym("calls.py", "DebugLogger.record_event")["calls"])
        self.assertEqual(self.sym("calls.py", "_on_signal")["references"], 1)    # passed as a callback
        self.assertEqual(self.sym("calls.py", "_unused_helper")["references"], 0)
        self.assertIn("tool.ps1::tool.ps1.Get-Inner", self.sym("tool.ps1", "tool.ps1")["calls"])  # command syntax
        self.assertIn("serial.pas::Bump", self.sym("serial.pas", "(main)")["calls"])             # bare call

    def test_tests_flagged(self):
        self.assertTrue(self.sym("shapes.rs", "tests.it_works")["is_test"])
        self.assertTrue(self.sym("store.go", "TestStore")["is_test"])
        self.assertFalse(self.sym("service.py", "test_parse")["is_test"])   # not in a test file


class Scanner(unittest.TestCase):
    def masked(self, text: str, lang: str) -> str:
        return C.scan(text, C.LANGUAGES[lang]).masked

    def test_strings_and_comments_blanked(self):
        m = self.masked('var s = "}{"; // { comment\n/* } */ x();', "C#")
        self.assertEqual(m.count("{"), 0)
        self.assertEqual(m.count("}"), 0)
        self.assertEqual(len(m), len('var s = "}{"; // { comment\n/* } */ x();'))

    def test_rust_lifetimes_are_not_char_literals(self):
        m = self.masked("fn f<'a>(x: &'a str) -> char { '}' }", "Rust")
        self.assertEqual(m.count("{"), 1)
        self.assertEqual(m.count("}"), 1)

    def test_shell_hash_inside_expansion(self):
        res = C.scan('n=${#ARR[@]} # real comment\n', C.LANGUAGES["Shell"])
        self.assertIn("${#ARR[@]}", res.masked)
        self.assertNotIn("real", res.masked)

    def test_js_regex_literal(self):
        self.assertEqual(self.masked("const re = /[{}]/g; if (a / b) { }", "JavaScript").count("{"), 1)

    def test_python_docstring_is_comment(self):
        res = C.scan('def f():\n    """Doc."""\n    return 1\n', C.LANGUAGES["Python"])
        self.assertEqual(res.comment_lines, [False, True, False, False])


class LanguageStats(unittest.TestCase):
    def test_percentages_sum_to_100(self):
        data = L.analyze(FIXTURES, [], False, False)
        self.assertAlmostEqual(sum(r["pct_code"] for r in data["languages"]), 100.0, places=6)
        self.assertAlmostEqual(sum(r["pct_bytes"] for r in data["languages"]), 100.0, places=6)
        names = {r["language"] for r in data["languages"]}
        self.assertTrue({"TypeScript", "C#", "Python", "Rust", "Go"} <= names)

    def test_markers_only_in_comments(self):
        data = L.analyze(FIXTURES, [], False, False)
        self.assertEqual(data["markers"].get("FIXME", 0), 0)      # 'TODO FIXME' string in tool.ps1 ignored
        self.assertEqual(data["markers"].get("TODO"), 2)          # the two comment mentions

    def test_largest_remainder(self):
        pct = L.largest_remainder({"a": 1, "b": 1, "c": 1})
        self.assertAlmostEqual(sum(pct.values()), 100.0)
        self.assertEqual(sorted(pct.values()), [33.3, 33.3, 33.4])


class Detection(unittest.TestCase):
    def test_language_detection(self):
        self.assertEqual(C.detect_language("x/.editorconfig").name, "INI")
        self.assertEqual(C.detect_language("LICENSE-MIT").name, "Text")
        self.assertEqual(C.detect_language("tool", "#!/usr/bin/env python3\n").name, "Python")
        self.assertEqual(C.detect_language("a.m", "#import <Foundation/Foundation.h>\n").name, "Objective-C")
        self.assertEqual(C.detect_language("a.m", "function y = f(x)\n").name, "MATLAB")

    def test_generated_header_requires_comment(self):
        self.assertTrue(C.has_generated_header("// Code generated by protoc. DO NOT EDIT.\npackage x\n"))
        self.assertFalse(C.has_generated_header("# Specs\nThis folder is auto-generated by the build.\n"))


class Pipeline(unittest.TestCase):
    """analyze.py → scaffold_report.py → check_report.py on the fixtures."""

    def test_end_to_end(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp) / "work"
            report = Path(tmp) / "SUMMARY.md"
            run = lambda *a: subprocess.run([sys.executable, *map(str, a)], capture_output=True, text=True)  # noqa
            r = run(SCRIPTS / "analyze.py", FIXTURES, "--workdir", work)
            self.assertEqual(r.returncode, 0, r.stderr)
            for name in ("metadata.json", "languages.json", "symbols.json"):
                self.assertTrue((work / name).is_file(), name)
            r = run(SCRIPTS / "scaffold_report.py", work, "-o", report)
            self.assertEqual(r.returncode, 0, r.stderr)
            text = report.read_text(encoding="utf-8")
            sym_total = json.loads((work / "symbols.json").read_text(encoding="utf-8"))["summary"]["callables"]
            self.assertIn(f"{sym_total} <!-- total-callables -->", text)
            # An unfilled scaffold must fail the check...
            r = run(SCRIPTS / "check_report.py", work / "symbols.json", report)
            self.assertEqual(r.returncode, 1, r.stdout)
            # ...and a fully filled one must pass.
            filled = FILL_ALL(text)
            report.write_text(filled, encoding="utf-8")
            r = run(SCRIPTS / "check_report.py", work / "symbols.json", report)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            # Deleting one entry must fail again.
            first = filled.index("<!-- sym:")
            broken = filled[:first] + filled[first:].replace("<!-- sym:", "<!-- gone:", 1)
            report.write_text(broken, encoding="utf-8")
            r = run(SCRIPTS / "check_report.py", work / "symbols.json", report)
            self.assertEqual(r.returncode, 1)


def run_script(*args) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, *map(str, args)], capture_output=True, text=True)


def fill_reference(files: list[Path], summary: str = "Loads settings | merges env") -> None:
    """Fill every slot except the generated index rows, as an agent would."""
    import re
    for f in files:
        t = f.read_text(encoding="utf-8")
        t = re.sub(r"\*\*Summary:\*\* \[\[FILL:[^\]]*\]\]", f"**Summary:** {summary}", t)
        t = "\n".join(ln if "<!-- idx:" in ln else FILL_ALL(ln) for ln in t.split("\n"))
        f.write_text(t, encoding="utf-8")


class SyncReport(unittest.TestCase):
    """The index and all counts are rebuilt from the reference entries."""

    def test_sync_fills_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            run_script(SCRIPTS / "analyze.py", FIXTURES, "--workdir", tmp / "w")
            report = tmp / "R.md"
            run_script(SCRIPTS / "scaffold_report.py", tmp / "w", "-o", report, "--split", "always",
                       "--inline-index-limit", "10")
            fill_reference([report] + sorted((tmp / "codebase-summary").rglob("*.md")))
            r = run_script(SCRIPTS / "check_report.py", tmp / "w" / "symbols.json", report)
            self.assertEqual(r.returncode, 1)                 # index rows still open
            r = run_script(SCRIPTS / "sync_report.py", tmp / "w" / "symbols.json", report)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            r = run_script(SCRIPTS / "check_report.py", tmp / "w" / "symbols.json", report)
            self.assertEqual(r.returncode, 0, r.stdout)
            index = (tmp / "codebase-summary" / "function-index.md").read_text(encoding="utf-8")
            self.assertIn("Loads settings \\| merges env |", index)

    def test_corrections_drop_and_manual(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            run_script(SCRIPTS / "analyze.py", FIXTURES, "--workdir", tmp / "w")
            report = tmp / "R.md"
            run_script(SCRIPTS / "scaffold_report.py", tmp / "w", "-o", report, "--split", "never")
            fill_reference([report])
            text = report.read_text(encoding="utf-8")
            total = json.loads((tmp / "w" / "symbols.json").read_text(encoding="utf-8"))["summary"]["callables"]
            # Drop one entry (remove it and record the drop) ...
            sid = "run.bat::greet"
            start = text.index(f"<!-- sym:{sid}")
            start = text.rfind("\n####", 0, start) + 1
            end = text.index("\n###", start + 5)
            text = text[:start] + text[end + 1:]
            # ... and add a manual entry to an existing file group.
            manual = ("#### `Sample.cs lambda` <!-- sym:manual:Sample.cs::OnTick -->\n\nlocal function · line 44\n\n"
                      "**Summary:** Logs each timer tick with its sequence number\n\n" + "Handles ticks. " * 12 + "\n\n")
            anchor = text.index("### `Sample.cs`")
            anchor = text.index("\n####", anchor) + 1
            text = text[:anchor] + manual + text[anchor:]
            text = text.replace("## Appendix B. Extractor corrections",
                                f"## Appendix B. Extractor corrections\n\n<!-- drop:{sid} label, not a routine -->")
            report.write_text(text, encoding="utf-8")
            r = run_script(SCRIPTS / "check_report.py", tmp / "w" / "symbols.json", report)
            self.assertEqual(r.returncode, 1)                 # stale total and index before syncing
            r = run_script(SCRIPTS / "sync_report.py", tmp / "w" / "symbols.json", report)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            synced = report.read_text(encoding="utf-8")
            self.assertIn(f"{total} <!-- total-callables -->", synced)   # -1 dropped +1 manual
            self.assertIn("<!-- idx:manual:Sample.cs::OnTick -->", synced)
            self.assertNotIn(f"<!-- idx:{sid} -->", synced)
            r = run_script(SCRIPTS / "check_report.py", tmp / "w" / "symbols.json", report)
            self.assertEqual(r.returncode, 0, r.stdout)


class Paging(unittest.TestCase):
    def test_large_files_split_into_parts(self):
        syms = [{"id": f"big.py::f{i}", "file": "big.py", "line": i + 1} for i in range(130)] + \
               [{"id": "small.py::g", "file": "small.py", "line": 1}]
        pages = C.reference_pages(syms)
        self.assertEqual(sorted({pages[s["id"]] for s in syms if s["file"] == "big.py"}),
                         ["big-py-part-1", "big-py-part-2", "big-py-part-3"])
        self.assertEqual(pages["small.py::g"], "root")


class Artifacts(unittest.TestCase):
    def test_zip_package_compared_with_tree(self):
        import collect_metadata as M
        import zipfile
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "a.txt").write_text("same\n", encoding="utf-8")
            (tmp / "b.txt").write_text("new\n", encoding="utf-8")
            with zipfile.ZipFile(tmp / "pkg.skill", "w") as zf:
                zf.writestr("pkg/a.txt", "same\r\n")
                zf.writestr("pkg/b.txt", "old\n")
            res = M.compare_zip_to_tree(tmp / "pkg.skill")
            self.assertEqual((res["zip_members_matching_tree"], res["zip_members_differing"]), (1, 1))
            self.assertIn("pkg/b.txt", res["possibly_stale"])


class CarryOver(unittest.TestCase):
    """A refresh keeps descriptions of unchanged callables and re-opens changed ones."""

    def test_refresh(self):
        import shutil
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            src = tmp / "code"
            shutil.copytree(FIXTURES, src)
            run = lambda *a: subprocess.run([sys.executable, *map(str, a)], capture_output=True, text=True)  # noqa
            run(SCRIPTS / "analyze.py", src, "--workdir", tmp / "w1")
            run(SCRIPTS / "scaffold_report.py", tmp / "w1", "-o", tmp / "old.md")
            (tmp / "old.md").write_text(FILL_ALL((tmp / "old.md").read_text(encoding="utf-8")), encoding="utf-8")
            svc = src / "service.py"
            svc.write_text(svc.read_text(encoding="utf-8").replace("return 1", "return 2"), encoding="utf-8")
            run(SCRIPTS / "analyze.py", src, "--workdir", tmp / "w2")
            run(SCRIPTS / "scaffold_report.py", tmp / "w2", "-o", tmp / "new.md")
            r = run(SCRIPTS / "carry_over.py", "--old-symbols", tmp / "w1" / "symbols.json", "--old-report",
                    tmp / "old.md", "--new-symbols", tmp / "w2" / "symbols.json", "--new-report", tmp / "new.md")
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn("1 changed", r.stdout)
            new = (tmp / "new.md").read_text(encoding="utf-8")
            seg = new[new.index("<!-- sym:service.py::Service._get"):]
            self.assertIn("[[FILL:", seg[:seg.index("####", 5)])            # changed → reopened
            seg = new[new.index("<!-- sym:service.py::Service.fetch"):]
            self.assertNotIn("[[FILL:", seg[:seg.index("####", 5)])         # unchanged → carried


def FILL_ALL(text: str) -> str:
    import re
    return re.sub(r"\[\[FILL:[^\]]*\]\]", "Reads the configuration file from disk, validates every section "
                  "against the schema, and returns the parsed settings as a dictionary keyed by section name; "
                  "raises ValueError on malformed input.", text)


if __name__ == "__main__":
    unittest.main(verbosity=1)
