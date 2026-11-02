#!/usr/bin/env python3
"""
Collect a codebase's specifications and metadata as evidence, not guesses.

Every value carries the file (or git command) it came from, so the report can
cite it and the agent can resolve conflicts instead of silently picking one.

Collected:
  identity     name candidates (display vs package id), version candidates and
               conflicts, description, license (manifest + LICENSE text), authors,
               homepage, repository URL, keywords
  git          HEAD snapshot (hash, branch, describe, tags, author, dates, subject),
               path-scoped last/first commit when the root is a subfolder, commit
               and contributor counts, remote (credentials stripped), upstream
               ahead/behind, dirty state, shallow-clone flag, latest tag
  dates        last updated (with its basis), created, newest file mtime
  runtime      language/runtime targets (requires-python, engines, TFMs, editions...)
  entry_points package bins/scripts, __main__ modules, Program.cs, main.go, ...
  dependencies runtime/dev/peer/build dependencies per manifest
  tooling      package managers, build systems, CI, containers, test frameworks,
               linters/formatters, detected frameworks and libraries
  docs         README title + first paragraph, CHANGELOG latest entry, license,
               contributing/security/agent docs
  subprojects  workspace/monorepo packages below the root
  sensitive    paths of secret-bearing files (never read)

Usage:
  python collect_metadata.py <root>                 # JSON to stdout
  python collect_metadata.py <root> -o metadata.json

Exit codes: 0 = ok, 2 = root not found.
"""

from __future__ import annotations

import argparse
import configparser
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

from _common import (GENERATED_DIRS, SCHEMA_VERSION, TOOL_NAME, VENDOR_DIRS, dump_json, git_toplevel, now_iso,
                     read_text, run_git, utf8_stdio)

try:
    import tomllib  # Python 3.11+
except ImportError:  # pragma: no cover - older interpreters
    try:
        import tomli as tomllib  # type: ignore
    except ImportError:
        tomllib = None  # type: ignore

SKIP_DIRS = VENDOR_DIRS | GENERATED_DIRS | {".git", ".hg", ".svn", ".idea", ".vs"}
MANIFEST_NAMES = {
    "package.json", "pyproject.toml", "setup.py", "setup.cfg", "Pipfile", "Cargo.toml", "go.mod",
    "composer.json", "Gemfile", "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle",
    "settings.gradle.kts", "pubspec.yaml", "mix.exs", "Package.swift", "CMakeLists.txt", "deno.json",
    "deno.jsonc", "jsr.json", "manifest.json", "SKILL.md", "plugin.json", "marketplace.json", "DESCRIPTION",
    "Directory.Build.props", "global.json", "vcpkg.json", "conanfile.txt", "conanfile.py", "flake.nix",
    "requirements.txt", "environment.yml", "Project.toml", "rebar.config", "stack.yaml", "dune-project",
    "build.zig", "build.zig.zon", "shard.yml", "project.clj", "deps.edn", "Makefile", "justfile",
    "Justfile", "Dockerfile", "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml",
    "app.json", "angular.json", "nx.json", "turbo.json", "lerna.json", "pnpm-workspace.yaml",
    "tsconfig.json", "vite.config.ts", "vite.config.js", "next.config.js", "next.config.mjs",
    "next.config.ts", "electron-builder.yml", "electron-builder.json", "forge.config.js", "tauri.conf.json",
    "wrangler.toml", "vercel.json", "netlify.toml", "serverless.yml", "Chart.yaml", "host.json",
    "local.settings.json", "AndroidManifest.xml", "Info.plist", "app.config.ts", "app.config.js",
}
MANIFEST_EXTS = {".csproj", ".vbproj", ".fsproj", ".vcxproj", ".sln", ".slnx", ".psd1", ".gemspec", ".nimble",
                 ".cabal", ".rockspec", ".uproject", ".uplugin"}
SENSITIVE = re.compile(r"(^|/)(\.env(\..+)?|.+\.pem|.+\.key|id_rsa.*|id_ed25519.*|.+\.pfx|.+\.p12|"
                       r"credentials(\.json)?|secrets?\.(json|ya?ml|toml)|.+\.keystore|.+\.jks|"
                       r"\.npmrc|\.pypirc|\.netrc|service-account.*\.json)$", re.I)
ARTIFACT_RE = re.compile(r"\.(zip|skill|vsix|nupkg|snupkg|whl|jar|war|aar|apk|aab|ipa|crx|xpi|msi|msix|appx|"
                         r"dmg|pkg|deb|rpm|7z|rar|tgz|tar\.gz|tar\.xz|gem|egg)$", re.I)
SENSITIVE_OK = re.compile(r"\.(example|sample|template|dist)$|example|sample", re.I)


def ev(value, source: str) -> dict:
    return {"value": value, "source": source}


def clean_url(url: str | None) -> str | None:
    """Strip credentials from URLs; normalize git@host:owner/repo to https."""
    if not url:
        return url
    url = url.strip()
    url = re.sub(r"^(https?://)[^/@\s]+@", r"\1", url)
    m = re.match(r"^git@([^:]+):(.+?)(?:\.git)?$", url)
    if m:
        return f"https://{m.group(1)}/{m.group(2)}"
    url = re.sub(r"^git\+", "", url)
    return re.sub(r"\.git$", "", url)


def load_toml(path: Path) -> dict:
    text = read_text(path)
    if tomllib is not None:
        try:
            return tomllib.loads(text)
        except Exception:  # noqa: BLE001 - malformed manifests are reported, not fatal
            pass
    return mini_toml(text)


def mini_toml(text: str) -> dict:
    """Tiny TOML subset for interpreters without tomllib: tables and simple scalar/array keys."""
    root: dict = {}
    cur = root
    logical: list[str] = []
    pending = ""
    for raw in text.splitlines():                  # join multi-line arrays into one logical line
        line = raw.split(" #", 1)[0].strip()
        if not line or line.startswith("#"):
            continue
        pending = f"{pending} {line}".strip() if pending else line
        if pending.count("[") - pending.count("]") > 0 and "=" in pending:
            continue
        logical.append(pending)
        pending = ""
    for line in logical:
        m = re.match(r"^\[\[?([^\]]+)\]\]?$", line)
        if m:
            cur = root
            for part in m.group(1).strip().split("."):
                cur = cur.setdefault(part.strip().strip('"'), {})
            continue
        m = re.match(r'^([\w.\-"]+)\s*=\s*(.+)$', line)
        if m:
            key, val = m.group(1).strip('"'), m.group(2).strip()
            if val[:1] in "\"'":
                cur[key] = val.strip("\"'")
            elif val.startswith("["):
                cur[key] = re.findall(r'"([^"]*)"|\'([^\']*)\'', val) and \
                    [a or b for a, b in re.findall(r'"([^"]*)"|\'([^\']*)\'', val)]
            elif val.startswith("{"):
                cur[key] = dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', val)) or val
            else:
                cur[key] = val
    return root


def load_json_loose(path: Path) -> dict:
    text = read_text(path)
    try:
        return json.loads(text)
    except ValueError:
        text = re.sub(r"^\s*//.*$", "", text, flags=re.M)             # jsonc comments
        text = re.sub(r",(\s*[}\]])", r"\1", text)                      # trailing commas
        try:
            return json.loads(text)
        except ValueError:
            return {}


def rel(root: Path, p: Path) -> str:
    return p.relative_to(root).as_posix()


# ── Discovery ────────────────────────────────────────────────────────────────

def find_files(root: Path, max_depth: int = 4) -> list[Path]:
    out = []
    root_depth = len(root.parts)
    for dirpath, dirnames, filenames in os.walk(root):
        depth = len(Path(dirpath).parts) - root_depth
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not (d.startswith(".") and d not in
                       {".github", ".gitlab", ".circleci", ".claude-plugin", ".devcontainer", ".husky",
                        ".config", ".vscode"})]
        if depth >= max_depth:
            dirnames[:] = []
        for fn in filenames:
            out.append(Path(dirpath) / fn)
    return out


# ── Parsers per manifest ─────────────────────────────────────────────────────

def parse_manifest(root: Path, p: Path, meta: dict) -> None:
    name = p.name
    r = rel(root, p)
    top = "/" not in r
    ident = meta["identity"]
    deps = meta["dependencies"]
    tooling = meta["tooling"]
    runtime = meta["runtime"]
    entries = meta["entry_points"]

    def cand(field: str, value, label: str | None = None):
        if value and isinstance(value, str) and value.strip():
            ident[field].append({"value": value.strip(), "source": f"{r}{' ' + label if label else ''}",
                                 "root": top})

    def dep_block(block, scope: str, eco: str):
        if isinstance(block, dict):
            for k, v in block.items():
                spec = v if isinstance(v, str) else (v.get("version") if isinstance(v, dict) else None)
                deps.append({"ecosystem": eco, "manifest": r, "scope": scope, "name": k, "spec": spec})
        elif isinstance(block, list):
            for item in block:
                if isinstance(item, str):
                    m = re.match(r"^\s*([A-Za-z0-9_.\-\[\]]+)\s*(.*)$", item)
                    if m:
                        deps.append({"ecosystem": eco, "manifest": r, "scope": scope,
                                     "name": re.sub(r"\[.*\]", "", m.group(1)), "spec": m.group(2).strip() or None})

    if name == "package.json":
        d = load_json_loose(p)
        if not isinstance(d, dict):
            return
        cand("names", d.get("name"), "name")
        cand("display_names", d.get("displayName"), "displayName")
        cand("versions", d.get("version"), "version")
        cand("descriptions", d.get("description"), "description")
        lic = d.get("license")
        cand("licenses", lic if isinstance(lic, str) else (lic or {}).get("type") if isinstance(lic, dict) else None,
             "license")
        author = d.get("author")
        if isinstance(author, dict):
            author = author.get("name")
        cand("authors", author, "author")
        cand("homepages", d.get("homepage"), "homepage")
        repo = d.get("repository")
        cand("repositories", clean_url(repo.get("url") if isinstance(repo, dict) else repo), "repository")
        if isinstance(d.get("keywords"), list) and top:
            ident["keywords"] += [k for k in d["keywords"] if isinstance(k, str)]
        for scope, key in (("runtime", "dependencies"), ("dev", "devDependencies"), ("peer", "peerDependencies"),
                           ("optional", "optionalDependencies")):
            dep_block(d.get(key), scope, "npm")
        if d.get("engines"):
            runtime.append(ev(d["engines"], f"{r} engines"))
        if d.get("packageManager"):
            tooling["package_managers"].append(ev(d["packageManager"], f"{r} packageManager"))
        for key in ("main", "module", "types", "browser"):
            if isinstance(d.get(key), str):
                entries.append({"kind": f"package {key}", "name": key, "target": d[key], "source": r})
        bins = d.get("bin")
        if isinstance(bins, str):
            entries.append({"kind": "cli", "name": d.get("name"), "target": bins, "source": r})
        elif isinstance(bins, dict):
            for k, v in bins.items():
                entries.append({"kind": "cli", "name": k, "target": v, "source": r})
        if isinstance(d.get("scripts"), dict):
            meta["scripts"].append({"manifest": r, "scripts": d["scripts"]})
        if d.get("workspaces"):
            tooling["build_systems"].append(ev("npm/yarn/pnpm workspaces", f"{r} workspaces"))
        if d.get("private") is True and top:
            ident["flags"].append(ev("private package (not published)", f"{r} private"))
    elif name == "pyproject.toml":
        d = load_toml(p)
        proj = d.get("project", {}) if isinstance(d.get("project"), dict) else {}
        poetry = d.get("tool", {}).get("poetry", {}) if isinstance(d.get("tool"), dict) else {}
        for src, table in (("[project]", proj), ("[tool.poetry]", poetry)):
            if not table:
                continue
            cand("names", table.get("name"), f"{src} name")
            cand("versions", table.get("version"), f"{src} version")
            cand("descriptions", table.get("description"), f"{src} description")
            lic = table.get("license")
            cand("licenses", lic if isinstance(lic, str) else (lic or {}).get("text") if isinstance(lic, dict)
                 else None, f"{src} license")
            for a in table.get("authors", []) or []:
                cand("authors", a.get("name") if isinstance(a, dict) else a, f"{src} authors")
            if "version" in (table.get("dynamic") or []):
                ident["flags"].append(ev("version is dynamic (set at build time, e.g. from git tags)",
                                         f"{r} {src} dynamic"))
        if proj.get("requires-python"):
            runtime.append(ev(f"Python {proj['requires-python']}", f"{r} requires-python"))
        dep_block(proj.get("dependencies"), "runtime", "pypi")
        for group, items in (proj.get("optional-dependencies") or {}).items():
            dep_block(items, f"optional[{group}]", "pypi")
        for group, items in (d.get("dependency-groups") or {}).items():
            dep_block([i for i in items if isinstance(i, str)], f"group[{group}]", "pypi")
        if poetry:
            dep_block({k: v for k, v in (poetry.get("dependencies") or {}).items() if k != "python"},
                      "runtime", "pypi")
            if (poetry.get("dependencies") or {}).get("python"):
                runtime.append(ev(f"Python {poetry['dependencies']['python']}", f"{r} poetry python"))
            dep_block(poetry.get("dev-dependencies"), "dev", "pypi")
            for g, t in (poetry.get("group") or {}).items():
                dep_block((t or {}).get("dependencies"), f"group[{g}]", "pypi")
        for src, scripts in (("[project.scripts]", proj.get("scripts")), ("[project.gui-scripts]",
                             proj.get("gui-scripts")), ("[tool.poetry.scripts]", poetry.get("scripts"))):
            for k, v in (scripts or {}).items():
                entries.append({"kind": "cli", "name": k, "target": v if isinstance(v, str) else str(v),
                                "source": f"{r} {src}"})
        bs = d.get("build-system", {})
        if isinstance(bs, dict) and bs.get("build-backend"):
            tooling["build_systems"].append(ev(bs["build-backend"], f"{r} build-backend"))
        for tool in (d.get("tool") or {}):
            if tool in ("ruff", "black", "isort", "mypy", "pyright", "pylint", "flake8", "pytest", "coverage",
                        "tox", "hatch", "pdm", "uv", "poetry", "setuptools", "bandit", "pydocstyle"):
                (tooling["test_frameworks"] if tool in ("pytest", "coverage", "tox") else
                 tooling["linters_formatters"] if tool not in ("hatch", "pdm", "uv", "poetry", "setuptools")
                 else tooling["build_systems"]).append(ev(tool, f"{r} [tool.{tool}]"))
    elif name == "setup.cfg":
        cp = configparser.ConfigParser(interpolation=None)
        try:
            cp.read_string(read_text(p))
        except configparser.Error:
            return
        if cp.has_section("metadata"):
            for key, field in (("name", "names"), ("version", "versions"), ("description", "descriptions"),
                               ("license", "licenses"), ("author", "authors"), ("url", "homepages")):
                cand(field, cp.get("metadata", key, fallback=None), f"[metadata] {key}")
        if cp.has_section("options"):
            dep_block([x for x in cp.get("options", "install_requires", fallback="").splitlines() if x.strip()],
                      "runtime", "pypi")
            if cp.get("options", "python_requires", fallback=None):
                runtime.append(ev(f"Python {cp.get('options', 'python_requires')}", f"{r} python_requires"))
        if cp.has_section("options.entry_points"):
            for line in cp.get("options.entry_points", "console_scripts", fallback="").splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    entries.append({"kind": "cli", "name": k.strip(), "target": v.strip(), "source": r})
    elif name == "setup.py":
        t = read_text(p)
        for key, field in (("name", "names"), ("version", "versions"), ("description", "descriptions"),
                           ("license", "licenses"), ("author", "authors")):
            m = re.search(rf"\b{key}\s*=\s*['\"]([^'\"]+)['\"]", t)
            if m:
                cand(field, m.group(1), f"{key}=")
        m = re.search(r"python_requires\s*=\s*['\"]([^'\"]+)", t)
        if m:
            runtime.append(ev(f"Python {m.group(1)}", f"{r} python_requires"))
    elif name == "requirements.txt" or re.match(r"requirements[-_.\w]*\.txt$", name):
        scope = "dev" if re.search(r"dev|test|lint|doc", name) else "runtime"
        dep_block([ln for ln in read_text(p).splitlines() if ln.strip() and not ln.lstrip().startswith(("#", "-"))],
                  scope, "pypi")
    elif name == "Pipfile":
        d = load_toml(p)
        dep_block(d.get("packages"), "runtime", "pypi")
        dep_block(d.get("dev-packages"), "dev", "pypi")
        tooling["package_managers"].append(ev("pipenv", r))
    elif name == "Cargo.toml":
        d = load_toml(p)
        pkg = d.get("package", {}) if isinstance(d.get("package"), dict) else {}
        cand("names", pkg.get("name"), "[package] name")
        v = pkg.get("version")
        cand("versions", v if isinstance(v, str) else None, "[package] version")
        cand("descriptions", pkg.get("description"), "[package] description")
        cand("licenses", pkg.get("license"), "[package] license")
        cand("repositories", clean_url(pkg.get("repository")) if isinstance(pkg.get("repository"), str) else None,
             "[package] repository")
        for a in pkg.get("authors", []) or []:
            cand("authors", a if isinstance(a, str) else None, "[package] authors")
        if isinstance(pkg.get("edition"), str):
            runtime.append(ev(f"Rust edition {pkg['edition']}", f"{r} edition"))
        if isinstance(pkg.get("rust-version"), str):
            runtime.append(ev(f"Rust {pkg['rust-version']}+", f"{r} rust-version"))
        dep_block(d.get("dependencies"), "runtime", "crates")
        dep_block(d.get("dev-dependencies"), "dev", "crates")
        dep_block(d.get("build-dependencies"), "build", "crates")
        ws = d.get("workspace", {})
        if isinstance(ws, dict) and ws.get("members"):
            tooling["build_systems"].append(ev(f"Cargo workspace ({len(ws['members'])} members)", r))
            ws_pkg = ws.get("package", {}) if isinstance(ws.get("package"), dict) else {}
            cand("versions", ws_pkg.get("version"), "[workspace.package] version")
            dep_block(ws.get("dependencies"), "workspace", "crates")
        for b in d.get("bin", []) or []:
            if isinstance(b, dict):
                entries.append({"kind": "cli", "name": b.get("name"), "target": b.get("path"), "source": r})
    elif name == "go.mod":
        t = read_text(p)
        m = re.search(r"^module\s+(\S+)", t, re.M)
        if m:
            cand("names", m.group(1).rsplit("/", 1)[-1], "module")
            cand("repositories", "https://" + m.group(1) if "." in m.group(1).split("/")[0] else None, "module")
        m = re.search(r"^go\s+(\S+)", t, re.M)
        if m:
            runtime.append(ev(f"Go {m.group(1)}", f"{r} go"))
        for mm in re.finditer(r"^\s*([\w.\-/]+\.[\w.\-/]+)\s+(v[\w.\-+]+)(\s*//\s*indirect)?", t, re.M):
            deps.append({"ecosystem": "go", "manifest": r, "scope": "indirect" if mm.group(3) else "runtime",
                         "name": mm.group(1), "spec": mm.group(2)})
    elif p.suffix in (".csproj", ".vbproj", ".fsproj", ".vcxproj") or name == "Directory.Build.props":
        parse_msbuild(root, p, meta, cand)
    elif p.suffix in (".sln", ".slnx"):
        t = read_text(p)
        n = len(re.findall(r'^Project\(|<Project Path=', t, re.M))
        tooling["build_systems"].append(ev(f"Visual Studio solution ({n} projects)", r))
    elif name == "global.json":
        d = load_json_loose(p)
        v = (d.get("sdk") or {}).get("version") if isinstance(d, dict) else None
        if v:
            runtime.append(ev(f".NET SDK {v}", f"{r} sdk.version"))
    elif p.suffix == ".psd1":
        t = read_text(p)
        if "ModuleVersion" not in t:
            return
        g = lambda k: (re.search(rf"^\s*{k}\s*=\s*['\"]([^'\"]+)['\"]", t, re.M | re.I) or [None, None])[1]  # noqa
        cand("names", p.stem, "module manifest file name")
        cand("versions", g("ModuleVersion"), "ModuleVersion")
        cand("descriptions", g("Description"), "Description")
        cand("authors", g("Author"), "Author")
        if g("PowerShellVersion"):
            runtime.append(ev(f"PowerShell {g('PowerShellVersion')}+", f"{r} PowerShellVersion"))
        if g("RootModule") or g("ModuleToProcess"):
            entries.append({"kind": "module root", "name": p.stem, "target": g("RootModule") or g("ModuleToProcess"),
                            "source": r})
        if g("ProjectUri"):
            cand("repositories", clean_url(g("ProjectUri")), "PSData.ProjectUri")
        if g("LicenseUri"):
            cand("licenses", g("LicenseUri"), "PSData.LicenseUri")
        m = re.search(r"FunctionsToExport\s*=\s*@?\(?([^)\n]*(?:\n[^)=]*)*)\)?", t)
        if m:
            funcs = re.findall(r"['\"]([\w\-]+)['\"]", m.group(1))
            if funcs:
                meta["exports"].append({"source": f"{r} FunctionsToExport", "names": funcs})
        for mm in re.finditer(r"ModuleName\s*=\s*['\"]([^'\"]+)['\"]", t):
            deps.append({"ecosystem": "psgallery", "manifest": r, "scope": "runtime", "name": mm.group(1),
                         "spec": None})
    elif name == "composer.json":
        d = load_json_loose(p)
        cand("names", d.get("name"), "name")
        cand("versions", d.get("version"), "version")
        cand("descriptions", d.get("description"), "description")
        lic = d.get("license")
        cand("licenses", lic if isinstance(lic, str) else ", ".join(lic) if isinstance(lic, list) else None,
             "license")
        req = d.get("require") or {}
        if req.get("php"):
            runtime.append(ev(f"PHP {req['php']}", f"{r} require.php"))
        dep_block({k: v for k, v in req.items() if k != "php"}, "runtime", "packagist")
        dep_block(d.get("require-dev"), "dev", "packagist")
    elif p.suffix == ".gemspec":
        t = read_text(p)
        for key, field in (("name", "names"), ("version", "versions"), ("summary", "descriptions"),
                           ("license", "licenses"), ("homepage", "homepages")):
            m = re.search(rf"\.{key}\s*=\s*['\"]([^'\"]+)['\"]", t)
            if m:
                cand(field, m.group(1), key)
        for mm in re.finditer(r"add_(development_|runtime_)?dependency\s*\(?\s*['\"]([^'\"]+)['\"](?:,\s*['\"]([^'\"]+))?",
                              t):
            deps.append({"ecosystem": "rubygems", "manifest": r, "scope": "dev" if mm.group(1) == "development_"
                         else "runtime", "name": mm.group(2), "spec": mm.group(3)})
    elif name == "Gemfile":
        for mm in re.finditer(r"^\s*gem\s+['\"]([^'\"]+)['\"](?:,\s*['\"]([^'\"]+))?", read_text(p), re.M):
            deps.append({"ecosystem": "rubygems", "manifest": r, "scope": "runtime", "name": mm.group(1),
                         "spec": mm.group(2)})
        m = re.search(r"^\s*ruby\s+['\"]([^'\"]+)", read_text(p), re.M)
        if m:
            runtime.append(ev(f"Ruby {m.group(1)}", f"{r} ruby"))
    elif name == "pom.xml":
        parse_pom(p, r, meta, cand)
    elif name in ("build.gradle", "build.gradle.kts"):
        t = read_text(p)
        m = re.search(r"^\s*version\s*=?\s*['\"]([^'\"]+)", t, re.M)
        if m:
            cand("versions", m.group(1), "version")
        for mm in re.finditer(r"^\s*(implementation|api|compileOnly|runtimeOnly|testImplementation|kapt|ksp)"
                              r"\s*\(?\s*['\"]([^'\"]+)['\"]", t, re.M):
            parts = mm.group(2).split(":")
            deps.append({"ecosystem": "maven", "manifest": r, "scope": "dev" if "test" in mm.group(1).lower()
                         else "runtime", "name": ":".join(parts[:2]), "spec": parts[2] if len(parts) > 2 else None})
        m = re.search(r"(?:jvmTarget|sourceCompatibility|languageVersion\.set\(JavaLanguageVersion\.of\()"
                      r"\s*=?\s*['\"]?(?:JavaVersion\.VERSION_)?([\d_.]+)", t)
        if m:
            runtime.append(ev(f"JVM target {m.group(1).replace('_', '.')}", r))
        tooling["build_systems"].append(ev("Gradle", r))
    elif name in ("settings.gradle", "settings.gradle.kts"):
        m = re.search(r"rootProject\.name\s*=\s*['\"]([^'\"]+)", read_text(p))
        if m:
            cand("names", m.group(1), "rootProject.name")
    elif name == "pubspec.yaml":
        t = read_text(p)
        for key, field in (("name", "names"), ("version", "versions"), ("description", "descriptions"),
                           ("homepage", "homepages"), ("repository", "repositories")):
            m = re.search(rf"^{key}:\s*['\"]?([^'\"\n]+)", t, re.M)
            if m:
                cand(field, m.group(1).strip(), key)
        m = re.search(r"^\s*sdk:\s*['\"]?([^'\"\n]+)", t, re.M)
        if m:
            runtime.append(ev(f"Dart SDK {m.group(1).strip()}", f"{r} environment.sdk"))
        block = re.search(r"^dependencies:\s*\n((?:[ \t]+.*\n?)*)", t, re.M)
        if block:
            for mm in re.finditer(r"^[ \t]{2}([\w_]+):\s*([^\n]*)", block.group(1), re.M):
                deps.append({"ecosystem": "pub", "manifest": r, "scope": "runtime", "name": mm.group(1),
                             "spec": mm.group(2).strip() or None})
    elif name == "mix.exs":
        t = read_text(p)
        m = re.search(r"app:\s*:(\w+)", t)
        if m:
            cand("names", m.group(1), "app")
        m = re.search(r"version:\s*\"([^\"]+)\"", t)
        if m:
            cand("versions", m.group(1), "version")
        m = re.search(r"elixir:\s*\"([^\"]+)\"", t)
        if m:
            runtime.append(ev(f"Elixir {m.group(1)}", r))
    elif name == "CMakeLists.txt" and top:
        t = read_text(p)
        m = re.search(r"project\s*\(\s*([\w\-]+)(?:[^)]*?\bVERSION\s+([\d.]+))?", t, re.I | re.S)
        if m:
            cand("names", m.group(1), "project()")
            cand("versions", m.group(2), "project(VERSION)")
        m = re.search(r"CMAKE_CXX_STANDARD\s+(\d+)", t)
        if m:
            runtime.append(ev(f"C++{m.group(1)}", f"{r} CMAKE_CXX_STANDARD"))
        tooling["build_systems"].append(ev("CMake", r))
    elif name in ("deno.json", "deno.jsonc", "jsr.json"):
        d = load_json_loose(p)
        cand("names", d.get("name"), "name")
        cand("versions", d.get("version"), "version")
    elif name == "manifest.json":
        d = load_json_loose(p)
        if isinstance(d, dict) and d.get("manifest_version"):
            cand("display_names", d.get("name") if not str(d.get("name", "")).startswith("__MSG_") else None,
                 "name (browser extension)")
            cand("versions", d.get("version"), "version (browser extension)")
            cand("descriptions", d.get("description"), "description")
            runtime.append(ev(f"WebExtension Manifest V{d['manifest_version']}", r))
            bg = d.get("background") or {}
            for key in ("service_worker", "scripts", "page"):
                if bg.get(key):
                    entries.append({"kind": "extension background", "name": key, "target": bg[key], "source": r})
            for cs in d.get("content_scripts") or []:
                entries.append({"kind": "extension content script", "name": ",".join(cs.get("matches", [])[:3]),
                                "target": cs.get("js"), "source": r})
            if (d.get("action") or d.get("browser_action") or {}).get("default_popup"):
                entries.append({"kind": "extension popup", "name": "popup",
                                "target": (d.get("action") or d.get("browser_action"))["default_popup"],
                                "source": r})
        elif isinstance(d, dict) and d.get("start_url"):
            cand("display_names", d.get("name"), "name (web app manifest)")
    elif name == "SKILL.md":
        fm = re.match(r"\A---\s*\n(.*?)\n---", read_text(p), re.S)
        if fm:
            m = re.search(r"^name:\s*(.+)$", fm.group(1), re.M)
            if m:
                cand("names", m.group(1).strip().strip("'\""), "frontmatter name (agent skill)")
            m = re.search(r"^description:\s*(.+)$", fm.group(1), re.M)
            if m:
                cand("descriptions", m.group(1).strip().strip("'\""), "frontmatter description")
            m = re.search(r"^version:\s*(.+)$", fm.group(1), re.M)
            if m:
                cand("versions", m.group(1).strip().strip("'\""), "frontmatter version")
    elif name in ("plugin.json", "marketplace.json") and ".claude-plugin" in r:
        d = load_json_loose(p)
        cand("names", d.get("name"), "name (Claude Code plugin)")
        cand("versions", d.get("version"), "version")
        cand("descriptions", d.get("description"), "description")
    elif name == "DESCRIPTION":
        t = read_text(p)
        for key, field in (("Package", "names"), ("Version", "versions"), ("Title", "descriptions"),
                           ("License", "licenses")):
            m = re.search(rf"^{key}:\s*(.+)$", t, re.M)
            if m:
                cand(field, m.group(1).strip(), key)
    elif name == "Package.swift":
        m = re.search(r"name:\s*\"([^\"]+)\"", read_text(p))
        if m:
            cand("names", m.group(1), "Package(name:)")
        m = re.search(r"swift-tools-version:\s*([\d.]+)", read_text(p))
        if m:
            runtime.append(ev(f"Swift tools {m.group(1)}", r))
    elif name == "Project.toml":
        d = load_toml(p)
        cand("names", d.get("name"), "name")
        cand("versions", d.get("version"), "version")
    elif name == "tauri.conf.json":
        d = load_json_loose(p)
        cand("display_names", d.get("productName") or (d.get("package") or {}).get("productName"), "productName")
        cand("versions", d.get("version") or (d.get("package") or {}).get("version"), "version")
    elif p.suffix == ".nimble":
        m = re.search(r'^version\s*=\s*"([^"]+)"', read_text(p), re.M)
        if m:
            cand("versions", m.group(1), "version")
            cand("names", p.stem, "file name")


def parse_msbuild(root: Path, p: Path, meta: dict, cand) -> None:
    r = rel(root, p)
    try:
        tree = ET.fromstring(read_text(p).encode("utf-8"))
    except ET.ParseError:
        return

    def texts(tag: str) -> list[str]:
        return [e.text.strip() for e in tree.iter() if e.tag.split("}")[-1] == tag and e.text and e.text.strip()]

    sdk = tree.get("Sdk")
    for tag, field in (("AssemblyName", "names"), ("PackageId", "names"), ("Product", "display_names"),
                       ("Version", "versions"), ("VersionPrefix", "versions"), ("Description", "descriptions"),
                       ("Authors", "authors"), ("PackageLicenseExpression", "licenses"),
                       ("RepositoryUrl", "repositories"), ("PackageProjectUrl", "homepages")):
        for v in texts(tag):
            if "$(" not in v:
                cand(field, v, f"<{tag}>")
    if p.suffix in (".csproj", ".vbproj", ".fsproj") and not texts("AssemblyName"):
        cand("names", p.stem, "project file name")
    tfms = texts("TargetFramework") + [t for v in texts("TargetFrameworks") for t in v.split(";")]
    if tfms:
        meta["runtime"].append(ev(", ".join(dict.fromkeys(tfms)), f"{r} TargetFramework(s)"))
    if sdk:
        meta["tooling"]["build_systems"].append(ev(f"MSBuild SDK {sdk}", r))
    for flag, label in (("UseWPF", "WPF"), ("UseWindowsForms", "Windows Forms"), ("UseWinUI", "WinUI 3"),
                        ("UseMaui", ".NET MAUI"), ("PublishAot", "Native AOT"), ("Nullable", "nullable context")):
        if any(v.lower() in ("true", "enable") for v in texts(flag)):
            meta["tooling"]["frameworks"].append(ev(label, f"{r} <{flag}>"))
    out = texts("OutputType")
    if out and out[0].lower() in ("exe", "winexe"):
        meta["entry_points"].append({"kind": f".NET {out[0]}", "name": texts("AssemblyName")[0] if
                                     texts("AssemblyName") else p.stem, "target": r, "source": f"{r} <OutputType>"})
    for e in tree.iter():
        tag = e.tag.split("}")[-1]
        if tag in ("PackageReference", "PackageVersion") and e.get("Include"):
            ver = e.get("Version") or next((c.text for c in e if c.tag.split("}")[-1] == "Version"), None)
            meta["dependencies"].append({"ecosystem": "nuget", "manifest": r, "scope": "runtime",
                                         "name": e.get("Include"), "spec": ver})
        elif tag == "ProjectReference" and e.get("Include"):
            meta["dependencies"].append({"ecosystem": "project", "manifest": r, "scope": "project",
                                         "name": e.get("Include").replace("\\", "/"), "spec": None})


def parse_pom(p: Path, r: str, meta: dict, cand) -> None:
    try:
        tree = ET.fromstring(read_text(p).encode("utf-8"))
    except ET.ParseError:
        return
    ns = {"m": tree.tag.split("}")[0].strip("{")} if tree.tag.startswith("{") else {}
    q = (lambda t: f"m:{t}") if ns else (lambda t: t)
    get = lambda t: (tree.findtext(q(t), namespaces=ns) or "").strip() or None  # noqa: E731
    cand("names", get("artifactId"), "artifactId")
    cand("display_names", get("name"), "<name>")
    cand("versions", get("version"), "<version>")
    cand("descriptions", get("description"), "<description>")
    props = tree.find(q("properties"), ns)
    if props is not None:
        for child in props:
            tag = child.tag.split("}")[-1]
            if tag in ("java.version", "maven.compiler.release", "maven.compiler.source", "kotlin.version"):
                meta["runtime"].append(ev(f"{tag} {child.text}", f"{r} <properties>"))
    for dep in tree.iter(("{%s}dependency" % ns["m"]) if ns else "dependency"):
        g = dep.findtext(q("groupId"), namespaces=ns)
        a = dep.findtext(q("artifactId"), namespaces=ns)
        v = dep.findtext(q("version"), namespaces=ns)
        s = dep.findtext(q("scope"), namespaces=ns)
        meta["dependencies"].append({"ecosystem": "maven", "manifest": r, "scope": "dev" if s == "test" else
                                     (s or "runtime"), "name": f"{g}:{a}", "spec": v})
    meta["tooling"]["build_systems"].append(ev("Maven", r))


# ── Detection tables ─────────────────────────────────────────────────────────

LOCKFILES = {"package-lock.json": "npm", "yarn.lock": "yarn", "pnpm-lock.yaml": "pnpm", "bun.lockb": "bun",
             "bun.lock": "bun", "poetry.lock": "poetry", "uv.lock": "uv", "Pipfile.lock": "pipenv",
             "pdm.lock": "pdm", "Cargo.lock": "cargo", "go.sum": "go modules", "composer.lock": "composer",
             "Gemfile.lock": "bundler", "packages.lock.json": "NuGet (locked)", "pubspec.lock": "pub",
             "mix.lock": "hex", "Podfile.lock": "CocoaPods", "flake.lock": "Nix flakes", "gradle.lockfile": "gradle",
             "conan.lock": "conan", "vcpkg.json": "vcpkg", "deno.lock": "deno"}
LINT_FILES = [(r"^\.eslintrc", "ESLint"), (r"^eslint\.config\.", "ESLint"), (r"^biome\.jsonc?$", "Biome"),
              (r"^\.prettierrc", "Prettier"), (r"^prettier\.config\.", "Prettier"), (r"^ruff\.toml$", "Ruff"),
              (r"^\.ruff\.toml$", "Ruff"), (r"^\.flake8$", "flake8"), (r"^mypy\.ini$", "mypy"),
              (r"^pyrightconfig\.json$", "Pyright"), (r"^\.editorconfig$", "EditorConfig"),
              (r"^\.stylelintrc", "Stylelint"), (r"^rustfmt\.toml$", "rustfmt"), (r"^\.rustfmt\.toml$", "rustfmt"),
              (r"^clippy\.toml$", "Clippy"), (r"^\.golangci\.ya?ml$", "golangci-lint"),
              (r"^\.rubocop\.yml$", "RuboCop"), (r"^PSScriptAnalyzerSettings\.psd1$", "PSScriptAnalyzer"),
              (r"^\.clang-format$", "clang-format"), (r"^\.clang-tidy$", "clang-tidy"),
              (r"^tsconfig(\..+)?\.json$", "TypeScript compiler"), (r"^\.markdownlint", "markdownlint"),
              (r"^stylecop\.json$", "StyleCop"), (r"^\.pre-commit-config\.ya?ml$", "pre-commit"),
              (r"^lefthook\.ya?ml$", "Lefthook"), (r"^\.swiftlint\.yml$", "SwiftLint"),
              (r"^detekt\.yml$", "detekt"), (r"^\.luacheckrc$", "luacheck"), (r"^\.stylua\.toml$", "StyLua"),
              (r"^stylua\.toml$", "StyLua"), (r"^\.credo\.exs$", "Credo"), (r"^analysis_options\.yaml$", "Dart analyzer"),
              (r"^\.php-cs-fixer", "PHP-CS-Fixer"), (r"^phpstan\.neon", "PHPStan"), (r"^knip\.json", "Knip")]
CI_FILES = [(r"^\.github/workflows/.+\.ya?ml$", "GitHub Actions"), (r"^\.gitlab-ci\.yml$", "GitLab CI"),
            (r"^azure-pipelines.*\.ya?ml$", "Azure Pipelines"), (r"^Jenkinsfile$", "Jenkins"),
            (r"^\.circleci/config\.ya?ml$", "CircleCI"), (r"^\.travis\.yml$", "Travis CI"),
            (r"^appveyor\.yml$", "AppVeyor"), (r"^bitbucket-pipelines\.yml$", "Bitbucket Pipelines"),
            (r"^\.drone\.yml$", "Drone"), (r"^\.buildkite/", "Buildkite"), (r"^cloudbuild\.ya?ml$", "Cloud Build")]
CONTAINER_FILES = [(r"(^|/)Dockerfile[^/]*$", "Docker"), (r"(^|/)Containerfile$", "Podman/OCI"),
                   (r"(^|/)(docker-)?compose(\.[\w-]+)?\.ya?ml$", "Docker Compose"),
                   (r"(^|/)\.devcontainer/", "Dev Container"), (r"(^|/)Chart\.yaml$", "Helm"),
                   (r"(^|/)(k8s|kubernetes)/", "Kubernetes manifests"), (r"(^|/)Vagrantfile$", "Vagrant"),
                   (r"(^|/)\.?terraform/|\.tf$", "Terraform"), (r"(^|/)fly\.toml$", "Fly.io"),
                   (r"(^|/)vercel\.json$", "Vercel"), (r"(^|/)netlify\.toml$", "Netlify"),
                   (r"(^|/)wrangler\.toml$", "Cloudflare Workers"), (r"(^|/)serverless\.ya?ml$", "Serverless Framework")]
TEST_DEPS = {"pytest": "pytest", "hypothesis": "Hypothesis", "nose2": "nose2", "jest": "Jest", "vitest": "Vitest",
             "mocha": "Mocha", "jasmine": "Jasmine", "ava": "AVA", "@playwright/test": "Playwright",
             "playwright": "Playwright", "cypress": "Cypress", "@testing-library/react": "Testing Library",
             "xunit": "xUnit", "xunit.v3": "xUnit v3", "nunit": "NUnit", "MSTest.TestFramework": "MSTest",
             "MSTest": "MSTest", "MSTest.Sdk": "MSTest", "TUnit": "TUnit", "Microsoft.NET.Test.Sdk": ".NET test SDK",
             "Pester": "Pester", "junit:junit": "JUnit 4", "org.junit.jupiter:junit-jupiter": "JUnit 5",
             "org.testng:testng": "TestNG", "io.kotest:kotest-runner-junit5": "Kotest", "rspec": "RSpec",
             "minitest": "Minitest", "phpunit/phpunit": "PHPUnit", "pestphp/pest": "Pest",
             "flutter_test": "flutter_test", "proptest": "proptest", "criterion": "Criterion",
             "insta": "insta", "rstest": "rstest", "tokio-test": "tokio-test", "busted": "busted",
             "vows": "Vows", "tap": "node-tap", "uvu": "uvu", "bun-types": "bun test"}
FRAMEWORK_DEPS = {
    "react": "React", "react-dom": "React DOM", "next": "Next.js", "vue": "Vue", "nuxt": "Nuxt", "svelte": "Svelte",
    "@sveltejs/kit": "SvelteKit", "@angular/core": "Angular", "solid-js": "Solid", "astro": "Astro",
    "preact": "Preact", "lit": "Lit", "express": "Express", "fastify": "Fastify", "koa": "Koa", "hono": "Hono",
    "@nestjs/core": "NestJS", "electron": "Electron", "@tauri-apps/api": "Tauri", "react-native": "React Native",
    "expo": "Expo", "tailwindcss": "Tailwind CSS", "vite": "Vite", "webpack": "webpack", "esbuild": "esbuild",
    "rollup": "Rollup", "typescript": "TypeScript", "@modelcontextprotocol/sdk": "MCP SDK",
    "zod": "Zod", "prisma": "Prisma", "drizzle-orm": "Drizzle", "graphql": "GraphQL", "socket.io": "Socket.IO",
    "three": "three.js", "d3": "D3", "redux": "Redux", "zustand": "Zustand", "@tanstack/react-query": "TanStack Query",
    "django": "Django", "flask": "Flask", "fastapi": "FastAPI", "starlette": "Starlette", "pydantic": "Pydantic",
    "sqlalchemy": "SQLAlchemy", "celery": "Celery", "pandas": "pandas", "numpy": "NumPy", "torch": "PyTorch",
    "tensorflow": "TensorFlow", "transformers": "Hugging Face Transformers", "langchain": "LangChain",
    "anthropic": "Anthropic SDK", "openai": "OpenAI SDK", "mcp": "MCP SDK", "fastmcp": "FastMCP", "click": "Click",
    "typer": "Typer", "rich": "Rich", "textual": "Textual", "requests": "Requests", "httpx": "HTTPX",
    "aiohttp": "aiohttp", "scrapy": "Scrapy", "playwright ": "Playwright", "selenium": "Selenium",
    "nodriver": "nodriver", "pillow": "Pillow", "opencv-python": "OpenCV", "PyQt5": "PyQt5", "PyQt6": "PyQt6",
    "PySide6": "PySide6", "streamlit": "Streamlit", "gradio": "Gradio",
    "tokio": "Tokio", "axum": "Axum", "actix-web": "Actix Web", "rocket": "Rocket", "serde": "Serde", "clap": "clap",
    "bevy": "Bevy", "tauri": "Tauri", "reqwest": "reqwest", "sqlx": "SQLx", "diesel": "Diesel", "egui": "egui",
    "ratatui": "Ratatui", "mlua": "mlua", "pyo3": "PyO3", "napi": "napi-rs", "wasm-bindgen": "wasm-bindgen",
    "github.com/gin-gonic/gin": "Gin", "github.com/labstack/echo/v4": "Echo", "github.com/gofiber/fiber/v2": "Fiber",
    "github.com/spf13/cobra": "Cobra", "google.golang.org/grpc": "gRPC",
    "org.springframework.boot:spring-boot-starter": "Spring Boot", "io.quarkus:quarkus-core": "Quarkus",
    "rails": "Ruby on Rails", "sinatra": "Sinatra", "laravel/framework": "Laravel", "symfony/symfony": "Symfony",
    "phoenix": "Phoenix", "flutter": "Flutter",
    "Microsoft.AspNetCore.App": "ASP.NET Core", "Microsoft.EntityFrameworkCore": "EF Core",
    "Microsoft.WindowsAppSDK": "Windows App SDK", "CommunityToolkit.Mvvm": "MVVM Toolkit", "Avalonia": "Avalonia",
    "Microsoft.Maui.Controls": ".NET MAUI", "Newtonsoft.Json": "Json.NET", "Serilog": "Serilog",
    "MediatR": "MediatR", "Dapper": "Dapper", "Grpc.AspNetCore": "gRPC", "Microsoft.Extensions.AI": "Microsoft.Extensions.AI",
    "Microsoft.SemanticKernel": "Semantic Kernel", "Spectre.Console": "Spectre.Console",
}


def detect_license_text(text: str) -> str | None:
    t = text[:4000]
    checks = [
        (r"MIT License|Permission is hereby granted, free of charge", "MIT"),
        (r"Apache License[\s\S]{0,200}Version 2\.0", "Apache-2.0"),
        (r"GNU AFFERO GENERAL PUBLIC LICENSE", "AGPL-3.0"),
        (r"GNU LESSER GENERAL PUBLIC LICENSE[\s\S]{0,200}Version 3", "LGPL-3.0"),
        (r"GNU LESSER GENERAL PUBLIC LICENSE", "LGPL-2.1"),
        (r"GNU GENERAL PUBLIC LICENSE[\s\S]{0,200}Version 3", "GPL-3.0"),
        (r"GNU GENERAL PUBLIC LICENSE[\s\S]{0,200}Version 2", "GPL-2.0"),
        (r"Mozilla Public License,? [Vv]ersion 2\.0", "MPL-2.0"),
        (r"Redistribution and use in source and binary forms[\s\S]*Neither the name", "BSD-3-Clause"),
        (r"Redistribution and use in source and binary forms", "BSD-2-Clause"),
        (r"ISC License|Permission to use, copy, modify, and/or distribute", "ISC"),
        (r"This is free and unencumbered software released into the public domain", "Unlicense"),
        (r"Boost Software License", "BSL-1.0"),
        (r"Creative Commons Attribution[- ]ShareAlike 4\.0", "CC-BY-SA-4.0"),
        (r"Creative Commons Attribution 4\.0", "CC-BY-4.0"),
        (r"CC0 1\.0 Universal", "CC0-1.0"),
        (r"Eclipse Public License[\s\S]{0,60}2\.0", "EPL-2.0"),
        (r"The Zero Clause BSD|0BSD", "0BSD"),
        (r"zlib License|This software is provided 'as-is'", "Zlib"),
        (r"Business Source License", "BUSL-1.1"),
        (r"All rights reserved", "Proprietary / all rights reserved"),
    ]
    for rx, spdx in checks:
        if re.search(rx, t, re.I):
            return spdx
    return None


def readme_info(p: Path) -> dict:
    text = read_text(p)
    body = re.sub(r"\A---\s*\n.*?\n---\s*\n", "", text, flags=re.S)
    body = re.sub(r"^(```|~~~).*?^\1[^\n]*$", "", body, flags=re.S | re.M)   # `# comments` in code fences
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    title = None
    m = re.search(r"^#\s+(.+?)\s*#*\s*$", body, re.M) or re.search(r"^(.+)\n=+\s*$", body, re.M)
    if m:
        title = re.sub(r"!\[[^\]]*\]\([^)]*\)|<[^>]+>|\[([^\]]*)\]\([^)]*\)", r"\1", m.group(1)).strip() or None
    if not title:
        m = re.search(r"<h1[^>]*>(.*?)</h1>", body, re.S | re.I)
        if m:
            title = re.sub(r"<[^>]+>", "", m.group(1)).strip() or None
    para = None
    start = m.end() if m else 0
    for block in re.split(r"\n\s*\n", body[start:]):
        b = block.strip()
        if not b or b.startswith(("#", "!", "[!", "<", "|", "```", "---", "***", "- [", "> [!")) or \
                re.fullmatch(r"(\[!\[.*?\]\(.*?\)\]\(.*?\)\s*)+", b):
            continue
        para = re.sub(r"\s+", " ", re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", b))[:600]
        break
    return {"path": p.name, "title": title, "first_paragraph": para, "lines": text.count("\n") + 1}


def changelog_info(p: Path) -> dict:
    text = read_text(p)
    m = re.search(r"^#{1,3}\s*\[?v?(\d+\.\d+(?:\.\d+)?(?:[-+.][\w.]+)?)\]?(?:[^\n]*?(\d{4}-\d{2}-\d{2}))?",
                  text, re.M)
    unreleased = bool(re.search(r"^#{1,3}\s*\[?Unreleased\]?", text, re.M | re.I))
    return {"path": p.name, "latest_version": m.group(1) if m else None, "latest_date": m.group(2) if m else None,
            "has_unreleased_section": unreleased}


# ── Git ──────────────────────────────────────────────────────────────────────

def git_info(root: Path) -> dict:
    top = git_toplevel(root)
    if not top:
        return {"is_repo": False}
    sub = root.resolve().relative_to(top.resolve()).as_posix() if root.resolve() != top.resolve() else ""
    info: dict = {"is_repo": True, "repo_root": str(top), "subpath": sub or None}

    def g(*args, cwd=root) -> str | None:
        out = run_git(list(args), cwd)
        return out.strip() if out is not None else None

    fmt = "%H%x1f%h%x1f%an%x1f%aI%x1f%cI%x1f%s"
    head = g("log", "-1", f"--format={fmt}")
    if head:
        h, sh, an, ad, cd, subj = head.split("\x1f")
        branch = g("rev-parse", "--abbrev-ref", "HEAD")
        info["head"] = {"hash": h, "short": sh, "branch": None if branch == "HEAD" else branch,
                        "detached": branch == "HEAD", "author": an, "author_date": ad, "commit_date": cd,
                        "subject": subj, "describe": g("describe", "--tags", "--always", "--dirty"),
                        "tags_at_head": (g("tag", "--points-at", "HEAD") or "").split()}
    else:
        info["head"] = None                    # repository with no commits yet
    if sub:
        last = g("log", "-1", f"--format={fmt}", "--", ".")
        if last:
            h, sh, an, ad, cd, subj = last.split("\x1f")
            info["path_last_commit"] = {"hash": h, "short": sh, "author": an, "author_date": ad,
                                        "commit_date": cd, "subject": subj, "scope": sub}
    first = g("log", "--reverse", "--format=%h%x1f%aI", "--", ".")
    if first:
        fh, fd = first.splitlines()[0].split("\x1f")
        info["first_commit"] = {"short": fh, "author_date": fd, "scope": sub or "(repository)"}
    info["commit_count"] = {"repository": int(g("rev-list", "--count", "HEAD") or 0) if head else 0}
    if sub:
        info["commit_count"]["path"] = int(g("rev-list", "--count", "HEAD", "--", ".") or 0)
    shortlog = g("shortlog", "-sn", "--no-merges", "HEAD", "--", ".") if head else None
    if shortlog:
        people = [re.sub(r"^\s*\d+\s+", "", ln) for ln in shortlog.splitlines() if ln.strip()]
        counts = [int(ln.split()[0]) for ln in shortlog.splitlines() if ln.strip()]
        info["contributors"] = {"count": len(people), "top": [{"name": n, "commits": c}
                                                              for n, c in zip(people[:5], counts[:5])]}
    remotes = (g("remote") or "").split()
    if remotes:
        name = "origin" if "origin" in remotes else remotes[0]
        info["remote"] = {"name": name, "url": clean_url(g("remote", "get-url", name)), "all": remotes}
    up = g("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    if up:
        ab = g("rev-list", "--left-right", "--count", "@{u}...HEAD")
        behind, ahead = (ab.split() + ["0", "0"])[:2] if ab else ("?", "?")
        info["upstream"] = {"ref": up, "ahead": int(ahead) if ahead.isdigit() else None,
                            "behind": int(behind) if behind.isdigit() else None}
    # Not g(): stripping would eat the leading space of the first " M path" line (XY status codes).
    status = run_git(["status", "--porcelain=v1", "--untracked-files=normal", "--", "."], root) or ""
    lines = [ln for ln in status.splitlines() if ln.strip()]
    info["dirty"] = {"clean": not lines, "staged": sum(1 for ln in lines if ln[0] not in " ?"),
                     "modified": sum(1 for ln in lines if len(ln) > 1 and ln[1] == "M"),
                     "untracked": sum(1 for ln in lines if ln.startswith("??"))}
    info["shallow"] = g("rev-parse", "--is-shallow-repository") == "true"
    tag = g("describe", "--tags", "--abbrev=0") if head else None
    if tag:
        info["latest_tag"] = {"name": tag, "date": g("log", "-1", "--format=%aI", tag),
                              "commits_since": int(g("rev-list", "--count", f"{tag}..HEAD") or 0)}
    subs = g("config", "--file", ".gitmodules", "--get-regexp", "path", cwd=top)
    if subs:
        info["submodules"] = [ln.split(" ", 1)[1] for ln in subs.splitlines() if " " in ln]
    return info


def compare_zip_to_tree(archive: Path) -> dict:
    """For zip-based packages (.skill, .zip, .vsix, .nupkg, .whl, .jar), compare each member with the
    same path next to the archive (with or without the archive's top folder). Exact, content-based."""
    import zipfile
    if archive.stat().st_size > 50_000_000 or not zipfile.is_zipfile(archive):
        return {}
    base = archive.parent
    same = differ = absent = 0
    examples = []
    try:
        with zipfile.ZipFile(archive) as zf:
            for info in zf.infolist():
                if info.is_dir():
                    continue
                parts = info.filename.split("/")
                cands = [base.joinpath(*parts)] + ([base.joinpath(*parts[1:])] if len(parts) > 1 else [])
                target = next((c for c in cands if c.is_file()), None)
                if target is None:
                    absent += 1
                    continue
                packed = zf.read(info).replace(b"\r\n", b"\n")
                if packed == target.read_bytes().replace(b"\r\n", b"\n"):
                    same += 1
                else:
                    differ += 1
                    if len(examples) < 5:
                        examples.append(info.filename)
    except (zipfile.BadZipFile, OSError, RuntimeError):
        return {"zip_compare": "unreadable archive"}
    out = {"zip_members_matching_tree": same, "zip_members_differing": differ,
           "zip_members_not_in_tree": absent}
    if differ:
        out["possibly_stale"] = f"{differ} packaged file(s) differ from the working tree, e.g. {', '.join(examples)}"
    return out


# ── Assembly ─────────────────────────────────────────────────────────────────

def norm_version(v: str) -> str:
    return re.sub(r"^[vV]", "", v.strip())


def pick(cands: list[dict], prefer_root: bool = True) -> dict | None:
    if not cands:
        return None
    ordered = sorted(cands, key=lambda c: (not c.get("root", False))) if prefer_root else cands
    return {"value": ordered[0]["value"], "source": ordered[0]["source"]}


def collect(root: Path) -> dict:
    root = root.resolve()
    meta: dict = {
        "tool": f"{TOOL_NAME}/collect_metadata", "schema": SCHEMA_VERSION, "generated": now_iso(),
        "root": str(root), "directory_name": root.name,
        "identity": {"names": [], "display_names": [], "versions": [], "descriptions": [], "licenses": [],
                     "authors": [], "homepages": [], "repositories": [], "keywords": [], "flags": []},
        "runtime": [], "entry_points": [], "dependencies": [], "scripts": [], "exports": [],
        "tooling": {"package_managers": [], "build_systems": [], "ci": [], "containers": [], "test_frameworks": [],
                    "linters_formatters": [], "frameworks": []},
        "docs": {}, "manifests": [], "subprojects": [], "sensitive_files": [], "artifacts": [],
    }
    files = find_files(root)
    rels = [rel(root, f) for f in files]
    for f, r in zip(files, rels):
        name = f.name
        depth = r.count("/")
        if SENSITIVE.search(r) and not SENSITIVE_OK.search(name):
            meta["sensitive_files"].append(r)
        if name in MANIFEST_NAMES or f.suffix in MANIFEST_EXTS or re.match(r"requirements[-_.\w]*\.txt$", name):
            if name in ("Makefile", "justfile", "Justfile") and depth == 0:
                meta["tooling"]["build_systems"].append(ev({"Makefile": "Make"}.get(name, "just"), r))
            if name == "manifest.json" and depth > 2:
                continue
            meta["manifests"].append(r)
            try:
                parse_manifest(root, f, meta)
            except Exception as exc:  # noqa: BLE001 - one bad manifest must not sink the run
                meta.setdefault("warnings", []).append(f"{r}: {type(exc).__name__}: {exc}")
        if name in LOCKFILES:
            meta["tooling"]["package_managers"].append(ev(LOCKFILES[name], r))
        for rx, label in CI_FILES:
            if re.search(rx, r):
                meta["tooling"]["ci"].append(ev(label, r))
        for rx, label in CONTAINER_FILES:
            if re.search(rx, r):
                meta["tooling"]["containers"].append(ev(label, r))
        for rx, label in LINT_FILES:
            if re.search(rx, name) and depth <= 2:
                meta["tooling"]["linters_formatters"].append(ev(label, r))
    # Version fallbacks: VERSION files, __version__, AssemblyInfo.
    ident = meta["identity"]
    for f, r in zip(files, rels):
        if r.count("/") > 2:
            continue
        if f.name == "VERSION" and f.stat().st_size < 100:
            ident["versions"].append({"value": read_text(f).strip(), "source": r, "root": "/" not in r})
        elif f.name in ("__init__.py", "_version.py", "version.py", "__about__.py"):
            m = re.search(r"^__version__\s*[:=][^\"'\n]*[\"']([^\"']+)[\"']", read_text(f), re.M)
            if m:
                ident["versions"].append({"value": m.group(1), "source": f"{r} __version__", "root": False})
        elif f.name == "AssemblyInfo.cs":
            m = re.search(r"AssemblyVersion\(\"([^\"]+)\"\)", read_text(f))
            if m:
                ident["versions"].append({"value": m.group(1), "source": f"{r} AssemblyVersion", "root": False})
    # Docs.
    docs = meta["docs"]
    for f in sorted((p for p in root.iterdir() if p.is_file()), key=lambda p: p.name.lower()):
        low = f.name.lower()
        if low.startswith("readme") and "readme" not in docs:
            docs["readme"] = readme_info(f)
        elif low.startswith(("changelog", "changes", "history", "releases")) and "changelog" not in docs:
            docs["changelog"] = changelog_info(f)
        elif low.startswith(("license", "licence", "copying")):
            docs.setdefault("license_files", []).append(f.name)
            spdx = detect_license_text(read_text(f)) or f"Custom license (see {f.name})"
            ident["licenses"].append({"value": spdx, "source": f"{f.name} (text match)", "root": True})
        elif low.startswith(("contributing", "security", "code_of_conduct", "support", "governance")):
            docs.setdefault("community", []).append(f.name)
        elif low in ("claude.md", "agents.md", "gemini.md", ".cursorrules", "copilot-instructions.md"):
            docs.setdefault("agent_instructions", []).append(f.name)
    for d in ("docs", "doc", "documentation", "wiki", "site", "website"):
        if (root / d).is_dir():
            docs.setdefault("docs_dirs", []).append(d)
    if (root / ".github" / "copilot-instructions.md").is_file():
        docs.setdefault("agent_instructions", []).append(".github/copilot-instructions.md")
    if docs.get("changelog", {}).get("latest_version"):
        ident["versions"].append({"value": docs["changelog"]["latest_version"],
                                  "source": f"{docs['changelog']['path']} latest heading", "root": False})
    # Git and dates.
    meta["git"] = git_info(root)
    gi = meta["git"]
    if gi.get("latest_tag"):
        ident["versions"].append({"value": gi["latest_tag"]["name"], "source": "git latest tag", "root": False})
    newest = max(((f.stat().st_mtime, r) for f, r in zip(files, rels) if f.is_file()), default=None)
    dates = {}
    scoped = gi.get("path_last_commit") or gi.get("head")
    if scoped:
        dates["last_updated"] = {"value": scoped["commit_date"],
                                 "basis": "last commit touching this directory" if gi.get("path_last_commit")
                                 else "HEAD commit"}
    elif newest:
        dates["last_updated"] = {"value": datetime.fromtimestamp(newest[0], timezone.utc).astimezone()
                                 .isoformat(timespec="seconds"), "basis": f"newest file mtime ({newest[1]})"}
    if newest:
        dates["newest_file_mtime"] = {"value": datetime.fromtimestamp(newest[0], timezone.utc).astimezone()
                                      .isoformat(timespec="seconds"), "path": newest[1]}
    if gi.get("first_commit"):
        dates["created"] = {"value": gi["first_commit"]["author_date"], "basis": "first commit"}
    if gi.get("dirty") and not gi["dirty"]["clean"]:
        dates["uncommitted_changes"] = True
    meta["dates"] = dates
    # Tooling from dependency names.
    dep_names = {d["name"]: d for d in meta["dependencies"]}
    for dn, d in dep_names.items():
        base = dn.split("[")[0]
        if base in TEST_DEPS or dn in TEST_DEPS:
            meta["tooling"]["test_frameworks"].append(ev(TEST_DEPS.get(base) or TEST_DEPS[dn], d["manifest"]))
        if base in FRAMEWORK_DEPS or base.lower() in FRAMEWORK_DEPS:
            label = FRAMEWORK_DEPS.get(base) or FRAMEWORK_DEPS[base.lower()]
            meta["tooling"]["frameworks"].append(ev(f"{label}{' ' + d['spec'] if d.get('spec') else ''}",
                                                    d["manifest"]))
    if any(r.endswith("_test.go") for r in rels):
        meta["tooling"]["test_frameworks"].append(ev("go test", "*_test.go files"))
    if any(re.search(r"\.Tests\.ps1$", r) for r in rels):
        meta["tooling"]["test_frameworks"].append(ev("Pester", "*.Tests.ps1 files"))
    if any(r.startswith(("tests/", "test/")) and r.endswith(".py") for r in rels) and \
            not any(t["value"] == "pytest" for t in meta["tooling"]["test_frameworks"]):
        meta["tooling"]["test_frameworks"].append(ev("Python tests (pytest or unittest)", "tests/ directory"))
    # Entry points discovered from source layout.
    for f, r in zip(files, rels):
        if r.count("/") > 3 or f.stat().st_size > 1_000_000:
            continue
        if f.name == "__main__.py":
            meta["entry_points"].append({"kind": "python -m", "name": f.parent.name, "target": r, "source": r})
        elif f.suffix == ".py" and f.name not in ("setup.py", "conftest.py"):
            t = read_text(f)
            if re.search(r"^if\s+__name__\s*==\s*['\"]__main__['\"]\s*:", t, re.M):
                meta["entry_points"].append({"kind": "python script", "name": f.stem, "target": r, "source": r})
        elif f.name == "main.go" or (f.suffix == ".go" and re.search(r"^package main\b", read_text(f), re.M)
                                     and "func main()" in read_text(f)):
            meta["entry_points"].append({"kind": "go main", "name": f.parent.name, "target": r, "source": r})
        elif r in ("src/main.rs",) or re.match(r"src/bin/[^/]+\.rs$", r):
            meta["entry_points"].append({"kind": "rust binary", "name": f.stem, "target": r, "source": r})
        elif f.name in ("Program.cs", "Program.fs", "App.xaml.cs", "MauiProgram.cs"):
            meta["entry_points"].append({"kind": ".NET host", "name": f.stem, "target": r, "source": r})
        elif f.suffix.lower() == ".ps1" and r.count("/") <= 2 and not re.search(r"\.Tests\.ps1$", f.name, re.I):
            t = read_text(f)
            head = re.sub(r"<#.*?#>", "", t[:20000], flags=re.S)
            head = "\n".join(ln for ln in head.splitlines() if not ln.lstrip().startswith(("#", "[", "using ")))
            if re.match(r"\s*param\s*\(", head, re.I):
                meta["entry_points"].append({"kind": "PowerShell script", "name": f.stem, "target": r, "source": r})
        elif f.suffix in (".sh", ".bash", "") and r.count("/") <= 1 and f.stat().st_size < 500_000 and \
                read_text(f)[:2].startswith("#!") and (r.count("/") == 0 or r.split("/")[0] in ("bin", "scripts")):
            meta["entry_points"].append({"kind": "shell script", "name": f.name, "target": r, "source": r})
        elif f.name == "SKILL.md" and r.count("/") <= 1:
            meta["entry_points"].append({"kind": "agent skill", "name": f.parent.name or root.name, "target": r,
                                         "source": r})
        elif re.match(r"(^|/)(Dockerfile|Containerfile)$", r):
            m = re.search(r"^(ENTRYPOINT|CMD)\s+(.+)$", read_text(f), re.M)
            if m:
                meta["entry_points"].append({"kind": f"container {m.group(1)}", "name": f.name,
                                             "target": m.group(2)[:120], "source": r})
    # Packaged artifacts committed alongside the source (archives, installers, bundles). Staleness is
    # only claimed from an exact content comparison: commit dates flag third-party binaries such as
    # gradle-wrapper.jar whose neighbours simply change more often.
    for f, r in zip(files, rels):
        if not ARTIFACT_RE.search(f.name) or r.count("/") > 3:
            continue
        item = {"path": r, "bytes": f.stat().st_size}
        if gi.get("head"):
            item["committed"] = (run_git(["log", "-1", "--format=%cI", "--", r], root) or "").strip() or None
        item.update(compare_zip_to_tree(f))
        meta["artifacts"].append(item)
    # Subprojects: manifests below the root that declare their own name.
    for r in meta["manifests"]:
        if "/" in r and r.rsplit("/", 1)[-1] in ("package.json", "pyproject.toml", "Cargo.toml", "go.mod",
                                                 "composer.json", "pubspec.yaml") and r.count("/") <= 3:
            n = next((c["value"] for c in ident["names"] if c["source"].startswith(r)), None)
            v = next((c["value"] for c in ident["versions"] if c["source"].startswith(r)), None)
            meta["subprojects"].append({"path": r.rsplit("/", 1)[0], "manifest": r, "name": n, "version": v})
    # Summary picks and conflicts.
    names = ident["names"]
    display = ident["display_names"]
    readme_title = docs.get("readme", {}).get("title")
    remote_name = None
    if gi.get("remote", {}).get("url"):
        remote_name = gi["remote"]["url"].rstrip("/").rsplit("/", 1)[-1]
    # Root manifests speak for the codebase; a workspace member's name or version only as a last resort.
    root_only = lambda cands: [c for c in cands if c.get("root")]  # noqa: E731
    name_pick = pick(root_only(display)) or pick(root_only(names)) or \
        (ev(readme_title, "README title") if readme_title else None) or \
        (ev(remote_name, "git remote") if remote_name else None) or ev(root.name, "directory name")
    versions = ident["versions"]
    root_versions = root_only(versions)
    non_member = [v for v in versions if v.get("root") or not any(v["source"].startswith(s["manifest"])
                                                                  for s in meta["subprojects"])]
    distinct = sorted({norm_version(v["value"]) for v in versions})
    meta["summary"] = {
        "name": name_pick,
        "package_id": pick(root_only(names)) or pick(names),
        "readme_title": readme_title,
        "version": pick(root_versions) or pick(non_member) or pick(versions) or ev(None, "no version declared"),
        "version_conflict": distinct if len(distinct) > 1 else None,
        "description": pick(root_only(ident["descriptions"])) or
        (ev(docs["readme"]["first_paragraph"], "README first paragraph")
         if docs.get("readme", {}).get("first_paragraph") else None) or pick(ident["descriptions"]),
        "license": pick(root_only(ident["licenses"])) or pick(ident["licenses"]),
        "repository": pick(root_only(ident["repositories"])) or
        (ev(gi["remote"]["url"], "git remote") if gi.get("remote", {}).get("url") else None) or
        pick(ident["repositories"]),
        "unreleased_commits_since_tag": gi.get("latest_tag", {}).get("commits_since"),
    }
    # De-duplicate evidence lists.
    runtime_seen: dict = {}
    for it in meta["runtime"]:
        key = json.dumps(it["value"], sort_keys=True)
        if key in runtime_seen:
            runtime_seen[key]["also_in"] = runtime_seen[key].get("also_in", 0) + 1
        else:
            runtime_seen[key] = dict(it)
    meta["runtime"] = list(runtime_seen.values())
    if any(re.match(r"requirements[-_.\w]*\.txt$", r.rsplit("/", 1)[-1]) for r in meta["manifests"]):
        meta["tooling"]["package_managers"].append(ev("pip", "requirements*.txt"))
    for key, items in meta["tooling"].items():
        seen = {}
        for it in items:
            seen.setdefault(it["value"], it)
        meta["tooling"][key] = list(seen.values())
    for fld in ("names", "display_names", "versions", "descriptions", "licenses", "authors", "homepages",
                "repositories"):
        seen = {}
        for it in ident[fld]:
            seen.setdefault((it["value"], it["source"]), it)
        ident[fld] = list(seen.values())
    ident["keywords"] = list(dict.fromkeys(ident["keywords"]))
    return meta


def main(argv: list[str] | None = None) -> int:
    utf8_stdio()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default=".", help="codebase directory (default: .)")
    ap.add_argument("-o", "--output", type=Path, help="write JSON to this file")
    args = ap.parse_args(argv)
    root = Path(args.root)
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 2
    meta = collect(root)
    dump_json(meta, args.output)
    if args.output:
        s = meta["summary"]
        print(f"name: {s['name']['value']} ({s['name']['source']})  version: {s['version']['value']} "
              f"({s['version']['source']})")
        if s["version_conflict"]:
            print(f"version conflict: {', '.join(s['version_conflict'])}")
        print(f"wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
