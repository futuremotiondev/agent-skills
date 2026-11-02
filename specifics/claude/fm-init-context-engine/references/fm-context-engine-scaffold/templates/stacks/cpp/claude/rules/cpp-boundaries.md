---
paths:
  - "include/**"
  - "src/**"
---

# C++ Header / Source Boundary Rules

Auto-loaded when editing public headers or implementation. Seeded by the context-engine `cpp` adapter — if the project's directory names differ, fix the `paths:` globs above.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## In `include/`

- Public headers only. Nothing here includes a private header from `src/`.
- Every header is guarded against multiple inclusion and includes what it uses, rather than relying on another header's transitive includes.
- A change here recompiles every consumer — prefer adding over reshaping, and keep ABI-facing structs stable.
- Anything crossing a foreign-language boundary is `extern "C"` with POD types and opaque handles; no `std::` types, no exceptions.

## In `src/`

- Implementation and private headers.
- New public surface = a declaration in `include/` + its definition here + a CMake target update if a new file was added. Never expose a symbol only from a `.cpp`.
- No `new`/`delete` outside an owning wrapper; no raw owning pointers in signatures.
- Exceptions (if the module uses them) are caught and translated to error codes before any `extern "C"` function returns.
