# EVAL-LOG: fm-spacing-rhythm-audit

One entry per test session. Newest first. Record facts, not impressions: the prompt, the selection, what the agent did, what it should have done, and the change made in response.

## Open questions this skill can settle on upload

This is the first skill built through fm-figma-skill-creator, so its first upload answers questions the research could not. Tick and record each, then copy the answers into `figma/fm-figma-skill-creator/references/troubleshooting.md`.

- [ ] Extra frontmatter keys on upload (try uploading the master, which carries `metadata`): kept / stripped / rejected: not yet tried; the name-and-description-only upload edition was accepted
- [x] Description limit: the Start-from-scratch form rejects more than 1,024 characters (observed). Name limit: not yet probed. This skill's description is 468 chars.
- [x] Body size limit hit: no (upload edition of about 190 lines accepted)
- [x] Markdown tables render in chat output: yes, with clickable node links (`figma-node-link`); question cards do not render Markdown
- [ ] `evaluate_script` ran the collect helper as written: not observable from the chat; results matched the helper's logic exactly
- [ ] `figma.getNodeByIdAsync` available in-app: yes / no
- [ ] `node.boundVariables` readable in-app: yes / no
- [ ] Export produces: ____ (format, whether frontmatter round-trips)

## Static results (2026-11-02)

- Master: 0 errors, 0 warnings (`validate-figma-skill.mjs --edition master`)
- Upload edition: see build log
- Paste edition: see build log
- Coding-agent edition: see build log

## Entries

### 2026-11-02 · v1.1 · Figma Design

- **Edition tested:** paste (`dist/fm-spacing-rhythm-audit.paste.md` in Instructions; name and description typed into the form). The form enforces a 1,024-character description limit.
- **File and selection:** `fm-spacing-audit-seed`, Card reset to 52 / 19 / 13; selection Card, three instances, Hero (5 frames).
- **Prompt 1:** `/fm-spacing-rhythm-audit`. 56 s. Exactly the five expected rows: P0 Card Padding left 52 → 48 (−4); P1 Hero Gap 14 → 16; P1 Card Padding right 19 → 20; P1 Card Gap 13 → 12; P1 Card / Override Gap 15 → 16. "Gap" used throughout, signed deltas, "No changes applied", clickable layer links, plain-text fix question. The table scrolls horizontally in the narrow panel, so Priority and Note are off-screen until scrolled.
- **Prompt 2:** `1`. 32 s. Applied 4 properties on 2 layers, verified 4 of 4: Card 48 / 20 / 12 and Hero Gap 16. Reported "hug heights adjusted naturally" instead of reverting. Left the override at 15 and asked a numbered approval question for it. Canvas read-back over MCP confirmed all values.
- **Prompt 3:** "Is this on the 8pt grid?" with nothing selected. 45 s, then the scope question as plain text with no stray asterisks, rendered as a normal message this time rather than a question card.
- **Output contract met:** yes.
- **Source changed:** only confirmed properties.
- **Credits consumed:** not visible.
- **Defects:** none blocking. Candidates for v1.2: move Priority to the second column so it stays visible without horizontal scrolling; the 45 s before the scope question suggests the agent may read the page before asking, worth a stronger "do not read before asking" line if credits matter.
- **Change made:** none; v1.1 accepted.
- **Re-test needed:** no. Next test should be a real design-system file for scale and speed.

### 2026-11-02 · v1.0 · Figma Design

- **Edition tested:** upload (`dist/fm-spacing-rhythm-audit.figma.md`); upload accepted the file.
- **File and selection:** `fm-spacing-audit-seed` (hPBA9odanfBNpvMRTPXZLJ), page Seed. Selected: Card main component, three instances (one with gap override 15), Hero. 5 frames.
- **Prompt:** `/fm-spacing-rhythm-audit`, then `1` at the fix question.
- **Triggered:** yes by slash.
- **What the agent did:** Reported 13 rows (P0 1, P1 11, P2 1, P3 0) matching ground truth exactly, with nearest values and signed deltas. Rendered layer references as clickable node links, added a "No changes applied" line, asked the fix question verbatim, stopped. After `1`: changed 3 properties on the main component (52 to 48, 19 to 20, 13 to 12), verified 11 of 11 inherited values, left the override row untouched, then reverted the Hero gap snap (14 to 16) because the hug frame grew 2 px. Worked 45 s on the fix pass. Canvas read-back over MCP confirmed every claim.
- **What it should have done:** Applied the confirmed Hero snap. A hug frame growing because its gap changed is not a size change. If it judged a confirmed row unsafe, it should have said so and asked, not reverted silently.
- **Output contract met:** yes, with the one deviation above.
- **Source changed:** only confirmed properties; override and out-of-scope frames untouched.
- **Credits consumed (if visible):** not recorded.
- **Defects:**
  1. Property column says "Item spacing"; designers know it as "Gap". Instruction uses API names.
  2. Nine inherited instance rows duplicate the component rows. Should fold into the component row with an instance count; only true overrides get their own row.
  3. P0 threshold "delta 3 or more" cannot fire below 48 on a 4 pt grid (max delta is 2). Severity must key on delta 2 vs 1.
  4. "Never change sizes" read as "preserve rendered height", causing a silent revert of a confirmed snap.
- **Change made:** v1.1 (see the entry below).
- **Re-test needed:** yes.

### 2026-11-02 · v1.0 · Figma Design (prompts 2 and 3)

- **Prompt 2:** "Check the spacing on these cards", same five-frame selection, no slash. Auto-triggered. Correct two-row result after the earlier fix (override gap 15, Hero gap 14), with a grouped node link for the three on-grid cards. Used "Item gap" as the property name.
- **Prompt 3:** "Is this on the 8pt grid?" with nothing selected. Asked the scope question in a question card first (the card does not render Markdown: the bold markers showed as literal asterisks), waited, then after `1` audited the page in 24 s. Led with "Not entirely." Frames measured 7, hidden skipped 1; bound rows at P2 with the variable name and "change variable"; fractional rows ranked P3 by reading "sub-pixel" as the delta. Nothing changed.
- **Credits consumed:** no counter visible anywhere in the Figma UI on this plan.
- **Defects:** 5. Verbatim questions carry Markdown bold that the question card shows raw. (Scope gate itself passed.)
- **Change made (v1.1):** UI property names (Gap, Row gap); inherited instance values folded into the main component row with a count; severity keyed on delta 2 vs 1 so P0 can fire below 48; P3 defined as fractional delta below 1; "size change" defined precisely plus a no-silent-revert rule and an override flag in the apply helper; verbatim questions as plain text; output contract gains the one-line answer, signed deltas, clickable layer links, and "No changes applied."
- **Re-test needed:** yes, with the seed Card reset to 52 / 19 / 13.
