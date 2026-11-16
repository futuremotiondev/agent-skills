// mirrors examples/fm-spacing-rhythm-audit/SKILL.md collect helper, master 2.4 (metadata.version "2.4")
// Oracle for fm-spacing-rhythm-audit 2.4, run through use_figma (top-level await, result from return).
// Changes from the master fence: this header and preamble, MODE preset, MAX_ROWS lifted to Infinity, one line after the walk
// that clears the selection, and a block before the return that restores `tokens` and `unbound[].ids`. Edit SELECTION, PAGE, and MODE per scope.
const SELECTION = "page"; // "page" (every top-level node on the page) or an array of top-level node names
const PAGE = null; // page name to switch to first; null keeps the current page (use_figma starts on the first page)
// Resolve the scope and select it; each name must match exactly one top-level node.
{
  if (PAGE) {
    const pg = figma.root.children.find((p) => p.name === PAGE);
    if (!pg) throw new Error('No page named "' + PAGE + '"');
    await figma.setCurrentPageAsync(pg);
  }
  const tops = figma.currentPage.children;
  const picked = SELECTION === "page" ? [...tops] : SELECTION.map((name) => {
    const m = tops.filter((n) => n.name === name);
    if (m.length !== 1) throw new Error('SELECTION name "' + name + '" matches ' + m.length + " top-level nodes on page " + figma.currentPage.name);
    return m[0];
  });
  figma.currentPage.selection = picked;
}
let MODE = "tokens"; // tokens | rhythm, set per scope (the helper falls back to rhythm when no tokens exist)
// Collect: read auto-layout padding and gaps, fold inherited instance values into the main component, rank off-grid values, group by component. Read-only.
const MAX_FRAMES = 2000, MAX_ROWS = Infinity;
let onGrid = (v) => v === 0 || (v < 48 ? v % 4 === 0 : v % 8 === 0);
let nearest = (v) => {
  if (onGrid(v)) return v;
  const step = v < 48 ? 4 : 8;
  const lo = Math.floor(v / step) * step, hi = lo + step;
  if (lo === 0 || v - lo !== hi - v) return lo !== 0 && v - lo < hi - v ? lo : hi; // A positive value never snaps to 0.
  return hi % 8 === 0 && lo % 8 !== 0 ? hi : lo;
};
// enhancement: token-conformance begin
// Discovery: candidates are local FLOATs scoped to GAP or named space/spacing (not letter, line-height, line-spacing, paragraph); WIDTH_HEIGHT-only and type-spacing names are matched, never offered.
if (MODE !== "discover" && MODE !== "tokens") MODE = "rhythm";
const V = figma.variables, cols = new Map(), varCache = new Map();
const getVar = (id) => { if (!varCache.has(id)) varCache.set(id, V.getVariableByIdAsync(id)); return varCache.get(id); };
const isAlias = (x) => !!x && typeof x === "object" && x.type === "VARIABLE_ALIAS";
const resolveValue = async (x, modeId) => {
  for (let hop = 0; hop < 3 && isAlias(x); hop++) {
    const t = await getVar(x.id);
    if (!t) return null;
    const tc = cols.get(t.variableCollectionId);
    x = modeId in t.valuesByMode ? t.valuesByMode[modeId] : t.valuesByMode[tc ? tc.defaultModeId : Object.keys(t.valuesByMode)[0]];
  }
  return typeof x === "number" ? x : null;
};
const discoverTokens = async () => {
  for (const c of await V.getLocalVariableCollectionsAsync()) cols.set(c.id, c);
  const found = [], perCol = new Map(), unoffered = new Map();
  const tally = (cid, why, n) => { const m = unoffered.get(cid) || new Map(); m.set(why, (m.get(why) || 0) + n); unoffered.set(cid, m); };
  for (const v of await V.getLocalVariablesAsync("FLOAT")) {
    const c = cols.get(v.variableCollectionId), scopes = v.scopes || [];
    const named = /space|spacing/i.test(v.name), typeName = /letter|\bline[-\s]?(height|spacing)\b|paragraph/i.exec(v.name);
    const candidate = scopes.includes("GAP") || (named && !typeName);
    if (!c || !(candidate || named || scopes.includes("WIDTH_HEIGHT"))) continue;
    if (candidate) perCol.set(c.id, (perCol.get(c.id) || 0) + 1);
    else tally(c.id, named ? (/^line/i.test(typeName[0]) ? "line-" + typeName[1].toLowerCase() : typeName[0].toLowerCase() + "-spacing") : "WIDTH_HEIGHT", 1);
    for (const m of c.modes) {
      const raw = v.valuesByMode[m.modeId], value = await resolveValue(raw, m.modeId);
      if (value !== null) found.push({ id: v.id, name: v.name, value, collection: c.id, modeId: m.modeId, modeName: m.name, isAlias: isAlias(raw), candidate });
    }
  }
  const dv = (id) => found.filter((t) => t.candidate && t.collection === id && t.modeId === cols.get(id).defaultModeId && !t.isAlias).map((t) => t.value);
  const pos = (id) => dv(id).some((x) => x > 0);
  let best = null;
  for (const [id, count] of perCol) if (dv(id).length && (best === null || count > perCol.get(best) || (count === perCol.get(best) && pos(id) && !pos(best)))) best = id; // Elect the most candidates among collections with a non-alias Default-mode candidate; on a tie, one with a candidate above 0.
  const c = best && cols.get(best), vals = c ? dv(best) : [], lo = Math.min(...vals), above = vals.filter((x) => x > 0);
  for (const [id, count] of perCol) if (id !== best) tally(id, dv(id).length ? "not elected" : "alias only", count);
  const dm = c && c.modes.find((m) => m.modeId === c.defaultModeId);
  const matchedCollections = [...unoffered].map(([id, m]) => ({ name: cols.get(id).name, count: [...m.values()].reduce((a, b) => a + b, 0), reasons: [...m].map(([w, n]) => n + " " + w).join(", ") }));
  let lib = "unavailable";
  try { const tl = figma.teamLibrary; if (tl && tl.getAvailableLibraryVariableCollectionsAsync) lib = (await tl.getAvailableLibraryVariableCollectionsAsync()).length ? "present, not audited" : "none"; } catch (e) { lib = "unavailable"; }
  return { all: found, candidateValues: [...new Set(vals)].sort((a, b) => a - b), libraryTokens: lib, matchedCollections, spacingCollection: c ? { id: c.id, name: c.name, defaultModeName: dm ? dm.name : "", min: lo, max: Math.max(...vals), minPositive: above.length ? Math.min(...above) : null, minNegative: lo < 0 ? lo : null } : null };
};
let found = { all: [], candidateValues: [], libraryTokens: "unavailable", matchedCollections: [], spacingCollection: null };
try { found = await discoverTokens(); } catch (e) { /* no variables API: rhythm mode below */ }
const { all, candidateValues, libraryTokens, matchedCollections, spacingCollection } = found;
const tokens = spacingCollection ? all.filter((t) => t.candidate && t.collection === spacingCollection.id) : []; // Token entries stay internal (the spacing collection's candidates, one per variable per mode); results carry only their count.
if (MODE === "discover" && spacingCollection) return { mode: "discover", tokenCount: tokens.length, candidateValues, spacingCollection, matchedCollections, libraryTokens }; // Discover with no spacing tokens falls through to the rhythm audit (the line below sets MODE).
if (tokens.length === 0) MODE = "rhythm";
const rhythm = onGrid, col = spacingCollection && cols.get(spacingCollection.id);
const inCol = (t, modeId) => !!col && t.collection === col.id && t.modeId === modeId;
if (MODE === "rhythm" && col) { const extra = new Set(tokens.filter((t) => inCol(t, col.defaultModeId)).map((t) => t.value)), above = [...extra].filter((x) => x > 0), grid = nearest; onGrid = (v) => rhythm(v) || extra.has(v); nearest = (v) => nearestToken(v, [grid(v), ...above]); } // Rhythm mode: the spacing collection's Default-mode values also count as on-grid, and its positive values as snap targets.
const cands = new Map(col ? col.modes.map((m) => [m.modeId, tokens.filter((t) => inCol(t, m.modeId) && !t.isAlias && t.value > 0)]) : []); // Per mode: bind candidates are the spacing collection's non-alias tokens above 0; its alias tokens are never offered.
const aliasCands = new Map(col ? col.modes.map((m) => [m.modeId, tokens.filter((t) => inCol(t, m.modeId) && t.isAlias)]) : []);
const bound = new Map(), boundTop = new Map(), opps = new Map(), choices = new Map(), onRhythm = new Set(), aliasMatched = new Map();
const nearestToken = (v, values) => values.reduce((b, x) => { if (b === null) return x; const dx = Math.abs(x - v), db = Math.abs(b - v); if (dx !== db) return dx < db ? x : b; if ((x % 8 === 0) !== (b % 8 === 0)) return x % 8 === 0 ? x : b; return Math.min(x, b); }, null); // Nearest token value; on a tie the multiple of 8 when exactly one is, else the lower.
// One value in token mode: null when it passes (a value only an alias holds passes too) or is a bind opportunity, else { target, fix }.
const tokenCheck = (own, k, v, isBound) => {
  if (isBound || v === 0) return null;
  const key = own.id + "|" + k, modes = own.resolvedVariableModes || {};
  const pool = cands.get(modes[col.id]) || cands.get(col.defaultModeId) || [];
  const eq = pool.filter((t) => t.value === v);
  if (eq.length) { opps.set(key, { own, k, v, eq }); return null; }
  if ((aliasCands.get(modes[col.id]) || aliasCands.get(col.defaultModeId) || []).some((t) => t.value === v)) { aliasMatched.set(key, { own, k, v }); return null; }
  const tv = nearestToken(v, pool.map((t) => t.value));
  if (tv !== null && Math.abs(tv - v) <= 4) {
    const same = pool.filter((t) => t.value === tv);
    const fix = { kind: "bind", value: tv, variableId: same[0].id, name: same[0].name, modeName: same[0].modeName };
    choices.set(fix, { list: same, top: topOf(own).id });
    if (rhythm(v)) { const alt = pool.filter((t) => t.value === 2 * v - tv).sort((a, b) => a.name.length - b.name.length)[0]; fix.nearMiss = true; if (alt) fix.alternatives = [{ name: alt.name, value: alt.value }]; } // Near miss: an on-rhythm value with a token within 4 is a P3 bind opportunity; keep a tied second token for the note.
    return { target: tv, fix };
  }
  if (rhythm(v)) { onRhythm.add(key); return null; }
  return { target: nearest(v), fix: { kind: "set", value: nearest(v), reason: "no token within 4" } };
};
// enhancement: token-conformance end
const LABEL = { paddingTop: "Padding top", paddingRight: "Padding right", paddingBottom: "Padding bottom", paddingLeft: "Padding left", itemSpacing: "Gap", counterAxisSpacing: "Row gap" };
const page = figma.currentPage;
const scratch = /scratch|archive|playground/i.test(page.name);
const pageOf = (n) => { let p = n; while (p && p.type !== "PAGE") p = p.parent; return p; };
// Path: skip unnamed ancestors, keep the last four segments, name the page when it differs.
const pathOf = (n) => {
  const parts = [];
  for (let p = n; p && p.type !== "PAGE"; p = p.parent) if (p.name && p.name.trim()) parts.unshift(p.name.trim());
  const short = parts.length > 4 ? "… / " + parts.slice(-4).join(" / ") : parts.join(" / ");
  const pg = pageOf(n);
  return pg && pg !== page ? short + " (page: " + pg.name + ")" : short;
};
// Component context: outermost component ancestor (for grouping) and depth below the nearest one.
const compInfo = (n) => {
  let root = null, depth = null, d = 0;
  for (let p = n; p && p.type !== "PAGE"; p = p.parent, d++) {
    if (p.type === "COMPONENT" || p.type === "COMPONENT_SET") { root = p; if (depth === null) depth = d; }
  }
  return { root, depth };
};
const topOf = (n) => { let p = n, t = n; while (p && p.type !== "PAGE") { t = p; p = p.parent; } return t; };
const rank = (delta, info, inst, bound, half) => {
  if (scratch || half || delta < 1) return "P3";
  if (bound) return "P2";
  if (inst) return "P1";
  if (info.root) return delta >= 2 && info.depth <= 1 ? "P0" : "P1";
  return delta >= 2 ? "P1" : "P2";
};
const rows = new Map(), inherited = new Map(), negs = new Map();
const neg = (s, k, v) => { const b = s.boundVariables && s.boundVariables[k], key = (b ? b.id : "") + "|" + v, e = negs.get(key) || { boundId: b ? b.id : null, value: v, owners: new Set(), exampleId: s.id, examplePath: pathOf(s) }; e.owners.add(s.id + "|" + k); negs.set(key, e); }; // A negative value is never classified or snapped: it is counted per variable and value, or per unbound value, for the Negative values line.
let frames = 0, hidden = 0, absolute = 0, truncated = false;
const measure = (n, inst, twin) => {
  frames++;
  const props = ["paddingTop", "paddingRight", "paddingBottom", "paddingLeft", "itemSpacing"];
  if (n.layoutWrap === "WRAP") props.push("counterAxisSpacing");
  for (const k of props) {
    const v = n[k];
    if (typeof v !== "number") continue;
    if (v < 0) { neg(inst && twin && twin[k] === v ? twin : n, k, v); continue; }
    let target = null, fix = null, half = v === 2 && (k === "itemSpacing" || k === "counterAxisSpacing");
    // enhancement: token-conformance begin
    // Record every bound value (both modes); in token mode classify against the tokens instead.
    const own = inst && twin && twin[k] === v ? twin : n, b = own.boundVariables && own.boundVariables[k];
    if (b) { bound.set(own.id + "|" + k, { id: b.id, v, modes: own.resolvedVariableModes }); const tp = topOf(own).id; boundTop.set(tp, (boundTop.get(tp) || new Set()).add(b.id)); }
    if (MODE === "tokens") { const r = tokenCheck(own, k, v, !!b); if (!r) { if (own !== n) inherited.set(own.id + "|" + k, (inherited.get(own.id + "|" + k) || 0) + 1); continue; } target = r.target; fix = r.fix; half = false; }
    // enhancement: token-conformance end
    if (target === null) {
      if (onGrid(v)) continue;
      target = nearest(v); fix = { kind: "set", value: target, reason: "nearest on-grid" };
    }
    const delta = Math.abs(target - v), signed = +(target - v).toFixed(2);
    if (inst && twin && twin[k] === v) {
      // Inherited from the main component: count it there instead of repeating the row.
      const key = twin.id + "|" + k;
      inherited.set(key, (inherited.get(key) || 0) + 1);
      if (!rows.has(key)) {
        const ti = compInfo(twin);
        const where = pageOf(twin) === page ? " (main component, outside selection)" : " (main component)";
        // The binding that matters is the main component's: an inherited value is bound there.
        const tb = twin.boundVariables && twin.boundVariables[k] ? twin.boundVariables[k].id : null;
        rows.set(key, { id: twin.id, path: pathOf(twin) + where, group: ti.root ? ti.root.name : topOf(twin).name, property: LABEL[k], current: v, nearest: target, delta: signed, priority: rank(delta, ti, false, !!tb, half), boundId: tb, note: half ? "2 px half-step" : "", fix });
      }
      continue;
    }
    const info = compInfo(n);
    const boundId = n.boundVariables && n.boundVariables[k] ? n.boundVariables[k].id : null;
    const notes = [];
    if (inst) notes.push("instance override; main component uses " + (twin ? twin[k] : "?"));
    if (half) notes.push("2 px half-step");
    if (v % 1) notes.push("fractional");
    rows.set(n.id + "|" + k, { id: n.id, path: pathOf(n), group: info.root ? info.root.name : topOf(n).name, property: LABEL[k], current: v, nearest: target, delta: signed, priority: rank(delta, info, inst, !!boundId, half), boundId, note: notes.join("; "), fix });
  }
  for (const c of n.children) if (c.layoutPositioning === "ABSOLUTE") absolute++;
};
const walk = async (n, inst, twin) => {
  if (truncated) return;
  if (n.visible === false) { hidden++; return; }
  let isInst = inst, t = twin;
  if (n.type === "INSTANCE") { isInst = true; t = n.getMainComponentAsync ? await n.getMainComponentAsync() : n.mainComponent; }
  if ("layoutMode" in n && n.layoutMode !== "NONE") {
    if (frames >= MAX_FRAMES) { truncated = true; return; }
    measure(n, isInst, t);
  }
  if ("children" in n) for (let i = 0; i < n.children.length; i++) await walk(n.children[i], isInst, t && t.children ? t.children[i] : null);
};
for (const n of page.selection) await walk(n, false, null);
figma.currentPage.selection = []; // oracle: clear the selection the preamble set
for (const [key, count] of inherited) {
  const r = rows.get(key);
  if (r) r.note = (r.note ? r.note + "; " : "") + "inherited by " + count + " instance" + (count === 1 ? "" : "s");
}
// Resolve variable names once so bound rows can name the token.
const varNames = new Map();
for (const r of rows.values()) {
  if (!r.boundId) continue;
  if (!varNames.has(r.boundId)) { const v = await figma.variables.getVariableByIdAsync(r.boundId); varNames.set(r.boundId, v ? v.name : r.boundId); }
  r.note = "bound to " + varNames.get(r.boundId) + "; change the variable" + (r.note ? "; " + r.note : "");
}
// Merge rows that read identically (same group, path, property, value) into one row with every id; the fix still hits all.
const merged = new Map();
for (const r of rows.values()) {
  let key = [r.group, r.path, r.property, r.current, r.fix.modeName].join("|");
  // enhancement: token-conformance begin
  if (r.fix && r.fix.nearMiss) { r.priority = "P3"; key += "|nm"; }
  // enhancement: token-conformance end
  const m = merged.get(key);
  if (m) { m.ids.push(r.id); m.count++; } else merged.set(key, { ...r, ids: [r.id], count: 1 });
}
const order = { P0: 0, P1: 1, P2: 2, P3: 3 };
const list = [...merged.values()].sort((a, b) => order[a.priority] - order[b.priority] || Math.abs(b.delta) - Math.abs(a.delta));
const byPriority = { P0: 0, P1: 0, P2: 0, P3: 0 };
const groups = new Map();
for (const r of list) {
  if (r.count > 1) r.note = (r.note ? r.note + "; " : "") + "in " + r.count + " frames";
  byPriority[r.priority] += r.count;
  const g = groups.get(r.group) || { group: r.group, rows: 0, P0: 0, P1: 0, P2: 0, P3: 0 };
  g.rows += r.count; g[r.priority] += r.count; groups.set(r.group, g);
}
const byGroup = [...groups.values()].sort((a, b) => b.rows - a.rows).slice(0, 15);
const boundValues = list.filter((r) => r.boundId).reduce((s, r) => s + r.count, 0);
const out = { framesMeasured: frames, hiddenSkipped: hidden, notMeasurable: absolute, truncated, values: rows.size, tableRows: list.length, byPriority, byGroup, boundValues, boundTokens: [...new Set(varNames.values())], negatives: { values: 0, list: [] }, rows: list.slice(0, MAX_ROWS) };
for (const [i, e] of [...negs.values()].sort((a, b) => b.owners.size - a.owners.size).entries()) { const n = e.owners.size, l = out.negatives.list, va = e.boundId && i < 8 ? await figma.variables.getVariableByIdAsync(e.boundId) : null; out.negatives.values += n; if (i < 8) l.push({ label: (e.boundId ? (va ? va.name : e.boundId) + " = " : "unbound ") + e.value, values: n, exampleId: e.exampleId, examplePath: e.examplePath }); else (l[8] = l[8] || { label: "others", values: 0, exampleId: e.exampleId, examplePath: e.examplePath }).values += n; } // Largest first; past eight entries the rest fold into one "others" entry.
// enhancement: token-conformance begin
// Settle bind targets (same top-level frame, then shortest name), summarise bind opportunities per token, list bound tokens off the 4/8 rhythm.
const inTop = (top, id) => (boundTop.get(top) && boundTop.get(top).has(id) ? 1 : 0);
const pick = (opts, top) => opts.slice().sort((a, b) => inTop(top, b.id) - inTop(top, a.id) || a.name.length - b.name.length)[0];
const also = (note, opts, t) => { const alts = opts.filter((x) => x !== t).map((x) => x.name); return alts.length ? (note ? note + "; " : "") + "also " + alts.join(", ") : note; };
const nearNote = (r) => { const a = r.fix.alternatives, s = r.fix.name + " (" + r.fix.value + ")"; return r.fix.nearMiss ? (r.note ? r.note + "; " : "") + (a ? "tie: " + s + " or " + a[0].name + " (" + a[0].value + ")" : "on rhythm, no token; nearest " + s) : r.note; };
for (const r of list) {
  const ch = choices.get(r.fix);
  if (ch) { const t = pick(ch.list, ch.top); r.fix.variableId = t.id; r.fix.name = t.name; r.note = also(nearNote(r), ch.list, t); }
  else if (r.fix.reason === "no token within 4") r.note = (r.note ? r.note + "; " : "") + r.fix.reason;
  else if (MODE === "rhythm" && col && !rhythm(r.fix.value)) { const t = tokens.filter((x) => inCol(x, col.defaultModeId) && x.value === r.fix.value).sort((a, b) => a.isAlias - b.isAlias || a.name.length - b.name.length)[0]; if (t) r.note = (r.note ? r.note + "; " : "") + "nearest token " + t.name + " (" + t.value + ")"; } // Rhythm mode: a snap to a token value off the 4/8 rhythm names the token.
}
const unbound = new Map(), oppRows = [];
for (const o of opps.values()) {
  const t = pick(o.eq, topOf(o.own).id), id = o.own.id, key = t.id + "|" + t.modeId, ci = compInfo(o.own), n = inherited.get(id + "|" + o.k);
  const u = unbound.get(key) || { tokenName: t.name, tokenId: t.id, modeName: t.modeName, count: 0, exampleId: id, examplePath: pathOf(o.own) };
  u.count++; unbound.set(key, u);
  oppRows.push({ id, path: pathOf(o.own), group: ci.root ? ci.root.name : topOf(o.own).name, property: LABEL[o.k], current: o.v, nearest: o.v, delta: 0, priority: "P3", boundId: null, note: also("unbound; bind to " + t.name, o.eq, t) + (n ? "; inherited by " + n + " instance" + (n === 1 ? "" : "s") : ""), fix: { kind: "bind", value: o.v, variableId: t.id, name: t.name, modeName: t.modeName }, ids: [id], count: 1 });
}
const off = new Map();
for (const b of bound.values()) {
  if (rhythm(b.v)) continue;
  const va = await getVar(b.id), c = va && cols.get(va.variableCollectionId);
  const mid = c ? (b.modes || {})[c.id] || c.defaultModeId : "", m = c && c.modes.find((x) => x.modeId === mid);
  const e = off.get(b.id + "|" + mid) || { name: va ? va.name : b.id, value: b.v, modeName: m ? m.name : "", values: 0 };
  e.values++; off.set(b.id + "|" + mid, e);
}
Object.assign(out, { mode: MODE, tokenCount: tokens.length, libraryTokens, spacingCollection, matchedCollections, unbound: [...unbound.values()].sort((a, b) => b.count - a.count), onRhythmNoToken: onRhythm.size, aliasMatched: aliasMatched.size, offRhythmTokens: [...off.values()], boundPassed: MODE === "tokens" ? bound.size : [...bound.values()].filter((b) => onGrid(b.v)).length });
oppRows.sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0) || (a.property < b.property ? -1 : a.property > b.property ? 1 : 0));
out.rows = list.concat(frames <= 50 ? oppRows : []).slice(0, MAX_ROWS);
// enhancement: token-conformance end
// oracle: restore what the helper no longer returns, for the compare script: the full token list and each unbound token's node ids
out.tokens = tokens;
for (const o of opps.values()) { const t = pick(o.eq, topOf(o.own).id), u = unbound.get(t.id + "|" + t.modeId); if (!u.ids) u.ids = []; if (!u.ids.includes(o.own.id)) u.ids.push(o.own.id); }
return out;
