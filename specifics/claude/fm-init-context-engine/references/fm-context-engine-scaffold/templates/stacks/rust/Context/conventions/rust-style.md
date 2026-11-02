---
last_verified: {{TODAY}}
---

# Rust Style

Seeded by the context-engine `rust` adapter. This is a starting point — tighten as the project develops, and record contested choices as ADRs.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Toolchain

Rust is one toolchain (`rustc` + `cargo`), so only three facts vary per project. Record them here — the target triple in particular is not in `Cargo.toml` and is the fact that bites when another language consumes this crate.

<!-- Filled at init by /fm-init-context-engine from the interview. Expected shape: a table with one row per layer —
     Channel + pinned version (stable 1.xx / nightly, from rust-toolchain.toml),
     Target triple (e.g. x86_64-pc-windows-msvc vs -gnu — must match any consuming C/C++ toolchain),
     Edition (2021 / 2024, from Cargo.toml). One line each. -->
{{TOOLCHAIN}}

## Errors

- Library code returns `Result`; `unwrap` / `expect` are for tests, examples, and `main` after the error has already been reported.
- One error strategy per crate boundary, recorded in an ADR.
- **Default:** a typed error enum (`thiserror`) for libraries, and `anyhow` (or equivalent) only in binaries.
- `panic!` is a bug, not an error path. Never rely on it for control flow.

## `unsafe`

- Every `unsafe` block carries a `// SAFETY:` comment stating the invariant that makes it sound. No comment, no merge.
- Keep `unsafe` small and wrapped: a safe public function owns the invariant; callers never see the raw pointer.
- **Default:** prefer a maintained crate binding over hand-written `unsafe` for platform APIs.

## Lints and formatting

- **Default:** `cargo fmt` and `cargo clippy --all-targets -- -D warnings` gate every change.
- Silence a lint at the site with `#[allow(...)]` and a reason, never crate-wide.
- `#![deny(unsafe_op_in_unsafe_fn)]` in any crate that has `unsafe` (edition 2024 warns on it by default).

## Crate layout

- **Default:** one responsibility per crate; a workspace (`[workspace]` in the root `Cargo.toml`, members under `crates/`) once a second crate appears.
- Public surface is whatever `lib.rs` makes reachable as `pub`, including through a chain of `pub mod`s.
- **Default:** re-export deliberately and keep module internals `pub(crate)`, widening to `pub` only when a consumer needs it.
- `build.rs` only for genuine build-time work (codegen, native linking); never for network access.

## Foreign-language boundaries

Applies whenever this crate is built as a library for another language (C++, C#, Python, ...) or consumes one.

- The boundary is a **C ABI**: `#[repr(C)]` structs, `extern "C"` functions with `#[no_mangle]`, opaque handles. No `String`, `Vec`, slices, traits, or generics cross it.
- Crate type is `cdylib` (DLL / .so) or `staticlib`.
- **Default:** generate the header with `cbindgen`, so the Rust side owns it; the ADR records that choice.
- A panic must never unwind across the boundary — set `panic = "abort"` for the FFI crate or wrap every export in `std::panic::catch_unwind` and return an error code.
- Memory allocated in Rust is freed in Rust: expose a matching `*_free` export; the consumer never calls `free` / `delete` on Rust pointers.
- Record the target triple the consumer needs (MSVC vs GNU on Windows) and where the built artifact lands relative to the consumer's build.

## Layout and boundaries

**Default** split: `src/` (crate source, `lib.rs` / `main.rs`), `crates/<name>/src/` in a workspace, `tests/` (integration tests). The path-scoped rule at `.claude/rules/rust-boundaries.md` auto-loads when editing crate source; if this project uses different directory names, update BOTH that rule's `paths:` globs and this section.
