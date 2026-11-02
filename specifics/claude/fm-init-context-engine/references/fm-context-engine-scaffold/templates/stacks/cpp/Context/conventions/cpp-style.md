---
last_verified: {{TODAY}}
---

# C++ Style

Seeded by the context-engine `cpp` adapter. This is a starting point — tighten as the project develops, and record contested choices as ADRs.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Toolchain

A C++ "toolchain" spans several independent layers. Record each one here so every session knows what actually builds this project. The watches in `.claude/context-engine.psd1` assume CMake as the meta-build; if that is wrong, fix the watch globs too.

<!-- Filled at init by /fm-init-context-engine from the interview. Expected shape: a table with one row per layer —
     Compiler (MSVC cl.exe / clang-cl / clang++ / g++), Standard library (MSVC STL / libstdc++ / libc++),
     Generator + executor (CMake -> Ninja / MSBuild / Make), Package manager (vcpkg / Conan / none),
     C++ standard (e.g. C++20). One line each; note the version where it matters. -->
{{TOOLCHAIN}}

## Ownership and lifetime

- RAII everywhere: resources are owned by objects whose destructors release them. No naked `new`/`delete` outside a wrapper type.
- **Default:** `std::unique_ptr` as the owning pointer; `std::shared_ptr` only when ownership is genuinely shared, and say why in a comment.
- Raw pointers and references mean "borrowed, non-owning" — never "you must free this".
- **Default:** prefer values and `std::string_view` / `std::span` parameters over owning copies at call sites.

## Headers

- **Default:** public headers live in one directory (conventionally `include/`) and include only what they need; implementation-only headers stay next to the `.cpp` files that use them.
- **Default:** `#pragma once` at the top of every header. Forward-declare where a full definition isn't needed — a header change recompiles every translation unit that includes it.
- Nothing in a public header depends on a private implementation detail; use the pimpl idiom or an abstract interface where the layout must stay stable.
- **Default:** a `.cpp` includes its own public header first, then private headers, then system headers. Including its own header first proves the header is self-contained.

## Errors

- Pick one error strategy per module boundary and record it in an ADR: exceptions, or an explicit result type (`std::expected` / project equivalent). Don't mix within a module.
- Never let an exception cross a C ABI boundary (see below) — catch at the edge and translate to an error code.

## Build

- **Default:** one CMake target per library or executable; targets declare their own include directories and link dependencies (`target_include_directories`, `target_link_libraries` with `PUBLIC`/`PRIVATE` chosen deliberately).
- **Default:** warnings on and treated as errors in CI (`/W4 /WX` or `-Wall -Wextra -Werror`).
- Silence a warning at the site with a comment, never globally.
- **Default:** dependencies come through the package manager named in the Toolchain table, not vendored by hand.

## Foreign-language boundaries

Applies whenever another language (Rust, C#, Python, ...) builds a library this project consumes, or consumes one this project builds.

- The boundary is a **C ABI**: `extern "C"` functions, plain-old-data structs, opaque handles. No C++ classes, templates, `std::` types, or exceptions cross it.
- One side owns the boundary header; the other generates or hand-mirrors from it, and the ADR says which.
- Memory allocated on one side is freed on that same side — expose a matching `*_free` function rather than letting the caller `delete`.
- Record where the foreign artifact (DLL / .so / .lib) is built, where the CMake build expects to find it, and which side's toolchain (e.g. Rust's MSVC target) must match this project's compiler and runtime.

## Layout and boundaries

**Default** split: `include/` (public headers), `src/` (implementation), `tests/`. The path-scoped rule at `.claude/rules/cpp-boundaries.md` auto-loads when editing `include/` or `src/`; if this project uses different directory names, update BOTH that rule's `paths:` globs and this section.
