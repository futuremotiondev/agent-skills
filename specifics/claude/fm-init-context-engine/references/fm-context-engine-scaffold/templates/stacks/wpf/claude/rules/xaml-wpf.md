---
paths:
  - "**/*.xaml"
---

# WPF XAML Rules

Auto-loaded when editing `.xaml` files. Seeded by the context-engine `wpf` adapter.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

- Treat runtime binding errors (debug Output window) as bugs, not noise.
- `TextBox.Text` bindings update the source on `LostFocus` by default; set `UpdateSourceTrigger` deliberately on text inputs.
- Theme-switchable values use `DynamicResource`; `StaticResource` resolves once and does not follow a theme change.
- Virtualize large `ItemsControl`s.
- Accessibility: `AutomationProperties.Name` on interactive elements without self-describing text.
