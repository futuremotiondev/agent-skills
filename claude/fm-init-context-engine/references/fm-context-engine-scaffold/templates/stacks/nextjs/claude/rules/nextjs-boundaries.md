---
paths:
  - "app/**"
  - "src/app/**"
  - "components/**"
  - "src/components/**"
  - "lib/**"
  - "src/lib/**"
---

# Next.js Boundary Rules

Auto-loaded when editing App Router code. Seeded by the context-engine `nextjs` adapter — if the project's layout differs, fix the `paths:` globs above.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## Before adding `"use client"`

- The directive marks a **boundary**, not a component. Everything the file imports joins the client bundle transitively. Check what comes along before adding it.
- Marking a whole page or layout sends its entire import graph to the client. Extracting only the interactive part keeps the rest on the server.
- It does not mean client-only. The component still server-renders first, so `window`, `document`, and `localStorage` must be inside an effect or guarded.
- Never add it to a module that reads a secret or imports a database client.

## In Server Components (the default)

- May be `async` and await data directly. Hooks and event handlers are not available here.
- This is where secrets, database access, and server-only modules belong.
- Props handed to a Client Component must be serializable. Pass a Server Action instead of a function.

## Server Actions (`"use server"`)

- Every action is a **public POST endpoint**. Authenticate and authorize inside the action; the calling component is not a security boundary.
- Validate every argument before use. It arrives from the network, whatever the caller's types claim.
- Revalidate the affected path or tag after a mutation, or the UI shows stale data.

## Routes

- `page.tsx` and `route.ts` are public URLs. Renaming or removing one needs a redirect.
- Dynamic segments call `notFound()` when the record does not exist rather than rendering an empty state.
- `(group)` does not change the URL; `_folder` is not routed; `@slot` is a parallel route.
- After adding or moving routes, run `/refresh-context` to update the generated route map.

## Environment variables

- `NEXT_PUBLIC_*` is compiled into the browser bundle. Never a credential.
- Everything else is server-only and must not be imported into a client-reachable module.
