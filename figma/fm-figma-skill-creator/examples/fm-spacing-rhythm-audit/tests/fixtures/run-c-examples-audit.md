<!-- Verbatim in-app output, Figma agent, skill v1.2, 2026-11-02. Prompt: "Is this on the 8pt grid?" on the Examples page (1,939 auto-layout frames by the oracle's count), nothing selected, then "1". 22 credits, 40 s. Run after the Run B2 fixes, which removed three gap values from this page's results. "4" afterwards returned "I’ve left everything unchanged." for 4 credits. -->
Not entirely. I found **17 off-grid padding and gap values**, grouped into 9 rows. Nothing was changed.

## Spacing rhythm audit: Examples
- **Scale:** 4pt below 48, 8pt from 48—not a strict 8pt-only scale.
- **Frames measured:** 1,937 · Hidden skipped: 0 · Absolute-positioned children excluded: 4
- **Off-grid values:** P0: 4 · P1: 0 · P2: 12 · P3: 1
- Inherited values are listed at their main components, including sources on other pages.

| # | Priority | Layer | Property | Current | Nearest | Delta | Note |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| 1 | P0 | <figma-node-link node-id="175:4451">Home Page / Desktop / Section</figma-node-link> | Gap | 10 | 8 | −2 | |
| 2 | P0 | <figma-node-link node-id="562:8144">Home Page / Mobile / Section</figma-node-link> | Gap | 10 | 8 | −2 | |
| 3 | P0 | <figma-node-link node-id="348:15995">Article / Desktop / Section</figma-node-link> | Gap | 10 | 8 | −2 | |
| 4 | P0 | <figma-node-link node-id="562:10143">Article / Mobile / Section</figma-node-link> | Gap | 10 | 8 | −2 | |
| 5 | P2 | <figma-node-group-link node-ids="4317:11256,4317:12913,4317:11262,4317:11264,4317:11266">AI Sidebar / nested Blocks</figma-node-group-link> | Padding right | 6 | 8 | +2 | 5 frames; inherited; bound to Space/150 |
| 6 | P2 | <figma-node-group-link node-ids="4317:11256,4317:12913,4317:11262,4317:11264,4317:11266">AI Sidebar / nested Blocks</figma-node-group-link> | Padding left | 6 | 8 | +2 | 5 frames; inherited; bound to Space/150 |
| 7 | P2 | <figma-node-link node-id="4317:10907">AI Chat → User message</figma-node-link> | Padding top | 6 | 8 | +2 | Inherited by 2 instances; bound to Space/150 |
| 8 | P2 | <figma-node-link node-id="4317:10907">AI Chat → User message</figma-node-link> | Padding bottom | 6 | 8 | +2 | Inherited by 2 instances; bound to Space/150 |
| 9 | P3 | <figma-node-link node-id="2010:15577">Avatar Block / Info</figma-node-link> | Gap | 2 | 0 | −2 | Optional half-step; inherited by 18 instances |

Rows 5–8 are variable-bound; I would leave their bindings intact. The 2pt gap in row 9 may be intentional.

Apply the snaps listed above? 1. All, 2. P0 and P1 only, 3. Pick by row number, 4. None.
