const PAYLOAD = 50000; // in-app sample size; see the MCP section for the 48,000-byte bridge limit
const checks = [];
const tidy = (s) => String(s).replace(/[|\r\n]+/g, " ");
const miss = (detail) => ({ status: "missing", detail });
const fn = (o, k) => o != null && typeof o[k] === "function";
// A Spec file has no canvas: rows that need a layer or a write are skipped there.
const SPEC = (() => { try { return figma.editorType === "figspec"; } catch (e) { return false; } })();
const NO_SPEC = /^(node\.|text sizing|figma\.(clientStorage|createAutoLayout|notify|commitUndo|saveVersionHistoryAsync|spec\.createOnCanvasAsync))/;
const run = async (api, body) => {
  if (SPEC && NO_SPEC.test(api)) { checks.push({ api, status: "missing", detail: "skipped in a Spec file" }); return; }
  try {
    const r = await body();
    if (r && typeof r === "object") checks.push({ api, status: r.status || "available", detail: tidy(r.detail || "—").slice(0, 120) });
    else checks.push({ api, status: "available", detail: r === undefined ? "—" : tidy(r).slice(0, 120) });
  } catch (e) {
    // Reading a member the surface does not have throws; that is a missing API, not a failed call.
    checks.push({ api, status: /no such property/.test(String(e)) ? "missing" : "error", detail: tidy(String(e).slice(0, 120)) });
  }
};
const presence = (o, k) => (fn(o, k) ? "presence only" : miss("not a function"));
const roundTrip = (v) => (v === "ok" ? "round trip ok" : { status: "error", detail: "read back " + JSON.stringify(v) });
const page = figma.currentPage;
// Find the first matching node; a malformed remote component can throw on property access.
const first = (test) => page.findOne((n) => { try { return test(n); } catch (e) { return false; } });
const drop = (n) => { try { if (n && !n.removed) n.remove(); } catch (e) { /* already gone */ } };
let frame = null, auto = null, text = null, spec = null, stored = false, walkMs = null, nodesWalked = null, aliasId = null;
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
  await run("figma.root.name", () => {
    const read = "read " + JSON.stringify(figma.root.name);
    if (SPEC) return read + "; set skipped in a Spec file";
    try { figma.root.name = figma.root.name; return read + "; set: ok"; } catch (e) { return read + "; set: " + String(e); }
  });
  await run("figma.motion", () => (figma.motion ? "presence only" : miss("undefined")));
  await run("figma.commitUndo", () => {
    if (!fn(figma, "commitUndo")) return miss("not a function");
    figma.commitUndo();
    return "called";
  });
  await run("figma.saveVersionHistoryAsync", async () => {
    if (!fn(figma, "saveVersionHistoryAsync")) return miss("not a function");
    const r = await figma.saveVersionHistoryAsync("fm-probe");
    return "saved; id " + (r && r.id);
  });
  await run("node.annotations", () => {
    const n = tmpFrame();
    if (!("annotations" in n)) return miss("no annotations property");
    n.annotations = [{ label: "fm-probe" }];
    return n.annotations.length + " annotation read back";
  });
  await run("figma.annotations.getAnnotationCategoriesAsync", async () => {
    if (!fn(figma.annotations, "getAnnotationCategoriesAsync")) return miss("not a function");
    return (await figma.annotations.getAnnotationCategoriesAsync()).length + " categories";
  });
  await run("node.exportAsync PNG", async () => {
    if (!fn(tmpFrame(), "exportAsync")) return miss("not a function");
    return (await frame.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: 1 } })).length + " bytes";
  });
  await run("node.screenshot", () => presence(tmpFrame(), "screenshot"));
  await run("node.transform3d / scene3d / transformOrigin", () => {
    const found = ["transform3d", "scene3d", "transformOrigin"].filter((k) => k in tmpFrame());
    return found.length ? "present: " + found.join(", ") : miss("none of the three");
  });
  await run("figma.teamLibrary.getVariablesInLibraryCollectionAsync + importVariableByKeyAsync", async () => {
    if (!fn(figma.teamLibrary, "getVariablesInLibraryCollectionAsync")) return miss("not a function");
    const cols = await figma.teamLibrary.getAvailableLibraryVariableCollectionsAsync();
    if (!cols.length) return "presence only; no library collection enabled";
    const vars = await figma.teamLibrary.getVariablesInLibraryCollectionAsync(cols[0].key);
    if (!vars.length || SPEC) return "listed " + vars.length + " in " + cols[0].name + "; nothing imported";
    const v = await figma.variables.importVariableByKeyAsync(vars[0].key);
    return "listed " + vars.length + "; imported " + v.name;
  });
  await run("figma.variables.setBoundVariableForPaint", async () => {
    if (!fn(figma.variables, "setBoundVariableForPaint")) return miss("not a function");
    const c = (await figma.variables.getLocalVariablesAsync()).find((v) => v.resolvedType === "COLOR");
    if (!c) return "presence only; no local colour variable";
    const p = figma.variables.setBoundVariableForPaint({ type: "SOLID", color: { r: 0, g: 0, b: 0 } }, "color", c);
    return p.boundVariables && p.boundVariables.color ? "returned paint is bound to " + c.name : { status: "error", detail: "returned paint has no binding" };
  });
  // Object.keys(figma.spec) is empty even when every method exists, so members are tested by name.
  await run("figma.spec members", () => {
    const s = figma.spec;
    if (!s) return miss("figma.spec is undefined");
    const lost = ["getContent", "setContent", "editContent", "createOnCanvasAsync", "getBlockContent"].filter((k) => !fn(s, k));
    for (const k of ["create", "getThread", "reply"]) if (!fn(s.comments, k)) lost.push("comments." + k);
    return lost.length ? (8 - lost.length) + " of 8 are functions; not: " + lost.join(", ") : "8 of 8 are functions";
  });
  await run("figma.spec.getContent", async () => {
    if (!fn(figma.spec, "getContent")) return miss("not a function");
    const docs = page.findAllWithCriteria({ types: ["SPEC_BLOCK"] }).filter((n) => n.specBlockType === "DOCUMENT");
    if (!docs.length) return miss("no Spec on this page");
    const c = await figma.spec.getContent({ specNodeId: docs[0].id, maxLines: 1 });
    return "totalLines " + c.totalLines + ", hasMore " + c.hasMore;
  });
  await run("figma.spec.createOnCanvasAsync", async () => {
    if (!fn(figma.spec, "createOnCanvasAsync")) return miss("not a function");
    const r = await figma.spec.createOnCanvasAsync({ title: "fm-probe", content: "# fm-probe\n" });
    spec = await figma.getNodeByIdAsync(r.specNodeId);
    const size = spec ? Math.round(spec.width) + " x " + Math.round(spec.height) : "node not found";
    drop(spec);
    return "created and removed; " + size;
  });
  drop(frame);
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
  drop(frame); drop(auto); drop(text); drop(spec);
  if (stored) { try { await figma.clientStorage.deleteAsync("fm-probe"); } catch (e) { /* key may not exist */ } }
}
const count = (l) => (l ? l.length : null);
const styleCounts = { text: count(styles.text), paint: count(styles.paint), effect: count(styles.effect), grid: count(styles.grid) };
// Payload last: PAYLOAD characters, so truncation of the result is visible from the chat.
const payloadSample = "x".repeat(PAYLOAD);
return { runtime, date: new Date().toISOString().slice(0, 10), checks, payloadBytesReturned: payloadSample.length, payloadSample, walkMs, nodesWalked, styleCounts };
