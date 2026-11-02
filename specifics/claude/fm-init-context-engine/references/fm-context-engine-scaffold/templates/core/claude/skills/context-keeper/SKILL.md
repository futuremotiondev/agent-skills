---
name: context-keeper
description: Use when new public surface is added to the project (as defined by PublicSurface in .claude/context-engine.psd1), when a spec under Context/specs/active/ reaches a shipped state, when an architectural decision emerges from conversation (phrases like "let's standardize X", "we're going to switch from A to B", "from now on all Y should Z"), or when an unexpected gotcha / workaround surfaces during debugging that would be valuable to capture for future sessions.
---

# context-keeper

Maintain coherence of this project's context management system as work progresses. The system — adopted in [ADR-0001](../../../Context/adr/0001-adopt-context-engine.md) — only stays useful if changes flow into the indexes, archives, ADRs, and insights as they happen. That's this skill's job.

## When to use

Four concrete triggers:

1. **New public surface appears.** What counts as public surface for this project is defined by the `PublicSurface` sentence in `.claude/context-engine.psd1` — read it before deciding whether this trigger applies. Cues: the user says they added it, a new file is created in a public-surface location, or the commit log shows one.

2. **A spec ships.** A document tree in `Context/specs/active/<slug>/` is now done — the feature is merged, tests pass, the work is complete. Cues: "<feature> is done", "we shipped <thing>", or explicit "let's archive this spec".

3. **An architectural decision emerges in conversation.** Cues: "we're standardizing on X", "from now on, all Y should Z", "let's deprecate W", or explicit "add an ADR for this". Also triggered when a prior decision is reversed or refined — that warrants a superseding ADR.

4. **An insight / workaround / gotcha surfaces during debugging.** Cues: "that was surprising", "I kept hitting this", "that pattern will trip someone else up", "worth remembering", or clearly reusable debug discoveries that weren't obvious from the code.

## When NOT to use

- Casual edits to existing code. Edits are not additions, and routine bug fixes are not insights.
- Large batched changes mid-flight. If 20 files land at once, wait for a natural pause before running operations — do not interrupt coding with bookkeeping.
- When the user is exploring ideas that may not stick. Wait for commitment before writing an ADR; tentative decisions clutter the record.
- When the slash commands (`/refresh-context`, `/new-adr`, `/archive-spec`, `/new-spec`) would be a cleaner explicit path. Prefer offering the slash command to the user over silently running its logic.

## The four operations

Each operation is a deterministic sequence. Execute only the operation that applies for the current trigger; do not run multiple operations on a single trigger unless the user explicitly asks.

### Operation A — new public surface added

1. Confirm the addition matches the `PublicSurface` definition in `.claude/context-engine.psd1` and follows the project's placement conventions (see `Context/conventions/agent-rules.md`).
2. If `.claude/context-engine.psd1` lists any `Regenerators`, invoke `/refresh-context` to regenerate the indexes under `Context/generated/`.
3. Check whether the addition's area has a path-scoped rule in `.claude/rules/`. If the new code introduces a pattern not covered, propose an addition — do not write it unilaterally; ask the user first.
4. If the project's conventions or roadmap flag follow-up obligations for new public surface (e.g. "every new X needs a reference doc under `Context/api/`"), surface them as a checklist — do not perform them without confirmation.

### Operation B — spec completed

1. Invoke `/archive-spec <slug>` or replicate its logic:
   a. `git mv Context/specs/active/<slug> Context/specs/archive/YYYY-MM-DD-<slug>` using today's date.
   b. Prepend a **Shipped summary** block to the primary spec file (PLAN.md or equivalent) with: what shipped, what was deferred, commit range from `git log --oneline`.
2. Remove the spec entry from `Context/roadmap/current.md` under "Active work". Add a brief entry under "Recently shipped" (create the section if missing).
3. Update `Context/specs/README.md`'s index table (move from Active to Recent archives).
4. If the shipped work produced a notable decision — "we learned X", "we committed to approach Y" — suggest Operation C as a follow-up.

### Operation C — architectural decision

1. Invoke `/new-adr "<title>"` or replicate its logic:
   a. Glob `Context/adr/NNNN-*.md` for the highest existing number; increment; zero-pad to 4 digits.
   b. Create `Context/adr/NNNN-<kebab-slug>.md` using the Nygard template (Status / Context / Decision / Consequences Positive,Negative / Alternatives considered).
   c. Pre-fill Context, Decision, Consequences from what was discussed in the conversation — not empty placeholders when the material is available.
2. If the new ADR supersedes an earlier one, update the earlier one's **Status** line to `Superseded by ADR-NNNN`. Do not delete or substantively edit the earlier ADR otherwise — past decisions are frozen history.
3. Update `Context/adr/README.md`'s index table.
4. If the decision affects active work (changes scope, introduces a phase-out, blocks a planned feature), update `Context/roadmap/current.md` to reflect it.

### Operation D — insight / workaround / gotcha

1. Write to `Context/insights/_inbox/YYYY-MM-DD-<short-slug>.md`. Use a slug that captures the essence — e.g., `2026-04-21-skia-svg-draw-vs-drawpicture.md`.
2. Use this structure:

   ```markdown
   # <one-line description>

   **Date:** YYYY-MM-DD
   **Context:** <what task surfaced this?>

   ## Problem

   <observable symptom>

   ## Root cause

   <what is actually going on>

   ## Fix / Workaround

   <the code or pattern that works>

   ## Rule

   <short prevention heuristic, one sentence>
   ```

3. Do **not** promote to `Context/insights/<topic>.md` or `Context/conventions/*.md` without explicit user approval. Promotion is a weekly-review decision. The `_inbox/` is the holding pen for exactly this reason.
4. If the insight is critical and load-bearing (e.g., "skipping this step corrupts the output"), flag the severity separately so the user can decide whether to promote immediately.

## Never do

- Touch files under `Context/generated/`. They are machine-regenerated by the scripts under `Context/scripts/` (invoked via `/refresh-context`). Hand edits are overwritten on the next regen.
- Edit archived specs under `Context/specs/archive/*`. They are frozen.
- Renumber or substantively edit past ADRs. Supersede by creating a new numbered ADR.
- Create docs without updating their parent index (`Context/README.md`, `Context/adr/README.md`, etc.). A doc nobody can find is a doc nobody reads.
- Run Operation A, B, C, or D without checking whether the user already did it in this session. Especially ADRs — only one per distinct decision.
- Treat edits as additions. Editing existing code is not adding public surface; do not run Operation A on edits.
- Promote _inbox/ items to durable conventions/insights without explicit user approval.

## Integration with the existing system

Slash commands, hooks, and path-scoped rules already handle most of the mechanical work:

| Mechanism | Trigger | Role |
| --------- | ------- | ---- |
| `.claude/hooks/session-start.ps1` | Session start | Inject orientation briefing |
| `.claude/hooks/post-edit-watch.ps1` | File edits matching configured watch globs | Run fast action or mark dirty |
| `.claude/commands/*.md` | User `/command` | Explicit intentional operations |
| `.claude/rules/*.md` | File-path match | Per-area coding convention |
| This skill | Conversational signals | Notice when operations should happen |

Do not duplicate what the other mechanisms do. If a slash command exists for an operation, invoke it (or suggest the user do so) rather than replicating its logic inline.

## Red flags — STOP and reconsider

- About to edit a file under `Context/generated/`? STOP — run the regenerator instead.
- About to create an ADR for a tentative idea? STOP — wait for real commitment.
- About to promote an item from `_inbox/` without user approval? STOP — weekly review decision.
- About to archive a spec that still has outstanding tasks? STOP — confirm with user what is actually done.
- About to run multiple operations for a single trigger? STOP — usually only one applies.
- About to rename or delete an ADR? STOP — ADRs are frozen history; supersede, do not edit.

## References

- [ADR-0001: Adopt the context-engine system](../../../Context/adr/0001-adopt-context-engine.md) — the backbone this skill maintains
- [Context/roadmap/current.md](../../../Context/roadmap/current.md) — the rolling status to update
- [Context/README.md](../../../Context/README.md) — the doc index to keep coherent
- [.claude/commands/](../../commands/) — the slash commands this skill invokes
- `.claude/context-engine.psd1` — the project's PublicSurface definition and regenerator list
