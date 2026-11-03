# Contributing and maintaining this repo

How Futuremotion Studio works on this repository, and the pitfalls that have already cost time once. Skill-specific pitfalls for the Figma skills live in `figma/fm-figma-skill-creator/references/troubleshooting.md`; this file covers the repo, the tooling, and the way plans are executed.

## Ground rules

- **One master per skill.** The `SKILL.md` in a skill folder is the only editable file. Anything under `dist/` is generated and is overwritten or pruned on the next build; never hand-edit it.
- **Verbatim fixtures stay verbatim.** Files under `tests/fixtures/` are pasted agent output. They fail markdownlint on purpose and are never corrected.
- **Owner strings.** The author is `Futuremotion Studio` in every artifact: frontmatter, overlays, templates, commits, logs. A template that says `Futuremotion` alone leaks into every skill built from it.
- **Metadata.** Every master and template carries the six metadata keys: `version`, `author`, `category`, `tags`, `applies-to`, `runtimes`. Bump `metadata.version` on every instruction change, including house-style changes in the creator itself.
- **Line endings are LF.** Any tool that writes CRLF produces a whole-file diff and breaks the byte-identical rebuild check.
- **`docs/` and `.superpowers/` are gitignored by design.** Specs, plans, ledgers, briefs, and reports never reach the remote. Anything that must survive a workspace cleanup goes into a committed reference or this file. A forced clean of ignored files deletes both folders without asking.
- **Merge, commit, and push happen on Futuremotion's explicit go.** Local commits on a feature branch are fine; integration is theirs.

## Verification gates

Run from the skill folder (for the Figma skill creator, `figma/fm-figma-skill-creator`):

```bash
node scripts/build-skill-editions.mjs examples/<skill>/SKILL.md --out examples/<skill>/dist --validate
node scripts/validate-figma-skill.mjs examples/<skill>/SKILL.md --edition master
node scripts/validate-figma-skill.mjs --description "<the creator's own description text>"
node scripts/validate-figma-skill.mjs templates/<template>.md --edition master --allow-placeholders
npx markdownlint-cli2 --config <config with MD013 off and tests/fixtures/** ignored> "**/*.md"
```

Expected results: every edition at 0 errors and 0 warnings; a rebuild leaves `dist/` byte-identical (`git status --porcelain` empty); each skill template at 0 errors and exactly two placeholder warnings (`name-format`, `description-angle`); markdownlint at 0 issues outside `tests/fixtures/`. The four non-skill templates (eval log, concept cards, eval queries, listing copy) are not skill masters and are not validator targets.

Run the gates on the tree you are about to integrate, not on the tree that passed earlier. A green run proves only the tree it ran on.

## Windows and shell pitfalls

| Symptom | Cause | Rule |
| --- | --- | --- |
| A one-line edit shows as a whole-file diff | Python `write_text` or `open(..., "w")` turned LF into CRLF | Edit bytes (`read_bytes`/`write_bytes`) or pass `newline=""`; check `git diff --stat` before committing; `git diff \| grep -c $'\r'` must be 0 |
| A file gains a literal backspace (0x08) | `\b` inside an unquoted shell heredoc is interpreted | Use a quoted heredoc delimiter or the editor tools for anything containing backslashes; grep modified files for `\x08` afterwards |
| A `// helper:` marker or a `/tmp` path is silently rewritten | Git Bash (MSYS) converts arguments that look like paths, and Node resolves `/tmp` as `D:\tmp` while Bash rewrites it | Set `MSYS_NO_PATHCONV=1` when passing `//` strings, use the session scratchpad or repo-relative paths for fixtures, and confirm a size probe fails on a deliberately oversized file before trusting a pass |
| A Bash call is refused by a hook with no stderr | The dotnet-claude-kit pre-bash guard rejects the recursive delete flag pair anywhere in the command text, including inside heredocs and echoed strings | Delete with PowerShell `Remove-Item -Recurse -Force` or one path at a time; write files that mention the pattern with the editor tools |
| `git -C <root> log -- <file>` prints nothing for a tracked file | With `-C`, pathspecs resolve against the repo root, not the shell's cwd | Pass root-relative paths or `cd` first |
| markdownlint reports hundreds of MD013 line-length errors | No committed markdownlint config; the gate uses a config with MD013 off | Use a config file with `{ "default": true, "MD013": false }` and `tests/fixtures/**` ignored. A committed `.markdownlint-cli2.jsonc` is a pending housekeeping item |
| MD022 or MD032 on a comment line, MD024 on repeated deck headings, a table swallowed into a bullet | markdownlint treats HTML comments as content; rerun logs repeat headings; CommonMark continues a list item across a pipe line | Blank lines around comment lines; prefix repeated headings with the round; put tables before bullets, not under them |
| A validator flag "works" on the wrong input | `--description` takes the text itself, never a file path; multi-word text must be one quoted argument with inner quotes escaped | See the gates above |
| The Figma MCP steps are blocked at session start | The `figma-desktop` server refuses connections | Use the remote `figma` server; `use_figma` also requires a `description` argument |

## Executing plans with subagents

The repo's plans run through the subagent-driven-development process: one implementer per task, a task review after each, a whole-branch review at the end, all recorded in a ledger under `.superpowers/sdd/<plan>/progress.md`. These are the process failures the Plan 1 run hit.

- **Record BASE before every dispatch** with `git rev-parse HEAD` and build review packages from `BASE..HEAD`, never `HEAD~1`, which silently drops all but the last commit of a multi-commit task. When an approved task gets a polish commit afterwards, set the next task's BASE to that polish commit's parent so the polish is reviewed inside the next package, and say so in the ledger.
- **Mark subagent and MCP steps as orchestrator steps.** The implementer template forbids dispatching subagents. A plan step that needs them (parallel ideation runs) or needs a live MCP call the implementer cannot make is executed by the orchestrator, with the implementer stopping before it and resuming after.
- **Test every literal in a ruling before dispatching it.** Three rulings were wrong because a number, a regex, or a name was not checked: `timeout: 1` is one millisecond, `/letter|line|paragraph/i` matches "inline", and a dispatch note gave the wrong author string. Run the regex against sample names, check units, grep Global Constraints for the exact string. Reviewers verify ruling-derived code as well as plan-derived code.
- **Plan-mandated defects need an amending ruling, not a fix.** When a reviewer flags something the plan itself required, the implementer reports it as plan-mandated, the orchestrator rules with a cost-if-wrong and marks it for the owner to confirm, and the list of amended rulings is presented after the run.
- **Drift-check after every plan patch.** Six plan-review rounds kept finding counts that disagreed with their asserts and field names that differed between the task that produced them and the task that consumed them. After each patch, grep every renamed field across all tasks and recount every number an assertion depends on. Scoped re-reviews carry the prior findings list and a drift-check section.
- **One schema table for producer and consumer.** Interfaces described in prose per task drifted (`modeName`, `boundPassed`, `offRhythmTokens`, `fix.value`). Write the return shape once, have both tasks cite it, and test the consumer with the producer's real output, not hand-built input.
- **Plans name things that do not exist.** Task contexts referenced two files that were never created and asked for 95 landscape rows from a corpus with 88 unique bodies. List the files and count the corpus before dispatch; when a count cannot be met honestly, label the shortfall instead of padding.
- **Line-saving estimates are guesses until measured.** A cut expected to save lines saved none because the paragraph was one physical line. Measure with the validator after each cut and decide where the next lines come from before any task adds prose.
- **Every fix round gets a scoped re-review.** The final fix commit added a parse check that broke the top-level-await helper form. Fix dispatches are broad; re-review them with named checks, including negative fixtures and builds of both helper forms. A small load-bearing residual can be applied by the orchestrator directly, with the re-reviewer verifying by running the build and validator.
- **Sweep stale claims in the same commit as a new observation.** New probe rows, size thresholds, and description lengths were written where they were found while sibling files kept the old claim (`loadAllPages`, "no in-app probe table yet", "468 chars"). Grep the whole skill folder for the old phrasing before committing.
- **Gate wording changes everywhere at once.** The same question contract is copied into seven templates, the masters, the house style, and the skeleton guide. Grep for `ask, verbatim` and the follow-up wording, change every site, rebuild every edition. One template was still missed and caught only by review.
- **Model by role, parallel only when read-only.** Implementers for this repo run on Opus by the owner's standing instruction; task reviewers on Sonnet except for helper-logic diffs; final and closing reviews on Opus; fix rounds 4 and 5 move up a tier. Never run two implementers in parallel. Parallel dispatch is for read-only ideation and independent review dimensions.
- **Mock harnesses prove logic only.** A mock kept a binding on a raw write that real Figma would not have kept. Label mock numbers as sanity checks and prove every write path over the live MCP.
- **A delta closing review is a trade.** Reviewing only the commits since the last whole-branch review costs a missed cross-task interaction; the ledger records when that trade was taken.
- **Assertion scripts need a human read.** Keyword checks flagged a correct card and missed a sample count cited as a population. Judge each flagged line in full and record soft observations without editing the artifact.
- **A safety classifier can stop a response mid-stream** while doing nothing more sensitive than comparing tables. Redo the step in the next turn; the records on disk are intact.
- **Credits in the Figma chat are invisible until the credits icon is hovered.** Record them per prompt during a live round, or write "not recorded"; never estimate.

## Where the records are

- Specs and plans: `docs/superpowers/specs/` and `docs/superpowers/plans/` (gitignored, local only).
- Run ledgers: `.superpowers/sdd/<plan>/progress.md` (gitignored, local only; the sole record of a run's rulings until archived).
- Raw pitfall extraction behind this file: `docs/superpowers/notes/2026-11-03-plan-1-pitfalls-raw.md` (gitignored).
- Live observations about the Figma runtime: `figma/fm-figma-skill-creator/references/agent-capabilities-and-tools.md` and each example's `EVAL-LOG.md`.
