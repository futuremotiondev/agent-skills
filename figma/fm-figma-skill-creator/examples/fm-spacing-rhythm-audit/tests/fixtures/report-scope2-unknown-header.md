<!-- Synthetic report for oracle-compare, not a capture: report-scope2.md with a layer column header ("Node") that no schema spelling matches, so the compare exits 2 and lists the header rows it found. -->
## Spacing rhythm audit: Seed selection (12 layers)

- **Mode:** tokens (Spacing)
- **Scale:** 4 pt below 48, 8 pt from 48
- **Frames measured:** 11 · Hidden skipped: 1 · Not measurable (absolute children): 0
- **Off-grid values:** P0 **2** · P1 **4** · P2 **0** · P3 **4** (10 values in 10 rows)
- **Bound values:** 6 passed
- **Tokens off the 4/8 rhythm:** legacy/odd-18 = 18 (4 values); Space/300 = 10 in Compact (1 value); a scale decision, not a defect
- **Bind opportunities:** 11 values across 4 tokens (table below)
- **On rhythm, no matching token:** 4
- **Matched but not offered:** Legacy (1 not elected)
- No changes applied.

## Bind opportunities

| Token (mode) | Values | Example layer |
| --- | --- | --- |
| Space/200 (Default) | 7 | <figma-node-link node-id="2:18">Token card</figma-node-link> |
| Space/400 (Default) | 2 | <figma-node-link node-id="2:11">Card</figma-node-link> |
| Space/150 (Default) | 1 | <figma-node-link node-id="2:18">Token card</figma-node-link> |
| Space/300 (Compact) | 1 | <figma-node-link node-id="2:21">Compact card</figma-node-link> |

| # | Priority | Node | Property | Current | Nearest | Fix | Delta | Note |
| --- | --- | --- | --- | ---: | ---: | --- | ---: | --- |
| 1 | P0 | <figma-node-link node-id="2:11">Card</figma-node-link> | Padding left | 52 | 48 | set 48 | –4 | inherited by 3 instances; no token within 4 |
| 2 | P0 | <figma-node-link node-id="2:11">Card</figma-node-link> | Padding right | 19 | 16 | bind Space/400 | −3 | inherited by 3 instances |
| 3 | P1 | <figma-node-link node-id="2:14">**Hero**</figma-node-link> | Gap | 14 | 16 | bind Space/400 | +2 |  |
| 4 | P1 | <figma-node-link node-id="2:20">Default card</figma-node-link> | Padding left | 10 | 8 | bind Space/200 | –2 |  |
| 5 | P1 | <figma-node-link node-id="2:11">Card</figma-node-link> | Gap | 13 | 12 | bind Space/300 | −1 | inherited by 2 instances |
| 6 | P1 | <figma-node-link node-id="2:28">**Card / Override**</figma-node-link> | Gap | 15 | 16 | bind Space/400 | +1 | instance override; main component uses 13 |
| 7 | P3 | **<figma-node-link node-id="2:16">Fractional</figma-node-link>** | Padding top | 15.5 | 16 | bind Space/400 | +0.5 | fractional |
| 8 | P3 | <figma-node-link node-id="2:16">Fractional</figma-node-link> | Padding right | 15.5 | 16 | bind Space/400 | +0.5 | fractional |
| 9 | P3 | <figma-node-link node-id="2:16">Fractional</figma-node-link> | Padding bottom | 15.5 | 16 | bind Space/400 | +0.5 | fractional |
| 10 | P3 | <figma-node-link node-id="2:16">Fractional</figma-node-link> | Padding left | 15.5 | 16 | bind Space/400 | +0.5 | fractional |
| 11 | P3 | <figma-node-link node-id="2:19">Alias card</figma-node-link> | Padding bottom | 8 | 8 | bind Space/200 | 0 | unbound; bind to Space/200 |
| 12 | P3 | <figma-node-link node-id="2:19">Alias card</figma-node-link> | Padding right | 8 | 8 | bind Space/200 | 0 | unbound; bind to Space/200 |
| 13 | P3 | <figma-node-link node-id="2:19">Alias card</figma-node-link> | Padding top | 8 | 8 | bind Space/200 | 0 | unbound; bind to Space/200 |
| 14 | P3 | <figma-node-link node-id="2:11">Card</figma-node-link> | Padding bottom | 16 | 16 | bind Space/400 | 0 | unbound; bind to Space/400; inherited by 3 instances |
| 15 | P3 | <figma-node-link node-id="2:11">Card</figma-node-link> | Padding top | 16 | 16 | bind Space/400 | 0 | unbound; bind to Space/400; inherited by 3 instances |
| 16 | P3 | <figma-node-link node-id="2:21">Compact card</figma-node-link> | Padding left | 10 | 10 | bind Space/300 (Compact) | 0 | unbound; bind to Space/300 |
| 17 | P3 | <figma-node-link node-id="2:18">… / Token card</figma-node-link> | Gap | 6 | 6 | bind Space/150 | 0 | unbound; bind to Space/150 |
| 18 | P3 | <figma-node-link node-id="2:18">Token card</figma-node-link> | Padding bottom | 8 | 8 | bind Space/200 | 0 | unbound; bind to Space/200 |
| 19 | P3 | <figma-node-link node-id="2:18">Token card</figma-node-link> | Padding left | 8 | 8 | bind Space/200 | 0 | unbound; bind to Space/200 |
| 20 | P3 | <figma-node-link node-id="2:18">Token card</figma-node-link> | Padding right | 8 | 8 | bind Space/200 | 0 | unbound; bind to Space/200 |
| 21 | P3 | <figma-node-link node-id="2:18">Token card</figma-node-link> | Padding top | 8 | 8 | bind Space/200 | 0 | unbound; bind to Space/200 |

Rows 11 to 21 are optional bind opportunities. Row 6 is an instance override and stays unchanged unless you approve the override.

Apply the snaps listed above? 1. All, 2. P0 and P1 only, 3. Pick by row number, 4. None.
