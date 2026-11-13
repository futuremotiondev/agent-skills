# Seed plan: <skill name>

Copy this file to the skill's `tests/seed-plan.md` in Workflow G step 1 and fill it before writing any script. It is the contract the seed (`tests/seed.use_figma.js`), the oracle (`tests/oracle.use_figma.js`), and the fixture (`tests/expected.json`) are checked against. `examples/fm-spacing-rhythm-audit/tests/` is the worked example; the example rows below come from it.

## Header

- **Skill:** `<fm-name>` at `metadata.version` "<x.y>"
- **File key:** `<file key>` (a throwaway test file, opened as `https://www.figma.com/design/<file key>/`; the key, not the file name, identifies it)
- **Page:** `<page name>` (the seed switches to it by name; `use_figma` starts every call on the file's first page)
- **SELECTION:** `<Name 1>`, `<Name 2>`, `<Name 3>`, in this order

Every name in `SELECTION` is unique among the page's top-level nodes. The seed finds and the oracle selects each node by name, and both throw, naming it, on zero or several matches. Include any node the skill must skip (a hidden frame, a locked layer) so the skip is counted.

## Planted cases

One row per planted case. The planted value is exact (no "about"), and the expected columns are what the report should print for that row.

| Case | Node | Property | Planted value | Binding | Expected priority | Expected fix | Pins |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 (example) | `Hero` | Gap | 14 | none | P1 | bind `Space/400` (16) | the tie-break toward the multiple of 8 |
| 2 (example) | `Fractional` | Padding right | 15.5 | none | P3 | bind `Space/400` (16) | the fractional note |
| 3 | `<node name>` | `<property>` | `<exact value>` | `<variable name or none>` | `<P0 to P3, or none>` | `<fix as the report prints it>` | `<the rule or edge case this row proves>` |

A case that should produce no row (a value already on the grid, a bound value that passes) still gets a line here, with "no row" under Expected priority, so the counts it feeds are checked.

## Modes

One line per scope the oracle runs. A scope is one file, page, selection, and preset; each becomes one `scopes[]` entry in `tests/expected.json`.

| Scope | File key | Page | Selection | Mode sent | Mode expected back |
| --- | --- | --- | --- | --- | --- |
| 1 | `<file key>` | `<page name>` | `SELECTION` | `<mode>` | `<mode>` |
| 2 | `<file key>` | `<page name>` | `page` (every top-level node) | `<mode>` | `<mode, or the fallback the skill should take>` |

- **Variable modes planted:** `<collection: mode names>`, or "one mode only" when the plan allows no second mode. Record which, because a multi-mode case cannot be pinned without it.
- **Fallback case:** `<the scope where the skill should fall back, such as a file with no tokens>`, or "none".

## Proofs

Only for a skill that writes. Each proof is one call per step, run over MCP on the seed and read back afterwards.

| Proof | Node and property | Steps | Expected result |
| --- | --- | --- | --- |
| Apply | `<node>` · `<property>` | read the value, apply the fix, verify, read back | `<value and binding after apply>` |
| Revert clean | the same | revert with the apply result's change list, read back | `<reverted count>`; the value and binding from before apply |
| Revert after edit | the same | after the clean revert, set `<value>` by hand, revert again with the same list, read back | the change is skipped as changed since, and the hand-set value stays |

Restore the seed after the proofs (`<value>`, `<binding>`) and rerun scope 1: the result must be identical to the run before the proofs.
