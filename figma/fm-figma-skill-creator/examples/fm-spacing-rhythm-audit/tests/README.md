# Tests for fm-spacing-rhythm-audit 2.2

These are the oracle fixtures for the 2.2 example. They were first written for 2.0 (2.1 changed instruction wording only), and were regenerated over MCP on 2026-11-13 after 2.2 changed the collect helper: near misses rank P3, the tie-break, the election, the discover fallback, and opportunity-row order and notes. A script run over the Figma MCP server (`use_figma`) produces the exact result the skill should reach, and an in-app or MCP run of the skill is compared against it. The fixtures are throwaway test files, not skill requirements: the skill works in any file.

## Files

| File | What it is |
| --- | --- |
| `seed.use_figma.js` | Builds the seed on the page named "Seed": the `Card` component and three instances, eight test frames, and the `Legacy` and `Spacing` variable collections. It is idempotent by name, so a second run creates nothing and returns the same ids. Top-level `await`, no wrapper. |
| `oracle.use_figma.js` | The master's collect helper at `metadata.version` 2.2, which is already in the top-level form `use_figma` runs (no wrapper). The oracle differs from the fence in `SKILL.md` by exactly the hunks listed under "Oracle hunks" below; nothing else differs. |
| `expected.json` | Expected results per scope, in the shape the compare script (`scripts/oracle-compare.mjs`, see "Compare" below) reads, described field by field under "Collect result fields" below. Rows are uncapped. `tokens` and `unbound[].ids` come from the oracle's restore block; the skill's own collect returns `tokenCount` and no ids, which keeps it under the 48,000-byte `use_figma` limit. The apply and revert proofs sit under `scopes[1].proofs`. `masterVersion` is the master's `metadata.version` the oracle mirrors (`"2.2"`); it replaces Plan 1's `masterCommit`, and nothing in the file is read from git. |
| `collect.harness.mjs` | Runs the master's collect fence under Node against a mock `figma` object, fourteen cases. Run `node examples/fm-spacing-rhythm-audit/tests/collect.harness.mjs` from `figma/fm-figma-skill-creator`; it prints `14 cases, 0 failed` and exits 1 on any failure. A mock proves logic only, never a live number. |
| `compare.harness.mjs` | Runs `scripts/oracle-compare.mjs` against the report fixtures and in-memory variants of them, twenty-four cases. Run `node examples/fm-spacing-rhythm-audit/tests/compare.harness.mjs` from `figma/fm-figma-skill-creator`; it prints `24 cases, 0 failed` and exits 1 on any failure. See "Compare" below. |
| `packs.harness.mjs` | Tests the enhancement-pack contract (`references/enhancement-packs.md`) as `scripts/lib/enhancements.mjs`, `scripts/enhancement-packs.mjs`, and the validator's pack rules implement it, fifty-seven cases: this master's unit counts per pack and per kind; strip of each pack and of both in either order (same result, 0/0, helpers parse, and every changed line inside a listed unit); `extract` reproducing the committed `enhancement.md` files twice over, and those files reading back as the same units; the contract's error cases; masters the pack is absent from (stripped already, every `.md` file in `templates/`, and the probe, which shares one declared table separator) passing through `strip` byte-identical with exit 0 and one not-present line, a tag such as `tokens` kept in a master without the pack, and a master that carries the pack but lacks one declared line still warning for that line; ordinary prose that must survive a strip (sentences that start with a pack's words without its colon, a phrase in parentheses, a line at the same indent after a block); `roundtrip` at exit 0 for each pack and both in either order, and strip then `expand` from the pack records giving this master back byte for byte; `roundtrip` at exit 1 on a block glued to the next paragraph and on a reworded declared prose sentence; `expand` refusing a master that carries the pack, but not one that only shares a declared table separator (the probe); `expand` into the untagged QA template, with one warning per orphan code region, the orphan fences, 0 errors and the two placeholder warnings, and a dry-run build of one helper; one failing input for each of the validator rules `enhancement-regions`, `enhancement-tags`, and `enhancement-surfaces`; `expand` commuting with edits that touch no anchor (15 prose lines, 30 code lines, and a decoy `};` function) for each pack and both; a renamed helper, a duplicated key line, and a duplicated prose anchor each falling back with one warning; a skill that takes this master's name still getting orphan regions; a separator-only template line matching only below another declared line; `expand` into the probe giving a master the tools accept; a library error reported by the validator; `expand` writing nothing when its result would be refused; a surface guard anywhere in the helper, and the no-overlap message; a phrase in a table row of a pack-free master; CRLF and no-final-newline masters passing through `strip` as their bytes; `roundtrip` naming a pack that is not present; a unit whose section is missing going to the end of the last core section; a section name that two sections carry falling back with a warning instead of placing a unit in the first; the validator not doubling the pack name on a library message; a region marker shown in a `markdown` or `ts` fence read as ordinary text; a surface guard covering only the helper it sits in; and the no-overlap advice to remove the pack, in the validator and in contract rule (i). Run `node examples/fm-spacing-rhythm-audit/tests/packs.harness.mjs` from `figma/fm-figma-skill-creator`; it prints `57 cases, 0 failed` and exits 1 on any failure. |
| `checks.harness.mjs` | Tests the validator rules that are not pack rules, and `scripts/check-all.mjs`, sixteen cases: a bare "does not" or "doesn't" is no description boundary; "Lets designers", "helps product teams", "allows anyone to" and "lets reviewers to" warn for voice; `gate-tool` on a gate with neither the question-tool clause nor `ask_user_question`, on a gate whose clause sits in its list item or paragraph, on a clause in another paragraph, and on both example masters; `helper-form` on wrapped helpers in the master, upload, and paste editions, on the top-level form, an indented inner wrapper and a plain fence, and on the audit's revert helper wrapped (a pack's whole-helper fence); `capability-gates` passing generated vector icons and image-to-vector conversion and warning on editing existing vector paths or points, and its basis text; the validator deciding helper fences only through `HELPER_FENCE_LANG`; and `check-all.mjs` listing every check, passing and failing each of the five changelog checks on a scratch copy, and ignoring a broken `history/` snapshot beside each master; and the committed `.markdownlint-cli2.jsonc` ignoring `**/history/**`, with a lint run from a scratch root skipping a failing snapshot (it runs `npx --yes markdownlint-cli2`). Run `node examples/fm-spacing-rhythm-audit/tests/checks.harness.mjs` from `figma/fm-figma-skill-creator`; it prints `16 cases, 0 failed` and exits 1 on any failure. |
| `build.harness.mjs` | Tests what `scripts/build-skill-editions.mjs` writes beside the editions, twenty cases, every build on a copy of this example or of the probe under the operating system's temporary folder: the manifest's keys in the order `references/format-and-frontmatter.md` lists them and its values from the master, the editions, the packs, and `EVAL-LOG.md`; edition sizes equal to the validator's own counts; no timestamp, absolute path, commit hash, or build-time key; two-space JSON with a trailing newline; a second build byte-identical; `history/<version>/` holding byte copies of the master and the overlay, a bump keeping the old snapshot, and a rebuild at the same version overwriting it; evalStatus nulls with no eval log, no `## Entries`, or no entry; a master with no overlay; a folder under no git repository with an empty stderr; a dry run and a build error writing neither file, and a failed `--validate` writing the editions and the manifest but no history; no `git` in the builder, and a build without `--validate` completing with every process call made to throw; regions listed from core helpers only; a region contract error stopping the build; and `metadata.cost` copied. Run `node examples/fm-spacing-rhythm-audit/tests/build.harness.mjs` from `figma/fm-figma-skill-creator`; it prints `20 cases, 0 failed` and exits 1 on any failure. |
| `schema.spacing.json` | The compare schema for this skill's report: key columns, the main-table header names with their alternative spellings, the header-line labels with their alternatives and the modes that print them, the fields they map to, the priority line, the optional header lines, and how a `fix` object prints. See "Compare" below. |
| `fixtures/` | Verbatim in-app outputs and counts from the v1.2 scale test (2026-11-02), kept as history, and six synthetic 2.2 reports for the compare: `report-scope2.md` (token mode) and `report-scope1.md` (rhythm mode) with their altered twins, `report-scope2-alt-headers.md`, and `report-scope2-unknown-header.md`. See the caveats below. |

## File keys

| File | Key | Used for |
| --- | --- | --- |
| `fm-spacing-audit-seed` | `hSEurPqV8Dgzn9yTwPSnnL` | Scopes 1 and 2, the apply and revert proofs, and the real-recon ideation deck |
| `fm-spacing-audit-notokens` | `idjl35MjLGg4IJtPPH86GA` | Scope 5: one vertical auto-layout frame `Plain` (id `1:2`), padding 18 on every side, no variables |
| Simple Design System (Futuremotion's Community duplicate) | `RoEqd4VFbADE0s0nZ0n8Yj` | Scopes 3 and 4, page `Sections` (id `348:13000`), 844 auto-layout frames |
| `fm-probe-scratch` | `kXhDI9zBD5rbh00c3Lzt9i` | Not used here. It is the capability probe's scratch file, listed for completeness. |

The seed and no-tokens files were created on 2026-11-03 UTC with `create_new_file`, which applied the names in this table. Over `use_figma`, `figma.root.name` reads back as "Document" for any file and cannot be set, so the key, not the root name, identifies a file: open them with `https://www.figma.com/design/<key>/`. They replace the 2026-11-02 seed file `hPBA9odanfBNpvMRTPXZLJ` that the v1.x entries in `EVAL-LOG.md` used.

## SEED_SELECTION

Scopes 1 and 2 select these twelve top-level nodes by name, in this order: Card, Card / A, Card / B, Card / Override, Hero, Bound padding, Fractional, Hidden scratch, Token card, Alias card, Default card, Compact card.

The names are distinct. The oracle resolves each one to exactly one top-level node on the page and throws, naming it, on zero or several matches. `Hidden scratch` is in the list on purpose, so `hiddenSkipped` is exercised. When `modesSupported` is false, the seed skips `Compact card` and the list has eleven names.

## modesSupported

`true`. The account's plan allowed a second mode, so `Spacing` has the modes Default (`2:1`) and Compact (`2:2`). `Legacy` has one mode, Default (`2:0`). Read back after seeding, `Compact card` padding top is 10: it is bound to `Space/300`, which is 10 in Compact. The multi-mode case (Review Focus 3) is therefore pinned by scope 2.

## Rerun over MCP

1. Load the `figma-use` skill, call `create_session` with the file key, and pass the returned `sessionId` on every later `use_figma` call.
2. Seed: send `seed.use_figma.js` through `use_figma` as-is. The result is `{ ids, variableIds, collectionIds, modesSupported, created, skipped }`, and a rerun returns `created: []` with the same ids.
3. Oracle: edit the three preamble lines, then send the file as-is.
   - `SELECTION`: `"page"` selects every top-level node on the page, which is how this suite defines a page scope. The master helper itself only walks the current selection. Otherwise use an array of top-level names, for example the twelve above.
   - `PAGE`: `null` keeps the current page. `use_figma` starts every call on the file's first page, so set a page name (for example `"Sections"`) to audit any other page.
   - `MODE`: `"tokens"` or `"rhythm"`. Without spacing tokens the helper falls back to rhythm by itself, which is what scope 5 checks.
4. Compare the returned object with the matching `scopes[]` entry: `counts`, then `rows`, `unbound`, `onRhythmNoToken`, `aliasMatched`, `boundPassed`, `offRhythmTokens`, and the token fields. A run of the skill's own collect has `tokenCount` where the oracle has `tokens`, and no `unbound[].ids`; compare those two fields only against an oracle run.
5. Proofs (scope 2): run the apply helper on `Token card` padding left with the `Space/200` variable id, then the revert helper with the returned `applied` list as its `changes` array (expect `reverted: 1`). Set the padding to 12 by hand and run revert again with the same list: expect `skipped` with `reason: "changed since"` and `actual: 12`. Afterwards restore the seed: padding left 8, unbound. The proofs in `expected.json` are the 2026-11-13 run of the 2.2 apply, verify, and revert helpers as written (top-level form), one `use_figma` call per step; `proofs.verify` holds the verify helper's return and `proofs.before` the reading before apply. Every value matched the 2026-11-03 run. After the restore, scopes 1 and 2 were rerun and returned results byte-identical to the runs before the proofs, so the seed ended as it started.

| Scope | File | Page | Selection | MODE sent | Mode returned |
| --- | --- | --- | --- | --- | --- |
| 1 | seed | Seed | SEED_SELECTION | rhythm | rhythm |
| 2 | seed | Seed | SEED_SELECTION | tokens | tokens |
| 3 | Simple Design System copy | Sections | page | tokens | tokens |
| 4 | Simple Design System copy | Sections | page | rhythm | rhythm |
| 5 | no-tokens | Page 1 | page | tokens | rhythm (no tokens) |

## Oracle hunks

`diff <collect fence> tests/oracle.use_figma.js` shows these hunks and nothing else. Extract the fence from `SKILL.md` (the block after `// helper: collect`) into a scratch file outside the repository first.

1. A four-line header comment naming master 2.2, then the preamble: `SELECTION`, `PAGE`, and the block that switches page and selects the scope. It sits before the fence's first line.
2. `let MODE = "discover"` becomes `let MODE = "tokens"`, the per-scope preset.
3. `MAX_ROWS = 60` becomes `MAX_ROWS = Infinity`.
4. After `for (const n of page.selection) await walk(n, false, null);`, one line clears the selection the preamble set.
5. Before `return out;`, a three-line block restores `out.tokens` and each `unbound[]` entry's `ids`.

The fence ends without a newline and the file ends with one, so `diff` also reports `\ No newline at end of file` on the last line.

## Scopes 3 and 4

Filled from Futuremotion's fresh Community duplicate (`RoEqd4VFbADE0s0nZ0n8Yj`), with `PAGE = "Sections"`, `SELECTION = "page"`, and `MODE` set to `tokens` (scope 3) and `rhythm` (scope 4). The page was found by name; its id in this duplicate is `348:13000`. Both runs measured 844 frames, skipped 9 hidden, and counted 4 absolute children. In the 2026-11-13 run (2.2) the returned payloads were 9,985 bytes (scope 3) and 5,653 bytes (scope 4) in oracle shape, and 6,124 and 2,502 bytes without `tokens` and `unbound[].ids` (the skill's own shape), all well under the 48,000-byte `use_figma` limit. Scopes 1, 2, and 5 returned 7,414, 9,940, and 1,379 bytes in oracle shape. Node ids in these scopes belong to this duplicate; a different copy needs a rerun.

## 2.2 deltas

Against the 2.0 fixture, the 2026-11-13 run changed:

- Scope 3: `byPriority` from P0 7, P1 3 to P0 2, P1 3, P3 5. The five `AI Chatbot` (`4331:7191`) values of 20 (four paddings and the gap) are near misses: P3, `fix.nearMiss: true`, bind `Space/400` (16) with `Space/600` (24) as the alternative, note "tie: Space/400 (16) or Space/600 (24)". The other five rows are unchanged and now sort ahead of them.
- Scope 2: `Hero` gap 14 binds `Space/400` (16) instead of `Space/300` (12), by the tie-break toward the multiple of 8. Counts are unchanged. The opportunity rows (rows 11 to 21) now sort by path, then property, and the two `Card` rows (padding top and bottom 16) gain "; inherited by 3 instances".
- `spacingCollection` gains `minPositive` and `minNegative`: 2 and −24 on scopes 3 and 4, 4 and `null` on scopes 1 and 2.
- Scopes 1, 4, and 5: counts and rows unchanged.

## Collect result fields

One table for the producer (the collect helper and this oracle) and every consumer (`expected.json`, the compare script). "Both" means both modes emit the field; "Tokens only" means rhythm mode returns it empty or zero.

| Field | Type | Mode | Returned by |
| --- | --- | --- | --- |
| `generated` | string, run date `YYYY-MM-DD` | file level | `expected.json` only |
| `masterVersion` | string, the master's `metadata.version` | file level | `expected.json` only |
| `seedFileKey`, `notokensFileKey`, `simpleDesignSystemFileKey` | string | file level | `expected.json` only |
| `modesSupported` | boolean | file level | `expected.json` only |
| `scopes[]` | array of scope objects, below | file level | `expected.json` only |
| `scope`, `fileKey`, `page`, `selection` | number, string, string, `"page"` or array of names | per scope | `expected.json` only (the run's inputs) |
| `mode` | `"tokens"` or `"rhythm"` | Both | shipped helper and oracle |
| `counts` | `{ framesMeasured, hiddenSkipped, notMeasurable, byPriority: { P0, P1, P2, P3 } }`, numbers | Both | shipped helper and oracle, as top-level fields; `expected.json` nests them |
| `tokens` | array of `{ id, name, value, collection, modeId, modeName, isAlias, candidate }`, one per variable per mode of the spacing collection | Both (empty without a spacing collection) | oracle only |
| `tokenCount` | number, `tokens.length` | Both | shipped helper (the oracle also returns it; `expected.json` does not store it) |
| `candidateValues` | sorted unique numbers, the spacing collection's non-alias Default-mode values | discover only | shipped helper only (the discover return) |
| `libraryTokens` | `"none"`, `"present, not audited"`, or `"unavailable"` | Both | shipped helper and oracle |
| `spacingCollection` | `{ id, name, defaultModeName, min, max, minPositive, minNegative }` or `null`; `minPositive` is the smallest value above 0 or `null`, `minNegative` is `min` when below 0, else `null` | Both | shipped helper and oracle |
| `matchedCollections` | array of `{ name, count, reasons }`: collections with matched but unoffered variables | Both | shipped helper and oracle |
| `unbound` | array of `{ tokenName, tokenId, modeName, count, exampleId, examplePath }`, by count descending | Tokens only (`[]` in rhythm) | shipped helper and oracle |
| `unbound[].ids` | array of the node ids that hold this bind opportunity | Tokens only | oracle only |
| `onRhythmNoToken` | number | Tokens only (0 in rhythm) | shipped helper and oracle |
| `aliasMatched` | number | Tokens only (0 in rhythm) | shipped helper and oracle |
| `boundPassed` | number: every bound value in tokens mode; bound values on the grid in rhythm mode | Both | shipped helper and oracle |
| `offRhythmTokens` | array of `{ name, value, modeName, values }` | Both | shipped helper and oracle |
| `rows` | array of row objects, below; capped at 60 by the shipped helper, uncapped by the oracle | Both | shipped helper and oracle |
| `proofs` | apply, verify, and revert proof record: `fileKey`, `node`, `before`, `apply { fixes, result, verify, readback }`, `revertClean`, `revertAfterHandEdit`, `restored`, `runAt`, `note` | scope 2 only | `expected.json` only |
| `rows[].id` | string, the node the row names (the main component for an inherited value) | Both | shipped helper and oracle |
| `rows[].path` | string, last four named segments, with the page and "(main component)" when they apply | Both | shipped helper and oracle |
| `rows[].group` | string, outermost component ancestor or top-level frame | Both | shipped helper and oracle |
| `rows[].property` | `Padding top`, `Padding right`, `Padding bottom`, `Padding left`, `Gap`, or `Row gap` | Both | shipped helper and oracle |
| `rows[].current` | number | Both | shipped helper and oracle |
| `rows[].nearest` | number, the target value | Both | shipped helper and oracle |
| `rows[].delta` | number, `nearest - current` to two decimals | Both | shipped helper and oracle |
| `rows[].priority` | `P0` to `P3`, or `—` on a negative-value row | Both (`—` and near-miss P3 in tokens only) | shipped helper and oracle |
| `rows[].boundId` | variable id or `null` | Both | shipped helper and oracle |
| `rows[].note` | string, notes joined by semicolons | Both | shipped helper and oracle |
| `rows[].fix` | object, or `null` on a negative-value row | Both | shipped helper and oracle |
| `rows[].fix.kind` | `"set"` or `"bind"` | `bind` in tokens only | shipped helper and oracle |
| `rows[].fix.value` | number | Both | shipped helper and oracle |
| `rows[].fix.variableId`, `rows[].fix.name`, `rows[].fix.modeName` | string, on `bind` | Tokens only | shipped helper and oracle |
| `rows[].fix.reason` | `"nearest on-grid"` (rhythm) or `"no token within 4"` (tokens), on `set` | Both | shipped helper and oracle |
| `rows[].fix.nearMiss` | `true` on a near miss, absent otherwise | Tokens only | shipped helper and oracle |
| `rows[].fix.alternatives` | `[{ name, value }]`, the tied second token, on a near miss with a tie | Tokens only | shipped helper and oracle |
| `rows[].ids` | array of node ids the row covers | Both | shipped helper and oracle |
| `rows[].count` | number, `ids.length` | Both | shipped helper and oracle |

The helper also returns `truncated`, `values`, `tableRows`, `byGroup`, `boundValues`, and `boundTokens`; `expected.json` does not store them.

## Fixture caveats

- The four `run-*` files in `fixtures/` were captured at v1.2 on 2026-11-02 from the first Simple Design System copy (`MvJFAtAswCm20cI7hEtc0v`). The node ids inside them will not match a fresh duplicate.
- That copy was later edited: run B2 snapped five gaps. A fresh copy starts from the Community original, so its results differ wherever those gaps were.
- 2.0 classifies values differently from v1.2. In rhythm mode the spacing collection's Default-mode values count as on-grid, so the twelve `Space/150` values now pass. In token mode, bind opportunities and token snaps replace number snaps. Read the fixtures as history, not as expected output.
- The `run-*.md` fixtures are verbatim agent output. They fail markdownlint on purpose (inline HTML node links, no top-level heading) and stay unedited. Lint the example folder with `tests/fixtures/**` excluded.
- The two `report-scope2*.md` fixtures are synthetic, not captures. They were generated from scope 2 of `expected.json` in the master's Output contract layout (token mode, signed deltas with the minus sign), with the in-app agent's decoration injected: bold around three layer names and the header labels, an en-dash in two negative deltas, every main-table layer wrapped in `<figma-node-link node-id="…">`, a leading "… / " on one path, `bind Space/300 (Compact)` naming the mode, and no "Matches an alias" line. The altered twin changes the `Hero` gap row's Nearest and Fix (16 and `bind Space/400` to 12 and `bind Space/300`) and deletes the `Fractional` padding right row. Regenerate them, rather than editing them, if scope 2 changes.
- `report-scope1.md` and `report-scope1-altered.md` are the rhythm-mode pair, generated the same way from scope 1: a "Mode: rhythm" line, "Bound to variables" in place of the token-mode lines, `set` fixes, the same kinds of decoration. The altered twin changes the `Card` padding right row's Nearest and Fix (20 and `set 20` to 16 and `set 16`) and deletes the `Bound padding` padding left row.
- `report-scope2-alt-headers.md` is `report-scope2.md` with the spellings of the v1.2 capture `run-b1-sections-audit.md`: "Absolute-positioned children excluded" for the not-measurable label and "Layer / path" for the layer column. `report-scope2-unknown-header.md` names the layer column "Node", a spelling the schema does not know, to pin the exit-2 message.

## Compare

`scripts/oracle-compare.mjs` compares a report pasted from the in-app agent, or an oracle-shaped `use_figma` return, with one scope of `expected.json`, driven by `schema.spacing.json`. It prints the header counts (expected, observed, delta), the priority counts, the rows missing from the report, the rows extra in it, the per-row mismatches in priority, nearest, fix, and delta keyed by layer path, property, and current value, a result line, and an EVAL-LOG entry stub built from the entry template in `templates/EVAL-LOG.md`. Run from `figma/fm-figma-skill-creator`:

```bash
node scripts/oracle-compare.mjs --expected examples/fm-spacing-rhythm-audit/tests/expected.json --scope 2 --schema examples/fm-spacing-rhythm-audit/tests/schema.spacing.json --report examples/fm-spacing-rhythm-audit/tests/fixtures/report-scope2.md
node scripts/oracle-compare.mjs --expected examples/fm-spacing-rhythm-audit/tests/expected.json --scope 2 --schema examples/fm-spacing-rhythm-audit/tests/schema.spacing.json --report examples/fm-spacing-rhythm-audit/tests/fixtures/report-scope2-altered.md
node scripts/oracle-compare.mjs --expected examples/fm-spacing-rhythm-audit/tests/expected.json --scope 3 --schema examples/fm-spacing-rhythm-audit/tests/schema.spacing.json --run <a saved use_figma return for scope 3>
```

The first prints `0 missing, 0 extra, 0 mismatched` with every count delta 0 and exits 0. The second exits 1 with `Fractional · Padding right · 15.5` missing and `Hero · Gap · 14: nearest 16 vs 12; fix bind Space/400 vs bind Space/300` mismatched. The third exits 0 on the raw return scope 3 was assembled from; `--run` reads counts from the return's top-level fields and compares the same counts and rows, except token-only counts that a rhythm-mode return does not carry (see the `modes` paragraph below).

The other synthetic reports, with the same `--expected` and `--schema`:

| `--scope` | `--report fixtures/…` | Exit | What it shows |
| --- | --- | --- | --- |
| 1 | `report-scope1.md` | 0 | A rhythm-mode report compares clean; the token-mode lines are listed as not printed in rhythm mode |
| 1 | `report-scope1-altered.md` | 1 | `Bound padding · Padding left · 18` missing; `Card · Padding right · 19: nearest 20 vs 16; fix set 20 vs set 16` |
| 2 | `report-scope2-alt-headers.md` | 0 | The captured spellings "Layer / path" and "Absolute-positioned children excluded" are read |
| 2 | `report-scope2-unknown-header.md` | 2 | The message lists every header row the report has, so the missing spelling can be added to the schema |

Exit codes:

| Exit | Meaning |
| --- | --- |
| 0 | Nothing missing, extra, or mismatched, and every count within tolerance |
| 1 | Any count outside tolerance, or any missing, extra, or mismatched row, or a compared column missing from the report table |
| 2 | An input could not be read or parsed: a bad argument, unreadable JSON, no such scope, no "Off-grid values" line, or no table holding the key columns while the scope has rows (the message lists the header rows found) |

Schema entries in `columns` and `headerLines` are either a field name or an object `{ "field", "aliases", "modes" }`. The key is the canonical spelling, from the master's Output contract; `aliases` are other spellings with evidence behind them, here the ones in the v1.2 captures under `fixtures/` ("Layer / path", "Layer", "Absolute-positioned children excluded"). Labels and column names match after the same cleaning as cells, ignoring case. `modes` lists the modes whose report prints the line, following the Output contract: "Bound values", "On rhythm, no matching token", and "Matches an alias" are token mode only, so a rhythm-mode report is neither expected to print them nor flagged for leaving them out. For a report, the mode comes from the oracle scope. A `--run` compare applies `modes` only to fields the run does not carry, judged against the scope's mode. A header line whose `modes` leave out the scope's mode, and whose field is absent from the return, is listed as "Not carried by the run, and not printed in rhythm mode, not compared". That is the return of a helper with the token-conformance pack stripped, which has no token-only counts to report. A field the run carries is compared whatever its `modes`, and an absent field whose `modes` include the scope's mode, or that has no `modes`, is a difference. The return's own `mode` never widens what is set aside. When the return carries a `mode`, it is printed as "Mode (expected, observed)" and must equal the scope's; a different one is a difference (exit 1), even when every count matches.

Rhythm mode's own `Bound to variables: <n> values` line is not compared. Its number is the helper's `boundValues` (bound values in the table, 5 in scope 1), not `boundPassed` (1 in scope 1), and `expected.json` does not store `boundValues`, so it is not an alias of "Bound values".

`--frame-tolerance <n>` (default 0) lets `framesMeasured` and `boundPassed` drift by up to n, because the in-app agent can count a few frames differently from the oracle. Every other count, the priority counts included, must match exactly. An omitted optional header line ("Matches an alias") reads as 0; any other missing header line is a difference. Before reading, the parser removes the agent's decoration: `**` bold, en and em dashes and the minus sign become a hyphen, node-link markup becomes its text, a leading "… / " on a path is dropped, "→" reads as "->", and thousands separators are ignored. A numeric cell (Current, Nearest, Delta) counts as a number only when the whole cleaned cell is one, so `16 or 12` and `+2 pt` are mismatches, and numbers compare exactly, with no epsilon: the helper rounds to two decimals and the report prints that same number. A row that ends before a compared column reads as absent there, and an empty cell reads as empty; both are mismatches. A Fix cell may name the token's mode after the token ("bind Space/300 (Compact)"), but only the mode the oracle recorded. Expected rows follow the master's print rule: on more than 50 frames the token-mode bind-opportunity rows (P3, delta 0) are left out.

`tests/compare.harness.mjs` pins all of this. Run `node examples/fm-spacing-rhythm-audit/tests/compare.harness.mjs` from `figma/fm-figma-skill-creator`; it prints one line per case and `24 cases, 0 failed`, and exits 1 on any failure. It checks the exit code and the missing, extra, and mismatched counts of the six report fixtures and of an oracle-shaped `--run` built from scope 3, plus variants it writes to a temporary folder: a short row, empty cells, numeric cells that are not a whole number or differ by 0.004, a changed run, runs without the three token-only counts (scope 5, rhythm, compares clean and names them as not compared; scope 2, tokens, is flagged), a rhythm run carrying a wrong token-only count (flagged), runs whose own `mode` differs from the scope's (flagged, with or without the token-only counts, and named on the Result line), a rhythm run with no `mode` and no token-only counts (the shape the stripped helper returns; compares clean), and copies of the script with the en-dash fold, the ellipsis drop, or the node-link strip disabled, each of which must stop the clean report comparing clean.

What the compare does not check, one line each:

- The Mode line (`Mode: tokens (Spacing)` or `rhythm`) and the Scale line.
- The "(N values in N rows)" parenthetical on the "Off-grid values" line.
- The Bind opportunities line and its table (token, count, example layer), and the "Tokens off the 4/8 rhythm" and "Matched but not offered" lines.
- The Note column.
- Rhythm mode's `Bound to variables: <n> values` line (see above).
- The mode after a bound token in the Fix cell is optional: a report that writes `bind Space/300` for the Compact row passes as well as one that writes `bind Space/300 (Compact)`; only a wrong mode is flagged.

Known limitation: a report of more than 30 rows. The Output contract tells the agent to show a "By component" summary, the top 30 rows, and then the remaining count per priority, but it prescribes no sentence that states the table is partial, so the compare has nothing reliable to key on. Every row beyond the 30 shown is listed as missing. No scope in `expected.json` has more than 21 printed rows.
