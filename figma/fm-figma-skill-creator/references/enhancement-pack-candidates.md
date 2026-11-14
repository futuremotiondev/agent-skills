# Enhancement pack candidates

Packs researched but not built, moved here from `enhancement-packs.md`, which holds the contract for the shipped ones. Read this file when planning a new pack, not when choosing one in Workflow A step 6a.

## Candidate packs

The candidates below come from Futuremotion's pack research of 2026-11-13 (round two), in its ranked order. Origin is `spec` for a pack in the v2 design's first-wave list and `new` for one the research added. Usefulness and readiness are scores out of 6; a one-point difference is not meaningful. `revert` was not ranked and is listed last.

| Pack | Definition | Origin | Usefulness | Readiness | Status |
| --- | --- | --- | --- | --- | --- |
| `scope-gate` | Resolves the scope from the selection, asks before widening it, and warns about credit cost on large scopes | spec | 6 | 6 | candidate |
| `report-format` | Keeps the priority column visible and makes each layer a clickable node link, linking the containing node for instance-scoped ids and resolving stored ids before linking | spec | 6 | 6 | candidate |
| `coverage-ledger` | States what was scanned, skipped, unmeasurable, and failed, with a count and a reason for each, so a report never implies an uninspected surface was reviewed | new | 6 | 5 | candidate |
| `ignore-list` | Lets a designer exempt a layer once, by a name tag or a shared-plugin-data record, so every later run honours the exemption and counts it | new | 6 | 4 | candidate |
| `spec-report` | Writes the report as Markdown into an embedded Spec beside the audited frames, and updates its own Spec on a re-run | new | 6 | 4 | candidate |
| `token-conformance` | Audits values against the file's tokens and fixes by binding to the matching variable; generalises to any numeric or colour property | spec | 6 | 3 | shipped |
| `confirm-tiered` | Applies high-confidence rows, previews the rest, and always discloses the main-component blast radius before a write | spec | 5 | 6 | candidate |
| `batch-and-summary` | Treats large results as one behaviour: a group summary over 30 rows and batch continuation at a cap | spec | 5 | 6 | candidate |
| `run-journal` | Persists the apply result and a change-log line (skill version and rows) on the page in shared plugin data, so a revert works in a later conversation | new | 5 | 4 | candidate |
| `canvas-report` | Writes the report as an auto-layout frame beside the source, fonts loaded and stamped so a re-run replaces it; the fallback where Specs are not available | new | 5 | 3 | candidate |
| `spec-report-file` | Writes the report into a separate standalone Spec file, the coding agent carrying the Markdown between two calls on two files | new | 5 | 3 | candidate |
| `spec-safe-write` | The write discipline every Spec-writing pack requires: unique-match edits, one re-read and retry, verification by `includes`, preserved comment markers, the H1 kept first, and a size guard before return | new | 5 | 3 | candidate |
| `spec-changelog` | Appends one dated entry per run to a change-log Spec kept in the file, readable and editable by people | new | 5 | 3 | candidate |
| `library-tokens` | Extends token conformance to variables published from an enabled library, importing a variable only when the user confirms a bind | new | 5 | 2 | candidate |
| `spec-check` | Compares the named things a Spec claims with what is on the canvas, reporting claims with no match and canvas items the Spec never mentions | new | 5 | 2 | candidate |
| `verify-readback` | Re-reads every written property after a write and reports any mismatch as not fixed | spec | 4 | 6 | candidate |
| `work-on-copy` | Duplicates the target beside the original and applies changes to the copy, with a snapshot mode that takes the place of `checkpoint` | new | 4 | 5 | candidate |
| `spec-rules` | Reads the rules in a named rules Spec before judging or writing, and says which Spec and heading each rule came from | new | 4 | 4 | candidate |
| `spec-comments` | Leaves each finding as a comment anchored on the exact text it concerns in a Spec, in a call after the write | new | 4 | 2 | candidate |
| `spec-to-canvas` | Works through one Spec section as a to-do list, does the canvas work for each item, then ticks it and writes the produced node id beside it | new | 4 | 2 | candidate |
| `read-guidelines` | Before judging, reads the standing rules the file carries (library guidelines, component descriptions, documentation links) and names each rule's source | new | 3 | 6 | candidate |
| `one-question-mode` | Chooses the skill's mode with one numbered question, asked once | spec | 3 | 6 | candidate |
| `fold-and-merge` | Reports a value inherited from a main component once, on that component, and merges rows that read identically into one | spec | 3 | 6 | candidate |
| `checkpoint` | Takes a restorable snapshot before the first write so a whole run can be rolled back where `revert` does not reach; now a snapshot mode of `work-on-copy` | new | 3 | 4 | candidate |
| `annotate-findings` | Writes each finding as a Dev Mode annotation on its node, in one of the fixed categories with a skill-name prefix, so a re-run rewrites its own | new | 3 | 4 | candidate |
| `cost-estimate` | Counts cheaply before any heavy gate and asks "about N frames, about M credits, continue?" | spec | 3 | 4 | candidate |
| `contrast-measure` | Measures contrast one correct way: relative luminance with alpha composited over the resolved background, per variable mode, "unmeasurable" for image and gradient backgrounds | new | 3 | 3 | candidate |
| `mode-matrix` | Runs a check across every variable mode, extended-collection overrides included, and reports failures per mode | new | 3 | 3 | candidate |
| `change-impact` | After a write to a component or variable, lists the instances and consumers affected and drafts a changelog line | new | 3 | 3 | candidate |
| `tolerance` | Makes the pass threshold a setting instead of a fixed rule | spec | 2 | 6 | candidate |
| `dry-run` | Previews every write the skill would make without changing the canvas | spec | 2 | 4 | candidate |
| `revert` | Restores each applied change's previous value or binding from the apply result, only where the layer still reads what apply set | spec | not ranked | not ranked | shipped |

Dropped: `answer-first` for yes-or-no prompts, because no published skill shows the need.

Not packs: evidence-bound findings and a defined severity scale belong in the audit and critique templates (the scale with a validator warning when a skill says "severity" without defining one), and the surface gate is already step 1 of "Before you start" in the skeleton. None of the three is optional or separable.

The table records candidates only. None is built yet, and no workflow offers a candidate.
