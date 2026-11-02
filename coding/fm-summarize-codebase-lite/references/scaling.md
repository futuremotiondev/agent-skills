# Scaling

How to cover every function in a large codebase when you have limited context, a limited
reply size, and perhaps a limited number of tool calls per turn.

## Contents

- [Size the job](#size-the-job)
- [Tiers](#tiers)
- [Confirming scope](#confirming-scope)
- [Working across several turns](#working-across-several-turns)
- [Using sub-agents](#using-sub-agents)
- [Resuming](#resuming)

## Size the job

Before reading in depth, estimate the callable count. It needn't be exact yet:

- **With search:** run the language's main declaration pattern (function-inventory.md)
  across the codebase and count the hits.
- **Without search:** count files per language from the listing, read three typical
  files, and multiply by the average callables per file.

Tell the user the estimate, the tier, and the delivery plan in one or two sentences
before the long part of the work. In a non-interactive run (scheduled, or a workflow
step), put that sentence at the top of the delivered report instead.

In hosted-API mode, also count requests: the tree, languages, and metadata take about
8, plus one per file read. Check that against the rate limit in
access-and-delivery.md before starting.

## Tiers

| Tier | Callables | Delivery | Approach |
| --- | --- | --- | --- |
| S | ≤ 40 | One file, or one chat reply | Read every file, then write the whole report |
| M | 41–250 | One file if your write tool can append (or can write about 15,000 words at once); otherwise reference pages per module; or several chat parts | File by file: inventory, read, write entries, then sections 1–3 last |
| L | 251–1500 | Split files (a reference page per module), or many chat parts | As M, module by module, one module per turn when turns are limited; sub-agents if available |
| XL | > 1500 | As L | Confirm the scope first; then as L, in several sessions |

## Confirming scope

For tier XL, and for tier L when the delivery is chat-only, ask before starting.
Offer:

| Option | What it means |
| --- | --- |
| Whole codebase | Every callable, delivered in many parts or files |
| Application code only | Tests are summarized in 3.9 but not inventoried |
| Selected modules | Only the modules the user names; the rest appear in 3.1 and 3.4 at module level |
| Staged | Complete one module group per session, each verified before the next |

If you can't ask (a scheduled or non-interactive run), take the whole codebase and say
so at the top of the delivery. If only one reply is possible and there's no write tool,
follow "Single-reply runs" in access-and-delivery.md.

## Working across several turns

Platforms that cap tool calls or output per turn need the work split into self-contained
steps. Each turn:

1. Reads the ledger (below) from your previous output.
2. Does one unit of work: survey and metadata, or the inventory for one module, or the
   entries for one file group.
3. Saves the result: appends to the report file, or delivers a chat part.
4. Ends with an updated ledger.

The ledger:

```text
Ledger — {project} summary
Done: survey, metadata, languages, inventory (388 IDs), entries F001–F120
Next: module `src/api` — files routes.py, auth.py (F121–F176)
Withdrawn: F057 · Added: none
Delivery: file CODEBASE_SUMMARY.md (appending) | chat parts 1–4 of ~9 sent
```

Keep the inventory in the report file, or in the first chat part, so later turns can
reuse it instead of rebuilding it. If you rebuild it anyway, the IDs must come out the
same: follow the ordering rule in function-inventory.md.

## Using sub-agents

If you can delegate to sub-agents (for example, published agents your agent may call):

- Give each sub-agent a disjoint set of files, their inventory rows (IDs, names, lines),
  the entry format from function-entries.md, and 3–6 sentences of context about the
  system.
- Ask each for: the finished entries for its IDs, a list of any missed or withdrawn
  callables (with file and line), and findings for 3.11 with evidence and severity.
- Merge their entries in ID order, assign new IDs to their additions, and verify
  everything yourself. Re-check at least one entry from each sub-agent against the code.

## Resuming

If a run stops midway, the report and the ledger are the state. Find the highest ID
with a finished entry, confirm the inventory still matches the code (the latest commit
is unchanged, or the files you'll read are unchanged), and continue from the next ID.
If the code changed, re-inventory the changed files. Keep existing IDs for callables
that still exist, give new callables new IDs, and withdraw the IDs of removed ones.
