---
paths:
  - "src/**"
  - "crates/**/src/**"
---

# Rust Crate Boundary Rules

Auto-loaded when editing crate source. Seeded by the context-engine `rust` adapter — if the project's directory names differ, fix the `paths:` globs above.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## Public surface

- Public surface is what `lib.rs` re-exports. Adding a `pub` item deep in a module and reaching it via a `pub mod` chain is a surface change too — treat it as one.

## `unsafe`

- Every `unsafe` block has a `// SAFETY:` comment naming the invariant. Wrap it in a safe function that owns that invariant.
- No `unsafe` to silence the borrow checker. If the types fight you, the design is wrong.

## FFI exports (`extern "C"`)

- `#[no_mangle] pub extern "C"` functions take and return only `#[repr(C)]` types, primitives, and opaque pointers — never `String`, `Vec`, `&[T]`, `Option<T>` (except `Option<&T>` / `Option<fn>`), or trait objects.
- Catch every panic before returning across the boundary (`catch_unwind`), or the crate is built with `panic = "abort"`.
- Anything allocated here is freed here: pair every constructor export with a `*_free` export, and document the ownership on the header.
