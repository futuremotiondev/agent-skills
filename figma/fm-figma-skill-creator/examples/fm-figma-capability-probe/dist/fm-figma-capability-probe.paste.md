# Capability probe

Runs one script that tests which Plugin API surfaces the agent's script runtime exposes and returns a three-column table: API, Status (available, missing, or error), and Detail. The table goes to chat and nowhere else; the user pastes it back to whoever maintains their skills. The probe creates three temporary layers and one client-storage key, removes all of them before it returns, shows one one-second toast, and changes nothing else. It is a maintenance tool for skill authors: it reports what it observed and never adapts, retries, or works around a failed check (one rerun of the whole script after a size rejection is the single exception).

## When to use

- The user asks to probe, test, or check what the Figma agent can do.
- The user asks which Plugin APIs are available to scripts, or whether scripts can do a specific thing.
- A skill author wants fresh evidence for the capability reference after a Figma release.
- **Do not** use this to audit, fix, or change a design. It is optional: no other skill depends on it, end users never need it, and it can be removed from Figma once its table has been pasted back.

## Before you start

1. **Check the surface.** Run it in a Figma Design or Figma Make file; no selection is needed. In FigJam or Slides, say the probe needs a Design or Make file and stop.
2. **Disclose and ask.** Ask, verbatim and as plain text (the question card does not render Markdown):
   > This probe creates and deletes three temporary layers (one frame reused for both plugin-data round trips, one auto-layout frame, one text layer), writes one client-storage key, and shows one one-second toast, nothing else. Run it? 1. Yes, 2. No
   Wait for the answer. On 2, say nothing was run or changed and stop.

## Instructions

Ask one question at a time, wait for the answer, then act.

1. **Run the helper once.** Run the probe helper under Helper scripts exactly as written, one time, after the user answers 1; a second run is allowed only after a size rejection, as the target section says. Each target section below says how to run it on that runtime.
2. **Print the table exactly as returned.** One row per entry in `checks`, in the order returned, with the status and detail copied character for character. Append the two in-app experiment rows, omitted over MCP, then the four scalar lines. Use the output contract.
3. **Close with the paste-back.** Say, verbatim and as plain text:
   > Paste this table back to whoever maintains your skills so the capability reference can be updated. Nothing in your file was changed.
   Then stop.

## Output contract

Print the payload length, never the payload itself. If `payloadSample` arrived shorter than `payloadBytesReturned` or was replaced by a truncation notice, write "truncated" after the number.

```markdown
## Capability probe: <file name>
- Runtime: <Figma Design agent, Figma Make agent, or MCP>; script reports <runtime>; <date>

| API | Status | Detail |
| --- | --- | --- |
| <api> | <available, missing, or error> | <detail, or — when there is nothing to say> |

- Payload bytes returned: <payloadBytesReturned; or, after a rerun, <bytes> (first run rejected: <rejection text>)>
- Walk time: <walkMs> ms
- Nodes walked: <nodesWalked>
- Style counts: text <n> · paint <n> · effect <n> · grid <n>
```

The table holds every entry in `checks`, then the two in-app experiment rows, omitted over MCP. A value the helper returned as null prints as "null". No row is added, merged, reworded, or reordered.

## Do and do not

### Report, never adapt

- **Do:** `figma.loadAllPagesAsync | missing | not a function`, printed as returned.
- **Do not:** Rerunning a failed check with a workaround and printing "available (via fallback)".

### One run, or two only after a size rejection

- **Do:** One helper call, one table, then the paste-back line; a second call, with `PAYLOAD` at 30000, only when the first was rejected for size.
- **Do not:** Running the helper a second time to confirm an error, or splitting it into one call per check.

## Examples

**Request:** "What can the Figma agent's scripts do in this file?" with nothing selected.
**Result:** The disclosure question. On 1, one helper run, the two in-app experiments, the table with its four scalar lines, and the paste-back line.

**Request:** "Probe the agent's APIs" and the user answers 2 to the disclosure question.
**Result:** "Nothing was run or changed." No helper call, no table.

## Common edge cases

- **No script-execution path is available.** Say so, then list every check under Helper scripts as a numbered question ("Is figma.getNodeByIdAsync available?") for the maintainer to answer. Run nothing else.
- **Figma Make file.** Run the same probe and name Figma Make in the Runtime line.
- **The user declines the disclosure.** Say nothing was run or changed and stop.

## Final gate: do not finish until every line is true

- [ ] The user answered 1 to the disclosure question before the helper ran, and it ran once, or twice only after a size rejection
- [ ] Every row came from the helper's result or from an experiment actually attempted, copied without change
- [ ] No layer named fm-probe remains on the current page, and the paste-back line was said

## Helper scripts

The probe helper is self-contained and returns one result object. Every check is wrapped so a throw records `error` with the first 120 characters of the error text; every temporary layer and the `fm-probe` client-storage key are removed in a `finally` block.

```javascript
// helper: probe
(async () => {
  const PAYLOAD = 50000; // in-app sample size; see the MCP section for the 48,000-byte bridge limit
  const checks = [];
  const tidy = (s) => String(s).replace(/[|\r\n]+/g, " ");
  const miss = (detail) => ({ status: "missing", detail });
  const fn = (o, k) => o != null && typeof o[k] === "function";
  const run = async (api, body) => {
    try {
      const r = await body();
      if (r && typeof r === "object") checks.push({ api, status: r.status || "available", detail: tidy(r.detail || "—").slice(0, 120) });
      else checks.push({ api, status: "available", detail: r === undefined ? "—" : tidy(r).slice(0, 120) });
    } catch (e) {
      checks.push({ api, status: "error", detail: tidy(String(e).slice(0, 120)) });
    }
  };
  const presence = (o, k) => (fn(o, k) ? "presence only" : miss("not a function"));
  const roundTrip = (v) => (v === "ok" ? "round trip ok" : { status: "error", detail: "read back " + JSON.stringify(v) });
  const page = figma.currentPage;
  // Find the first matching node; a malformed remote component can throw on property access.
  const first = (test) => page.findOne((n) => { try { return test(n); } catch (e) { return false; } });
  const drop = (n) => { try { if (n && !n.removed) n.remove(); } catch (e) { /* already gone */ } };
  let frame = null, auto = null, text = null, stored = false, walkMs = null, nodesWalked = null, aliasId = null;
  const tmpFrame = () => { if (!frame) { frame = figma.createFrame(); frame.name = "fm-probe"; } return frame; };
  const tmpText = () => { if (!text) { text = figma.createText(); text.name = "fm-probe"; } return text; };
  const styles = { text: null, paint: null, effect: null, grid: null };
  // Read each runtime property on its own so one throw leaves the others readable.
  const prop = (k) => { try { const v = figma[k]; return v === undefined ? "unknown" : String(v); } catch (e) { return "unknown"; } };
  const runtime = "editorType " + prop("editorType") + ", mode " + prop("mode") + ", apiVersion " + prop("apiVersion");
  try {
    await run("figma.getNodeByIdAsync", async () => {
      if (!fn(figma, "getNodeByIdAsync")) return miss("not a function");
      return (await figma.getNodeByIdAsync(page.id)) ? "resolved the current page" : { status: "error", detail: "null for the current page" };
    });
    await run("figma.currentPage.selection", () => page.selection.length + " selected");
    await run("node.getMainComponentAsync", async () => {
      const inst = first((n) => n.type === "INSTANCE");
      if (!inst) return miss("no instance on page");
      if (!fn(inst, "getMainComponentAsync")) return miss("not a function");
      const main = await inst.getMainComponentAsync();
      return main ? "main component " + main.name : "returned null";
    });
    await run("node.boundVariables", () => {
      const n = first((x) => "layoutMode" in x && x.layoutMode !== "NONE");
      if (!n) return miss("no auto-layout node on page");
      if (n.boundVariables === undefined) return miss("undefined on " + n.type);
      const keys = Object.keys(n.boundVariables || {});
      for (const k of keys) {
        const a = Array.isArray(n.boundVariables[k]) ? n.boundVariables[k][0] : n.boundVariables[k];
        if (a && a.id) { aliasId = a.id; break; }
      }
      return keys.length + " bound properties on " + n.name;
    });
    await run("figma.variables.getVariableByIdAsync", async () => {
      if (!fn(figma.variables, "getVariableByIdAsync")) return miss("not a function");
      if (!aliasId) { try { const l = await figma.variables.getLocalVariablesAsync(); if (l[0]) aliasId = l[0].id; } catch (e) { /* no fallback id */ } }
      const v = await figma.variables.getVariableByIdAsync(aliasId || "VariableID:0:0");
      if (!aliasId) return v ? "no variable in file; dummy id resolved unexpectedly" : "no variable in file; null for a dummy id";
      return v ? "resolved " + v.name : "returned null for " + aliasId;
    });
    await run("figma.variables.getLocalVariablesAsync", async () => {
      if (!fn(figma.variables, "getLocalVariablesAsync")) return miss("not a function");
      return (await figma.variables.getLocalVariablesAsync()).length + " variables";
    });
    await run("figma.variables.getLocalVariableCollectionsAsync", async () => {
      if (!fn(figma.variables, "getLocalVariableCollectionsAsync")) return miss("not a function");
      return (await figma.variables.getLocalVariableCollectionsAsync()).length + " collections";
    });
    await run("figma.teamLibrary.getAvailableLibraryVariableCollectionsAsync", async () => {
      if (!fn(figma.teamLibrary, "getAvailableLibraryVariableCollectionsAsync")) return miss("not a function");
      return (await figma.teamLibrary.getAvailableLibraryVariableCollectionsAsync()).length + " library collections";
    });
    await run("figma.variables.importVariableByKeyAsync", () => presence(figma.variables, "importVariableByKeyAsync"));
    await run("node.setBoundVariable", () => presence(tmpFrame(), "setBoundVariable"));
    for (const [kind, name] of [["text", "getLocalTextStylesAsync"], ["paint", "getLocalPaintStylesAsync"], ["effect", "getLocalEffectStylesAsync"], ["grid", "getLocalGridStylesAsync"]]) {
      await run("figma." + name, async () => {
        if (!fn(figma, name)) return miss("not a function");
        styles[kind] = await figma[name]();
        return styles[kind].length + " styles";
      });
    }
    await run("figma.getStyleByIdAsync", async () => {
      if (!fn(figma, "getStyleByIdAsync")) return miss("not a function");
      const s = [styles.text, styles.paint, styles.effect, styles.grid].map((l) => l && l[0]).find(Boolean);
      if (!s) return miss("no local style in file");
      const r = await figma.getStyleByIdAsync(s.id);
      return r ? "resolved " + r.name : { status: "error", detail: "null for " + s.id };
    });
    await run("node.setFillStyleIdAsync", () => presence(tmpFrame(), "setFillStyleIdAsync"));
    await run("node.setTextStyleIdAsync", () => presence(tmpText(), "setTextStyleIdAsync"));
    await run("figma.getImageByHash + image.getBytesAsync", async () => {
      const isImage = (f) => f.type === "IMAGE" && f.imageHash;
      const n = first((x) => Array.isArray(x.fills) && x.fills.some(isImage));
      if (!n) return miss("no image on page");
      if (!fn(figma, "getImageByHash")) return miss("not a function");
      const img = figma.getImageByHash(n.fills.find(isImage).imageHash);
      if (!img) return { status: "error", detail: "getImageByHash returned null" };
      return (await img.getBytesAsync()).length + " bytes from " + n.name;
    });
    await run("figma.createImage", () => presence(figma, "createImage"));
    await run("node.setPluginData / getPluginData", () => {
      if (!fn(tmpFrame(), "setPluginData")) return miss("not a function");
      frame.setPluginData("fm-probe", "ok");
      return roundTrip(frame.getPluginData("fm-probe"));
    });
    await run("node.setSharedPluginData / getSharedPluginData", () => {
      if (!fn(tmpFrame(), "setSharedPluginData")) return miss("not a function");
      frame.setSharedPluginData("fmprobe", "check", "ok");
      return roundTrip(frame.getSharedPluginData("fmprobe", "check"));
    });
    await run("figma.clientStorage.setAsync / getAsync", async () => {
      if (!fn(figma.clientStorage, "setAsync")) return miss("not a function");
      stored = true;
      await figma.clientStorage.setAsync("fm-probe", "ok");
      return roundTrip(await figma.clientStorage.getAsync("fm-probe"));
    });
    await run("node.query", () => presence(tmpFrame(), "query"));
    await run("node.set", () => presence(tmpFrame(), "set"));
    drop(frame);
    await run("figma.createAutoLayout", () => {
      if (!fn(figma, "createAutoLayout")) return miss("not a function");
      auto = figma.createAutoLayout();
      auto.name = "fm-probe";
      const mode = auto.layoutMode;
      drop(auto);
      return "created and removed; layoutMode " + mode;
    });
    await run("figma.loadAllPagesAsync", () => presence(figma, "loadAllPagesAsync"));
    await run("figma.ui", () => (figma.ui ? "presence only" : miss("undefined")));
    // Text sizing order under test: resize, then textAutoResize, then characters.
    await run("text sizing: resize, textAutoResize, characters", async () => {
      await figma.loadFontAsync({ family: "Inter", style: "Regular" });
      const t = tmpText();
      t.resize(200, 16);
      t.textAutoResize = "HEIGHT";
      t.characters = "Capability probe text sizing check";
      const h = t.height;
      drop(t);
      return "height " + h + " at width 200";
    });
    await run("figma.notify", () => {
      if (!fn(figma, "notify")) return miss("not a function");
      const h = figma.notify("fm-probe", { timeout: 1000 });
      return h && fn(h, "cancel") ? "called; handler returned" : "called";
    });
    // Timed walk of the current page, page node excluded.
    try {
      const t0 = Date.now();
      let count = 0;
      const stack = [...page.children];
      while (stack.length) { const n = stack.pop(); count++; if ("children" in n) for (const c of n.children) stack.push(c); }
      walkMs = Date.now() - t0;
      nodesWalked = count;
    } catch (e) { /* walk fields stay null */ }
  } finally {
    drop(frame); drop(auto); drop(text);
    if (stored) { try { await figma.clientStorage.deleteAsync("fm-probe"); } catch (e) { /* key may not exist */ } }
  }
  const count = (l) => (l ? l.length : null);
  const styleCounts = { text: count(styles.text), paint: count(styles.paint), effect: count(styles.effect), grid: count(styles.grid) };
  // Payload last: PAYLOAD characters, so truncation of the result is visible from the chat.
  const payloadSample = "x".repeat(PAYLOAD);
  return { runtime, date: new Date().toISOString().slice(0, 10), checks, payloadBytesReturned: payloadSample.length, payloadSample, walkMs, nodesWalked, styleCounts };
})();
```

## In-app execution (Figma agent)

If a script-execution tool such as `evaluate_script` is available, run the probe helper through it once, exactly as written; it returns the result object. If the run is rejected for size, run it exactly once more with `PAYLOAD` set to 30000 and record the rejection text on the payload line. If no script tool is available, follow the edge case for a missing script path.

After the helper returns and before printing the table, run the two UI experiments, one at a time, and append their rows after the helper's rows in this order. A tool that exists but fails records `error` with the error text.

1. **Question card.** If a structured question tool such as `ask_user_question` is available, ask through it: "Did this question render with clickable options? 1. Yes, 2. No, 3. I only see text". Wait for the answer and record `ask_user_question | available | <answer>`. If the tool does not exist, record `ask_user_question | missing | —`.
2. **Widget.** If a widget tool such as `show_widget` is available, render a two-card picker: "Card A" and "Card B", each with a Select button that calls `sendPrompt("Picked A")` or `sendPrompt("Picked B")`. Wait for the next message and record `show_widget | available | <what rendered and what was clicked>`. If the tool does not exist, record `show_widget | missing | —`.
