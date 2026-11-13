# EVAL-LOG: fm-figma-capability-probe

One entry per test session. Newest first. Record facts, not impressions: the prompt, the file, what the agent did, what it should have done, and the change made in response.

## Open questions this skill can settle on upload

Tick and record the answer the first time the upload edition goes through Figma's "Add skill" dialog. Copy the answers into `references/troubleshooting.md` of fm-figma-skill-creator. The probe table itself goes into `references/agent-capabilities-and-tools.md` under "Observed in-app (probe results)".

- [ ] Extra frontmatter keys (`metadata`, `license`) on upload: kept / stripped / rejected: ____
- [ ] Name or description length limit hit: yes / no (lengths tried: ____)
- [ ] Body size limit hit: yes / no (lines / bytes tried: ____)
- [ ] Markdown images or links render in the instructions view: yes / no
- [ ] `node.query` / `node.set` work under `evaluate_script`: present (presence only, 2026-11-03 and 2026-11-13); calls not tried
- [ ] Export produces: ____ (format, whether frontmatter round-trips)

## Entry template

### YYYY-MM-DD · v1.0 · Figma Design, Figma Make, or Claude Code

- **Edition tested:** upload, paste, or coding-agent
- **File and selection:** file name and key; selection (none needed)
- **Prompt:** the prompt, verbatim
- **Triggered:** yes by slash, yes by auto, or no
- **What the agent did:** steps, in order, with counts
- **What it should have done:** only where different
- **Output contract met:** yes, or no with the part that failed
- **Source changed:** no, or yes with what (any fm-probe layer or key left behind is a defect)
- **Credits consumed (if visible):** n
- **Defects:** numbered; each with symptom and the instruction line that should have prevented it
- **Change made:** the edit to SKILL.md, or none
- **Re-test needed:** yes or no

## MCP baseline (scratch file key: kXhDI9zBD5rbh00c3Lzt9i)

2026-11-03 UTC · v1.0 · Claude Code over MCP. File `fm-probe-scratch` (an empty design file at `https://www.figma.com/design/kXhDI9zBD5rbh00c3Lzt9i`), nothing selected, helper body run through `use_figma` in top-level-await form.

Runtime line returned: `editorType figma, mode unknown, apiVersion 1.0.0` (rerun of the final helper; the first capture read `unknown` because one throwing property took the whole line down, which is why the helper now reads each property in its own try). Every other row and scalar was identical across the two runs.

The first attempt with a 50,000-character payload was rejected by the bridge before any result came back: `Return value exceeds the 48000-byte limit (52907 bytes). Canvas edits from this run were not committed.` The table below is from the rerun with `PAYLOAD = 30000`.

| API | Status | Detail |
| --- | --- | --- |
| figma.getNodeByIdAsync | available | resolved the current page |
| figma.currentPage.selection | available | 0 selected |
| node.getMainComponentAsync | missing | no instance on page |
| node.boundVariables | missing | no auto-layout node on page |
| figma.variables.getVariableByIdAsync | available | no variable in file; null for a dummy id |
| figma.variables.getLocalVariablesAsync | available | 0 variables |
| figma.variables.getLocalVariableCollectionsAsync | available | 0 collections |
| figma.teamLibrary.getAvailableLibraryVariableCollectionsAsync | available | 0 library collections |
| figma.variables.importVariableByKeyAsync | available | presence only |
| node.setBoundVariable | available | presence only |
| figma.getLocalTextStylesAsync | available | 0 styles |
| figma.getLocalPaintStylesAsync | available | 0 styles |
| figma.getLocalEffectStylesAsync | available | 0 styles |
| figma.getLocalGridStylesAsync | available | 0 styles |
| figma.getStyleByIdAsync | missing | no local style in file |
| node.setFillStyleIdAsync | available | presence only |
| node.setTextStyleIdAsync | available | presence only |
| figma.getImageByHash + image.getBytesAsync | missing | no image on page |
| figma.createImage | available | presence only |
| node.setPluginData / getPluginData | error | Error: in setPluginData: figma.setPluginData is not supported in this host runtime (only private plugins on web can use |
| node.setSharedPluginData / getSharedPluginData | available | round trip ok |
| figma.clientStorage.setAsync / getAsync | error | Error: in setAsync: "setAsync" is not a supported API |
| node.query | available | presence only |
| node.set | available | presence only |
| figma.createAutoLayout | available | created and removed; layoutMode HORIZONTAL |
| figma.loadAllPagesAsync | available | presence only |
| figma.ui | available | presence only |
| text sizing: resize, textAutoResize, characters | available | height 15 at width 200 |
| figma.notify | available | called; handler returned |

The two in-app experiment rows are omitted over MCP.

- Payload bytes returned: 30000 (a 50,000-character sample is rejected: the bridge limits the whole return to 48,000 bytes)
- Walk time: 1 ms
- Nodes walked: 0
- Style counts: text 0, paint 0, effect 0, grid 0

Observed versus the plan's expectation: `setPluginData` reported `error` as expected; `figma.notify` did not throw over MCP (the figma-use guidance says it does); `clientStorage` is unsupported over MCP; `setSharedPluginData` works.

Changes made in response (still v1.0, before any upload): `PAYLOAD` constant with an MCP instruction to set it to 30000; `figma.notify` became a call check; the runtime probe reads each property separately.

## Entries

### 2026-11-13 · v1.2 · Figma Design agent, two runs

- **Edition tested:** the 1.2 body in the probe installed in Figma; the run record does not name the edition, and its finding 8 describes replacing an installed skill's instructions in place through Manage skills, Edit, at no credit cost.
- **File and selection:** `fm-probe-scratch` (`kXhDI9zBD5rbh00c3Lzt9i`), empty page; nothing selected.
- **Prompt:** not recorded in the run record.
- **Triggered:** not recorded in the run record.
- **What the agent did, first run:** sent the helper exactly as written, still in the 1.1 form (an async function wrapped and invoked on its last line). The script tool answered `Plugin executed successfully` with no result object, and the agent reported that the results were not returned. Asked afterwards, it confirmed it had added no outer `return` or `await`. In the same run a small `probe-tla` helper, written with top-level `await` and `return`, came back whole.
- **What the agent did, second run (helper rewritten in top-level form):** asked the disclosure as a card with lettered options (`A` "1. Yes", `B` "2. No", `C` "Add a custom response"); after the answer, ran the helper once and got all 43 rows back; asked the question-card experiment and recorded `ask_user_question | available | 1. Yes`; recorded `show_widget | missing | —`; reported the payload as 50,000 sent and 50,000 received.
- **What it should have done:** the second run is the intended behaviour. The first run shows what a wrapped helper does in-app: nothing comes back.
- **Output contract met:** second run yes for what the run record holds: 45 rows (43 helper rows and the two experiment rows), the runtime line `editorType figma, mode default, apiVersion 1.0.0`, and the four scalars; the paste-back line is not recorded. First run no: no table, because the helper returned nothing.
- **Source changed:** no. Nothing was left behind in the file.
- **Credits consumed:** second run three turns, read as 52, 52 and 10, 114 in total, one reading each (the readouts could not be shown again to confirm). First run four turns including the follow-up question, not read; about 100 to 120 by the same pattern.
- **Result:** the second run's table is merged into `references/agent-capabilities-and-tools.md` as "Figma Design agent (evaluate_script), 2026-11-13", replacing the 2026-11-03 table. Against the MCP run in the same file: the same status and detail on all 43 rows. New in 1.2: `commitUndo` and `saveVersionHistoryAsync` throw "not a supported API" when called; annotations (1 read back, 4 categories), PNG export (372 bytes), the three 3D transform members and `figma.motion` are available; an embedded Spec was created (850 x 1100) and removed; `figma.root.name` reads "Document" and assigning it throws; the library rows and the paint-binding row stay presence only for lack of an enabled library and a local colour variable.
- **Scalars:** payload 50,000 sent and 50,000 received, so a return of about 55,000 bytes arrived whole in-app, where about 53,000 bytes did not on 2026-11-03; walk 1 ms; 0 nodes walked; style counts 0 / 0 / 0 / 0.
- **Defects:** 1. The 1.1 helper form, a wrapped async function that is never returned, gives back nothing in-app; earlier runs worked only because the agent added a `return` on its own.
- **Change made (1.2, before the second run):** the helper is written with top-level `await` and a final `return`, with no function wrapper, and the helper paragraph says why. The `probe-tla` helper used to test the form was removed again once the main helper took its form.
- **Re-test needed:** the in-app run in a Spec file, not started to save credits; it would add the Spec disclosure and the question card in the Specs agent.

### 2026-11-13 · v1.2 · Claude Code over MCP, Design and Spec files

- **Edition tested:** the 1.2 helper, sent through `use_figma` in its top-level form; the run record does not name the edition file.
- **File and selection:** `fm-probe-scratch` (`kXhDI9zBD5rbh00c3Lzt9i`), empty page, and `fm-spec-scratch` (`CLZvom3IjzGswGa8yuuUrV`), a standalone Spec file; nothing selected in either.
- **Prompt:** not recorded; the maintainer ran the helper directly.
- **Triggered:** not applicable.
- **What the agent did:** one helper run per file. Runtime lines `editorType figma, mode default, apiVersion 1.0.0` (Design) and `editorType figspec, mode default, apiVersion 1.0.0` (Spec). In the Spec file the guard skipped the twenty rows that need a canvas or a write.
- **What it should have done:** run with `PAYLOAD` at 30000 and print the payload lengths. Both runs used `PAYLOAD` 1000 and packaged the return as strings, a maintainer deviation to save context; the 48,000-byte limit was measured directly the same day instead.
- **Output contract met:** yes for the rows, 43 per file in the helper's order without the two in-app experiment rows; the payload line is not a measurement because of the deviation above.
- **Source changed:** no. Nothing was left behind in either file.
- **Credits consumed:** not recorded.
- **Result:** merged into `references/agent-capabilities-and-tools.md` as "MCP (use_figma), 2026-11-13", replacing the 2026-11-03 table, and the new "MCP (use_figma) in a Spec file, 2026-11-13". The Design rows match the in-app run row for row. In the Spec file `figma.motion` and `figma.annotations` are absent, the variable, style and library reads return empty lists, all eight `figma.spec` members are functions, and `figma.spec.getContent` read `totalLines 26, hasMore true`.
- **Scalars:** walk 1 to 2 ms; the Spec walk counted 1 node, the `SPEC_BLOCK`; style counts 0 / 0 / 0 / 0 in both files.
- **Defects:** 1. In the Spec file the two rows that read `figma.motion` and `figma.annotations` were recorded as `error`, although reading a member the surface does not have is a missing API, not a failed call.
- **Change made:** the helper records an error whose text contains `no such property` as `missing`; the reference table shows those two rows as `missing`.
- **Re-test needed:** library import and paint binding against a seeded file with an enabled library and a local colour variable.

### 2026-11-03 · v1.0 (fixed in 1.1) · Figma Design (Round 3, prompt c)

- **Edition tested:** upload, v1.0.
- **File and selection:** `fm-spacing-audit-seed` (`hSEurPqV8Dgzn9yTwPSnnL`); nothing selected.
- **Prompt:** `/fm-figma-capability-probe`, then 1 to the disclosure, then A ("Yes") to the question-card experiment.
- **Triggered:** yes by slash.
- **What the agent did:** asked the disclosure as plain text, with no card ("This probe creates and deletes three temporary layers ..., writes one client-storage key, and shows one one-second toast, nothing else. Run it? 1. Yes, 2. No"); after the typed 1, ran the helper and asked the `ask_user_question` experiment as a card (A Yes, B No, C I only see text, D custom) 1 m 23 s later; recorded `show_widget` as missing because no widget tool existed (no two-card picker appeared); printed the table immediately after the answer. The reply box then read "Ask for changes".
- **What it should have done:** the same, except that the disclosure should have been a card; 1.0 did not name the structured question tool for it.
- **Output contract met:** yes. 31 rows (29 helper rows and the two experiment rows) in the helper's order, the runtime line, and the four scalar lines.
- **Source changed:** no design source; the skill master went 1.0 → 1.1 (below). No fm-probe layer was left behind; the client-storage write errored, so there was no key to leave.
- **Credits consumed:** not recorded in Round 3; see testing-and-maintenance step 5 for where to read them.
- **Result:** the full table is merged into `references/agent-capabilities-and-tools.md` as the first in-app dated table, "Figma Design agent (evaluate_script), 2026-11-03". Against the MCP baseline above: identical on every row the empty scratch file could test; the seed file fills four rows MCP reported missing for lack of content (`getMainComponentAsync` "main component Card", `boundVariables` "0 bound properties on Card", `getVariableByIdAsync` "resolved legacy/odd-18", 7 variables and 2 collections). `setPluginData` and `clientStorage` error with the same text in both runtimes; `setSharedPluginData` round-trips; `figma.notify` was called and returned; `node.query` and `node.set` are present (presence only). `ask_user_question` is available and rendered a card; `show_widget` is missing.
- **Scalars:** payload bytes returned "50000 truncated", so the return carrying the 50,000-character sample did not arrive whole; it measured 52,907 bytes over MCP, so the in-app limit is somewhere below that total (over MCP, `use_figma` rejects returns over 48,000 bytes); walk 3 ms; 20 nodes walked; style counts 0 / 0 / 0 / 0. Runtime line: `editorType figma, mode unknown, apiVersion 1.0.0`, the same as over MCP.
- **Defects:** 1. The disclosure gate rendered as plain text, because the instruction did not route it through the structured question tool (the experiment question, which did, rendered as a card).
- **Change made (1.1):** `metadata.version` 1.0 → 1.1. The disclosure is asked "through a structured question tool when the runtime has one", and the in-app section names `ask_user_question` for it, with the plain-text wording as the fallback. The helper and the two experiments are unchanged: the probe keeps testing `show_widget` and `clientStorage` on purpose. Rebuilt; the master and the upload, paste, and coding-agent editions each validate with 0 errors and 0 warnings.
- **Round 4 (optional, folds into the next real use of the skill):** confirm the scope question renders as a card and the header carries the Matched-but-not-offered line; the Ruling 31 frame-count diagnostic is a one-prompt check whenever someone cares. Those are fm-spacing-rhythm-audit's items; for this probe, the next real run only needs to confirm that the disclosure renders as a card.
