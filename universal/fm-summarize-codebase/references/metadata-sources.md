# Metadata sources and precedence

`collect_metadata.py` records every candidate value with the file or git command it
came from. This file explains how the scaffold picks among them, when to override,
and where to look by hand for ecosystems the script doesn't parse.

## Contents

- [Official name](#official-name)
- [Version](#version)
- [Last updated and the git snapshot](#last-updated-and-the-git-snapshot)
- [License](#license)
- [Other fields](#other-fields)
- [Git edge cases](#git-edge-cases)
- [Manual lookups](#manual-lookups)

## Official name

The report shows two things: the **official name** (what humans call it) and the
**package identifier** (what tools call it), when they differ.

Precedence for the official name:

1. The README H1, when it is a real title. Skip a title that is a badge, a logo
   caption, or something generic like "Documentation" or "Overview".
2. A root display name: `displayName` (VS Code extensions), `productName` (Tauri,
   Electron), the browser-extension `name`, `<Product>` (.NET), or `<name>` (Maven).
3. The root package name: `package.json`, `pyproject.toml`, `Cargo.toml [package]`,
   the `go.mod` module's last segment, `.csproj` AssemblyName, `.psd1` file name, or
   the `SKILL.md` frontmatter.
4. The git remote repository name.
5. The directory name.

Names from **workspace members** (`crates/*`, `packages/*`) never name the whole
repository. List them as subprojects instead.

## Version

1. The root manifest version.
2. For workspaces: `[workspace.package]` or the version shared by the members.
3. The latest git tag (a leading `v` is ignored for comparison).
4. The latest dated CHANGELOG heading.
5. `__version__`, `VERSION`, or `AssemblyVersion` files.
6. Otherwise: "Not declared".

**Conflicts are findings.** When sources disagree, the report keeps every value with
its source. Add which one the build or publishing actually uses when the code makes
that clear: `pyproject.toml` feeds the wheel, `setup.py` reads `__version__`, or CI
stamps the version from the tag. **Dynamic versions** (`dynamic = ["version"]`,
setuptools-scm, MinVer, GitVersion) come from git tags at build time, so the tag is
authoritative. Say so.

**Release status** compares HEAD to the latest tag: "HEAD is the tagged release" or
"N commits past vX (unreleased)".

## Last updated and the git snapshot

- **Last updated** is the commit date of the last commit that touched the target
  directory. At a repository root that is HEAD. For a subfolder of a monorepo it's the
  path-scoped commit, which can be much older than HEAD.
- **Uncommitted changes** are reported separately (modified, staged, and untracked
  counts), because the working tree can be newer than any commit. The newest file mtime
  is shown as supporting evidence only; mtimes change on checkout and copy.
- **Latest git snapshot** is HEAD's short hash, branch (or "detached HEAD"), subject,
  author, commit date, and `git describe`. With a dirty tree, `describe` ends in
  `-dirty`.
- **Upstream** ahead/behind counts come from the last fetch and may be stale. The
  report doesn't fetch.

## License

- The manifest `license` field (an SPDX expression) is authoritative when present.
- Otherwise the LICENSE file text is matched against common licenses (MIT, Apache-2.0,
  GPL/LGPL/AGPL, BSD-2/3, MPL-2.0, ISC, Unlicense, BSL, CC, EPL, Zlib, BUSL). An
  unmatched license file reads "Custom license (see LICENSE)".
- If the manifest and the file disagree, report both. Per-directory licenses and
  third-party notices (`NOTICE`, `THIRD_PARTY*`) belong in "Other important metadata".
- With no declaration at all, write "Not declared (all rights reserved by default)".

## Other fields

| Field | Sources |
| --- | --- |
| Description | Root manifest `description`, then the README's first paragraph, then member manifests |
| Authors | Manifest `authors`/`author`, `.psd1` Author, gemspec; git top contributors are shown separately |
| Runtime targets | `requires-python`, `engines`, `TargetFramework(s)`, `rust-version`/edition, `go` directive, `PowerShellVersion`, Manifest V2/V3, `environment.sdk`, Java release |
| Entry points | Package `bin`/scripts, `__main__.py`, `if __name__ == "__main__"`, `func main` in `package main`, `src/main.rs` and `src/bin/*`, .NET `OutputType Exe` and `Program.cs`, PowerShell `.ps1` files starting with `param()`, shebang shell scripts at the root or in `bin/`/`scripts/`, Dockerfile `ENTRYPOINT`/`CMD`, extension background/content scripts, `SKILL.md` |
| Packaged artifacts | Committed archives and packages (`.zip`, `.skill`, `.vsix`, `.nupkg`, `.whl`, `.jar`, installers…). Zip-based ones are compared file by file with the working tree next to them, and any difference marks the package possibly stale. Other packages are only listed; check by hand whether they're built from this repo |
| Tooling | Lockfiles → package managers; CI config paths; container and deploy files; lint/format configs; test dependencies |
| Sensitive files | `.env*`, keys, certificates, credential files. Paths only; contents are never read |

## Git edge cases

| Situation | What the report says |
| --- | --- |
| Not a git repository | "Not a git repository". Last updated falls back to the newest file mtime, and says so |
| No commits yet | "Repository has no commits yet" |
| Shallow clone | ⚠ History counts, first commit, and contributors are partial |
| Detached HEAD | The branch shows as "detached HEAD"; the describe output still identifies the commit |
| Target is a subfolder | Both the repository HEAD and the last commit touching the subfolder |
| Submodules | Listed; their contents are only summarized if they're inside the target and checked out |
| Git LFS pointers | Treated as text stubs; mention LFS in "Other important metadata" |

## Manual lookups

Where the script has no parser, read the file yourself and cite it:

| Ecosystem | Where to look |
| --- | --- |
| Bazel / Buck / Pants | `MODULE.bazel`, `WORKSPACE`, `BUILD` files, `pants.toml` |
| Meson / autotools | `meson.build` `project()`, `configure.ac` `AC_INIT` |
| Haskell | `*.cabal` (name, version, synopsis), `package.yaml` |
| OCaml | `dune-project`, `*.opam` |
| Unity / Unreal | `ProjectSettings/ProjectSettings.asset`, `*.uproject` |
| Xcode | `*.xcodeproj/project.pbxproj` (`MARKETING_VERSION`), `Info.plist` |
| Android | `app/build.gradle` (`applicationId`, `versionName`), `AndroidManifest.xml` |
| Helm / Kubernetes | `Chart.yaml` (`name`, `version`, `appVersion`) |
| Terraform modules | `versions.tf` (`required_version`, providers) |
| Obsidian / VS Code / JetBrains plugins | `manifest.json`, `package.json` `engines.vscode`, `plugin.xml` |
