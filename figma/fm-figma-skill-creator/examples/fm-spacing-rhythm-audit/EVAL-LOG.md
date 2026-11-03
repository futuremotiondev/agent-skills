# EVAL-LOG: fm-spacing-rhythm-audit

One entry per test session. Newest first. Record facts, not impressions: the prompt, the selection, what the agent did, what it should have done, and the change made in response.

## Open questions this skill can settle on upload

This is the first skill built through fm-figma-skill-creator, so its first upload answers questions the research could not. Tick and record each, then copy the answers into `figma/fm-figma-skill-creator/references/troubleshooting.md`.

- [ ] Extra frontmatter keys on upload (try uploading the master, which carries `metadata`): kept / stripped / rejected: not yet tried; the name-and-description-only upload edition was accepted
- [x] Description limit: the Start-from-scratch form rejects more than 1,024 characters (observed). Name limit: not yet probed. This skill's description is 640 chars (2.0).
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

### v2.0 oracle, 2026-11-03 UTC

- **Method:** `tests/oracle.use_figma.js` (the collect helper at `a312065`, uncapped) was run over `use_figma` with the selection set by name, and `tests/seed.use_figma.js` built the seed. Results are stored verbatim in `tests/expected.json`. Every Step 4 assertion was checked by hand against them: scope 1 3 of 3, scope 2 14 of 14, scope 5 3 of 3.
- **Final-fix round (rerun 2026-11-03 UTC):** scopes 1, 2, and 5 were rerun over `use_figma` with the regenerated oracle, which mirrors the collect helper after the Plan 1 whole-branch review fixes. Every row and count below is unchanged. The results gain three things: bind fixes carry `fix.value` (20 of 20 in scope 2, each equal to Nearest); `tokenCount` is 12, 12, and 0, and `aliasMatched` is 0 in all three scopes; and `tokens` and `unbound[].ids` now come from the oracle's restore block, because the skill's own collect returns only `tokenCount` and no ids. `tests/expected.json` was regenerated from these runs (`masterCommit` `da17b9e+final-fix`) and the Step 4 assertions pass again: 3 of 3, 14 of 14, 3 of 3.
- **Files:** seed `fm-spacing-audit-seed` (`hSEurPqV8Dgzn9yTwPSnnL`) and no-tokens `fm-spacing-audit-notokens` (`idjl35MjLGg4IJtPPH86GA`), both carrying those names in Drafts (over `use_figma`, `figma.root.name` reads back as "Document" for any file, which is not the file's name). The first seed run created 22 items. The second created 0 and returned identical ids. `modesSupported` is true, and `Compact card` padding top reads 10.
- **Scope 1, seed, SEED_SELECTION, rhythm:** 11 frames measured, 1 hidden skipped, 0 not measurable. P0 1 · P1 6 · P2 5 · P3 4 (16 values in 16 rows). No bind opportunities (rhythm mode). On rhythm, no matching token: 0. Bound values passed: 1. Tokens off the 4/8 rhythm: `legacy/odd-18` (Default) = 18 (4 values) and `Space/300` (Compact) = 10 (1 value). `Compact card` padding top is P2 "bound to Space/300". `Token card` gap 6 passes, because the Default-mode token values count as on-grid.
- **Scope 2, seed, SEED_SELECTION, tokens:** 11 frames, 1 hidden, 0 not measurable. P0 2 · P1 4 · P2 0 · P3 4 (10 ranked rows). Bind opportunities: 11 values across 4 tokens, listed as 11 more P3 rows: `Space/200` (Default) 7, `Space/400` (Default) 2, `Space/150` (Default) 1, `Space/300` (Compact) 1. On rhythm, no matching token: 4 (the `Hero` paddings). Bound values passed: 6. Tokens off the 4/8 rhythm: the same two as scope 1. The matched-but-not-offered summary reads `Legacy` 1 "not elected". Library tokens: none. `Card` padding left 52 is set to 48 ("no token within 4"). `Card` padding right 19 binds `Space/400` (−3), which proves `legacy/odd-18` is never offered. `Compact card` padding left 10 binds `Space/300` (Compact) as a bind opportunity, which pins Review Focus 3.
- **Scope 3, Simple Design System duplicate (`RoEqd4VFbADE0s0nZ0n8Yj`), Sections, page, tokens (run 2026-11-03 UTC):** 844 frames measured, 9 hidden skipped, 4 not measurable, not truncated. P0 7 · P1 3 · P2 0 · P3 0 (10 values in 10 rows). Spacing collection `Size` (Default, −24 to 160, 18 candidate tokens); `Responsive` matched but not offered (1 WIDTH_HEIGHT); library tokens none. `AI Chatbot` padding and gap 20 on all five properties bind `Space/400` (−4) as P0: 20 is on the rhythm but the collection has no 20, and a token within 4 wins over the on-rhythm pass. The two `Hero (Slot)` gaps 10 and three inherited gaps 10 (`Checkbox Field`, `AI Sidebar`, `AI -> Conversation`, main components on other pages) bind `Space/200` (−2). Bind opportunities: 42 values across 7 tokens (`Space/600` 15, `Space/200` 10, `Space/1200` 6, `Space/400` 5, `Space/300` 4, `Space/050` 1, `Space/100` 1), summarised only, because 844 frames exceeds the 50-frame row limit. On rhythm, no matching token: 0. Alias matches: 0. Bound values passed: 622. Tokens off the 4/8 rhythm: `Space/150` (Default) = 6, 12 values. Payload 9,441 bytes in oracle shape, 5,580 in the skill's shape.
- **Scope 4, same duplicate, Sections, page, rhythm:** same 844 / 9 / 4. P0 2 · P1 3 · P2 0 · P3 0 (5 values in 5 rows): the same five gap-10 rows as scope 3, each set to 8 ("nearest on-grid"). The `AI Chatbot` 20s pass, the twelve `Space/150` bindings are reported on the off-rhythm line instead of as P2 rows (v1.2 listed them as rows), and the v1.2 half-step row is gone because `Space/050` = 2 makes 2 on-grid in this file. Bound values passed: 622. Payload 5,619 bytes (oracle), 2,468 (skill shape).
- **Scope 5, no-tokens, page, MODE tokens requested:** returned mode rhythm with tokens []. 1 frame measured. P1 4 (`Plain` padding 18 on every side, each → 16). No bind opportunities. On rhythm, no matching token: 0. Bound values passed: 0. No tokens off the rhythm.
- **Apply and revert proofs (`Token card` padding left, `Space/200`):** apply bound it (previous 8, previous binding none). Revert then returned `reverted: 1` and the layer read 8, unbound. After a hand edit to 12, revert returned `reverted: 0` and skipped the row with `reason: "changed since"`, `actual: 12`, and left the layer at 12. The seed was then restored to 8, unbound.
- **Real-recon deck:** the Workflow 0 recon on the seed fed a fourth ideation deck ("something to keep our spacing honest"), saved in `examples/ideation-runs.md` under "Deck from a real recon (seed file)". The Observed line is filled from the recon, and four of five cards ground in a recon observation. Every deck assertion passes.
- **Static:** the build validates every edition with 0 errors and 0 warnings. markdownlint is clean on the example folder with `tests/fixtures/**` excluded; the verbatim fixtures fail lint on purpose.

#### Round 3 plan

Upload `fm-figma-capability-probe` and the 2.0 example. Scopes 3 and 4 in `tests/expected.json` were filled on 2026-11-03 from Futuremotion's duplicate `RoEqd4VFbADE0s0nZ0n8Yj`; prompt (b) runs in that file. Review Focus 3 (multi-mode tokens) is pinned, because `modesSupported` is true.

- **(a)** In the seed file, select the SEED_SELECTION nodes by name, then run `/fm-spacing-rhythm-audit` and answer 1 to the mode question. Compare against scope 2. Answer 3 and pick the Token card rows, then say "revert the last snaps".
- **(b)** On the Sections page of the Simple Design System copy, with nothing selected, say "Audit the spacing on this page", then answer 1, then 1 to the mode question. Compare against scope 3, then answer 4.
- **(c)** Run `/fm-figma-capability-probe` in the seed file, answer 1 to the disclosure, and paste the table back.

Take a screenshot of every question the agent asks in (a), (b), and (c). Whether the gates render as cards with clickable options, as cards with text only, or as plain messages answers the open question on decision-gate UI.

### 2026-11-02 · v1.2 · scale test in Figma (Simple Design System copy)

- **Edition tested:** paste (v1.2).
- **Run A, AI section (51 frames), slash:** 47 s. 14 values in 6 rows; P1 2, P2 12. The 12 padding values are bound to `Space/150` (a 6 pt token) on their main components; the agent ranked them P2, named the token, and merged the five nested Blocks into one row with a grouped link. Oracle had ranked them P0 and P1 because the v1.2 helper did not check the main component's bindings on inherited rows. Agent correct, oracle wrong.
- **Run B, Sections page via scope question, then `2`:** 10 + 24 + 18 credits; 18 s + 42 s + 27 s. 842 frames (oracle 844; the agent does not count the two `SLOT` nodes as frames), 9 hidden, 4 absolute. 18 values in 10 rows: P0 2 (Hero slots), P1 3, P2 12 (bound), P3 1 (2 px half-step). Priority in column two, grouped links, "No changes applied". Fix pass applied the five gap snaps at their main components, including sources on the Inputs and AI Chat pages, verified 5 of 5, left bound values and the half-step alone. Canvas read-back over MCP confirmed every value and the bindings.
- **Run C, Examples page (1,937 frames) via scope question, then `4`:** 22 + 4 credits; 40 s. 17 values in 9 rows: P0 4 (Home Page and Article Section gaps per platform), P2 12, P3 1. The three gaps fixed in Run B no longer appear, which is the correct consequence of fixing main components. "I've left everything unchanged." after `4`.
- **Output contract met:** yes, all three runs.
- **Source changed:** only the five confirmed gap rows in Run B.
- **Credits:** about 10 to ask the scope question, 22 to 24 to audit a page regardless of size (842 or 1,937 frames), 18 to fix five values, 4 to decline.
- **Defects:** 6. Oracle and helper ignored bindings on inherited rows (agent compensated). 7. Editing main components on other pages is correct and was disclosed in notes, but deserved an explicit blast-radius line before applying. 8. "Frames measured" needs a stated counting rule (slots and components count).
- **Change made (v1.3):** inherited rows check the main component's bindings; variable names resolved and shown; "Bound to variables" line in the header; blast-radius sentence before applying rows outside the selection; counting rule stated in step 1.
- **Re-test needed:** optional; v1.3 changes are to the helper's classification and two sentences of instruction, both already exhibited by the agent in Runs A to C.

### 2026-11-02 · v1.2 · scale test preparation (MCP oracle, read-only)

- **File:** duplicate of Figma's Simple Design System (Community), key MvJFAtAswCm20cI7hEtc0v. 30 pages; Examples page holds 1,939 auto-layout frames and 1,372 instances at depth 13.
- **Oracle method:** the collect helper run over `use_figma` with the test selection set programmatically, before the in-app run, so expected counts are exact.
- **v1.1 helper at scale (defects found):** main components on other pages printed as " / Avatar Block / Info" (unnamed top-level section, no page name); one component's nested frames produced ten identical-looking rows; every row inside a design system ranked P0; a 2 px gap ranked like any other value; the 400-frame cap was far below what the helper handles (1,939 frames in 3.3 s, 3.4 KB payload).
- **v1.2 changes:** paths skip unnamed ancestors, keep the last four segments, and name the page; severity inside components keys on depth (root or direct child is P0, deeper is P1); 2 px gaps rank P3 as half-steps; identical rows merge with "in N frames" and carry all ids; a "By component" summary precedes the table when rows exceed 30; frame cap raised to 2,000 with a truncation flag; Priority moved to the second column.
- **Expected results (v1.2 oracle):**
  - AI section (51 frames): 14 values; P0 2, P1 12; groups AI Sidebar 11, AI Chat -> User message 2, AI -> Conversation 1. 0.25 s.
  - Sections page (844 frames, 9 hidden, 4 absolute): 18 values in 10 rows; P0 4, P1 13, P3 1; groups AI Sidebar 11, Hero (Slot) 2, AI Chat -> User message 2, Checkbox Field 1, AI -> Conversation 1, Avatar Block 1. 1.2 s.
  - Examples page (1,939 frames, 4 absolute): 20 values; P0 6, P1 13, P3 1; adds Examples / Home Page 2 and Examples/Article 2 (Section gap 10 → 8 per platform). 1.7 s, 4.7 KB payload.
- **Static:** master, upload, paste, coding-agent editions all 0 errors, 0 warnings; markdownlint clean; helper parses (111 lines).
- **Re-test needed:** yes, in-app, against the numbers above.

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
