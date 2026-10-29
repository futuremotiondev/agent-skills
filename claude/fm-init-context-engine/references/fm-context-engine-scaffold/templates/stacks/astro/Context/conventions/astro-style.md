---
last_verified: {{TODAY}}
---

# Astro Style

Seeded by the context-engine `astro` adapter. Framework-independent web rules live in [Web style](web-style.md) and language rules in [TypeScript style](typescript-style.md); this document covers islands, content collections, and the `.astro` component model.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Zero JavaScript is the default

Astro ships **no client-side JavaScript** unless you ask for it. That default is the whole point of choosing Astro, and it is easy to erode one component at a time.

- A `.astro` component renders on the server and disappears at build time. It has no runtime and no hydration cost.
- A UI framework component (React, Vue, Svelte, Solid) also renders to static HTML **unless** it carries a `client:*` directive. Without one, no JavaScript ships for it.
- **Default:** treat every added `client:*` as a deliberate cost with a reason. The generated route map reports which islands each page hydrates; watch that list grow.

## Client islands

Pick the directive by when the component genuinely needs to be interactive:

- `client:load` hydrates immediately.
- `client:idle` waits for the main thread to go quiet.
- `client:visible` waits until the component scrolls into view.
- `client:media` hydrates only at a breakpoint, for controls that exist only on one form factor.
- `client:only` skips server rendering entirely and must name its framework. It produces no HTML until JavaScript runs, so it costs layout shift and SEO.
- **Default:** `client:visible` for anything below the fold (usually the right answer), `client:idle` for non-urgent widgets, and `client:load` only for above-the-fold interactivity. Use `client:only` only when the component genuinely cannot render on the server.

Each island is an independent bundle with its own hydration. Islands do not share state by default: two islands are two React roots. Lift genuinely shared state into a small store or pass it as props from the server.

## Server islands

- `server:defer` turns a component into a **server island**: the page ships immediately with fallback content, and the component's HTML is fetched and slotted in afterward.
- **Default:** use a server island for a personalized or uncacheable fragment on an otherwise static page: a cart count, a greeting, a live figure. It keeps the shell cacheable.
- Server islands need an adapter configured for on-demand rendering.
- Provide meaningful fallback content. The fallback is what most users see first.

## `.astro` components

- Frontmatter between `---` fences runs **on the server**, at build time or per request. It can await data, read the filesystem, and use secrets.
- The template below the fences is HTML plus expressions. There is no re-render and no reactivity; it runs once.
- A `<script>` tag in the template is processed and bundled by Astro and runs in the browser. It has no access to frontmatter variables except through `define:vars` or data attributes.
- **Default:** prefer `.astro` components for anything non-interactive, even in a project that uses React elsewhere. They cost nothing at runtime.

## Content collections

- Content lives in collections with a **schema**. Define the schema once and let it validate every entry at build time; a typo in frontmatter should fail the build, not render blank.
- Query with the collection APIs rather than reading files directly, so the types and validation apply.
- A schema change is public surface when it changes what renders. Adding a required field breaks every existing entry that lacks it.
- **Default:** keep drafts out of production builds explicitly through a schema field and a filter, not by commenting out links.

## Rendering mode and routing

- The output mode decides whether pages are prerendered or rendered on demand. Record the project's choice in the Toolchain table above, and note per-route overrides where they exist.
- Anything on-demand needs an adapter for the hosting target. Static output needs none.
- `src/pages/**` maps to URLs. `.astro`, `.md`, and `.mdx` files are pages; `.ts` and `.js` files are endpoints.
- Files and folders starting with `_` are not routed, which is the idiomatic place for page-local partials.
- Dynamic routes in static output must enumerate their paths at build time; on-demand routes resolve at request time.

## Layout and boundaries

**Default** split: `src/pages/` (routes), `src/layouts/` (page shells), `src/components/` (shared UI), `src/content/` (collections), `public/` (files served verbatim). The path-scoped rule at `.claude/rules/astro-boundaries.md` auto-loads when editing them; if this project's layout differs, update BOTH that rule's `paths:` globs and this section.

`Context/generated/route-map.md` lists every route and the client islands each page hydrates. Regenerate it with `/refresh-context` after adding routes or islands.
