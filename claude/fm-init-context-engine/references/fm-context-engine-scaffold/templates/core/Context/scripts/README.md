# Context Regenerators

Scripts that produce the machine-authored indexes under `Context/generated/`. They are stack-specific — a PowerShell module walks its function ASTs, a C# library reflects over its built assembly, an Electron app enumerates its IPC channels and exports, a Python package walks the `ast` module.

## Contract

Every regenerator in this directory:

1. Is a standalone PowerShell 7 script, runnable as
   `pwsh -NoProfile -ExecutionPolicy Bypass -File Context/scripts/<name>.ps1` from the repo root.
2. Writes exactly one artifact into `Context/generated/`, starting with the three-line banner documented in [`../generated/README.md`](../generated/README.md).
3. Is fast (seconds, not minutes) and has no side effects outside `Context/generated/`.
4. Is registered in the `Regenerators` list of `.claude/context-engine.psd1` so `/refresh-context` picks it up.

## Current regenerators

- _(none yet — stack adapters or the maintainer add them here)_
