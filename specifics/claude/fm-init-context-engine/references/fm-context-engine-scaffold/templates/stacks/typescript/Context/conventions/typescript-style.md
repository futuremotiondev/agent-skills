---
last_verified: {{TODAY}}
---

# TypeScript Style

Seeded by the context-engine `typescript` adapter. This is a starting point — tighten as the project develops, and record contested choices as ADRs. If this project is plain JavaScript, keep the structural rules and drop the type-specific ones.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Compiler settings

- `strict: true` in `tsconfig.json`, and no per-file `// @ts-nocheck`. A `@ts-expect-error` is acceptable with a comment saying why and what would remove it; `@ts-ignore` is not.
- **Default:** `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes` on for new projects. They catch a whole class of runtime bug and are painful to adopt later.
- The typecheck is a gate, not a suggestion: it runs in CI and before release.

## Types at boundaries

- No `any` on anything exported, serialized, or sent across a process, network, or message boundary. Those types are the contract. Use `unknown` plus a narrowing check when the shape is genuinely unknown.
- Validate external input at the edge (network responses, file contents, message payloads) rather than asserting a type onto it. A type assertion is a claim the compiler cannot check.
- **Default:** prefer discriminated unions over optional-field soup for anything with modes or states. A `kind` field makes exhaustiveness checkable.
- **Default:** model impossible states out of existence where it is cheap. Two booleans that cannot both be true should be one union.

## Modules

- **Default:** one responsibility per module; a module's public surface is what its entry point re-exports.
- **Default:** use `import type` / `export type` for type-only imports so the emitted JavaScript stays clean and bundlers can drop them.
- **Default:** avoid deep relative import chains (`../../../`). Configure path aliases in `tsconfig.json` and use them consistently.
- **Default:** barrel files (`index.ts` re-export hubs) are fine at a package boundary and a liability inside one, where they create import cycles.

## Errors and async

- Reject with `Error` instances (or subclasses), never strings or plain objects. Stack traces matter.
- Every `await` is inside a function that either handles the rejection or documents that it propagates. No floating promises; enable the lint rule that catches them.
- **Default:** prefer `Promise.all` for independent work and a sequential loop for dependent work; do not `await` inside a loop for work that could run concurrently.

## Tooling

- The package manager is whatever the lockfile says; commit the lockfile and do not mix managers.
- **Default:** formatting and linting are automated and run in CI.
- Silence a lint rule at the site with a reason, never globally.
