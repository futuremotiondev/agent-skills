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
      if (!aliasId) return "no variable in file; null for a dummy id";
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
      const h = figma.notify("fm-probe", { timeout: 1 });
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
