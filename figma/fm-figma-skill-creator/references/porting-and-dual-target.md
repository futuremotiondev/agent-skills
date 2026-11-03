# Porting between the Figma agent and external MCP agents from one source

Figma separates the two ecosystems: Community skills "run directly inside the Figma app", while
MCP skills "are built for coding tools like Claude Code, Cursor, or Codex... and they don't run
inside the Figma app itself". Both rest on the Agent Skills specification, so one master file can
feed both if a build step strips target-marked sections and a validator checks each edition.

## Single-source layout

```text
figma/fm-<skill>/
  SKILL.md                      master: name + description (+ metadata.version), tool-neutral core,
                                target-marked sections
  overlay.claude.yaml           optional Claude Code keys merged into the coding-agent edition only
  references/                   optional, coding-agent edition only; nothing the Figma edition needs
  EVAL-LOG.md                   trigger and behaviour eval records
  listing/                      Community copy and artwork
  dist/
    fm-<skill>.figma.md         upload edition: figma-app sections kept, mcp sections and markers gone,
                                frontmatter reduced to name + description
    fm-<skill>.paste.md         Start-from-scratch edition: same body, no frontmatter
    fm-<skill>.paste.fields.txt the name and description to type into the Start-from-scratch form
    claude/fm-<skill>/SKILL.md  coding-agent edition: mcp sections kept, figma-app gone, overlay applied
    claude/fm-<skill>/scripts/<helper>.js
                                one file per core helper fence (first line `// helper: <helper>`);
                                the coding-agent SKILL.md carries a one-line pointer instead
```

`node scripts/build-skill-editions.mjs SKILL.md --out dist/` produces the three editions. The
Figma editions inline every helper fence; only the coding-agent edition moves them to `scripts/`.
`node scripts/build-skill-editions.mjs --flatten path/to/multi-file-skill --out dist/` inlines
`references/*.md` into one file for the reverse direction.

## Marker convention (build-time only)

```markdown
<!-- target:figma-app -->
## In-app execution (Figma agent)
...
<!-- /target -->

<!-- target:mcp -->
## MCP execution (Claude Code, Cursor, Codex)
...
<!-- /target -->
```

Neither runtime reads markers. Figma keeps HTML comments as visible text. Markers never ship; the
build removes them and the validator rejects any that remain.

## Porting steps

| # | Step | Direction | Why |
| --- | --- | --- | --- |
| 1 | Make `name` spec-strict and `fm-` prefixed, no `claude` or `anthropic` | both | Spec, Claude docs, Figma naming advice |
| 2 | Write `description` as capability, then "Use whenever...", then "Not for..."; key use case first; under 1,024 chars | both | Spec, Figma trigger advice, Claude Code truncation |
| 3 | Move Claude Code keys (`disable-model-invocation`, `argument-hint`, `allowed-tools`, `when_to_use`, `model`, `context`, `hooks`, `paths`) into `overlay.claude.yaml` | to Figma | Figma's behaviour with extra keys is unverified |
| 4 | Inline every `references/*.md` the agent always needs; shrink sometimes-needed reference to a table or checklist | to Figma | No folders in Figma |
| 5 | Convert `assets/` templates to fenced blocks or tables; drop binaries | to Figma | No folders; image rendering unverified |
| 6 | Replace `scripts/` with ordered natural-language steps, or a feature-checked `evaluate_script` block inside `target:figma-app` | to Figma | No shell in-app |
| 7 | Move `use_figma` code, `create_session`, `get_design_context`, `skillNames`, and `figma-use` prerequisites into `target:mcp` | to Figma | MCP-only tools |
| 8 | Move `evaluate_script`, `show_widget`/`sendPrompt`/`read_me`, `get_comments`, shader tools into `target:figma-app` with a prose fallback | to MCP | In-app-only tools |
| 9 | Delete relative links; refer to sibling skills only as "Not for X (use /y)" | to Figma | Single file; only the first skill runs |
| 10 | Re-check size after inlining; split into two named skills rather than exceed about 500 lines | to Figma | Spec recommendation |
| 11 | Build three editions; validate each with its `--edition` flag | both | Upload vs paste behaviour; spec directory rule |
| 12 | Upload and confirm the review screen filled name and description; run `/name` and an auto-trigger prompt on a duplicate file | to Figma | Figma upload flow; test rule |
| 13 | Never edit the Figma copy as master; if edited in-app, Export and merge by hand | from Figma | Export exists; format unverified |
| 14 | For the coding-agent edition, run `skills-ref validate ./dist/claude/fm-<skill>` if installed and `npx skills add ./dist/claude --list` | from Figma | agentskills.io; Vercel skills CLI |

## What breaks

| What breaks | MCP or Claude Code skill copied into Figma | Figma skill copied into a coding agent | Fix |
| --- | --- | --- | --- |
| `scripts/`, `references/`, `assets/` | Rejected or dead | n/a | Inline or drop (steps 4 to 6) |
| Relative links | Dead | Work | Remove from shared text |
| MCP tool names and `use_figma` JavaScript | No such tool in-app; `node.query`, `node.set`, `figma.io.write` unverified in-app | Work | `target:mcp` section |
| `evaluate_script`, `show_widget`, `get_comments`, shader tools | Work | No such tool | `target:figma-app` section with fallback |
| `allowed-tools` | Unknown | Supported, syntax varies per client | Overlay |
| `disable-model-invocation` | No key; the Figma toggle disables both paths | Supported in Claude Code | Overlay plus an in-body confirmation gate for high-risk skills |
| Selection context, `@` connectors, Make project loop | Native | Missing | Prose fallback: ask for a node URL or pasted content |
| Frontmatter in the paste path | Literal text that can mislead | Required | Separate paste edition |
| Name versus folder rule | Irrelevant | Required | Build names the folder |
| Invocation syntax | `/name` | `/name` (Claude Code), `/skills` or `$` (Codex), `/` (Cursor) | Same `name` everywhere |

## Writing the core so it ports

- Describe actions as design actions ("bind the fill to the matched colour variable", "place the
  new frame 80 px to the right of the source"), never as tool calls.
- Never assume the Plugin API, shell, or MCP in the core; a Figma Advocates skill says exactly
  this. Put tool-specific detail behind a feature check in the marked sections.
- Give every marked section a fallback sentence ("If it is not available, perform the step with
  your own canvas tools and say which path you took").
- Keep the in-app helper code under about 150 lines and self-contained per call.
- Branch by surface at the top (Design file, Make file, other) so the same file is valid in Make.
