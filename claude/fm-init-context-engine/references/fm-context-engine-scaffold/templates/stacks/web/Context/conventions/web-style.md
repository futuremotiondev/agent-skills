---
last_verified: {{TODAY}}
---

# Web Style

Seeded by the context-engine `web` adapter. General TypeScript rules live in [TypeScript style](typescript-style.md); this document covers what applies to any website or web application regardless of framework. A framework overlay (Next.js, Astro, ...) adds its own document with the mechanics.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Toolchain

<!-- Filled at init by /fm-init-context-engine from the interview. Expected shape: a table with one row per layer —
     Framework (Next.js / Astro / Nuxt / SvelteKit / none — plus its major version),
     UI library (React / Vue / Svelte / Solid / none), Styling (Tailwind vN / Sass / CSS modules / plain CSS),
     Build tooling + runtime (Vite / Turbopack; Node LTS / Bun / Deno), Package manager,
     Hosting target (static host / Node server / serverless / edge).
     One line each. -->
{{TOOLCHAIN}}

The hosting target is not a footnote. It decides whether long-lived server state is possible, whether Node built-ins are available, and what a cold start costs. Record it and revisit it when the deployment changes.

## The server/client boundary

Every modern web framework splits code into what runs on a server and what ships to the browser. The mechanics differ (directives, file suffixes, islands) but the rules do not:

- **Assume everything reachable from the client is public.** Bundlers follow imports. A secret imported into a module that a client component also imports ends up in the bundle, readable by anyone with devtools.
- Secrets live in server-only modules and are read from environment variables that are not exposed to the client. Most frameworks require a prefix such as `PUBLIC_` or `NEXT_PUBLIC_` to expose a variable deliberately; anything without it must never be referenced from client code.
- Database clients, API keys, and internal service URLs stay server-side. The client asks the server; it does not connect directly.
- Data crossing the boundary is serialized. Functions, class instances, and `Date`-heavy objects either fail or arrive transformed. Send plain data and parse it on arrival.
- Validate on the server even when the client already validated. Client validation is a convenience, never a control.

## Routing

- Routes are the site's public surface, and URLs outlive the code that serves them. Adding, renaming, or removing one is a user-visible change; renaming a published URL needs a redirect, not a rename.
- **Default:** lowercase, hyphenated URLs.
- Dynamic segments must handle the not-found case explicitly. An unmatched id returns a 404, never an empty page or a crash.
- Server endpoints are routes too, and they need the same authorization checks as the pages that call them. A route handler is directly reachable by URL; the UI calling it is not a security boundary.

`Context/generated/route-map.md` is a machine-generated inventory of every file-based route. Regenerate it with `/refresh-context` after adding or moving routes.

## HTML and accessibility

- Semantic elements before ARIA. A `<button>` is focusable, keyboard-activatable, and announced correctly for free; a `<div>` with a click handler is none of those and needs four attributes to fake it.
- One `<h1>` per page, and heading levels descend without skipping. Screen-reader users navigate by heading.
- Every interactive control is reachable and operable by keyboard, and the focus ring stays visible. Never remove an outline without replacing it with something at least as clear.
- Images carry meaningful `alt` text, or `alt=""` when decorative. Never omit the attribute.
- Form inputs have associated `<label>` elements. Placeholder text is not a label.
- Colour contrast meets WCAG AA (4.5:1 for body text). Never rely on colour alone to carry meaning.
- Respect `prefers-reduced-motion` for anything that animates beyond a subtle transition.

## Styling

- **Default:** one styling approach per project, chosen deliberately and recorded above. Mixing utility classes, CSS modules, and a CSS-in-JS runtime in one codebase makes every change a hunt.
- Tailwind v4 configures in CSS through `@theme`, not a JavaScript config file. If this project still has a `tailwind.config.js`, it is either v3 or a deliberate compatibility choice; say which.
- **Default:** design tokens (colour, spacing, type scale, radii) are defined once as CSS custom properties and referenced everywhere. A hard-coded hex in a component is a bug waiting for the next rebrand.
- **Default:** prefer cascade layers or a documented ordering convention over specificity escalation. `!important` is a last resort with a comment.
- **Default:** style the dark theme with the same tokens rather than a parallel stylesheet.

## Performance

- **Default:** the performance budget is part of the definition of done. Core Web Vitals: LCP under 2.5s, INP under 200ms, CLS under 0.1, measured on real devices rather than a local dev build.
- **Default:** ship the least JavaScript that does the job. Interactivity is opt-in per component in island and server-component frameworks; take the default and add only where needed.
- Images use the framework's image component or explicit `width`, `height`, and modern formats. An image without dimensions causes layout shift.
- **Default:** fonts are self-hosted or preloaded, with `font-display: swap` and a real fallback stack. A blocking webfont is a measurable LCP regression.
- **Default:** anything below the fold that is heavy loads lazily. Anything above it does not.

## Metadata and SEO

- **Default:** every page sets a unique `<title>` and meta description. Both are page-level data, not layout-level constants.
- **Default:** canonical URLs on anything reachable by more than one path.
- **Default:** Open Graph and Twitter card tags on anything meant to be shared.
- **Default:** a sitemap and `robots.txt` that match reality, and structured data where the content type warrants it.

## Forms and data

- **Default:** native form semantics first: a real `<form>`, a real submit button, and a server-side handler. Progressive enhancement means the form works before the JavaScript arrives.
- **Default:** validate with a schema at the server boundary and derive the client's types from it rather than declaring the shape twice.
- Show errors next to the field, associated with it programmatically, and never clear what the user typed.
- Guard against double submission on the server, not only by disabling the button.

## Layout and boundaries

The **Default** split separates route files, shared UI components, server-only modules, and static assets. The exact directory names come from the framework; the path-scoped rule at `.claude/rules/web-boundaries.md` auto-loads when editing them. If this project's layout differs, update BOTH that rule's `paths:` globs and this section.
