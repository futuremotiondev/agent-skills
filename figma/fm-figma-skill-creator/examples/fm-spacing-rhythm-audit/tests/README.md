# Tests for fm-spacing-rhythm-audit 2.2

These are the oracle fixtures for the 2.2 example. They were first written for 2.0 (2.1 changed instruction wording only), and were regenerated over MCP on 2026-11-13 after 2.2 changed the collect helper: near misses rank P3, the tie-break, the election, the discover fallback, and opportunity-row order and notes. A script run over the Figma MCP server (`use_figma`) produces the exact result the skill should reach, and an in-app or MCP run of the skill is compared against it. The fixtures are throwaway test files, not skill requirements: the skill works in any file.

## Files

| File | What it is |
| --- | --- |
| `seed.use_figma.js` | Builds the seed on the page named "Seed": the `Card` component and three instances, eight test frames, and the `Legacy` and `Spacing` variable collections. It is idempotent by name, so a second run creates nothing and returns the same ids. Top-level `await`, no wrapper. |
| `oracle.use_figma.js` | The master's collect helper at `metadata.version` 2.2, which is already in the top-level form `use_figma` runs (no wrapper). The oracle differs from the fence in `SKILL.md` by exactly the hunks listed under "Oracle hunks" below; nothing else differs. |
| `expected.json` | Expected results per scope, in the shape Plan 2's compare script reads, described field by field under "Collect result fields" below. Rows are uncapped. `tokens` and `unbound[].ids` come from the oracle's restore block; the skill's own collect returns `tokenCount` and no ids, which keeps it under the 48,000-byte `use_figma` limit. The apply and revert proofs sit under `scopes[1].proofs`. `masterVersion` is the master's `metadata.version` the oracle mirrors (`"2.2"`); it replaces Plan 1's `masterCommit`, and nothing in the file is read from git. |
| `collect.harness.mjs` | Runs the master's collect fence under Node against a mock `figma` object, fourteen cases. Run `node examples/fm-spacing-rhythm-audit/tests/collect.harness.mjs` from `figma/fm-figma-skill-creator`; it prints `14 cases, 0 failed` and exits 1 on any failure. A mock proves logic only, never a live number. |
| `fixtures/` | Verbatim in-app outputs and counts from the v1.2 scale test (2026-11-02), kept as history. See the caveats below. |

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
5. Proofs (scope 2): run the apply helper on `Token card` padding left with the `Space/200` variable id, then the revert helper with the returned `applied` list as its `changes` array (expect `reverted: 1`). Set the padding to 12 by hand and run revert again with the same list: expect `skipped` with `reason: "changed since"` and `actual: 12`. Afterwards restore the seed: padding left 8, unbound. The proofs in `expected.json` are the 2026-11-03 run. The 2026-11-13 regeneration ran only the five read-only oracle scopes and did not rerun them, because the apply and revert helpers in 2.2 are identical to that run's MCP form apart from the dropped wrapper.

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
| `proofs` | apply and revert proof record | scope 2 only | `expected.json` only |
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

- The four files in `fixtures/` were captured at v1.2 on 2026-11-02 from the first Simple Design System copy (`MvJFAtAswCm20cI7hEtc0v`). The node ids inside them will not match a fresh duplicate.
- That copy was later edited: run B2 snapped five gaps. A fresh copy starts from the Community original, so its results differ wherever those gaps were.
- 2.0 classifies values differently from v1.2. In rhythm mode the spacing collection's Default-mode values count as on-grid, so the twelve `Space/150` values now pass. In token mode, bind opportunities and token snaps replace number snaps. Read the fixtures as history, not as expected output.
- The `.md` fixtures are verbatim agent output. They fail markdownlint on purpose (inline HTML node links, no top-level heading) and stay unedited. Lint the example folder with `tests/fixtures/**` excluded.

## Plan 2

Plan 2 adds `scripts/oracle-compare.mjs`, which reads `expected.json` and a pasted report.
