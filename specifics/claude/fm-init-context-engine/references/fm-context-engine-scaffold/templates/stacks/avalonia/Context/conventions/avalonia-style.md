---
last_verified: {{TODAY}}
---

# Avalonia Style

Seeded by the context-engine `avalonia` adapter, on top of [csharp-style.md](csharp-style.md).

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Cross-platform is the contract

- No Windows-only APIs (registry, Win32 P/Invoke, drive-letter assumptions) in shared code — quarantine platform specifics behind interfaces with per-platform implementations.
- Paths via `Path.Combine` and `Environment.GetFolderPath`; never hardcode separators or roots.
- Test/run on at least one non-Windows target before calling a feature done, or record the debt in the roadmap.

## MVVM

- **Default:** CommunityToolkit.Mvvm (or ReactiveUI if the project chose it — record the choice as an ADR): `[ObservableProperty]`, `[RelayCommand]`.
- **Default:** ViewModels free of Avalonia types; marshal at the view boundary via `Dispatcher.UIThread.Post`/`InvokeAsync`.

## Binding

- Use compiled bindings: set `x:DataType` on the root of every view/DataTemplate so bindings resolve at build time — runtime-reflection bindings fail silently.
- `{Binding}` without `x:DataType` is a code smell; the compiled-bindings error is your friend.

## AXAML

- Styles are selector-based (CSS-like), not implicit-key like WPF.
- **Default:** app-wide selectors live in `App.axaml` or theme files, view-local styles in the view.
- Respect theme variants (`{DynamicResource ...}`, Fluent theme resources) so light/dark both work.
- **Default:** keep AXAML platform-neutral and put platform differences in code behind interfaces. Small per-platform or per-form-factor values can use the `OnPlatform` and `OnFormFactor` markup extensions, which resolve once at startup.
- See the path-scoped rule at `.claude/rules/axaml-avalonia.md` — it auto-loads when editing `.axaml` files.

## Rendering and performance

- Rendering is Skia-backed; custom drawing goes through `DrawingContext` or a custom `Control.Render` override — cache pens/brushes, don't allocate per frame.
- Virtualize large lists (`ItemsControl` with virtualizing panels / `TreeDataGrid` for big data).
- The XAML previewer lies occasionally — verify layout in the running app before polishing.
