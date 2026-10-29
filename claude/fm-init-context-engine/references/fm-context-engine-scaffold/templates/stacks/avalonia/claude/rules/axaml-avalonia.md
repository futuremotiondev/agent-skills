---
paths:
  - "**/*.axaml"
---

# Avalonia AXAML Rules

Auto-loaded when editing `.axaml` files. Seeded by the context-engine `avalonia` adapter.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

- Set `x:DataType` on every view root and DataTemplate — compiled bindings only; reflection bindings fail silently.
- Styles are selector-based (CSS-like), not implicit-key like WPF.
- `{DynamicResource}` for theme-variant values so light/dark both work.
- Virtualize large `ItemsControl`s.
