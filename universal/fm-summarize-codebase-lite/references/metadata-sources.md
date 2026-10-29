# Metadata sources and precedence

Where each fact in section 1.1 comes from, how to choose between conflicting sources,
and the command, file, or API call for each.

## Contents

- [Manifests by ecosystem](#manifests-by-ecosystem)
- [Official name](#official-name)
- [Version](#version)
- [Snapshot, dates, and history](#snapshot-dates-and-history)
- [License](#license)
- [Other fields](#other-fields)
- [Git edge cases](#git-edge-cases)

## Manifests by ecosystem

Read every manifest at the root, and note (but don't let them name the whole project)
manifests in workspace members such as `packages/*`, `crates/*`, or `apps/*`.

| Ecosystem | File | Name · version · description · license · dependencies · runtime |
| --- | --- | --- |
| Node / JS / TS | `package.json` | `name`, `displayName` · `version` · `description` · `license` · `dependencies`, `devDependencies`, `peerDependencies` · `engines`; also `bin`, `main`, `scripts`, `workspaces` |
| Python | `pyproject.toml` | `[project]` or `[tool.poetry]` name/version/description/license · `dependencies`, optional/dev groups · `requires-python`; `[project.scripts]` = CLIs; `dynamic = ["version"]` means the version comes from tags |
| Python (older) | `setup.cfg`, `setup.py`, `requirements*.txt`, `Pipfile` | `[metadata]`, `setup(...)` arguments, pinned requirements |
| Rust | `Cargo.toml` | `[package]` (or `[workspace.package]`) · `[dependencies]` · `edition`, `rust-version`; `[workspace] members` |
| Go | `go.mod` | `module` path (last segment = name) · `require` · `go` version |
| .NET | `*.csproj`, `*.fsproj`, `*.vbproj`, `Directory.Build.props`, `*.sln` | `AssemblyName`, `PackageId`, `Product` · `Version`/`VersionPrefix` · `Description` · `PackageLicenseExpression` · `PackageReference` · `TargetFramework(s)`, `OutputType`, `UseWPF`/`UseWinUI` |
| Java / Kotlin | `pom.xml`, `build.gradle(.kts)`, `settings.gradle` | `artifactId`/`name`/`version` · dependencies · Java release; `rootProject.name` |
| PHP | `composer.json` | name/version/description/license · `require` (includes `php`) |
| Ruby | `*.gemspec`, `Gemfile` | `spec.name/version/summary/license` · gems · `ruby` version |
| Dart / Flutter | `pubspec.yaml` | name/version/description · dependencies · `environment.sdk` |
| Elixir | `mix.exs` | `app:`, `version:` · deps · `elixir:` |
| Swift | `Package.swift` | `name:` · dependencies · `swift-tools-version` |
| C / C++ | `CMakeLists.txt`, `vcpkg.json`, `conanfile.*`, `meson.build` | `project(Name VERSION x.y)` · packages · `CMAKE_CXX_STANDARD` |
| PowerShell | `*.psd1` module manifest | file name · `ModuleVersion` · `Description` · `RequiredModules` · `PowerShellVersion`; `RootModule`, `FunctionsToExport` |
| Browser extension | `manifest.json` with `manifest_version` | `name` · `version` · `description` · Manifest V2/V3; background, content scripts, popup = entry points |
| Agent skill / plugin | `SKILL.md` frontmatter, `.claude-plugin/plugin.json` | `name` · `version` · `description` |
| Other | `deno.json`, `Project.toml` (Julia), `DESCRIPTION` (R), `*.nimble`, `build.zig`, `Chart.yaml`, `tauri.conf.json` | name/version fields |

Lockfiles identify the package manager: `package-lock.json` npm, `yarn.lock` yarn,
`pnpm-lock.yaml` pnpm, `bun.lock(b)` bun, `poetry.lock` poetry, `uv.lock` uv,
`Cargo.lock` cargo, `go.sum` Go modules, `composer.lock` composer, `Gemfile.lock`
bundler. Tooling shows in config files: `.github/workflows/` (GitHub Actions),
`.gitlab-ci.yml`, `Dockerfile`, `docker-compose.yml`, `.eslintrc*`, `biome.json`,
`ruff.toml` or `[tool.ruff]`, `.editorconfig`, and test configs.

## Official name

Report the **official name** (what people call it) and, when it differs, the **package
identifier** (what tools call it). Precedence for the official name:

1. The README's first `#` heading, if it's a real title. Skip headings inside code
   blocks, badge-only headings, and generic ones like "Documentation".
2. A root display name: `displayName`, `productName`, the browser-extension `name`,
   `<Product>`, or the Maven `<name>`.
3. The root package name.
4. The repository name (hosting API or git remote).
5. The folder name.

Names from workspace members never name the whole repository.

## Version

Precedence: the root manifest version, then `[workspace.package]`, then the latest git
tag (ignore a leading `v`), then the latest dated CHANGELOG heading, then `__version__`,
`VERSION`, or `AssemblyVersion`, and otherwise "Not declared".

**Conflicts are findings.** List every source that disagrees, with its value. Add which
one the build uses when the code makes that clear. **Release status** compares HEAD to
the latest tag: "HEAD is the tagged release" or "N commits past vX (unreleased)".

## Snapshot, dates, and history

| Fact | Shell (git) | No shell, local `.git` files | GitHub REST API |
| --- | --- | --- | --- |
| Current commit, branch | `git log -1 --format="%H %h %an %cI %s"`, `git rev-parse --abbrev-ref HEAD` | `.git/HEAD` names the branch (`ref: refs/heads/main`); the last line of `.git/logs/HEAD` has the new SHA, author name, Unix time, time-zone offset, and message | `GET /repos/{o}/{r}` → `default_branch`; `GET /repos/{o}/{r}/commits?sha={branch}&per_page=1` → `sha`, `commit.author.name`, `commit.committer.date`, `commit.message` |
| Describe / tags | `git describe --tags --always --dirty`, `git tag --points-at HEAD` | `.git/refs/tags/*`, `.git/packed-refs` | `GET /repos/{o}/{r}/tags`, `GET /repos/{o}/{r}/releases/latest` |
| Commits since the last tag | `git rev-list --count <tag>..HEAD` | Not available | `GET /repos/{o}/{r}/compare/{tag}...{branch}` → `ahead_by` |
| Last updated | Last commit touching the folder: `git log -1 --format=%cI -- .` | Last line of `.git/logs/HEAD` (only when the target is the repository root) | Latest commit date; for a subfolder, `commits?path={folder}&per_page=1` |
| First commit | `git log --reverse --format=%aI -- . \| head -1` | Not available | The last page of `commits?per_page=1` (see page probing below) |
| Commit count | `git rev-list --count HEAD -- .` | Not available | With `per_page=1`, the number of the last page, from the `Link` header's `rel="last"` or by page probing |
| Contributors | `git shortlog -sn --no-merges HEAD -- .` | Not available | `GET /repos/{o}/{r}/contributors?per_page=100&anon=1`: count the entries (fetch further pages while a page is full); the top names come first |
| Uncommitted changes | `git status --porcelain` (count modified, staged, untracked) | Not available | Not applicable |
| Repository URL | `git remote get-url origin` | `.git/config` `[remote "origin"] url` | `html_url` |
| Description, topics, homepage, license, archived | Manifest and README | Manifest and README | `GET /repos/{o}/{r}` → `description`, `topics`, `homepage`, `license.spdx_id`, `archived` |

**Page probing** (when your fetch tool doesn't show response headers): request
`commits?sha={branch}&per_page=1&page=N`. A page with one commit means there are at
least N commits; an empty list means fewer. Double N (1, 2, 4, …, 256, 512…) until a
page comes back empty, then halve the gap between the last full page and the first
empty one until they're adjacent. The last full page number is the commit count, and
that page holds the first commit. That's about 2 × log₂(count) requests, around 20 for
a thousand commits.

**Reading Unix timestamps by hand** (`.git/logs/HEAD` stores seconds since
1970-01-01 UTC). Midnight UTC on 1 January of each year:

| Year | Seconds | | Year | Seconds |
| --- | --- | --- | --- | --- |
| 2023 | 1,672,531,200 | | 2027 | 1,798,761,600 |
| 2024 | 1,704,067,200 | | 2028 | 1,830,297,600 |
| 2025 | 1,735,689,600 | | 2029 | 1,861,920,000 |
| 2026 | 1,767,225,600 | | 2030 | 1,893,456,000 |

Subtract the year's start, and divide by 86,400 to get whole days (the remainder is
the time of day in seconds). Day 0 is 1 January. Months start on day 0 (Jan), 31
(Feb), 59 (Mar), 90 (Apr), 120 (May), 151 (Jun), 181 (Jul), 212 (Aug), 243 (Sep), 273
(Oct), 304 (Nov), and 334 (Dec); add 1 from March on in leap years (2024, 2028). Then
apply the offset that follows the timestamp (`-0500` means subtract 5 hours). Check
your result against any date you can see elsewhere, such as a CHANGELOG entry or the
commit message. If a code tool is available, use it instead.

Rules:

- **`updated_at` and `pushed_at` are not "last updated".** The repository API's
  `updated_at` changes with stars and settings, and `pushed_at` includes other
  branches. Use the latest commit's date on the summarized ref.
- **Strip credentials** from URLs (`https://user:token@host/...` becomes
  `https://host/...`). Report contributor **names**, never email addresses.
- **Last updated** is the last *commit* that touched the target, not a file's
  modification time, which changes on checkout. Report uncommitted changes separately.
  If you have no git access at all, say "Not available", or give the newest file date
  labelled as a file date.
- A dirty working tree means the summary describes uncommitted code. Say so in the
  snapshot row, and say what kind of changes they are if you can tell (line endings
  only, or real edits).
- For GitLab the equivalents are `/projects/{id}`, `/repository/commits`,
  `/repository/tags`, and `/languages`. For Bitbucket, `/repositories/{ws}/{repo}` and
  `/commits`.

## License

- The manifest `license` field or the API `license.spdx_id` is authoritative when
  present.
- Otherwise read the LICENSE file. "Permission is hereby granted, free of charge" is
  MIT. "Apache License … Version 2.0" is Apache-2.0. "GNU GENERAL PUBLIC LICENSE Version
  3" is GPL-3.0 (Version 2 is GPL-2.0; LESSER is LGPL; AFFERO is AGPL-3.0).
  "Redistribution and use in source and binary forms" is BSD-2-Clause, or
  BSD-3-Clause if it adds "Neither the name". "Mozilla Public License Version 2.0" is
  MPL-2.0. "Permission to use, copy, modify, and/or distribute" is ISC. "This is free
  and unencumbered software" is the Unlicense. Anything else is "Custom license (see
  LICENSE)".
- If the manifest and the file disagree, report both. With no declaration at all,
  write "Not declared".

## Other fields

| Field | Sources |
| --- | --- |
| Description | Root manifest, then the README's first paragraph, then the API description |
| Runtime targets | `requires-python`, `engines`, `TargetFramework`, `rust-version`, the `go` directive, `PowerShellVersion`, Manifest V2/V3, `environment.sdk` |
| Entry points | Package `bin`/scripts, `__main__.py`, `if __name__ == "__main__"`, `func main` in `package main`, `src/main.rs`, `src/bin/*`, `Program.cs`, PowerShell `.ps1` files beginning with `param(`, shebang scripts in the root, `bin/`, or `scripts/`, Dockerfile `ENTRYPOINT`/`CMD`, extension background scripts, `SKILL.md` |
| Packaged artifacts | Committed archives (`.zip`, `.skill`, `.vsix`, `.nupkg`, `.whl`, `.jar`, installers). If one packages this repository's own files: when you can read its members (an unzip or archive tool), compare several with the tree, and any content difference means it's stale. When you can only see member *names* (for example by searching the archive's file list), report the names present in one place and missing from the other as differences, noting they may be intentional exclusions. Don't call the package stale on names alone |
| Secret-bearing files | `.env*`, `*.pem`, `*.key`, `id_rsa*`, `*.pfx`, `credentials.json`, `secrets.*`. Name the paths; never open them |
| Documentation | README (length), CHANGELOG (latest entry), CONTRIBUTING, SECURITY, `docs/`, agent files (`CLAUDE.md`, `AGENTS.md`) |

## Git edge cases

| Situation | What the report says |
| --- | --- |
| No git and no hosting API | "Not available (no version control access)" for every git row |
| No commits yet | "Repository has no commits yet" |
| Shallow clone (`.git/shallow` exists) | ⚠ History counts are partial |
| Detached HEAD (`.git/HEAD` holds a SHA) | "detached HEAD at {sha}" |
| Target is a subfolder of a repository | Both the repository HEAD and the last commit touching the subfolder. Without a shell or API, the subfolder's last commit is "Not available (needs `git log` on the path)"; give the repository HEAD, labelled as the repository's, not the folder's |
| Only `.git` files, with packed objects | Commit details beyond `.git/logs/HEAD` (the reflog) can't be read: the objects are compressed. Use the reflog lines, and mark the rest "Not available" |
| Monorepo with workspace members | The members, with their names and versions, in 1.1 |
