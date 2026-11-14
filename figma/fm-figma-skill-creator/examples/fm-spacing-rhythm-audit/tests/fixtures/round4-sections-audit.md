Spacing audit: Sections

I found 5 off-grid gaps and 5 lower-priority token-alignment opportunities. Nothing was changed.

Mode: Size tokens, Default mode
Frames measured: 842 · Hidden skipped: 9 · Absolute-positioned children excluded: 4
Ranked values: P0 2 · P1 3 · P2 0 · P3 5
Bound values: 618 passed, with inherited values counted at their source
Tokens off the 4/8 rhythm: Space/150 = 6, used by 12 bound values. This is a system-scale decision, not a defect.
Matched but not offered: Responsive (1 WIDTH_HEIGHT)
Ranked findings

All proposed bindings below use Default mode. Rows 6–10 already follow the 4 pt rhythm; they are optional token-alignment opportunities.

| # | Priority | Layer / path | Property | Current | Nearest | Fix | Delta | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | P0 | Hero (Slot) / Desktop / Slot | Gap | 10 | 8 | bind Space/200 | −2 | Direct child of a main component |
| 2 | P0 | Hero (Slot) / Mobile / Slot | Gap | 10 | 8 | bind Space/200 | −2 | Direct child of a main component |
| 3 | P1 | AI → Conversation / Content / Block | Gap | 10 | 8 | bind Space/200 | −2 | Main on AI Chat; inherited by 2 instances |
| 4 | P1 | AI Sidebar / Block / Block / Block | Gap | 10 | 8 | bind Space/200 | −2 | Main on AI Chat; inherited by 1 instance |
| 5 | P1 | Checkbox Field / Checked / Checkbox | Gap | 10 | 8 | bind Space/200 | −2 | Main on Inputs; inherited by 9 instances |
| 6 | P3 | AI / AI Chatbot | Padding top | 20 | 16 | bind Space/400 | −4 | Tie: 16 or Space/600 (24) |
| 7 | P3 | AI / AI Chatbot | Padding right | 20 | 16 | bind Space/400 | −4 | Tie: 16 or Space/600 (24) |
| 8 | P3 | AI / AI Chatbot | Padding bottom | 20 | 16 | bind Space/400 | −4 | Tie: 16 or Space/600 (24) |
| 9 | P3 | AI / AI Chatbot | Padding left | 20 | 16 | bind Space/400 | −4 | Tie: 16 or Space/600 (24) |
| 10 | P3 | AI / AI Chatbot | Gap | 20 | 16 | bind Space/400 | −4 | Tie: 16 or Space/600 (24) |

Exact-value bind opportunities

Another 42 unbound values already match tokens—these are not spacing defects.

| Token (Default) | Values | Example layer |
| --- | --- | --- |
| Space/600 | 15 | Card / Horizontal |
| Space/200 | 10 | Navigation Pill List / Row |
| Space/1200 | 6 | Card Grid Image / Desktop / Slot |
| Space/400 | 5 | Accordion / Items |
| Space/300 | 4 | Pricing Card / Text List / Slot |
| Space/050 | 1 | Avatar Block / Info |
| Space/100 | 1 | Slider Field / Label |

To bind these 42 values, select 50 frames or fewer and run the audit again. “All” below covers only rows 1–10. Rows 3–5 would change main components on AI Chat and Inputs, affecting their instances throughout the document.

Apply the snaps listed above? 1. All, 2. P0 and P1 only, 3. Pick by row number, 4. None.
