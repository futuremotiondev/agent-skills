---
description: Sweep Context/ frontmatter for stale last_verified stamps and spot-check claims
allowed-tools: [Read, Grep, Glob, Bash]
---

Sweep documents in `Context/` for stale `last_verified:` frontmatter stamps and verify a sample of their claims against the current codebase.

1. Use Grep to find all `.md` files under `Context/` that contain a `last_verified:` line in frontmatter.

2. For each matched file, extract the stamp date. Flag any stamp older than **90 days** from today (today's absolute date is available in the conversation's system context).

3. For each flagged file, spot-check 1-2 concrete claims against the codebase:
   - **Architecture docs** (`Context/architecture/*`) — verify referenced file paths exist and still look as described.
   - **Convention docs** (`Context/conventions/*`) — verify one recent unit of code still follows the pattern. Code that departs from a **Default:** is drift only when nothing records the deviation; then suggest recording it (an ADR, or an edit to the doc) rather than reverting the code.
   - **Reference docs** (`Context/api/**`, `Context/internals/**`, or equivalent) — verify the documented public surface (signatures, exports, parameters) still matches the doc's tables.

4. **Do NOT update stamps or doc content.** Only report findings.

5. Output a table:

   | Doc | Stamp age | Claims verified | Needs update? |
   | --- | --------- | --------------- | ------------- |
   | `Context/architecture/foo.md` | 92 days | file paths ✓, schema ✓ | No |
   | `Context/api/bar.md` | 120 days | signatures ✗ | **Yes** — `Foo.Bar()` renamed to `Foo.Baz()` |

6. For items marked "Needs update," suggest the specific edits (but don't make them). The user decides whether to update.

Not every stale-stamp doc needs updating — many docs describe stable patterns that haven't changed. The point is to surface drift candidates for human review.
