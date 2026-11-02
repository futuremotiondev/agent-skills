# Scaling: large codebases, parallel agents, resuming

How to cover every function in a codebase with thousands of them, without running out
of context and without two agents editing the same file.

## Contents

- [Tiers](#tiers)
- [Reading budget](#reading-budget)
- [Batches and page ownership](#batches-and-page-ownership)
- [Dispatch template](#dispatch-template)
- [Coordinator duties](#coordinator-duties)
- [Without subagents](#without-subagents)
- [Resuming an interrupted run](#resuming-an-interrupted-run)
- [Scope reduction for tier XL](#scope-reduction-for-tier-xl)

## Tiers

| Tier | Callables | Layout | Who fills the reference |
| --- | --- | --- | --- |
| S | ≤ 150 | Single file | You |
| M | 151–600 | Split pages above 250 | You, module by module; or subagents per batch (below) |
| L | 601–3000 | Split pages and a separate function index above 400 | One subagent per `plan.json` batch, in parallel |
| XL | > 3000 | As L | As L, after the user confirms the scope |

The thresholds are defaults (`scaffold_report.py --split-threshold`,
`--inline-index-limit`; `analyze.py --batch-size`). Lower the batch size for dense code
(C++, generated-looking APIs); raise it for many small functions (tests, accessors).

Pages: a small module shares one page, a module over 150 callables gets a page per
file, and a file over 90 callables is split into parts of 60 (`…-part-1.md`,
`…-part-2.md`), so one huge file never becomes the single slow batch.

**Tier M with subagents:** re-run `analyze.py --batch-size 60` (or 80) so `plan.json`
yields about 4–8 smaller batches, then dispatch them as for tier L. Batches always hold
whole pages, so smaller batches never make two agents share a page.

## Reading budget

Read each source file **once** and fill all of its entries while it's in context. A
batch of about 150 callables usually covers 5–20 files. If a single file is too large to
read at once, read it in consecutive ranges that follow the entries' line spans, and
fill each range's entries before reading the next.

## Batches and page ownership

`plan.json` → `batches[]` gives each batch its `reference_pages` (under the report's
`codebase-summary/` folder), the source `files` those pages cover, and a callable count.
A page is never split across batches, so a batch's owner can edit its pages without
colliding with anyone.

Ownership rules:

- A batch agent edits **only** its own reference pages: the file-role sentences and
  every entry's Summary line and description.
- Nobody edits the index or the counts by hand. The coordinator runs `sync_report.py`
  after the batches finish; it copies every Summary line into the index and recomputes
  the counts.
- `CODEBASE_SUMMARY.md` and sections 1–3 belong to the coordinator.

## Dispatch template

Send one subagent per batch, all in the same turn so they run in parallel. Fill the
angle-bracket fields from `plan.json`:

```text
You are filling part of a codebase summary. Work only with reading and editing tools;
do not run, build, install, or import anything from the codebase.

Codebase root: <target>
Your reference pages (you own these, edit no other file):
  <report_dir>/codebase-summary/reference/<page1>.md
  <report_dir>/codebase-summary/reference/<page2>.md
Source files they cover: <files from the batch>
Entry-writing rules: <skill>/references/function-entries.md (read it first)
Context: <3–6 sentences from your orientation: what the system does, the main
modules, and the vocabulary the code uses>

For each source file: read it in full, then in its page replace every [[FILL: …]] for
that file (the file-role sentence, and each entry's **Summary:** line and description)
with text based on reading the body. Leave the markers (<!-- sym:… -->) and the
pre-filled facts as they are. If an entry is not a real callable, or you find one the
inventory missed, don't delete or add entries: report it in your final message instead.
A page titled "part k of n" holds only some of a file's functions: read the whole file,
but fill only your part. Before finishing, search your pages for "[[FILL" and fill any
you missed.

Final message, and nothing else:
1. CORRECTIONS: false positives and missed callables, one per line, with file:line.
2. FINDINGS: bugs, risks, or oddities worth section 3.11, one per line, with
   file:line and a severity (High/Medium/Low).
3. MODULE NOTES: 2–4 sentences per module on its responsibility and key internals,
   for section 3.4.
```

## Coordinator duties

1. Before dispatching: finish orientation (SKILL.md step 3) so the context paragraph is
   accurate, and scaffold the report.
2. While agents run: fill section 1 and draft section 2 from orientation.
3. As each batch returns: apply its CORRECTIONS (drop markers, manual entries, Appendix
   B list; see function-entries.md), and keep its FINDINGS and MODULE NOTES for 3.4 and
   3.11. Verify each High finding against the code before using it.
4. When all batches are back, run `sync_report.py`, then `check_report.py`. Any ID
   still missing belongs to a known batch. Re-dispatch that batch with only the missing
   IDs, or fill them yourself.
5. Write sections 2–3 last, then spot-check five random entries per batch against the
   code. If a batch's entries read as restated names, re-dispatch it with the offending
   IDs and the checker output.

## Without subagents

Work through `plan.json` batches in order. After each batch, run `sync_report.py` and
`check_report.py`. The list of unfilled slots shrinking to the next batch's files is
your progress meter. Keep
a short running note of module responsibilities and findings as you go, so sections 3.4
and 3.11 don't depend on rereading.

## Resuming an interrupted run

The report itself is the state. Run:

```bash
python scripts/check_report.py <work>/symbols.json <report> --json
```

`errors` lists every unfilled slot with its file and line, and every callable still
missing an entry. Resume at the first unfilled reference page. If the code changed in
the meantime, re-run `analyze.py` into a new work directory and use `carry_over.py`
(SKILL.md step 8) rather than editing against a stale inventory.

## Scope reduction for tier XL

Before reading anything, give the user the numbers (callables, files, code lines, top
modules from `plan.json`) and offer these options:

| Option | How |
| --- | --- |
| Whole codebase | Proceed as tier L |
| Application code only | `analyze.py --no-tests` (tests are listed in 3.9 but not inventoried) |
| Selected modules | `analyze.py --exclude "<glob>"` for each excluded area; say what was excluded in Appendix A |
| Staged | Run it in several passes, one module group per pass, each checked before the next |

If the session is non-interactive, proceed with the whole codebase and state that
choice at the top of the delivery message.
