---
description: Regenerate Context/generated/ artifacts from the current codebase state
allowed-tools: [Bash, Read]
---

Regenerate the machine-authored artifacts in `Context/generated/`:

1. Read `.claude/context-engine.psd1` and collect the `Regenerators` list (repo-relative script paths under `Context/scripts/`).

2. If the list is empty or absent, report that this project has no regenerators configured and stop — nothing to do. (Regenerators are added by stack adapters or the maintainer; see `Context/scripts/README.md` for the contract.)

3. Run each regenerator in order:

   ```
   pwsh -NoProfile -ExecutionPolicy Bypass -File <regenerator-path>
   ```

   Report any non-zero exit code with the tail of its output; continue with the remaining regenerators.

4. Run `git diff --stat Context/generated/` to show what changed since the last regen. Briefly summarize.

These files start with a `GENERATED FILE — DO NOT EDIT` banner — they are machine-regenerated. Do not hand-edit them.
