// enhancement: revert begin
// Revert: restore each applied change's previous value or binding, only where the layer still reads what apply set.
(async () => {
  const changes = [/* the `applied` list apply returned: { id, property, previous, previousVariableId, value, variableId } */];
  const get = (id) => figma.getNodeByIdAsync ? figma.getNodeByIdAsync(id) : Promise.resolve(figma.getNodeById(id));
  const read = (n, p) => ({ actual: n[p], actualVariableId: n.boundVariables?.[p]?.id ?? null });
  const skipped = [];
  let reverted = 0;
  for (const c of changes) {
    let n = null, now = { actual: null, actualVariableId: null };
    try {
      n = await get(c.id);
      if (!n || n.removed || !(c.property in n)) { skipped.push({ ...c, reason: "node or property missing", ...now }); continue; }
      now = read(n, c.property);
      // Changed since apply, or no number to restore: never write; report what the layer reads now.
      if (now.actual !== c.value || now.actualVariableId !== (c.variableId ?? null)) { skipped.push({ ...c, reason: "changed since", ...now }); continue; }
      if (typeof c.previous !== "number" || !Number.isFinite(c.previous)) { skipped.push({ ...c, reason: "previous not a number", ...now }); continue; }
      if (c.previousVariableId) {
        const v = await figma.variables.getVariableByIdAsync(c.previousVariableId);
        if (!v) { skipped.push({ ...c, reason: "previous variable not found", ...now }); continue; }
        n.setBoundVariable(c.property, v);
      } else {
        // Previously unbound: remove the binding apply added, then restore the number.
        if (now.actualVariableId) n.setBoundVariable(c.property, null);
        n[c.property] = c.previous;
      }
      // Re-read: count it only when the layer reads the previous value and binding again.
      const after = read(n, c.property);
      if (after.actual === c.previous && after.actualVariableId === (c.previousVariableId ?? null)) reverted++;
      else skipped.push({ ...c, reason: "could not restore", ...after });
    } catch (e) { let r = now; try { r = read(n, c.property); } catch (e2) { /* unreadable: keep the last reading */ } skipped.push({ ...c, reason: String(e), ...r }); }
  }
  return { reverted, skipped };
})();
// enhancement: revert end
