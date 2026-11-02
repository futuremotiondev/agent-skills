# Dictionary expansion 2026-09-28 — audit trail

Supporting files for the "2026-09-28 expansion" section of `..\casing-dictionary-review.md`.
Nothing here is read by the builder; `data\casing-dictionary.tsv` is the only source of truth.

| File | What it is |
|---|---|
| `research\*.tsv` | Raw candidates from the five research agents (`term pack confidence note`), one file per domain: ai, dev, creative, acronyms, brands. Notes carry the source domain checked for non-obvious casing. |
| `classified.tsv` | Every unique candidate (9,886) after dedupe, with the tier it received and why (`reason` is empty for core/proper). |
| `conflicts.tsv` | Case-insensitive duplicates across domains with different casing, and the casing kept. |
| `verification-flags.tsv` | Findings of the three independent auditors over all core terms (`WRONG_CASE` fixes and `AMBIGUOUS` collisions). |
| `corrections.tsv` | Existing rows whose casing was corrected (old, new, tier, source). |
| `classify.py` | Tiering rules: Capitalize-Every-Word emulation, Hunspell en_US + wordfreq collision checks, 2-letter allowlist, hand lists (force-review, rescue, conflict winners, renames). Provenance: paths point at the build workspace, and it needs `pip install wordfreq spylls` plus the Hunspell `en` dictionary (`npm pack dictionary-en`). |
| `merge_dictionary.py` | Applies the corrections, appends the classified rows as `source=added`, validates (no case-insensitive duplicates, no illegal characters, no APA minor words) and writes the TSV in the file's order (tier, pack, term). |
| `jay-decisions.tsv` | Jay's casing decisions made after the expansion (12 rows: old, new, tier/pack/source change, note); see "Jay's casing decisions" in `..\casing-dictionary-review.md`. |
| `apply_decisions.py` | Applies those 12 changes to `_spec\data\casing-dictionary.tsv`, keyed by each row's current term and source, and refuses to write if a row is missing, a duplicate appears or unchanged rows move. |

To add terms later, prefer editing `data\casing-dictionary.tsv` by hand (see `references\casing.md` §6) over re-running
these scripts.
