# Tests for fm-spacing-rhythm-audit 2.0

These are the oracle fixtures for the 2.0 example. A script run over the Figma MCP server (`use_figma`) produces the exact result the skill should reach, and an in-app or MCP run of the skill is compared against it. The fixtures are throwaway test files, not skill requirements: the skill works in any file.

## Files

| File | What it is |
| --- | --- |
| `seed.use_figma.js` | Builds the seed on the page named "Seed": the `Card` component and three instances, eight test frames, and the `Legacy` and `Spacing` variable collections. It is idempotent by name, so a second run creates nothing and returns the same ids. Top-level `await`, no wrapper. |
| `oracle.use_figma.js` | The master's collect helper as of the Plan 1 fix round (parent `da17b9e`), unwrapped for `use_figma`. It adds a preamble (`SELECTION`, `PAGE`, `MODE`), lifts `MAX_ROWS` to `Infinity`, clears the selection after the walk, and adds a block before the return that restores the two fields the helper no longer returns: the full `tokens` list and each `unbound[]` entry's node `ids`. Nothing else differs from the fence in `SKILL.md`. |
| `expected.json` | Expected results per scope, in the shape Plan 2's compare script reads. Rows are uncapped. `tokens` and `unbound[].ids` come from the oracle's restore block; the skill's own collect returns `tokenCount` and no ids, which keeps it under the 48,000-byte `use_figma` limit. The apply and revert proofs sit under `scopes[1].proofs`. `masterCommit` reads `da17b9e+final-fix` because a file cannot name the commit that contains it; Plan 2 pins the real hash. |
| `fixtures/` | Verbatim in-app outputs and counts from the v1.2 scale test (2026-11-02), kept as history. See the caveats below. |

## File keys

| File | Key | Used for |
| --- | --- | --- |
| `fm-spacing-audit-seed` | `hSEurPqV8Dgzn9yTwPSnnL` | Scopes 1 and 2, the apply and revert proofs, and the real-recon ideation deck |
| `fm-spacing-audit-notokens` | `idjl35MjLGg4IJtPPH86GA` | Scope 5: one vertical auto-layout frame `Plain` (id `1:2`), padding 18 on every side, no variables |
| Simple Design System (Futuremotion's Community duplicate) | `RoEqd4VFbADE0s0nZ0n8Yj` | Scopes 3 and 4, page `Sections` (id `348:13000`), 844 auto-layout frames |
| `fm-probe-scratch` | `kXhDI9zBD5rbh00c3Lzt9i` | Not used here. It is the capability probe's scratch file, listed for completeness. |

The seed and no-tokens files were created on 2026-11-03 UTC. They replace the 2026-11-02 seed file `hPBA9odanfBNpvMRTPXZLJ` that the v1.x entries in `EVAL-LOG.md` used.

## SEED_SELECTION

Scopes 1 and 2 select these twelve top-level nodes by name, in this order: Card, Card / A, Card / B, Card / Override, Hero, Bound padding, Fractional, Hidden scratch, Token card, Alias card, Default card, Compact card.

The names are distinct. The oracle resolves each one to exactly one top-level node on the page and throws, naming it, on zero or several matches. `Hidden scratch` is in the list on purpose, so `hiddenSkipped` is exercised. When `modesSupported` is false, the seed skips `Compact card` and the list has eleven names.

## modesSupported

`true`. The account's plan allowed a second mode, so `Spacing` has the modes Default (`2:1`) and Compact (`2:2`). `Legacy` has one mode, Default (`2:0`). Read back after seeding, `Compact card` padding top is 10: it is bound to `Space/300`, which is 10 in Compact. The multi-mode case (Review Focus 3) is therefore pinned by scope 2.

## Rerun over MCP

1. Load the `figma-use` skill and call `create_session` with the file key.
2. Seed: send `seed.use_figma.js` through `use_figma` as-is. The result is `{ ids, variableIds, collectionIds, modesSupported, created, skipped }`, and a rerun returns `created: []` with the same ids.
3. Oracle: edit the three preamble lines, then send the file as-is.
   - `SELECTION`: `"page"` selects every top-level node on the page, which is how this suite defines a page scope. The master helper itself only walks the current selection. Otherwise use an array of top-level names, for example the twelve above.
   - `PAGE`: `null` keeps the current page. `use_figma` starts every call on the file's first page, so set a page name (for example `"Sections"`) to audit any other page.
   - `MODE`: `"tokens"` or `"rhythm"`. Without spacing tokens the helper falls back to rhythm by itself, which is what scope 5 checks.
4. Compare the returned object with the matching `scopes[]` entry: `counts`, then `rows`, `unbound`, `onRhythmNoToken`, `aliasMatched`, `boundPassed`, `offRhythmTokens`, and the token fields. A run of the skill's own collect has `tokenCount` where the oracle has `tokens`, and no `unbound[].ids`; compare those two fields only against an oracle run.
5. Proofs (scope 2): run the apply helper on `Token card` padding left with the `Space/200` variable id, then the revert helper with the returned `applied` list as its `changes` array (expect `reverted: 1`). Set the padding to 12 by hand and run revert again with the same list: expect `skipped` with `reason: "changed since"` and `actual: 12`. Afterwards restore the seed: padding left 8, unbound.

| Scope | File | Page | Selection | MODE sent | Mode returned |
| --- | --- | --- | --- | --- | --- |
| 1 | seed | Seed | SEED_SELECTION | rhythm | rhythm |
| 2 | seed | Seed | SEED_SELECTION | tokens | tokens |
| 3 | Simple Design System copy | Sections | page | tokens | tokens |
| 4 | Simple Design System copy | Sections | page | rhythm | rhythm |
| 5 | no-tokens | Page 1 | page | tokens | rhythm (no tokens) |

## Scopes 3 and 4

Filled on 2026-11-03 UTC from Futuremotion's fresh Community duplicate (`RoEqd4VFbADE0s0nZ0n8Yj`), with `PAGE = "Sections"`, `SELECTION = "page"`, and `MODE` set to `tokens` (scope 3) and `rhythm` (scope 4). The page was found by name; its id in this duplicate is `348:13000`. Both runs measured 844 frames, skipped 9 hidden, and counted 4 absolute children. The returned payloads were 9,441 bytes (scope 3) and 5,619 bytes (scope 4) in oracle shape, and 5,580 and 2,468 bytes in the skill's own shape (no `tokens`, no `unbound[].ids`), all well under the 48,000-byte `use_figma` limit. Node ids in these scopes belong to this duplicate; a different copy needs a rerun.

## Fixture caveats

- The four files in `fixtures/` were captured at v1.2 on 2026-11-02 from the first Simple Design System copy (`MvJFAtAswCm20cI7hEtc0v`). The node ids inside them will not match a fresh duplicate.
- That copy was later edited: run B2 snapped five gaps. A fresh copy starts from the Community original, so its results differ wherever those gaps were.
- 2.0 classifies values differently from v1.2. In rhythm mode the spacing collection's Default-mode values count as on-grid, so the twelve `Space/150` values now pass. In token mode, bind opportunities and token snaps replace number snaps. Read the fixtures as history, not as expected output.
- The `.md` fixtures are verbatim agent output. They fail markdownlint on purpose (inline HTML node links, no top-level heading) and stay unedited. Lint the example folder with `tests/fixtures/**` excluded.

## Plan 2

Plan 2 adds `scripts/oracle-compare.mjs`, which reads `expected.json` and a pasted report.
