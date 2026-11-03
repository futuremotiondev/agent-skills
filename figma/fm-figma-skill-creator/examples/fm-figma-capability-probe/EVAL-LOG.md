# EVAL-LOG: fm-figma-capability-probe

One entry per test session. Newest first. Record facts, not impressions: the prompt, the file, what the agent did, what it should have done, and the change made in response.

## Open questions this skill can settle on upload

Tick and record the answer the first time the upload edition goes through Figma's "Add skill" dialog. Copy the answers into `references/troubleshooting.md` of fm-figma-skill-creator. The probe table itself goes into `references/agent-capabilities-and-tools.md` under "Observed in-app (probe results)".

- [ ] Extra frontmatter keys (`metadata`, `license`) on upload: kept / stripped / rejected: ____
- [ ] Name or description length limit hit: yes / no (lengths tried: ____)
- [ ] Body size limit hit: yes / no (lines / bytes tried: ____)
- [ ] Markdown images or links render in the instructions view: yes / no
- [ ] `node.query` / `node.set` work under `evaluate_script`: yes / no / not tried
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

2026-11-03 · v1.0 · Claude Code over MCP. File `fm-probe-scratch` (an empty design file at `https://www.figma.com/design/kXhDI9zBD5rbh00c3Lzt9i`), nothing selected, helper body run through `use_figma` in top-level-await form.

Runtime line returned: `unknown`. Reading `figma.editorType`, `figma.mode`, or `figma.apiVersion` threw inside the v1.0 runtime probe; the helper now reads each property in its own try.

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

No live in-app entries yet.
