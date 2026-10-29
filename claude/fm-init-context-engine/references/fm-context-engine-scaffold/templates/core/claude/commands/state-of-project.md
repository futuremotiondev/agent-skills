---
description: Produce a fresh status brief from roadmap, active specs, and recent commits
allowed-tools: [Read, Bash, Glob]
---

Produce a concise "state of the project" brief:

1. Read `Context/roadmap/current.md` — the declared priorities and active work.
2. Glob `Context/specs/active/*/` and for each one, read the top of `PLAN.md` (first 30 lines) and `RESUMPTION-NOTES.md` if present. These carry the active-work cursor.
3. Run `git log --oneline -20` for recent activity.
4. Run `git status --short` for in-flight uncommitted changes.
5. Run `git branch --show-current` and compare to the main branch.

Output a concise summary (5-10 bullets, under 300 words) covering:

- **Currently active** — what's in progress, where the cursor is
- **Recently shipped** — last 3-5 commits of meaningful work
- **In-flight uncommitted** — staged/unstaged changes that haven't landed
- **Blocked / waiting** — items the roadmap flags as blocked
- **Next up** — one or two obvious next moves

Keep it readable — this brief is for quick orientation at the start of a work session, not a deep audit.
