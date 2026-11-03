// Verify: re-read each applied property and compare with the target. Run after Apply, never inside it.
(async () => {
  const fixes = [/* the same list that was applied */];
  const get = (id) => figma.getNodeByIdAsync ? figma.getNodeByIdAsync(id) : Promise.resolve(figma.getNodeById(id));
  const results = [];
  for (const f of fixes) {
    const n = await get(f.id);
    const actual = n ? n[f.property] : null;
    let ok = actual === f.value;
    // enhancement: token-conformance begin
    if (f.variableId) { const b = n && n.boundVariables && n.boundVariables[f.property]; ok = ok && !!b && b.id === f.variableId; }
    // enhancement: token-conformance end
    results.push({ ...f, actual, ok });
  }
  return { verified: results.filter((r) => r.ok).length, total: results.length, mismatches: results.filter((r) => !r.ok) };
})();
