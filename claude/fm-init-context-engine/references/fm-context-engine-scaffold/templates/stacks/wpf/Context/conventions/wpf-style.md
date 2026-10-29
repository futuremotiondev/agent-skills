---
last_verified: {{TODAY}}
---

# WPF Style

Seeded by the context-engine `wpf` adapter, on top of [csharp-style.md](csharp-style.md).

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## MVVM

- **Default:** CommunityToolkit.Mvvm: `[ObservableProperty]`, `[RelayCommand]`, `ObservableObject` — no hand-rolled `INotifyPropertyChanged` boilerplate.
- **Default:** ViewModels stay free of WPF types (`Dispatcher`, controls); marshal at the view boundary.
- **Default:** code-behind is for view plumbing only (focus, drag-drop wiring); logic lives in the ViewModel.

## Binding

- `Binding` fails silently at runtime — watch the debug Output window for binding errors during development and treat them as bugs.
- Specify `UpdateSourceTrigger=PropertyChanged` deliberately on text inputs; the LostFocus default surprises.
- Collections bound to the UI must be `ObservableCollection<T>` (or raise reset events); mutate them only on the UI thread.

## Threading

- UI objects are single-threaded: marshal via `Dispatcher.Invoke`/`BeginInvoke` or `await` back onto the UI context.
- Long work belongs on background threads/`Task.Run`; only the final assignment hops to the dispatcher.

## Performance

- Virtualize large lists (`VirtualizingStackPanel.IsVirtualizing="True"`, container recycling).
- **Default:** freeze `Freezable`s (brushes, geometries, transforms) that never change — `Freeze()` removes change-tracking overhead and enables cross-thread reads.
- **Default:** avoid deep visual trees in item templates; measure with the WPF Performance/Live Visual Tree tools before micro-optimizing.

## XAML hygiene

- **Default:** styles and brushes live in resource dictionaries.

The path-scoped rule at `.claude/rules/xaml-wpf.md` auto-loads when editing `.xaml` files and carries the XAML facts and guardrails.
