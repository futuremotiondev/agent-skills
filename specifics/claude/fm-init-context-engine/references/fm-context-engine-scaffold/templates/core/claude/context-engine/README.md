# Context Engine Records

Engine-managed. Do not edit anything in this folder by hand, and do not edit `.claude/context-engine-manifest.json`.

## What is here

- `baseline/` holds a snapshot of every seeded file (convention docs, rules, regenerators, `CLAUDE.md`, the `Context/` skeleton) exactly as the engine last rendered it: at install, after installer tokens were substituted and before the authoring pass filled anything in, and again at each refresh that took a new version. Each snapshot keeps its path and adds a `.base` suffix, which stops Claude Code from loading a snapshot as a live rule or `CLAUDE.md`.
- `incoming/` exists only after a seed refresh. It holds what the refresh would not write itself (merge candidates, proposals, `refresh-report.md`, and the `pending.json` that `-CompleteRefresh` reads). It ignores itself, so none of it is committed, and each refresh starts it afresh.
- `.claude/context-engine-manifest.json` indexes the snapshots and records the rest of the install: the stack and its adapter chain, the installer's answers, the config defaults spliced into `.claude/context-engine.psd1`, and a hash per file.

## Why it exists

Seeded files belong to this project, and the project changes them. When the engine's templates improve later (a corrected platform fact, a new rule), a refresh has to tell those project changes apart from what the engine originally wrote. These snapshots are that original: the common ancestor of a three-way merge, so engine changes can land in text this project never touched while its own edits survive. Editing a snapshot corrupts the merge base.

## What to do with it

Commit this folder with the rest of `.claude/`. Leave the contents alone; the engine's installer and updater maintain them.
