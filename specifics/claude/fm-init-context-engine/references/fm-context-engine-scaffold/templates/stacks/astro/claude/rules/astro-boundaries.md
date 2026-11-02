---
paths:
  - "src/pages/**"
  - "src/layouts/**"
  - "src/components/**"
  - "src/content/**"
---

# Astro Boundary Rules

Auto-loaded when editing Astro source. Seeded by the context-engine `astro` adapter — if the project's layout differs, fix the `paths:` globs above.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## Before adding a `client:*` directive

- Astro ships **zero JavaScript** unless a component carries a `client:*` directive. Every island adds a bundle and a hydration cost.
- `client:load` hydrates immediately, `client:idle` once the main thread is idle, and `client:visible` when the component scrolls into view.
- `client:only` renders nothing on the server. It costs layout shift and SEO, and must name its framework.
- Islands do not share state. Two islands are two roots; lift shared state to a store or pass server props.
- A `.astro` component has no runtime cost: it renders on the server and ships no JavaScript.

## In `.astro` files

- Frontmatter between `---` runs on the **server**. Secrets and data fetching belong there.
- The template runs once. There is no reactivity and no re-render.
- A `<script>` in the template runs in the browser and cannot see frontmatter variables; pass them with `define:vars` or data attributes.
- A `server:defer` component renders its fallback first and fetches its HTML afterward. Give it real fallback content; that is what users see first.

## In `src/pages/`

- Every file is a public URL. `.astro`, `.md`, and `.mdx` are pages; `.ts` and `.js` are endpoints.
- A file or folder prefixed with `_` is not routed.
- Dynamic routes in static output must enumerate their paths at build time.
- After adding or moving routes, run `/refresh-context` to update the generated route map.

## In `src/content/`

- Every collection has a schema. Add the field to the schema before using it in a template.
- Adding a required field breaks existing entries; make it optional or backfill in the same change.
- Query through the collection APIs so validation and types apply; do not read the files directly.
