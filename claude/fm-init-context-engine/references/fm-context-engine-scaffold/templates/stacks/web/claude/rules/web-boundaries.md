---
paths:
  - "src/**"
  - "app/**"
  - "pages/**"
  - "components/**"
  - "lib/**"
  - "server/**"
---

# Web Boundary Rules

Auto-loaded when editing web source. Seeded by the context-engine `web` adapter — if the project's layout differs, fix the `paths:` globs above. A framework overlay may add a second, more specific rule file.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## Secrets and the client bundle

- **Anything a client module can import is public.** Bundlers follow the import graph; a secret pulled into a shared module ships to the browser.
- Read secrets only in server-only modules, from environment variables without a public prefix. A variable named with the framework's public prefix is deliberately exposed and must never hold a credential.
- Database clients, API keys, and internal URLs stay server-side. The browser asks the server.
- Before importing a module into client code, check what that module imports transitively.

## Routes

- A new route is public surface. Renaming or removing a published URL needs a redirect.
- Dynamic segments handle the not-found case explicitly and return a real 404.
- A server endpoint is reachable directly by URL. Authorize inside the handler; the calling UI is not a security boundary.
- After adding or moving routes, run `/refresh-context` so the generated route map stays accurate.

## Components

- Semantic HTML first: `<button>`, `<a>`, `<nav>`, `<main>`. Reach for ARIA only when no element expresses the role.
- Interactive elements are keyboard-operable with a visible focus state.
- Images have `alt` and explicit dimensions; inputs have real labels.
- If the project defines design tokens, style with them rather than hard-coded colours or spacing values.

## Data crossing the boundary

- Only plain serializable data crosses. No functions, no class instances.
- Validate on the server, even when the client already checked.
