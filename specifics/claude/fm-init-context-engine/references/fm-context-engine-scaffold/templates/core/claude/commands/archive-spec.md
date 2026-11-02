---
description: Move a completed active spec to Context/specs/archive/YYYY-MM-DD-<slug>/
allowed-tools: [Read, Write, Edit, Bash, Glob]
---

Archive the active spec at `Context/specs/active/$ARGUMENTS/` to `Context/specs/archive/YYYY-MM-DD-$ARGUMENTS/`:

1. Confirm `Context/specs/active/$ARGUMENTS/` exists and contains markdown files.
2. Compute today's `YYYY-MM-DD` date prefix.
3. Use `git mv` to relocate:
   ```
   git mv "Context/specs/active/$ARGUMENTS" "Context/specs/archive/YYYY-MM-DD-$ARGUMENTS"
   ```
   (use `git mv` not a plain move, so git tracks the rename cleanly)
4. Open the primary spec file in the archived location (`PLAN.md` or equivalent) and prepend a **Shipped summary** block at the top:

   ```markdown
   ## Shipped summary (<today>)

   - **What shipped:** <...>
   - **What was deferred:** <...>
   - **Commit range:** <hash1>..<hash2>
   - **Follow-ups:** <pointers to new active specs or roadmap items if any>

   ---

   <original content follows>
   ```

   Pull commit range from `git log --oneline` of the relevant period. If the shipped summary is non-obvious from conversation or git history, leave `<...>` placeholders and flag to the user.

5. Remove references to this spec from `Context/roadmap/current.md`'s "Active work" section. If the spec had a notable outcome, add a one-line note under a "Recently shipped" section (create if missing).
6. Update `Context/specs/README.md`'s index tables (move from Active to Recent archives).
7. Report the new location and the summary-block status (auto-filled vs. placeholders).

Archived specs are **frozen** — do not edit them after this point. Follow-up work goes into new active specs, not edits to archived ones.
