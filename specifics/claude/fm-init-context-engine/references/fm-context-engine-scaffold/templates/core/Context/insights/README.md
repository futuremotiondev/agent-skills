# Insights

Dated catalog of non-obvious findings — pitfalls, workarounds, gotchas, unexpected language / framework / tooling behaviors. The point is to capture what would be expensive to rediscover.

## Folder layout

### Top-level `.md` files

Curated, promoted content, organized by topic (e.g. `powershell-pitfalls.md`, `xaml-binding-gotchas.md`, `electron-ipc-pitfalls.md`).

### `_inbox/`

Raw drops as work happens. Each finding lands here as `YYYY-MM-DD-<slug>.md`. The weekly review triages:

- Durable, widely-applicable findings → promote into a top-level topic file
- Area-specific gotchas → promote into the relevant reference doc elsewhere in `Context/`
- One-off noise → delete

Never leave items in `_inbox/` indefinitely.

## Contributing

Add a new entry to the appropriate topic file, or create a new topic file if the finding doesn't fit. Each entry should include:

- **Problem** — the observable symptom
- **Root cause** — what's actually going on
- **Fix** — the working code or pattern
- **Rule** — the prevention heuristic, short enough to remember
