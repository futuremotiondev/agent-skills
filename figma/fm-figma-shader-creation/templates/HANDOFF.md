# Handoff — `<repo or shader name>`

Written `<date>` by `<author>` for continuation in `<tool>`. Owner: `<name>` / Futuremotion Studio.

## What this repo is for

One folder per shader under `shaders/`, each holding `main.ts` (byte-identical to the live library
build), a mirrored `features.json` (never pushed), and `SHADER-NOTES.md`.

## Figma identifiers (needed for MCP calls)

| Thing | Value |
| --- | --- |
| Shader id | `<uuid>` |
| Shader kind | `<effect or fill>` |
| Current built version (SHA) | `<sha>` |
| Owner account / plan key | `<email>` / `team::<n>` |
| Test file | `<figma.com/design/... url>` |

If the shader may have been edited in Figma since this date, re-pull with `get_shader` before
editing; the live version is the source of truth.

## Active task

`<one paragraph>`

## Workflow reminders

- Load the `figma-shaders` skill before `update_shader`; load `figma-use` before `use_figma`.
- Validate: `node scripts/validate-shader.mjs shaders/<name>/main.ts --kind <kind>`.
- Push the whole `main.ts` with a specific `commitMessage`; record the returned SHA here.
- Keys, option ids, and preset ids are permanent. Labels and ranges are free to change.
- Verify on a layer at 1x and 0.5x; update layers pinned to older versions.

## Open questions

1. `<question>`
