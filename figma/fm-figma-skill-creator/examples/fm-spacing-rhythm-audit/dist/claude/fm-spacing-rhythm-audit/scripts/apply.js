// Apply: set only the confirmed properties to their target values. Fill `fixes` from the confirmed rows (add
// `variableId` for a bind fix); set `override: true` only when the user approved creating an instance override.
(async () => {
  const fixes = [/* { id: "12:34", property: "paddingLeft", value: 16, variableId: "VariableID:1:2", override: false } */];
  const get = (id) => figma.getNodeByIdAsync ? figma.getNodeByIdAsync(id) : Promise.resolve(figma.getNodeById(id));
  const insideInstance = (n) => { for (let p = n; p && p.type !== "PAGE"; p = p.parent) if (p.type === "INSTANCE") return true; return false; };
  const applied = [], skipped = [];
  for (const f of fixes) {
    const n = await get(f.id);
    if (!n || !(f.property in n)) { skipped.push({ ...f, reason: "node or property missing" }); continue; }
    // Capture the previous value and binding before anything changes; never replace an existing binding.
    const prior = n.boundVariables && n.boundVariables[f.property];
    const previous = n[f.property], previousVariableId = prior ? prior.id : null;
    if (prior && prior.id !== f.variableId) { skipped.push({ ...f, reason: "existing binding" }); continue; }
    if (insideInstance(n) && !f.override) { skipped.push({ ...f, reason: "override not approved" }); continue; }
    try {
      n[f.property] = f.value;
      // enhancement: token-conformance begin
      if (f.variableId) { const v = await figma.variables.getVariableByIdAsync(f.variableId); if (!v) throw new Error("variable not found"); n.setBoundVariable(f.property, v); }
      // enhancement: token-conformance end
      applied.push({ id: f.id, property: f.property, previous, previousVariableId, value: f.value, variableId: f.variableId || null });
    } catch (e) { skipped.push({ ...f, previous, reason: String(e) }); }
  }
  return { applied, skipped };
})();
