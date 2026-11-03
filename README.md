<!-- markdownlint-disable MD033 MD041 -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".assets/agent-skills-header/header-2-dark.svg">
    <img alt="Futuremotion Agent Skills" src=".assets/agent-skills-header/header-2.svg" width="640">
  </picture>
</p>

<p align="center">
  Production-grade <a href="https://agentskills.io">Agent Skills</a> by <strong>Futuremotion Studio</strong>:
  deeply researched, source-verified playbooks that teach coding agents how to do specialist work
  in design tooling, Figma, PowerShell, documentation, and agent ecosystems.
</p>

<p align="center">
  <a href="#install"><img alt="Install with npx skills" src="https://img.shields.io/badge/install-npx%20skills%20add-111418?style=for-the-badge&labelColor=111418&color=5e6366"></a>
  <img alt="27 skills" src="https://img.shields.io/badge/skills-27-111418?style=for-the-badge&labelColor=111418&color=5e6366">
  <img alt="Universal and vendor-specific" src="https://img.shields.io/badge/scope-universal%20%2B%20vendor--specific-111418?style=for-the-badge&labelColor=111418&color=5e6366">
  <a href="https://agentskills.io"><img alt="Agent Skills specification" src="https://img.shields.io/badge/spec-agentskills.io-111418?style=for-the-badge&labelColor=111418&color=5e6366"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-111418?style=for-the-badge&labelColor=111418&color=5e6366"></a>
</p>

<br>

## What this is

Every folder here is a skill: a `SKILL.md` with a precise trigger description, plus the references,
templates, and scripts the agent needs to finish the job without guessing. Skills are written the
way we want an expert colleague to brief us: the rules, the reasons behind them, the sources they
came from, and the things that are still unverified, labelled as such.

- **Research first.** Each skill is built from primary sources: vendor documentation, first-party
  code, live probes, and our own production use. Contradictions between sources are recorded, not
  papered over.
- **Progressive disclosure.** `SKILL.md` stays short and routes to `references/` for depth,
  `templates/` for starters, and `scripts/` for validation. Agents load only what the task needs.
- **Universal by default.** Skills follow the open Agent Skills specification and work in any
  agent that reads `SKILL.md`. The few that depend on one vendor's runtime live under
  [`specifics/`](specifics/).

## Install

Skills install with the [`skills`](https://github.com/vercel-labs/skills) CLI (Node.js 22.20 or
later). Run it from a project to install into that project, or add `-g` for your user-level skills
folder. The CLI detects your agents and asks which skills to install.

```bash
# Browse and pick skills interactively, install globally for Claude Code
npx skills add futuremotiondev/agent-skills -g -a claude-code

# Install one skill into the current project for Codex
npx skills add futuremotiondev/agent-skills --skill fm-figma-shader-creation -a codex

# Install everything, for every detected agent, without prompts
npx skills add futuremotiondev/agent-skills --all

# Try a skill once without installing it
npx skills use futuremotiondev/agent-skills@fm-markdown-formatting-guidelines --agent claude-code
```

Common `--agent` ids: `claude-code`, `codex`, `cursor`, `gemini-cli`, `antigravity`,
`github-copilot`, `grok`, `opencode`, `windsurf`. The full list is in the CLI's
[supported agents](https://github.com/vercel-labs/skills/blob/main/docs/agents.md) page.
Installed skills update with `npx skills update` and are listed with `npx skills list`.

> The repository ships a [`skills.sh.json`](skills.sh.json) that tells the CLI which folders hold
> skills, so the topic layout below is discovered without any extra flags.

### Vendor-specific skills

The skills under [`specifics/`](specifics/) depend on one vendor's runtime and are deliberately
left out of the CLI's discovery paths: the CLI cannot restrict a skill to one agent, so a bulk
install would copy Claude-only skills into Gemini's folder and so on. Install them one of two ways:

- **By hand.** Copy the skill folder into the agent's skills directory, project-level or global:
  Claude Code `.claude/skills/` or `~/.claude/skills/`; Codex `.agents/skills/` or `~/.codex/skills/`;
  Gemini CLI `.agents/skills/` or `~/.gemini/skills/`; Antigravity `.agents/skills/` or
  `~/.gemini/antigravity/skills/`; GitHub Copilot `.agents/skills/` or `~/.copilot/skills/`; Grok Build
  `.grok/skills/` or `~/.grok/skills/`. Microsoft 365 Copilot has no skills folder; its skills are
  reference material for Copilot Studio and the Agents Toolkit.
- **Through the vendor's own channel** where one exists. A Claude Code plugin marketplace for the
  `specifics/claude/` skills is planned, with Codex's plugin system to follow.


## Repository layout

```text
.
├── coding/          Git, Markdown, PowerShell, and codebase-analysis skills
├── design/          Design-tool automation, prompt generation, product design
├── den4b-renamer/   Presets for the ReNamer batch-renaming tool
├── figma/           Figma shaders, Figma skill research (more below)
├── skill-meta/      Finding and ranking skills across every agent ecosystem
├── specifics/       Skills that only work with one vendor's agent
│   ├── claude/          Claude Code
│   ├── chatgpt-codex/   OpenAI Codex
│   ├── gemini/          Gemini CLI and Antigravity
│   ├── github-copilot/  GitHub Copilot
│   ├── grok/            Grok Build
│   └── ms365-copilot/   Microsoft 365 Copilot
├── .assets/         Logos and header artwork used by this README
└── skills.sh.json   Discovery paths for the skills CLI
```

| Where | What goes there | Scope |
| --- | --- | --- |
| A topic folder at the root (`coding/`, `design/`, `figma/`, ...) | Skills that rely only on the Agent Skills specification and tools any agent has (shell, file access, MCP) | Universal |
| `specifics/<vendor>/` | Skills that depend on one vendor's runtime, config format, or ecosystem (for example Claude Code hooks and memory, or Codex plugin marketplaces); not in the CLI's discovery paths, see Vendor-specific skills above | That vendor only |
| `<skill>/references/` | Long-form reference material the skill loads on demand | |
| `<skill>/templates/` | Starter files the skill copies and adapts | |
| `<skill>/scripts/` | Validators and helpers, invoked through their interpreter (`node`, `python`, `pwsh`) | |

Every skill folder is named with the `fm-` prefix and matches its frontmatter `name`.

## Skill inventory

### Coding

| Skill | What it does | Scope |
| --- | --- | --- |
| [`fm-git-commit-conventional`](coding/fm-git-commit-conventional/) | Stages intelligently and writes Conventional Commits messages derived from the diff, with type and scope detection. | Universal |
| [`fm-markdown-formatting-guidelines`](coding/fm-markdown-formatting-guidelines/) | Creates and cleans up Markdown to markdownlint standards (headings, lists, code fences, tables, links), with per-rule fixes and a validation script. | Universal |
| [`fm-powershell-coding-style`](coding/fm-powershell-coding-style/) | Futuremotion's PowerShell style: region headers, comment conventions, naming, structure, and platyPS-compatible doc comments. | Universal |
| [`fm-powershell-file-processing`](coding/fm-powershell-file-processing/) | Scaffolds PowerShell 7 functions that batch-process files and folders, including parallel pipelines and wrappers around external CLIs. | Universal |
| [`fm-powershell-platyps-formatting-requirements`](coding/fm-powershell-platyps-formatting-requirements/) | Keeps comment-based help compatible with Microsoft.PowerShell.PlatyPS v1 so generated module docs and Starlight sites render cleanly. | Universal |
| [`fm-powershell-windows-admin`](coding/fm-powershell-windows-admin/) | Writes non-pipeline Windows 11 administration functions: services, processes, registry, scheduled tasks, Explorer, elevation patterns. | Universal |
| [`fm-summarize-codebase`](coding/fm-summarize-codebase/) | Produces an exhaustive, evidence-based codebase summary (metadata, language mix, architecture, every function), with helper scripts and references. | Universal |
| [`fm-summarize-codebase-lite`](coding/fm-summarize-codebase-lite/) | The same summary without scripts, for environments with only file or repository access. | Universal |

### Design

| Skill | What it does | Scope |
| --- | --- | --- |
| [`fm-eagle-autotagger-creator`](design/fm-eagle-autotagger-creator/) | Designs, audits, and converts presets for Eagle's AI Autotagger plugin and delivers paste-ready JSON that its validator has passed. | Universal |
| [`fm-extract-color-swatches`](design/fm-extract-color-swatches/) | Extracts a palette from a URL or image into a swatch CSV ready for conversion to Photoshop `.aco` or `.ase`. | Universal |
| [`fm-image-to-image-prompt-generator`](design/fm-image-to-image-prompt-generator/) | Generates clone, sibling, and variant text-to-image prompts from a reference image, tuned for 13 popular models. | Universal |
| [`fm-image-to-video-prompt-generator`](design/fm-image-to-video-prompt-generator/) | Analyses a still image and writes five cinematic image-to-video prompts across distinct motion archetypes. | Universal |
| [`fm-product-design`](design/fm-product-design/) | Designs, critiques, and systematises product UI/UX: tokens, visual identity, flows, WCAG 2.2 AA (with a contrast checker), voice UI, Figma handoff. | Universal |

### Figma

<p>
  <img alt="Figma" src=".assets/figma-logos/figma-logos-01.svg" width="28" align="left" style="margin-right:12px">
  Skills for building on Figma's extensibility surfaces: custom shaders and skills for Figma's
  built-in agent today, with design-system and plugin tooling next.
</p>

<br clear="left">

| Skill | What it does | Scope |
| --- | --- | --- |
| [`fm-figma-shader-creation`](figma/fm-figma-shader-creation/) | Creates and modifies custom Figma shader effects and fills (`main.ts`, WebGPU/WGSL): runtime contract, controls, factory presets, commenting standard, MCP and in-app workflows, cover artwork and publishing. Ships effect and fill templates and a dependency-free validator. | Universal |
| [`fm-figma-skill-creator`](figma/fm-figma-skill-creator/) | Creates, converts, reviews, tests, and publishes skills for Figma's built-in AI agent (single-file slash-command skills for Figma Design and Make) and ports them to and from coding-agent SKILL.md skills for the Figma MCP server. Ships six type templates, a 30-rule validator, a three-edition build and flatten script, a publishing kit, and a worked example (`fm-spacing-rhythm-audit`). | Universal |
| [`fm-figma-design-skill-finder`](figma/fm-figma-design-skill-finder/) | Researches and ranks Figma-specific agent skills across the Figma Community library and the MCP skill ecosystem, producing a verified, scored catalog. | Universal |

Planned additions: `fm-figma-design-system-creator` (builds a design system over MCP and emits a
per-system in-app skill through `fm-figma-skill-creator`) and `fm-figma-plugin-creator` (the full
Figma plugin lifecycle).

### File management

| Skill | What it does | Scope |
| --- | --- | --- |
| [`fm-renamer-preset-creator`](den4b-renamer/fm-renamer-preset-creator/) | Creates, explains, and verifies den4b ReNamer presets (`.rnp`) for any batch rename: casing, serialisation, dates, regex, Pascal Script. | Universal |

### Skill ecosystems

| Skill | What it does | Scope |
| --- | --- | --- |
| [`fm-universal-agent-skill-finder`](skill-meta/fm-universal-agent-skill-finder/) | Researches and ranks skills, plugins, extensions, and marketplaces across every AI coding agent for a topic, with a scored report and catalog. | Universal |

### Vendor-specific

These depend on one vendor's runtime and are installed only for that agent.

| Skill | What it does | Scope |
| --- | --- | --- |
| [`fm-claude-code-expert`](specifics/claude/fm-claude-code-expert/) | Deep specialist for Claude Code: installation, CLAUDE.md and memory, hooks, MCP servers, subagents, permissions, skills, headless use, troubleshooting. | Claude Code |
| [`fm-init-context-engine`](specifics/claude/fm-init-context-engine/) | Scaffolds, finishes, or refreshes the Futuremotion context engine (CLAUDE.md plus `Context/`) in a repository, with stack-specific templates. | Claude Code |
| [`fm-extract-app-assets`](specifics/claude/fm-extract-app-assets/) | Exhaustively extracts images and fonts (SVG, PNG, ICO, WEBP, TTF, WOFF and more) from an application and its data files. | Claude Code |
| [`fm-claude-agent-skill-finder`](specifics/claude/fm-claude-agent-skill-finder/) | Researches and ranks Claude Code compatible skills, plugins, and marketplaces for a topic. | Claude Code |
| [`fm-codex-agent-skill-finder`](specifics/chatgpt-codex/fm-codex-agent-skill-finder/) | Researches and ranks Codex-compatible skills, plugins, and plugin marketplaces for a topic. | OpenAI Codex |
| [`fm-antigravity-agent-skill-finder`](specifics/gemini/fm-antigravity-agent-skill-finder/) | Researches and ranks skills, plugins, and extensions for Google's agent surfaces. | Gemini CLI, Antigravity |
| [`fm-github-copilot-agent-skill-finder`](specifics/github-copilot/fm-github-copilot-agent-skill-finder/) | Researches and ranks Copilot customisations: skills, custom agents, instructions, prompt files, hooks, CLI plugins. | GitHub Copilot |
| [`fm-grok-agent-skill-finder`](specifics/grok/fm-grok-agent-skill-finder/) | Researches and ranks skills, plugins, and marketplaces for xAI's Grok Build coding agent. | Grok Build |
| [`fm-ms365-copilot-agent-skill-finder`](specifics/ms365-copilot/fm-ms365-copilot-agent-skill-finder/) | Researches and ranks Microsoft 365 Copilot extensions: declarative agents, plugins, connectors, Copilot Studio agents. | Microsoft 365 Copilot |

## How a skill is built

1. **Trigger description.** The frontmatter `description` says only *when* to use the skill, with
   the words a user would actually say, so agents load it at the right moment and not otherwise.
2. **Short body, deep references.** `SKILL.md` carries the workflow and the hard rules; everything
   that is long or optional lives in `references/` and is loaded on demand.
3. **Evidence tiers.** Where sources disagree, references label each claim as official, observed,
   or inferred, and record the open questions rather than guessing.
4. **Templates and validators.** When a skill produces code, it ships a starter and a script that
   checks the rules it teaches, so the agent can verify before it reports.

## Adding a skill

- Create `<topic>/fm-<name>/SKILL.md` with `name` (matching the folder) and a `description` that
  starts with the triggering situations. Put depth in `references/`, starters in `templates/`,
  checks in `scripts/`.
- Vendor-dependent skills go under `specifics/<vendor>/`.
- A new top-level topic folder also needs an entry in [`skills.sh.json`](skills.sh.json) so the
  CLI discovers it.
- Lint Markdown with the conventions in
  [`fm-markdown-formatting-guidelines`](coding/fm-markdown-formatting-guidelines/) before committing.

## License

Released under the [MIT License](LICENSE). Use the skills, adapt them, ship them with your own
projects; attribution in the license file is all that is asked.

<br>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".assets/futuremotion-logos/fm-dark-logotype-full.svg">
    <img alt="Futuremotion" src=".assets/futuremotion-logos/fm-light-logotype-full.svg" width="220">
  </picture>
</p>

<p align="center">
  Made by <a href="https://github.com/futuremotiondev">Futuremotion Studio</a>.
</p>
