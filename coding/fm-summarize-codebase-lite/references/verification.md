# Verification

The pre-delivery checklist: 17 checks. Run every check, fix every failure, and state
the result when you deliver ("17/17 checks pass" or "16/17 pass; check 14 not
performed: …"). Where a check says *search*, use a content-search tool on the report
file if you have one. Otherwise scan the text you wrote, part by part. With
overwrite-only write tools, run the checks on your drafts *before* writing the final
main file, so it's written once.

## Contents

- [Completeness](#completeness)
- [Counts and arithmetic](#counts-and-arithmetic)
- [Content quality](#content-quality)
- [Hygiene](#hygiene)
- [Spot check](#spot-check)
- [Result line](#result-line)

## Completeness

1. **IDs are contiguous.** List the IDs in the reference headings (search
   `^#### F\d+`). They run from F001 to the highest number. Every gap must be an ID
   listed as *withdrawn* in Appendix B.
2. **Every active ID appears exactly once in the reference and once in the index.**
   Search each ID (`F041 ·` in headings, `| F041 |` in the index) or compare the two
   lists side by side. Look out for duplicates from copy-paste and for IDs present in
   one place but not the other.
3. **Per-file tallies match.** For each file group, the number of entries under its
   heading equals the tally you recorded in the inventory, and equals the "({N})" in its
   index heading.
4. **Re-scan the dense files.** For the three files with the most callables, run the
   declaration patterns from function-inventory.md again (or skim the file again) and
   confirm nothing new turns up. Add any miss with the next free ID and note it in
   Appendix B.
5. **No placeholders or leftovers.** Search for template placeholders: a `{` followed
   by a lowercase word, outside code blocks and inline code (braces inside backticks,
   like `{CRLF}` or a signature's `{…}`, are content). Also search for "TBD", a
   standalone "…" as a whole sentence or cell, and leftover italic template notes. None
   may remain.

## Counts and arithmetic

6. **Totals agree everywhere.** The active ID count equals: the header line's "{N}
   functions & methods", the 1.1 Size row, the 1.6 total, the sum of the 1.6 Kind table,
   the sum of the Language table, the sum of the Module table, and the sum of the 3.1
   Functions column. Add each column; don't eyeball it.
7. **Percentages sum to 100.0.** Add the 1.3 Share column; it must be exactly 100.0 (see
   the largest-remainder rule). The Files and size totals equal their column sums.
8. **Every number has a method.** The 1.3 method line, the 1.6 counting line, and
   Appendix A name how each number was obtained, and say approximate where it is.

## Content quality

9. **Summaries add information.** For every Summary line, strip the words that appear
   in the function's name. If nothing informative is left ("Gets the user" for
   `get_user`), rewrite it.
10. **Entries have substance.** Non-compact descriptions have at least 25 words, and
    cover behavior plus whatever applies of parameters, returns, side effects, and
    errors. Compact entries and declared twins (function-entries.md) have at least one
    full sentence, and a twin names its original's ID and states every difference.
    No entry reads "See above" or "Same as F012" without that.
11. **Summaries match.** Each index row's Summary is character-for-character the
    entry's Summary line, and no row is broken by an unescaped `|`.
12. **Facts are sourced.** Every row of 1.1 has a Source. Every 3.11 finding has
    `file:line` evidence and a severity.

## Hygiene

13. **No secrets.** Search the report for: `AKIA` followed by 16 capitals or digits
    (AWS keys), `-----BEGIN` (private keys), `sk-` / `ghp_` / `xox` followed by long
    tokens (API keys, GitHub and Slack tokens), `AIza` (Google keys), and
    `password=`/`secret=`/`token=` with a quoted value. Remove any hit. Name the file
    or variable instead.
14. **Links resolve.** Every relative link to a split page points to a file you wrote.
    Anchors match headings.
15. **Diagrams parse.** Each `mermaid` block starts with a diagram type (`flowchart`,
    `graph`, `sequenceDiagram`, `erDiagram`, `stateDiagram-v2`, `classDiagram`). Labels
    with spaces or punctuation are quoted, node IDs are alphanumeric, `end` isn't a node
    ID, and every `subgraph` has its `end`.
16. **URLs are clean.** No credentials in URLs, and no contributor email addresses.

## Spot check

17. Pick five entries spread across different files, including one of the longest
    functions. Re-open the code and confirm each claim in the entry: the steps, the
    parameters, the return value, the side effects, the errors. Fix anything wrong, and
    if two or more are wrong, re-check that whole file's entries.

## Result line

Put the outcome in the delivery message, and in Appendix A if the report is a file:

```text
Verification: 17/17 checks pass · 388 active IDs (F001–F389, F057 withdrawn) · 1.3 sums to 100.0% · spot-checked F012, F088, F145, F260, F371
```
