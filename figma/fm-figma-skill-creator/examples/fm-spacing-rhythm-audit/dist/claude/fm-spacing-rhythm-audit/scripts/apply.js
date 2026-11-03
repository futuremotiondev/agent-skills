// Apply: set only confirmed properties; fill `fixes` from confirmed rows (`variableId` for a bind fix); `override: true` only when the user approved an instance override.
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
      let bound = false;
      // enhancement: token-conformance begin
      // A bind fix only binds (the binding sets the value); a missing variable leaves the node untouched.
      if (f.variableId) {
        const v = await figma.variables.getVariableByIdAsync(f.variableId);
        if (!v) { skipped.push({ ...f, previous, reason: "variable not found" }); continue; }
        n.setBoundVariable(f.property, v); bound = true;
      }
      // enhancement: token-conformance end
      if (!bound) n[f.property] = f.value;
      applied.push({ id: f.id, property: f.property, previous, previousVariableId, value: f.value, variableId: f.variableId || null });
    } catch (e) { skipped.push({ ...f, previous, reason: String(e) }); }
  }
  return { applied, skipped };
})();
