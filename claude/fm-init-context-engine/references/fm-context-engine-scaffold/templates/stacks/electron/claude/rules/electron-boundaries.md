---
paths:
  - "src/main/**"
  - "src/preload/**"
  - "src/renderer/**"
  - "src/shared/**"
---

# Electron Process-Boundary Rules

Auto-loaded when editing main / preload / renderer / shared code. Seeded by the context-engine `electron` adapter — if the project's directory names differ, fix the `paths:` globs above.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## In `src/main/`

- Validate every incoming IPC payload in its handler; the renderer is untrusted input.
- If the project uses the channel registry (the default), every handler imports its channel name and types from it.
- Window creation always sets `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`.

## In `src/preload/`

- Expose a minimal typed API via `contextBridge.exposeInMainWorld` — never `ipcRenderer` itself, never generic passthroughs.
- Preload runs with privileges the renderer lacks. Keep it a thin bridge with no business logic.

## In `src/renderer/`

- No Node or Electron imports — renderer is a pure web app consuming the typed preload API.
- A new backend need is a new typed channel (a main handler and a preload exposure, plus a registry entry if the project uses one), never a boundary leak.

## In `src/shared/`

- No runtime code that depends on one process's APIs; it breaks in the others.
