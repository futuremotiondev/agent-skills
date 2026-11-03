// Seed for fm-spacing-rhythm-audit 2.0 oracle tests (fm-spacing-audit-seed, page "Seed").
// Run through use_figma (top-level await, result from return). Idempotent: nodes, variables, and collections
// are found by name and skipped when present, so a second run creates nothing and returns the same ids.

// Page: the seed lives on the page named "Seed"; switch to it once.
const page = figma.root.children.find((p) => p.name === "Seed");
if (!page) throw new Error('No page named "Seed" in this file');
await figma.setCurrentPageAsync(page);
await figma.loadFontAsync({ family: "Inter", style: "Regular" });

const V = figma.variables;
const ids = {}, variableIds = {}, collectionIds = {}, created = [], skipped = [];
let modesSupported = true;

// ---------- Variables ----------

// Find a local collection by name, or create it and rename its first mode to "Default" at once.
const collections = await V.getLocalVariableCollectionsAsync();
const ensureCollection = (name) => {
  let c = collections.find((x) => x.name === name);
  if (c) { skipped.push(name); }
  else {
    c = V.createVariableCollection(name);
    c.renameMode(c.modes[0].modeId, "Default");
    created.push(name);
  }
  collectionIds[name] = c.id;
  return c;
};

// Find a FLOAT variable by name inside a collection, or create it with its Default value and scopes.
const floats = await V.getLocalVariablesAsync("FLOAT");
const ensureVariable = (name, collection, value, scopes) => {
  let v = floats.find((x) => x.name === name && x.variableCollectionId === collection.id);
  if (v) { skipped.push(name); }
  else {
    v = V.createVariable(name, collection, "FLOAT");
    v.setValueForMode(collection.modes[0].modeId, value);
    v.scopes = scopes;
    created.push(name);
  }
  variableIds[name] = v.id;
  return v;
};

// Legacy: one off-rhythm token in a second collection (a candidate there, never offered).
const legacy = ensureCollection("Legacy");
const odd18 = ensureVariable("legacy/odd-18", legacy, 18, ["GAP"]);

// Spacing: the collection that wins the candidate count (six candidates, one of them an alias).
const spacing = ensureCollection("Spacing");
const SPACE = [["Space/100", 4], ["Space/150", 6], ["Space/200", 8], ["Space/300", 12], ["Space/400", 16]];
const space = {};
for (const [name, value] of SPACE) space[name] = ensureVariable(name, spacing, value, ["GAP", "WIDTH_HEIGHT"]);

// Alias: created with a placeholder, then every mode set to the alias of Space/200 below.
const aliasName = "Space/alias-of-200";
const aliasExisted = floats.some((x) => x.name === aliasName && x.variableCollectionId === spacing.id);
const alias200 = ensureVariable(aliasName, spacing, 8, ["GAP", "WIDTH_HEIGHT"]);
const aliasValue = V.createVariableAlias(space["Space/200"]);

// Compact mode: Space/300 = 10, every other value equals Default. addMode can throw on plan limits.
let compactId = (spacing.modes.find((m) => m.name === "Compact") || {}).modeId || null;
if (compactId) { skipped.push("Spacing/Compact"); }
else {
  try {
    compactId = spacing.addMode("Compact");
    created.push("Spacing/Compact");
    for (const [name, value] of SPACE) space[name].setValueForMode(compactId, name === "Space/300" ? 10 : value);
  } catch (e) {
    modesSupported = false;
    compactId = null;
  }
}

// The alias reads Space/200 in every mode (set only when the alias was created or Compact was just added).
if (!aliasExisted || created.includes("Spacing/Compact")) {
  for (const m of spacing.modes) alias200.setValueForMode(m.modeId, aliasValue);
  alias200.scopes = ["GAP", "WIDTH_HEIGHT"];
}

// ---------- Nodes ----------

// Find a top-level node on the page by name, or build it with make().
const top = (name) => page.children.filter((n) => n.name === name);
const ensureNode = (name, make) => {
  const found = top(name);
  if (found.length > 1) throw new Error('Several top-level nodes named "' + name + '"');
  let n = found[0];
  if (n) { skipped.push(name); }
  else { n = make(); n.name = name; created.push(name); }
  ids[name] = n.id;
  return n;
};

// A vertical auto-layout frame with fixed size and the given paddings and gap; gap defaults to 0.
const frame = (p) => {
  const f = figma.createFrame();
  f.resize(160, 120);
  f.layoutMode = "VERTICAL";
  f.primaryAxisSizingMode = "FIXED";
  f.counterAxisSizingMode = "FIXED";
  f.paddingTop = p.top || 0; f.paddingRight = p.right || 0; f.paddingBottom = p.bottom || 0; f.paddingLeft = p.left || 0;
  f.itemSpacing = p.gap || 0;
  page.appendChild(f);
  return f;
};
const all = (v) => ({ top: v, right: v, bottom: v, left: v });

// Card: 280 wide, hugs its height, padding 16 / 19 / 16 / 52 (top / right / bottom / left), gap 13, two text children.
const card = ensureNode("Card", () => {
  const c = figma.createComponent();
  c.resize(280, 100);
  c.layoutMode = "VERTICAL";
  c.counterAxisSizingMode = "FIXED";
  c.primaryAxisSizingMode = "AUTO";
  c.paddingTop = 16; c.paddingRight = 19; c.paddingBottom = 16; c.paddingLeft = 52;
  c.itemSpacing = 13;
  for (const [n, s] of [["Title", "Card title"], ["Body", "Card body text"]]) {
    const t = figma.createText();
    t.name = n; t.characters = s;
    c.appendChild(t);
  }
  page.appendChild(c);
  return c;
});

// First row, left to right at y = 0 with 40 px gaps.
const row = [card];
row.push(ensureNode("Hero", () => frame({ ...all(24), gap: 14 })));
row.push(ensureNode("Bound padding", () => {
  const f = frame(all(18));
  for (const k of ["paddingTop", "paddingRight", "paddingBottom", "paddingLeft"]) f.setBoundVariable(k, odd18);
  return f;
}));
row.push(ensureNode("Fractional", () => frame(all(15.5))));
row.push(ensureNode("Hidden scratch", () => { const f = frame(all(7)); f.visible = false; return f; }));
row.push(ensureNode("Token card", () => frame({ ...all(8), gap: 6 })));
row.push(ensureNode("Alias card", () => {
  const f = frame({ top: 8, right: 8, bottom: 8, left: 8 });
  f.setBoundVariable("paddingLeft", alias200);
  return f;
}));
row.push(ensureNode("Default card", () => frame({ left: 10 })));
if (modesSupported && compactId) {
  row.push(ensureNode("Compact card", () => {
    const f = frame({ left: 10 });
    f.setExplicitVariableModeForCollection(spacing, compactId);
    f.setBoundVariable("paddingTop", space["Space/300"]);
    return f;
  }));
}
let x = 0;
for (const n of row) { n.x = x; n.y = 0; x += n.width + 40; }

// Second row: the three instances of Card, below it; the third overrides the gap to 15.
const y2 = Math.max(...row.map((n) => n.height)) + 80;
const instances = [
  ensureNode("Card / A", () => card.createInstance()),
  ensureNode("Card / B", () => card.createInstance()),
  ensureNode("Card / Override", () => { const i = card.createInstance(); i.itemSpacing = 15; return i; }),
];
x = 0;
for (const n of instances) { n.x = x; n.y = y2; x += n.width + 40; }

return { ids, variableIds, collectionIds, modesSupported, created, skipped };
