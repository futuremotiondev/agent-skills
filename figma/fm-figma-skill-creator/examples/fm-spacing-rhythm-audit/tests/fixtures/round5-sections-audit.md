I’ll audit the page against the Size spacing tokens and separate off-token values from unbound values that already match.

Auditing page padding and gaps

## Spacing rhythm audit: Sections

- Mode: tokens (Size)
- Scale: 4 pt below 48, 8 pt from 48; checked against the system’s spacing tokens
- Frames measured: 844 · Hidden skipped: 9 · Not measurable (absolute children): 4
- Off-grid values: P0 2 · P1 3 · P2 0 · P3 5 (10 values in 10 rows)
- Bound values: 622 passed
- Tokens off the 4/8 rhythm: Space/150 = 6 (12 values); a scale decision, not a defect
- Bind opportunities: 42 values across 7 tokens
- On rhythm, no matching token: 0
- Matched but not offered: Responsive (1 WIDTH_HEIGHT)
- No changes applied.

The five P0/P1 findings are **10 px gaps**. The five P3 findings are **20 px values that follow the rhythm**, but fall equally between the 16 and 24 px tokens—not spacing defects.

Inherited values are listed once at their main component. Rows 3–5 refer to main components on other pages; changing those would affect their instances throughout the design.

## Bind opportunities

| Token (mode) | Values | Example layer |
| --- | --- | --- |
| Space/600 (Default) | 15 | Card / Asset Type=Icon, Variant=Default, Direction=Horizontal (page: Cards) |
| Space/200 (Default) | 10 | Navigation Pill List / Direction=Row (page: Navigation) |
| Space/1200 (Default) | 6 | Card Grid Sections / Card Grid Image / Platform=Desktop / Slot |
| Space/400 (Default) | 5 | Accordion / Items (page: Accordion) |
| Space/300 (Default) | 4 | … / Pricing Card / Top / Text List / Slot |
| Space/050 (Default) | 1 | Avatar Block / Info (page: Avatars) |
| Space/100 (Default) | 1 | Slider Field / State=Default / Label (page: Inputs) |

To bind these, select 50 frames or fewer and run again. “All” below covers only the 10 numbered rows.

| # | Priority | Layer (path) | Property | Current | Nearest | Fix | Delta | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | P0 | Hero Sections / Hero (Slot) / Platform=Desktop / Slot | Gap | 10 | 8 | bind Space/200 | −2 |  |
| 2 | P0 | Hero Sections / Hero (Slot) / Platform=Mobile / Slot | Gap | 10 | 8 | bind Space/200 | −2 |  |
| 3 | P1 | Checkbox Field / State=Default, Value Type=Checked / Checkbox and Label / Checkbox (page: Inputs) (main component) | Gap | 10 | 8 | bind Space/200 | −2 | inherited by 9 instances |
| 4 | P1 | AI Sidebar / Block / Block / Block (page: AI Chat) (main component) | Gap | 10 | 8 | bind Space/200 | −2 | inherited by 1 instance |
| 5 | P1 | AI -> Conversation / Content / Block (page: AI Chat) (main component) | Gap | 10 | 8 | bind Space/200 | −2 | inherited by 2 instances |
| 6 | P3 | AI / AI Chatbot | Padding top | 20 | 16 | bind Space/400 | −4 | tie: Space/400 (16) or Space/600 (24) |
| 7 | P3 | AI / AI Chatbot | Padding right | 20 | 16 | bind Space/400 | −4 | tie: Space/400 (16) or Space/600 (24) |
| 8 | P3 | AI / AI Chatbot | Padding bottom | 20 | 16 | bind Space/400 | −4 | tie: Space/400 (16) or Space/600 (24) |
| 9 | P3 | AI / AI Chatbot | Padding left | 20 | 16 | bind Space/400 | −4 | tie: Space/400 (16) or Space/600 (24) |
| 10 | P3 | AI / AI Chatbot | Gap | 20 | 16 | bind Space/400 | −4 | tie: Space/400 (16) or Space/600 (24) |

All proposed bindings use the Default mode.

Apply the snaps listed above? 1. All, 2. P0 and P1 only, 3. Pick by row number, 4. None.
