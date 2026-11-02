---
last_verified: {{TODAY}}
---

# C# Style

Seeded by the context-engine `csharp` adapter. This is a starting point — tighten, loosen, or extend it as the project develops its own voice, and record contested choices as ADRs.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Namespaces and files

- **Default:** file-scoped namespace declarations, one root name for the whole project: e.g. `namespace MyApp.Imaging;` where `MyApp` is the project's root namespace (its name with no spaces).
- **Default:** one public type per file; file name matches the primary type name exactly.
- **Default:** keep the namespace tree shallow — split when a folder earns its own concept, not preemptively.

## Types

- **Default:** prefer `record` for immutable value objects and result/options shapes.
- **Default:** prefer `sealed class` for behavior-bearing types that aren't designed for extension — inheritance is opt-in, not default.
- Enable nullable reference types project-wide (`<Nullable>enable</Nullable>`); a `!` null-forgiveness operator requires a comment explaining why it is safe.
- **Default:** XML doc comments on every public type and public member. `<summary>` on one line when it fits; add `<param>`, `<returns>`, `<exception>` as applicable.

## Collections

- **Default:** `List<T>` for mutable accumulators; expose `IReadOnlyList<T>` / `IReadOnlyDictionary<K,V>` from public surface.
- **Default:** `Dictionary<TKey, TValue>` with an explicit `StringComparer` whenever keys are strings — `Ordinal` for machine identifiers, `OrdinalIgnoreCase` for user-supplied paths/names.
- **Default:** `ReadOnlySpan<T>` / `Span<T>` for hot parsing paths.
- **Default:** no LINQ in hot paths (parse loops, per-pixel/per-byte work) — span-walking wins by orders of magnitude. LINQ in orchestration and test code is fine.

## Errors

- **Default:** one domain-specific exception type per subsystem (e.g. `FooParseException`), derived from `Exception` directly.
- **Default:** `ArgumentException` / `ArgumentNullException` / `ArgumentOutOfRangeException` at parameter-validation sites; `InvalidOperationException` when internal state precludes the call.
- Never swallow exceptions silently — catch narrowly, add context, rethrow or surface.

## Async

- **Default:** `Async` suffix on async methods; `CancellationToken` as the last parameter of every public async method.
- No `async void` outside event handlers.
- Don't block on async (`.Result`, `.Wait()`) — async all the way up.

## Build hygiene

- Treat warnings seriously; prefer fixing over suppressing. A `#pragma warning disable` requires a comment.
- Keep `bin/` and `obj/` out of git; never edit files under them.
