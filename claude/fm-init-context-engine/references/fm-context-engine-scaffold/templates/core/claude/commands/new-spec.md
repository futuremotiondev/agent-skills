---
description: Scaffold a new active spec under Context/specs/active/
allowed-tools: [Read, Write, Bash]
---

Create a new active spec at `Context/specs/active/$ARGUMENTS/`:

1. Create the directory if it doesn't exist.
2. Write `PLAN.md` with this template:

   ```markdown
   # <Spec title>

   **Status:** Draft — not yet approved
   **Last updated:** <today>
   **Owner:** <user>

   This document is intentionally self-contained. A future development session should be able to read *only* this file and resume any phase of implementation without needing to replay the conversation that produced it.

   ## Top-level design principle

   <one-sentence tiebreaker that resolves close judgment calls>

   ## Project overview

   ### Goal

   <what are we building and why?>

   ### Non-goals

   - <scope exclusion>

   ### Scope

   <phased deliverable table>

   ## Architecture

   <components + how they fit>

   ## Phases

   ### Phase 1 — <name>

   <tasks>

   ### Phase 2 — <name>

   <tasks>

   ## Open questions

   - <...>

   ## References

   - <external spec / reference links>
   ```

3. If `Context/specs/archive/` already contains specs, skim the most detailed one as a quality reference — that's the detail level to aim for.
4. Add a reference to the new spec in `Context/roadmap/current.md` under "Active work" if it's an active-work item.
5. Report the created path.
