---
paths:
  - "**/*.xaml"
---

# WinUI 3 XAML Rules

Auto-loaded when editing `.xaml` files. Seeded by the context-engine `winui3` adapter — extend as the project's XAML patterns settle.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

- `x:Bind` defaults to `Mode=OneTime` (unlike `Binding`): specify `Mode` explicitly whenever the value can change.
- No `{StaticResource ...}` converters inside `x:Bind` on a `Window` — a Window is not a `FrameworkElement`; use function bindings.
- Colors come from theme resources (`ThemeResource`), not hard-coded values, or light, dark, and high-contrast themes break.
- Virtualize large `ItemsControl`s; never bind thousands of realized elements.
- Accessibility: interactive elements need `AutomationProperties.Name` when their content isn't self-describing text.
