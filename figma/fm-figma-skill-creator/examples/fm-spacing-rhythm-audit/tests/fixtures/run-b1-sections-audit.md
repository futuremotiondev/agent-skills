<!-- Verbatim in-app output, Figma agent, skill v1.2, 2026-11-02. Prompt: "Audit the spacing on this page" on the Sections page of the Simple Design System copy, nothing selected, then "1". 10 + 24 credits, 18 s + 42 s. -->
## Spacing rhythm audit: Sections

- **Scale:** 4 pt below 48; 8 pt from 48 onward.
- **Frames measured:** 842 · Hidden skipped: 9 · Absolute-positioned children excluded: 4
- **Off-grid values:** P0 **2** · P1 **3** · P2 **12** · P3 **1** — 18 values across 10 rows.
- **No changes applied.** Inherited values are listed at their main component rather than repeated per instance.

| # | Priority | Layer / path | Property | Current | Nearest | Delta | Note |
|---|---|---|---|---:|---:|---:|---|
| 1 | P0 | <figma-node-link node-id="6062:12601">Hero (Slot) / Desktop / Slot</figma-node-link> | Gap | 10 | 8 | −2 | Direct child of main component |
| 2 | P0 | <figma-node-link node-id="6062:12602">Hero (Slot) / Mobile / Slot</figma-node-link> | Gap | 10 | 8 | −2 | Direct child of main component |
| 3 | P1 | <figma-node-link node-id="565:14466">Checkbox Field / Checkbox and Label / Checkbox</figma-node-link> | Gap | 10 | 8 | −2 | Main on **Inputs**; inherited by 9 instances |
| 4 | P1 | <figma-node-link node-id="4317:11278">AI Sidebar / Block / Block / Block</figma-node-link> | Gap | 10 | 8 | −2 | Main on **AI Chat**; inherited by 1 instance |
| 5 | P1 | <figma-node-link node-id="4317:10977">AI → Conversation / Content / Block</figma-node-link> | Gap | 10 | 8 | −2 | Main on **AI Chat**; inherited by 2 instances |
| 6 | P2 | <figma-node-group-link node-ids="4317:11256,4317:12913,4317:11262,4317:11264,4317:11266">AI Sidebar / nested Blocks — 5 frames</figma-node-group-link> | Padding right | 6 | 8 | +2 | Bound to **Space/150**; main on **AI Chat** |
| 7 | P2 | <figma-node-group-link node-ids="4317:11256,4317:12913,4317:11262,4317:11264,4317:11266">AI Sidebar / nested Blocks — 5 frames</figma-node-group-link> | Padding left | 6 | 8 | +2 | Bound to **Space/150**; main on **AI Chat** |
| 8 | P2 | <figma-node-link node-id="4317:10907">AI Chat → User message</figma-node-link> | Padding top | 6 | 8 | +2 | Bound to **Space/150**; main on **AI Chat**; inherited by 2 instances |
| 9 | P2 | <figma-node-link node-id="4317:10907">AI Chat → User message</figma-node-link> | Padding bottom | 6 | 8 | +2 | Bound to **Space/150**; main on **AI Chat**; inherited by 2 instances |
| 10 | P3 | <figma-node-link node-id="2010:15577">Avatar Block / Info</figma-node-link> | Gap | 2 | 0 | −2 | Optional half-step; main on **Avatars**; inherited by 18 instances |

The 12 variable-bound values use an intentional **6 pt token** that falls outside this audit’s default scale. I won’t overwrite those bindings. The 2 pt gap is also a common intentional half-step, so it’s low priority.

Apply the snaps listed above? 1. All, 2. P0 and P1 only, 3. Pick by row number, 4. None.
