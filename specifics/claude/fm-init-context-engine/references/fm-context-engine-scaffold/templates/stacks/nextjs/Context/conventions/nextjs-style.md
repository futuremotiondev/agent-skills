---
last_verified: {{TODAY}}
---

# Next.js Style

Seeded by the context-engine `nextjs` adapter. Framework-independent web rules live in [Web style](web-style.md) and language rules in [TypeScript style](typescript-style.md); this document covers the App Router and the React Server Component model.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Server and Client Components

Components are **Server Components by default**. This is the most important thing to internalize, and the source of most confusion.

- `"use client"` at the top of a file marks the **boundary**, not a single component. Every module that file imports becomes part of the client bundle, transitively. Adding the directive to a shared utility can pull half the app into the browser.
- You do not need `"use client"` in every file containing a client component. It belongs only on the files whose components are rendered directly by a Server Component.
- `"use client"` does **not** mean client-only. Those components are still server-rendered for the initial HTML, then hydrated. Code that touches `window` must be inside an effect or guarded, not at module top level.
- Server Components can be `async` and await data directly. Client Components cannot.
- Hooks, event handlers, and browser APIs require a Client Component. Data fetching, secrets, and direct database access require a Server Component.
- **Default:** push the boundary **down** the tree. A page that needs one interactive button should keep the page as a Server Component and extract the button, not mark the whole page.
- Props passed from a Server to a Client Component must be serializable. Functions do not cross; pass a Server Action instead.

## Server Actions

- `"use server"` marks a function (or a whole file) as a Server Action. It compiles into a real POST endpoint.
- **A Server Action is a public endpoint.** Authenticate and authorize inside the action itself. The fact that only an admin page calls it is not a control; anyone can invoke it directly.
- Validate every argument with a schema. Arguments arrive from the network regardless of what the calling component's types claim.
- Never close over a secret in a module that a Client Component imports.
- Revalidate explicitly after a mutation so cached data does not go stale.

## Routing and file conventions

- `app/**/page.tsx` defines a page; `route.ts` defines an endpoint. Both are public URLs.
- `layout.tsx` wraps a segment and persists across navigation within it. `template.tsx` remounts instead.
- `loading.tsx` and `error.tsx` provide the streaming fallback and error boundary for a segment. An `error.tsx` must be a Client Component.
- `(group)` folders organize without affecting the URL. `_folder` is private and not routed. `@slot` folders define parallel routes.
- Dynamic segments are `[param]`, `[...slug]` for catch-all, `[[...slug]]` for optional catch-all. Handle the unmatched case with `notFound()`.

## Data and caching

- **Default:** fetch in Server Components, close to where the data is used. Prop-drilling data down from the page is usually a sign the boundary is in the wrong place.
- Be explicit about caching rather than relying on remembered defaults; the defaults have changed across major versions. State the intent per request or per route and record the project's convention here.
- **Default:** use `Suspense` to stream slow sections instead of blocking the whole page.
- Revalidate by tag or path after mutations. A stale list after a successful create is the classic bug.

## Environment and secrets

- Only variables prefixed `NEXT_PUBLIC_` reach the browser, and they are baked into the bundle at build time. Never put a credential behind that prefix.
- Everything else is server-only and must never be referenced from a file reachable by a Client Component.
- Import server-only modules into server code only.
- **Default:** import the `server-only` package in those modules, which turns a mistake into a build error rather than a leak.

## Components and assets

- Use the framework `Image` component, or set explicit dimensions. An unsized image is a layout-shift regression.
- **Default:** use the framework font loader so fonts are self-hosted and preloaded rather than fetched from a third party at runtime.
- **Default:** use `Link` for internal navigation so prefetching works; a bare anchor triggers a full page load.
- **Default:** set per-page metadata through the metadata export rather than rendering tags by hand.

## Layout and boundaries

**Default** split: `app/` (routes, layouts, and route handlers), `components/` (shared UI), `lib/` (shared logic, with server-only modules clearly named). The path-scoped rule at `.claude/rules/nextjs-boundaries.md` auto-loads when editing them; if this project's layout differs, update BOTH that rule's `paths:` globs and this section.

`Context/generated/route-map.md` lists every route with its rendering mode. Regenerate it with `/refresh-context` after adding or moving routes.
