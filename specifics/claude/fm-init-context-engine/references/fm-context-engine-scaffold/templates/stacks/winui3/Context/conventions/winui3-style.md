---
last_verified: {{TODAY}}
---

# WinUI 3 Style

Seeded by the context-engine `winui3` adapter, on top of [csharp-style.md](csharp-style.md). Several entries are field-tested gotchas from prior WinUI 3 projects — they will save you a compile-error hunt.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## MVVM

- **Default:** CommunityToolkit.Mvvm: `[ObservableProperty]` fields, `[RelayCommand]` methods, `ObservableObject` base.
- **Default:** ViewModels are plain, testable classes — no WinUI types (`DispatcherQueue`, `Window`, controls) inside them; marshal at the view boundary.
- **Default:** route multi-input recomputation through a single `Recompute()` funnel rather than per-property handlers.

## Binding

- **Default:** prefer `x:Bind` over `Binding` — compiled, typed, fails at build instead of silently at runtime.
- `x:Bind` defaults to `Mode=OneTime` (unlike `Binding`'s `OneWay`) — specify `Mode` explicitly whenever the value can change.
- **Gotcha:** a WinUI `Window` is *not* a `FrameworkElement`, so `{StaticResource SomeConverter}` inside `x:Bind` on a Window won't compile — use `x:Bind` function bindings instead.
- **Gotcha:** binding an empty string to `NavigateUri` throws — expose a nullable `Uri?` property, never a raw string.

## Threading

- UI objects are single-threaded: touch them only via `DispatcherQueue.TryEnqueue(...)` from background work.
- Move rasterization/IO off the UI thread; only the final "assign result to UI" hop goes through the dispatcher.

## Performance

- Virtualize every large collection (`ItemsRepeater` / `GridView` virtualization). Retained per-item UI (bitmaps, containers) leaks under deep zoom-out or huge lists.
- **Default:** for grids beyond ~10k live cells, an owner-drawn canvas (e.g. Skia `SKXamlCanvas` painting only visible cells) beats element virtualization outright — zoom becomes a repaint, not a layout pass.
- **Default:** throttle high-frequency layout-affecting inputs (sliders, Ctrl+wheel) — leading-edge immediate, trailing commit.

## Packaging and deployment

- Decide packaged (MSIX) vs unpackaged/self-contained early and record it in an ADR — it affects file access, activation, and updates.
- Unpackaged self-contained ships the full WindowsAppSDK native closure; accept the size or document the pruning.

## XAML hygiene

- **Default:** styles and brushes live in resource dictionaries; page XAML declares structure, not theme values.

The path-scoped rule at `.claude/rules/xaml-winui3.md` auto-loads when editing `.xaml` files and carries the XAML facts and guardrails.
