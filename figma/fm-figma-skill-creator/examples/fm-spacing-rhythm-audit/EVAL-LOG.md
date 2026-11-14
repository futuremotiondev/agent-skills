# EVAL-LOG: fm-spacing-rhythm-audit

One entry per test session. Newest first. Record facts, not impressions: the prompt, the selection, what the agent did, what it should have done, and the change made in response.

## Open questions this skill can settle on upload

This is the first skill built through fm-figma-skill-creator, so its first upload answers questions the research could not. Tick and record each, then copy the answers into `figma/fm-figma-skill-creator/references/troubleshooting.md`.

- [ ] Extra frontmatter keys on upload (try uploading the master, which carries `metadata`): kept / stripped / rejected: not yet tried; the name-and-description-only upload edition was accepted
- [x] Description limit: the Start-from-scratch form rejects more than 1,024 characters (observed). Name limit: not yet probed. This skill's description is 640 chars (2.0).
- [x] Body size limit hit: no (upload edition of about 190 lines accepted)
- [x] Markdown tables render in chat output: yes, with clickable node links (`figma-node-link`); question cards do not render Markdown
- [ ] `evaluate_script` ran the collect helper as written: not observable from the chat; results matched the helper's logic exactly
- [x] `figma.getNodeByIdAsync` available in-app: yes (capability probe, 2026-11-03)
- [x] `node.boundVariables` readable in-app: yes (capability probe, 2026-11-03; Round 3 bound counts)
- [ ] Export produces: ____ (format, whether frontmatter round-trips)

## Static results (2026-11-02)

- Master: 0 errors, 0 warnings (`validate-figma-skill.mjs --edition master`)
- Upload edition: see build log
- Paste edition: see build log
- Coding-agent edition: see build log

## Round 5 plan

The one in-app session of the audit's 2.3 plan, prepared on 2026-11-14. It is a plan, not a result, so it sits outside Entries; the results go in as a new entry. The orchestrator runs it through an automated browser, as in Round 4. Every expected value below comes from scope 3 of `tests/expected.json`, whose live oracle was rerun on 2.3 and is unchanged (844 frames, 622 bound values).

- **Edition:** 2.3, the paste edition `dist/fm-spacing-rhythm-audit.paste.md`, installed through Manage skills, Edit, Save (0 credits). The Ruling 31 diagnostic (closed in Round 4) and the capability probe are not part of this session.
- **File and page:** the Simple Design System duplicate `RoEqd4VFbADE0s0nZ0n8Yj`, Sections page, nothing selected (oracle scope 3).
- **Prompts:** "Audit the spacing on this page", then 1 (scope), 1 (mode), 3 at the fix question, "1, 2" at the follow-up, then "revert the last snaps" in the same chat.
- **Expected report:** the 2.3 Output contract template printed verbatim, filling only its `<…>` parts, with the priority line "Off-grid values: P0 2 · P1 3 · P2 0 · P3 5 (10 values in 10 rows)". Rows 1 and 2 are the two `Hero (Slot)` slot gaps, 10 to 8, bind `Space/200`. In-app the page has read 842 frames and 618 bound values in Rounds 3 and 4 against the oracle's 844 and 622, so the compare runs with `--frame-tolerance 4`: `node scripts/oracle-compare.mjs --expected examples/fm-spacing-rhythm-audit/tests/expected.json --scope 3 --schema examples/fm-spacing-rhythm-audit/tests/schema.spacing.json --report <the capture> --frame-tolerance 4`, hoped-for result exit 0.
- **Expected After fixes:** "Changed: 2 properties on 2 layers · Verified: 2 of 2". After "revert the last snaps", the two `Hero (Slot)` slot gaps must read 10 and unbound again, so the duplicate still matches scope 3.
- **Credits:** about 150, from Round 4's six matching responses (60, 14, 36, 6, 22, 12); stop at 200. Credits are read after every response, from the AI credits icon under it.
- **Micro-test (Task 4):** wording micro-test, 2026-11-14, no credits: five single-shot agents per edition were given the paste edition and scope 3's collect result and asked for the report. Scored with `oracle-compare` at tolerance 0, the 2.3 edition compared clean 5 of 5 and the 2.2 control 4 of 5 (its one failure appended node ids to the layer paths). The control already follows the template closely, so this shows that 2.3 does no harm and narrows the spread between runs; it does not reproduce the in-app rewrite of Round 4.
- **Run:** on 2026-11-14; the results are the entry "Round 5 in-app, v2.3, 2026-11-14" below.

## Round 4 plan

The one in-app session of the creator's Plan 2 (Ruling 34), prepared on 2026-11-13. It is a plan, not a result, so it sits outside Entries; the results go in as a new entry. Futuremotion runs it by hand from a local checklist that is not committed. Every expected value below comes from scope 3 of `tests/expected.json` or from the Round 3 entry.

- **Edition:** upload `dist/fm-spacing-rhythm-audit.figma.md` (2.2). The capability probe is not part of this session; 1.2 ran in-app on 2026-11-13.
- **Audit:** on the Simple Design System duplicate, Sections page, nothing selected, say "Audit the spacing on this page", then answer 1 (scope) and 1 (mode). Expect the scope question as a card, and the mode question reading "(2 to 160 px, plus negative tokens to -24)". Expect a header with "Matched but not offered: Responsive (1 WIDTH_HEIGHT)" and "P0 2 · P1 3 · P2 0 · P3 5 (10 values in 10 rows)". Expect the five `AI Chatbot` 20s at P3, each binding `Space/400` with the note "tie: Space/400 (16) or Space/600 (24)". Compare the pasted report against scope 3 with `--frame-tolerance 4`: Round 3 read 842 frames and 618 bound values in-app against 844 and 622 (Ruling 31).
- **Fix question:** answer 3, then type "1, 2". Expect the row-number follow-up as free text with no preset options. Rows 1 and 2, the two `Hero (Slot)` slot gaps (10 → 8, bind `Space/200`), are applied and verified 2 of 2. Then say "revert the last snaps": both read 10 again, unbound, so the duplicate matches scope 3 again.
- **Ruling 31 diagnostic:** in a fresh chat on the same page, run the script under "Round 4" in the Round 3 entry through the script tool and copy its return. Compare it with the MCP answer recorded there.
- **Credits:** read after every response, from the AI credits icon under it.
- **Run:** on 2026-11-13; the results are the entry "Round 4 in-app, v2.2, 2026-11-13" below.

## Entries

### Round 5 in-app, v2.3, 2026-11-14

- **Edition tested:** 2.3 in the Figma Design agent, run by the orchestrator through an automated browser. Installed through Manage skills, Edit, Save (0 credits): the paste edition (46,707 characters) replaced the body; the name and description fields were already equal to `dist/fm-spacing-rhythm-audit.paste.fields.txt` and were left as they were. Read back after Save: 46,706 characters (the trailing newline is trimmed), containing "verbatim, filling only its"; Last updated November 14, 2026.
- **File and selection:** the Simple Design System duplicate `RoEqd4VFbADE0s0nZ0n8Yj`, Sections page, nothing selected (oracle scope 3). Before the session, over MCP, the two `Hero (Slot)` slot frames `6062:12601` and `6062:12602` read gap 10, unbound; after the session, the same.
- **Prompts:** "Audit the spacing on this page" in a new chat, then 1 (scope), 1 (mode), 3 at the fix question, "1, 2" at the follow-up, then "revert the last snaps" in the same chat.
- **Gates:** the scope, mode, and fix questions rendered as cards with lettered options plus "Add a custom response", each with the master's text exactly. The mode question read "(2 to 160 px, plus negative tokens to -24)". The discover response printed "Matched but not offered: Responsive (1 WIDTH_HEIGHT)." above the mode question. The row-number follow-up was plain text, "Which row numbers?", with no options.
- **Report:** saved verbatim as `tests/fixtures/round5-sections-audit.md`. Each response was read from the page and written as Markdown: headings and list items in Markdown form, real tables as pipe tables, node links as their text, option buttons left out; nothing else changed. The capture therefore holds the agent's lead-in sentence and its work-status line ("Auditing page padding and gaps") above the report, and the fix question below it. The report follows the 2.3 template: heading `## Spacing rhythm audit: Sections`, the header lines in the template's order and labels ("Off-grid values: P0 2 · P1 3 · P2 0 · P3 5 (10 values in 10 rows)", "Bind opportunities: 42 values across 7 tokens", "On rhythm, no matching token: 0", "Matched but not offered: Responsive (1 WIDTH_HEIGHT)", "No changes applied."), the Bind opportunities table before the main table, and ten rows whose Layer (path) and Note cells are scope 3's `path` and `note`. It read 844 frames and 622 bound values, equal to the oracle; Rounds 3 and 4 read 842 and 618 on the same page. One run does not explain the change; it is recorded as an observation.
- **Compare:** `node scripts/oracle-compare.mjs --expected examples/fm-spacing-rhythm-audit/tests/expected.json --scope 3 --schema examples/fm-spacing-rhythm-audit/tests/schema.spacing.json --report examples/fm-spacing-rhythm-audit/tests/fixtures/round5-sections-audit.md --frame-tolerance 4`, with the committed schema unchanged. Exit 0. Its output up to the Result line (the EVAL-LOG entry stub it prints next is replaced by this entry):

  ```text
  oracle-compare: scope 3 (tokens), report examples/fm-spacing-rhythm-audit/tests/fixtures/round5-sections-audit.md, frame tolerance 4

  Counts (expected, observed, delta)
    Frames measured                        844     844     0
    Hidden skipped                           9       9     0
    Not measurable (absolute children)       4       4     0
    Bound values                           622     622     0
    On rhythm, no matching token             0       0     0
    Matches an alias                         0       0     0  (line omitted, read as 0)

  Priority counts, Off-grid values (expected, observed, delta)
    P0       2       2     0
    P1       3       3     0
    P2       0       0     0
    P3       5       5     0

  Missing from the report (0)
  Extra in the report (0)
  Mismatched (0)

  Result: 0 missing, 0 extra, 0 mismatched; every count within tolerance; exit 0
  ```

  The same command with `--frame-tolerance 0` prints the same Result line and exits 0. `tests/compare.harness.mjs` pins the tolerance-4 result (exit 0, 0 missing, 0 extra, 0 mismatched).
- **Hand check:** what the compare does not read, checked against the 2.3 Output contract template and scope 3 of `tests/expected.json`:

  | Item | Expected | Observed (file, line) | Result |
  | --- | --- | --- | --- |
  | Heading | `## Spacing rhythm audit: Sections` | the same (`round5-sections-audit.md`, 5) | pass |
  | Mode line | `- Mode: tokens (Size)` (`spacingCollection.name` is `Size`) | the same (7) | pass |
  | Scale line | `- Scale: 4 pt below 48, 8 pt from 48` | the same, with "; checked against the system's spacing tokens" added inside the placeholder (8) | pass (label and value as the template; the added clause is an observation) |
  | Bind opportunities section | `## Bind opportunities` and its table before the main table | heading 22, table 24 to 32, main table 36 | pass |
  | Note cells, rows 1 to 10 | each row's `note`: empty for rows 1 and 2; "inherited by 9 instances", "inherited by 1 instance", "inherited by 2 instances" for rows 3 to 5; "tie: Space/400 (16) or Space/600 (24)" for rows 6 to 10 | the same, in order (38 to 47) | pass |
  | After fixes heading | `## After fixes` | the same (`round5-after-fixes.md`, 9) | pass |
  | After fixes record line | "Previous is the human record; the revert list is the apply result." | the same (11) | pass |
  | After fixes columns | `#`, Layer, Property, Previous, Now, Fix, in that order | the same (13) | pass |
  | Changed line | "- Changed: 2 properties on 2 layers · Verified: 2 of 2" | the same (18) | pass |
  | Revert | both rows reported restored | "I reverted both snaps using the previous change record and confirmed both gaps are back to **10 px, unbound**. Nothing else changed." (`round5-revert.md`, 3) | pass |

- **Apply (answer 3, "1, 2"):** both `Hero (Slot)` slot gaps 10 → 8, bound to `Space/200`, in an After fixes table with Previous "10 px, unbound"; rows 3 to 10 listed as not changed, user excluded; "Structure, constraints, layout mode, and explicit sizes: unchanged".
- **Revert:** reported in one sentence (see the hand check). Checked over MCP afterwards: both slot frames read gap 10, unbound, as before the session.
- **Credits:** 148 in six responses, read under each response (Round 4's six matching responses were 150). Allowance: 184 + 148 = 332 of 600.

  | Step | Turn | Credits |
  | --- | --- | --- |
  | 1 | Update the installed skill through Manage skills, Edit | 0 |
  | 2a | "Audit the spacing on this page", scope question | 60 |
  | 2b | 1, discover run and mode question | 14 |
  | 2c | 1, the report and the fix question | 34 |
  | 3a | 3, row-number follow-up | 6 |
  | 3b | "1, 2", apply and After fixes | 22 |
  | 3c | "revert the last snaps" | 12 |

- **Micro-test:** recorded in the Round 5 plan above; not repeated here.

#### Observations: what the agent added outside the template

None of these is a hand-check item or read by the compare, so none changes the result.

- A lead-in sentence and a work-status line before the heading (`round5-sections-audit.md`, 1 and 3), and in `round5-after-fixes.md` a lead-in sentence and three status lines (1 to 7).
- Two explanatory paragraphs between the header list and the Bind opportunities section (18 and 20): the P0/P1 rows are 10 px gaps and the P3 rows are ties; rows 3 to 5 are main components on other pages.
- The sentence "All proposed bindings use the Default mode." after the main table (49).
- The Scale line's added clause inside its placeholder (8).
- In `round5-after-fixes.md` the Layer cells are the agent's own names ("Desktop hero slot", "Mobile hero slot"), not layer paths (15 and 16). The 2.3 wording names the "Layer (path)" and Note cells only, so this column of the After fixes table is not covered.
- In `round5-revert.md` the revert is reported in one sentence, not in a table; the template prescribes none.
- The Bind opportunities table names `Accordion / Items (page: Accordion)` as the `Space/400` example layer where scope 3 records `Footer / Footer / Platform=Desktop`, as in Rounds 3 and 4; the counts (15, 10, 6, 5, 4, 1, 1) agree.
- Frames measured 844 and Bound values 622, equal to the oracle, where Rounds 3 and 4 read 842 and 618; the cause is not established.

- **Change made:** none to the master. The creator (1.4) now says an in-app report of the audit (2.3) compares clean with `--frame-tolerance 4`, in `SKILL.md`, `references/testing-and-maintenance.md`, and `tests/README.md`; `references/troubleshooting.md` adds the 844 and 622 reading to "Frame counts can differ between runtimes". `tests/fixtures/round5-sections-audit.md` and its harness case are new.
- **Re-test needed:** no.

### Round 4 in-app, v2.2, 2026-11-13

- **Edition tested:** 2.2 in the Figma Design agent, run by the orchestrator through an automated browser rather than by Futuremotion by hand. The installed skill was updated through Manage skills, Edit, Save (0 credits). The Edit screen holds the body without a frontmatter block, so the paste edition went in and the name and description fields, already equal to `dist/fm-spacing-rhythm-audit.paste.fields.txt`, were left as they were. Read back after Save: 46,399 characters, contains "plus negative tokens to".
- **File and selection:** the Simple Design System duplicate `RoEqd4VFbADE0s0nZ0n8Yj`, Sections page, nothing selected (oracle scope 3).
- **Prompts:** "Audit the spacing on this page", then 1 (scope), 1 (mode), 3 at the fix question, "1, 2" at the follow-up, then "revert the last snaps" in the same chat. The plain prompt triggered the skill; the slash form was not needed.
- **Gates:** the scope, mode, and fix questions rendered as cards with lettered clickable options plus "Add a custom response", each with the master's text exactly. The mode question read "(2 to 160 px, plus negative tokens to -24)", the 2.2 wording. The row-number follow-up was plain text, "Which row numbers?", with no options. Round 3's mismatches 1 and 2 are fixed in-app.
- **Report:** saved verbatim as `tests/fixtures/round4-sections-audit.md` (the page's tables converted to Markdown, nothing else changed). Ten rows; P0 2 · P1 3 · P2 0 · P3 5; the five `AI Chatbot` 20s at P3 binding `Space/400` with a tie note, the 2.2 classification. "Matched but not offered: Responsive (1 WIDTH_HEIGHT)" was printed, so Round 3's mismatch 3 is fixed. The blast-radius sentence for rows 3 to 5 and the 50-frame line were present.
- **Compare:** `node scripts/oracle-compare.mjs --expected examples/fm-spacing-rhythm-audit/tests/expected.json --scope 3 --schema examples/fm-spacing-rhythm-audit/tests/schema.spacing.json --report examples/fm-spacing-rhythm-audit/tests/fixtures/round4-sections-audit.md --frame-tolerance 4`, with the committed schema unchanged. Exit 2. It printed no stub; its whole output is one line on stderr:

  ```text
  oracle-compare: no "Off-grid values:" line in the report
  ```

  The agent printed the priority line as "Ranked values", so the compare stopped before it read a count or a row. After the whole-branch review fix wave (2026-11-13) a missing priority line is a reported difference, and the same command exits 1 with 5 missing, 5 extra, 0 mismatched and 5 counts outside tolerance (the four priority counts and "On rhythm, no matching token"); `tests/compare.harness.mjs` pins that result. The one difference the compare reports, and every other line and row checked by hand against scope 3 of `tests/expected.json`:

  | Item | Report | Scope 3 | Kind |
  | --- | --- | --- | --- |
  | Priority line (the compare's exit-2 difference) | "Ranked values: P0 2 · P1 3 · P2 0 · P3 5" | Off-grid values, P0 2 · P1 3 · P2 0 · P3 5 | the label or layout differs, the number agrees |
  | Frames measured | 842 | 844 | a number differs (−2, inside the tolerance of 4; Ruling 31) |
  | Bound values | 618 passed | 622 | a number differs (−4, inside the tolerance of 4; Ruling 31) |
  | Hidden skipped, absolute children | 9, 4 ("Absolute-positioned children excluded") | 9, 4 | the label or layout differs, the number agrees (the label is a known schema alias) |
  | Title | "Spacing audit: Sections", plain text | `## Spacing rhythm audit: Sections` | the label or layout differs |
  | Mode | "Size tokens, Default mode" | tokens, `Size` | the label or layout differs, the number agrees |
  | Scale | not printed | `Scale: 4 pt below 48, 8 pt from 48` | the line is left out |
  | Tokens off the 4/8 rhythm | "Space/150 = 6, used by 12 bound values" | `Space/150` = 6, 12 values | the label or layout differs, the number agrees |
  | On rhythm, no matching token | not printed | 0 | the line is left out (a 0); the compare reads an absent line as a difference |
  | Bind opportunities | no header line; "Another 42 unbound values" in a sentence; table after the main table | 42 across 7 tokens | the label or layout differs, the number agrees |
  | Bind opportunity counts | 15, 10, 6, 5, 4, 1, 1 | 15, 10, 6, 5, 4, 1, 1 | agree; example layers shortened, and `Space/400` shows `Accordion / Items` (`6031:7224`, in the oracle's id list, as in Round 3) for the oracle's `Footer / Footer / Platform=Desktop` |
  | Rows 1 to 10: property, current, nearest, fix, delta, priority | as scope 3 | as scope 3 | agree |
  | Rows 1 to 5: layer path | shortened, for example "Hero (Slot) / Desktop / Slot" | "Hero Sections / Hero (Slot) / Platform=Desktop / Slot" | the label or layout differs, the number agrees |
  | Rows 3 to 5: order | `AI -> Conversation`, `AI Sidebar`, `Checkbox Field` | the reverse | the label or layout differs, the number agrees (same priority and delta) |
  | Notes | "Direct child of a main component", "Main on AI Chat; inherited by 2 instances", "Tie: 16 or Space/600 (24)" | "", "inherited by 2 instances", "tie: Space/400 (16) or Space/600 (24)" | the label or layout differs, the number agrees |
  | Matched but not offered | Responsive (1 WIDTH_HEIGHT) | same | agree |

  Only the two Ruling 31 counts differ in number. A scratch copy outside the repository with only "Ranked values" renamed (not committed, not the capture) gets past that line and exits 1 with 5 missing, 5 extra, 0 mismatched and "On rhythm, no matching token" absent: the shortened paths of rows 1 to 5 no longer match the key column, while the five `AI Chatbot` rows, whose path the agent kept, match on every compared column.
- **Apply (answer 3, "1, 2"):** both `Hero (Slot)` slot gaps 10 → 8, bound to `Space/200`, in an After fixes table with Previous "10 px, unbound"; "Both values and bindings are confirmed. Rows 3–10 were left unchanged." Applying to a `SLOT` node worked. No blast-radius sentence, correctly (neither row is a main component elsewhere).
- **Revert:** "Reverted both last snaps: the gaps are back to 10 px, unbound, as recorded before the changes. Both restorations are confirmed; nothing else was changed." Checked over MCP afterwards, read-only: the committed oracle for scope 3 (`PAGE = "Sections"`, `SELECTION = "page"`, `MODE = "tokens"`) returned 9,985 bytes, and `oracle-compare.mjs --run` against scope 3 printed `0 missing, 0 extra, 0 mismatched; every count within tolerance; exit 0` with tolerance 0; rows, `unbound` with its ids, and `tokens` equal the fixture. The duplicate is as the oracle recorded it.
- **Ruling 31 diagnostic (closed as H3):** in a new chat, the Round 3 script returned, on the third attempt:

  ```json
  [{"id":"I4317:11022;4317:10969","type":"INSTANCE","visible":true,"layoutMode":"HORIZONTAL","children":["I4317:11022;4317:10969;4317:319 FRAME","I4317:11022;4317:10969;4317:10864 SLOT"]},{"id":"I4317:11022;4317:10969;4317:10864","type":"SLOT","visible":true,"layoutMode":"VERTICAL","children":["I4317:11022;4317:10969;4317:10866 TEXT"]},{"id":"I4331:7195;4317:10969;4317:10864","type":"SLOT","visible":true,"layoutMode":"VERTICAL","children":["I4331:7195;4317:10969;4317:10866 TEXT"]}]
  ```

  Both nested `Code` slots are listed, visible, `VERTICAL`, each with its text child, the same as the MCP run, so the in-app runtime reaches them: H1 and H2 are ruled out. The audit again read 842 frames and 618 bound values. What remains is H3: most likely, by elimination, the agent ran its own walk rather than the helper as written; this is not confirmed, because the chat cannot show which, and the same 842 and 618 in three sessions point to a deterministic cause. No runtime difference goes into the capability reference; the helper is unchanged. Attempts 1 and 2 were faults of the automation's paste method, not of Figma: the scripted insert dropped the line breaks, so the leading `//` comment swallowed the script (attempt 1 returned "Plugin executed successfully" and no data), and with the comment removed the prompt box likely rewrote `(c)` (attempt 2 returned a SyntaxError). Attempt 3 sent the script on one line with the callback parameter renamed `kid`, its only difference from the Round 3 script.
- **Credits:** 184 in nine turns, read from "View AI credit usage" under each response; the hand-off estimated about 100.

  | Step | Turn | Credits |
  | --- | --- | --- |
  | 1 | Update the installed skill through Manage skills, Edit | 0 |
  | 2a | "Audit the spacing on this page", scope question | 60 |
  | 2b | 1, mode question | 14 |
  | 2c | 1, the report and the fix question | 36 |
  | 3a | 3, row-number follow-up | 6 |
  | 3b | "1, 2", apply | 22 |
  | 3c | "revert the last snaps" | 12 |
  | 4 | Diagnostic, attempt 1 (fault of the automation's paste method) | 18 |
  | 4 | Diagnostic, attempt 2 (fault of the automation's paste method) | 8 |
  | 4 | Diagnostic, attempt 3 (valid) | 8 |

  The first turn, which loads the 46,399-character skill, cost 60 where the 2026-11-02 model said about 10 for a question.
- **Timings:** about 8 s to the scope question, about 9 s to the mode question, 52 s to the report, about 5 s to the follow-up, 22 s to apply, 14 s to revert.

#### Open finding: the agent rewrote the report template

Recorded for Futuremotion's decision on whether the skill should insist on its template; no change is proposed here. Its consequence: an in-app report of this audit does not compare clean today, so compare `--run` on MCP returns and check an in-app report's numbers by hand until the audit enforces its template (planned as separate work).

| Master's Output contract | What the agent printed |
| --- | --- |
| `## Spacing rhythm audit: <scope name>` | "Spacing audit: Sections", plain text |
| `Mode: tokens (<spacingCollection.name>)` | "Mode: Size tokens, Default mode" |
| `Scale: 4 pt below 48, 8 pt from 48` | not printed |
| `Not measurable (absolute children): <n>` | "Absolute-positioned children excluded: 4" |
| `Off-grid values: P0 <n> · P1 <n> · P2 <n> · P3 <n> (<n> values in <n> rows)` | "Ranked values: P0 2 · P1 3 · P2 0 · P3 5", no parenthetical |
| `Bound values: <n> passed` | "Bound values: 618 passed, with inherited values counted at their source" |
| `Tokens off the 4/8 rhythm: Space/150 = 6 (12 values); a scale decision, not a defect` | "Space/150 = 6, used by 12 bound values. This is a system-scale decision, not a defect." |
| `Bind opportunities: <n> values across <n> tokens` | no header line; "Another 42 unbound values already match tokens" under the second table |
| `On rhythm, no matching token: <n>` | not printed (it is 0) |
| `No changes applied.` | "Nothing was changed." in the opening sentence |
| The Bind opportunities table before the main table | after it, headed "Exact-value bind opportunities" |
| `Layer (path)` cells as the helper returns them | shortened paths, page and "(main component)" dropped |
| Note cells as the helper returns them | reworded notes |
| After applying: `Changed: <n> properties on <n> layers · Verified: <n> of <n>` | "Both values and bindings are confirmed. Rows 3–10 were left unchanged." |

- **Change made:** none to the master and no version bump. Recorded in the creator's references: `troubleshooting.md` closes "Frame counts can differ between runtimes" and adds the 2026-11-13 credit readings and the prompt-box paste row; `format-and-frontmatter.md` adds the Edit-screen note. `tests/fixtures/round4-sections-audit.md` and its harness case are new.
- **Re-test needed:** no for the gates and the 2.2 classification. The template finding waits on Futuremotion's decision.

### v2.2 oracle, 2026-11-13

- **Change made:** `tests/oracle.use_figma.js` regenerated from the 2.2 collect fence. It differs from the fence by the declared hunks only (header and preamble, `MODE` preset, `MAX_ROWS = Infinity`, the selection clear after the walk, the restore block for `tokens` and `unbound[].ids`); the fence is already in the top-level form, so there is no wrapper to strip. `tests/expected.json` reassembled from the five returns, with `masterVersion: "2.2"` in place of `masterCommit` and `generated: "2026-11-13"`. `tests/README.md` gains the hunk list, the 2.2 deltas, and the "Collect result fields" table.
- **Run:** the five oracle scopes over `use_figma` (remote `figma` server, one session, read-only calls that set and clear the selection): scopes 1 and 2 on the seed with SEED_SELECTION (rhythm, tokens), 3 and 4 on the Simple Design System duplicate's `Sections` page (tokens, rhythm), 5 on the no-tokens file (tokens requested, rhythm returned). Returns were 7,414, 9,940, 9,985, 5,653, and 1,379 bytes, none truncated.
- **Deltas from the 2.0 fixture:** scope 3 `byPriority` P0 7, P1 3 → P0 2, P1 3, P3 5: the five `AI Chatbot` 20s (`4331:7191`, four paddings and the gap) are P3 near misses binding `Space/400` with the note "tie: Space/400 (16) or Space/600 (24)". Scope 2 `Hero` gap 14 binds `Space/400` (16) instead of `Space/300` (12); its opportunity rows sort by path then property, and the two `Card` 16s add "; inherited by 3 instances"; counts unchanged. `spacingCollection` gains `minPositive` and `minNegative` (2 and −24 on scopes 3 and 4; 4 and `null` on 1 and 2). Scopes 1, 4, and 5 are otherwise unchanged. Every delta traces to a change listed in the static 2.2 entry below.
- **Proofs (rerun in a follow-up commit):** the 2.2 apply, verify, and revert helpers as written (top-level form, no wrapper), on the seed's `Token card` (`2:18`) padding left with `Space/200` (`VariableID:2:7`), one `use_figma` call per step. Apply returned `applied` with previous 8, previous binding none; verify returned `verified: 1` of 1; readback 8 bound to `Space/200`. The clean revert returned `reverted: 1`; readback 8, unbound. After a hand edit to 12, the second revert returned `reverted: 0` with `skipped` reason "changed since", `actual: 12`, and wrote nothing. The restore set padding left back to 8, unbound. Every value matches the 2026-11-03 run; the new record replaces it under `scopes[1].proofs` and adds `before` and `verify`. Scopes 1 and 2 rerun after the restore returned results byte-identical to the runs before the proofs (7,414 and 9,940 bytes), so the seed ended as it started.

### Static (2.2), 2026-11-13

- **Change made:** `metadata.version` 2.1 → 2.2. An on-rhythm unbound value with no equal token but a token within 4 is a near miss: the row ranks P3 as a bind opportunity (`fix.nearMiss: true`), names the nearest token ("on rhythm, no token; nearest Space/400 (16)") or both on a tie ("tie: Space/400 (16) or Space/600 (24)"), and stays out of "P0 and P1 only". Token ties go to the multiple of 8, else the lower. The election skips collections with no non-alias Default-mode candidate (tallied "alias only") and breaks a count tie toward a collection with a candidate above 0. `spacingCollection` gains `minPositive` and `minNegative`, and the mode question shows the positive span plus a negatives clause. Discover with no spacing tokens returns the rhythm audit. Opportunity rows sort by path then property and carry "inherited by N instances". All four helpers are in the top-level form (no wrapper), and the MCP section, the surface check, and the overlay's `compatibility` line follow the creator's 2026-11-13 wording.
- **Harness:** `tests/collect.harness.mjs` runs the collect fence as written under Node against a mock `figma` object. Before the helper change it printed `14 cases, 11 failed` (cases 3, 4, and 6b passed); after it, `14 cases, 0 failed`. A mock proves logic only.
- **Static:** the master validates with 0 errors and 0 warnings at 490 body lines (2.1: 497) and about 8,745 tokens. The build printed `helpers: 4 scripts`, and the upload, paste, and coding-agent editions each validate with 0 errors and 0 warnings (482, 481, and 161 body lines; about 8,478, 8,478, and 4,996 tokens). "Token mode" appears 17 times and `enhancement: token-conformance` 12 times (six code regions). markdownlint is clean on the touched files.
- **Stale until regenerated over MCP:** `tests/oracle.use_figma.js` and `tests/expected.json` still mirror the 2.1 helper. In scope 3, for example, the five `AI Chatbot` 20s that bound `Space/400` at P0 become P3 near misses. Plan 2 Task 2 regenerates both.

### Round 3 in-app, v2.0 (fixed in 2.1), 2026-11-03

- **Edition tested:** upload, v2.0, Figma Design agent. Every gate was screenshotted.
- **Credits:** not recorded in Round 3; see testing-and-maintenance step 5 for where to read them.

#### Prompt (a): seed file, SEED_SELECTION (12 nodes), `/fm-spacing-rhythm-audit`, then 1

- **Timings:** 34 s to the mode question, 47 s from the mode answer to the report, 26 s from the row-number answer to the apply reply, 19 s for the revert.
- **Report against scope 2:** 0 mismatches. Mode tokens (Spacing), each layer's applied mode. Frames 11, hidden 1, not measurable 0. P0 2 · P1 4 · P2 0 · P3 4 (10 values in 10 rows). Bound values 6 passed. Tokens off the 4/8 rhythm: `legacy/odd-18` = 18 (4 values) and `Space/300` = 10 in Compact (1). Bind opportunities: 11 values across 4 tokens, the table equal to scope 2's `unbound` (`Space/200` 7, `Space/400` 2, `Space/150` 1, `Space/300` Compact 1). On rhythm, no matching token: 4. Matched but not offered: Legacy (1 token). 21 ranked rows in the oracle's order with current, nearest, fix, and priority equal. Note under the table: rows 11 to 21 are optional binding opportunities, and row 6 (the `Card / Override` gap 15) stays unchanged unless the override is approved.
- **Apply (answer 3, rows 13 to 17, `Token card`):** paddings 8 → bind `Space/200`, gap 6 → bind `Space/150`. Changed 5 properties on 1 layer, verified 5 of 5. Equal to the apply proof (previous 8, previous binding none).
- **Revert ("revert the last snaps"):** all five restored to their numbers, unbound, verified 5 of 5, none skipped. Equal to the revert proof. The changed-since path was not exercised in-app.
- **Gates:** mode and fix questions rendered as cards with lettered clickable options. The row-number follow-up rendered as a card reading "Awaiting custom response", and the agent added presets "1. Choose rows 1-5, 2. Choose rows 7-10" that the skill never defined; they would have snapped the Card and Fractional rows.

#### Prompt (b): Simple Design System duplicate `RoEqd4VFbADE0s0nZ0n8Yj`, Sections page, nothing selected

- **Prompts:** "Audit the spacing on this page", then 1 (scope), then 1 (mode), then 4 at the fix question.
- **Timings:** 17 s to the scope question, 17 s to the mode question, 49 s to the report.
- **Gates:** the scope question rendered as plain text and was answered by typing. The mode question (range −24 to 160 px, equal to the Size collection) and the fix question rendered as cards. Decline reply: "I've left everything unchanged. The audit found 10 token mismatches and 42 optional binding opportunities across 842 auto-layout frames."
- **Header against scope 3:**

  | Line | Agent | Oracle | Match |
  | --- | --- | --- | --- |
  | Frames measured | 842 | 844 | no (−2) |
  | Hidden / not measurable | 9 / 4 | 9 / 4 | yes |
  | Priority | P0 7, P1 3, P2 0, P3 0 | same | yes |
  | Bound values passed | 618 | 622 | no (−4) |
  | Tokens off the 4/8 rhythm | `Space/150` = 6, 12 values | same | yes |
  | Bind opportunities | 42 across 7 tokens | same | yes |
  | Mode | tokens, Size, Default | same | yes |
  | Matched but not offered | not printed | Responsive (1 WIDTH_HEIGHT) | no (omitted) |
  | On rhythm, no matching token; library tokens | not printed (0; none) | 0; none | acceptable |

- **Rows against scope 3:** 10 of 10 equal on id, property, current, nearest, fix token, delta, and priority: `4331:7191` ×5 (20 → `Space/400`, −4, P0), `6062:12601` and `6062:12602` (10 → `Space/200`, P0), `565:14466` (inherited by 9), `4317:11278` (1), `4317:10977` (2). The blast-radius sentence for rows 8 to 10 was present.
- **Bind-opportunity table:** counts 15 / 10 / 6 / 5 / 4 / 1 / 1 equal. Example layers equal the oracle's `exampleId` except `Space/400`, which shows `6031:7224` (in the oracle's id list) instead of `7717:4142`; acceptable, and consistent with a different visiting order in-app. The 50-frame footer line was present.
- **Tie disclosure (Ruling 32):** the agent said "The 20 px values below follow a 4 pt rhythm, but don't match this system's tokens. Where tokens were equally near, I chose the lower value." 20 is 4 from both `Space/400` (16) and `Space/600` (24); the lower was chosen, as the oracle does. Whether an on-rhythm value with a token within 4 should rank P0 or pass is Futuremotion's decision in Plan 2; 2.1 leaves the classification unchanged.

#### Mismatches, each with its root cause

1. **Scope question as plain text** (instruction). Step 2 did not route the scope question through the structured question tool, while steps 5 and 6 did through the in-app section. Fixed in 2.1: step 2 and step 6 say "through a structured question tool when the runtime has one", and the in-app section names `ask_user_question` for the scope, mode, and fix questions.
2. **Invented presets at the row-number follow-up** (agent behaviour the instruction allowed). Fixed in 2.1: on 3, ask "Which row numbers?" as a free-text question with no preset options or ranges, and apply exactly the rows named; the in-app section repeats it.
3. **"Matched but not offered" dropped in (b)** (instruction). The line was defined only in the discover step, so it was not part of the output contract; prompt (a) printed it, prompt (b) did not. Fixed in 2.1: the line is in the report template and the output-contract prose, omitted when `matchedCollections` is empty, and the discover step says to repeat it in the report header.
4. **842 frames and 618 bound values against 844 and 622** (closed on 2026-11-13 as H3; no helper change). The Round 4 diagnostic found both nested `Code` slots visible in-app, `VERTICAL`, each with its text child, the same as over MCP, which rules out H1 and H2; the in-app agent sometimes walks on its own, so in-app counts are compared with `--frame-tolerance 4` (see the Round 4 entry). The evidence as recorded on 2026-11-03 follows. The collect walk (`"layoutMode" in n && n.layoutMode !== "NONE"`, a manual recursion over `children`, `visible === false` skips) is identical in v1.2 and 2.0, and v1.2 Run B also read 842, so the gap is reproducible, not a restated number. The v1.2 attribution to "the two SLOT nodes" is wrong: the Hero slots `6062:12601` and `6062:12602` are measured in-app, because they appear as rows 6 and 7 with no inherited note. A read-only `use_figma` replay of the walk on 2026-11-03 found exactly one pair of frames that accounts for both gaps: the two nested `Code` slots, `I4317:11022;4317:10969;4317:10864` and `I4331:7195;4317:10969;4317:10864`. Each is a SLOT inside an `AI Chat -> Code Block` instance that sits in the `Content` slot of an `AI -> Conversation` instance inside the `AI Chatbot` component set; they are the only measured SLOTs nested in slot content inside another instance. Their four paddings are bound and inherited, so the four bound keys sit on the main slot `4317:10864` (page AI Chat) and are reached only through these two frames: skipping both removes exactly 2 frames and 4 bound values. Hypotheses for why the in-app walk misses them: (H1) the in-app runtime does not list a slot that belongs to an instance placed inside another instance's slot, so `Code Block`'s `children` comes back without its `Code` slot; (H2) those nested nodes read `visible === false` or lack `layoutMode` in-app; (H3) the agent ran its own walk rather than the helper (the chat cannot show which), though matching rows, priorities, and the same 842 in two versions make this least likely. The helper is not changed on a guess.

#### Change made (2.1)

`metadata.version` 2.0 → 2.1. Step 2: the scope question goes through the structured question tool when the runtime has one. Step 4: the matched-but-not-offered line is repeated in the report header. Step 6: the fix question names the structured question tool, and the row-number follow-up is free text with no presets. Output contract: "Matched but not offered" in the prose and the template. In-app section: `ask_user_question` for the scope, mode, and fix questions, and the free-text row-number follow-up. The token classification (Ruling 32) and every helper are unchanged. Rebuilt the editions; static results are below the Round 4 note.

#### Round 4 (optional, folds into the next real use of the skill)

Confirm the scope question renders as a card and the header carries the Matched-but-not-offered line; the Ruling 31 frame-count diagnostic is a one-prompt check whenever someone cares. That check: on the Sections page of `RoEqd4VFbADE0s0nZ0n8Yj`, ask the agent to run this through its script tool and paste the result back, then run the same script over `use_figma` and compare:

```javascript
// Ruling 31 diagnostic: read-only. Does this runtime reach the nested Code slots?
const ids = ["I4317:11022;4317:10969", "I4317:11022;4317:10969;4317:10864", "I4331:7195;4317:10969;4317:10864"];
const out = [];
for (const id of ids) {
  const n = await figma.getNodeByIdAsync(id);
  out.push(n ? { id, type: n.type, visible: n.visible, layoutMode: "layoutMode" in n ? n.layoutMode : "absent", children: "children" in n ? n.children.map((c) => c.id + " " + c.type) : "absent" } : { id, found: false });
}
return out;
```

Over MCP (2026-11-03) the `Code Block` instance lists two children, `I4317:11022;4317:10969;4317:319` (FRAME) and the `Code` slot, and both `Code` slots read SLOT, visible, VERTICAL, each with one TEXT child. A different in-app answer confirms H1 or H2; the same answer points to H3, and the next step is to have the agent return the measured frame ids from the collect helper and diff them against the oracle.

#### Static (2.1)

The master validates with 0 errors and 0 warnings at 497 body lines (2.0: 496). The build printed `helpers: 4 scripts`, and the upload, paste, and coding-agent editions each validate with 0 errors and 0 warnings (489, 488, and 163 body lines). markdownlint is clean on the touched files.

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
