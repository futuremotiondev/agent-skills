---
last_verified: {{TODAY}}
---

# Electron Style

Seeded by the context-engine `electron` adapter. The process-boundary rules are security-load-bearing guardrails: deviating from one needs an ADR that explains the threat model.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Process model (guardrails)

- `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true` on every `BrowserWindow`. No exceptions without an ADR explaining the threat model.
- The **preload script is the only bridge**: expose a minimal, typed API via `contextBridge.exposeInMainWorld` — never leak `ipcRenderer` itself, Node modules, or generic "invoke anything" passthroughs to the renderer.
- Renderer code contains **zero** Node/Electron API usage — it is a web app that talks to the typed preload API.
- Privileged work (filesystem, shell, native modules, child processes) lives in the main process behind IPC handlers.

## IPC

- **Default:** one **channel registry module** owns every channel name and its request/response types — main handlers, preload exposure, and renderer callers all import from it. A stringly-typed channel used in two places is a bug factory.
- No `any` on a channel payload type: the payload types are the app's contract.
- **Default:** prefer `ipcMain.handle` / `ipcRenderer.invoke` (request/response) over `send`/`on` fire-and-forget; use events only for genuine push notifications.
- Validate inputs in main-process handlers — the renderer is untrusted input once anything remote can render in it.

## Security

- A restrictive Content-Security-Policy on every window; no remote content unless the ADR says so.
- `shell.openExternal` only after validating the URL scheme is http(s).
- Handle `will-navigate` / `setWindowOpenHandler` to block unexpected navigation.

## Layout and boundaries

**Default** split: `src/main/` (main process), `src/preload/` (bridge), `src/renderer/` (UI), `src/shared/` (types/constants only). Shared **types** between the three processes live in `src/shared/` and are imported by all of them; runtime code that depends on one process's APIs never goes there. General TypeScript rules live in [TypeScript style](typescript-style.md). The path-scoped rule at `.claude/rules/electron-boundaries.md` auto-loads when editing any of them; if this project uses different directory names, update BOTH that rule's `paths:` globs and this section.
