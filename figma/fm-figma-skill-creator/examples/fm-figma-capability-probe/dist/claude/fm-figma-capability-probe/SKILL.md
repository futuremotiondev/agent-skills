---
name: fm-figma-capability-probe
description: "Reports which Plugin API surfaces the Figma agent's script runtime exposes, as a table of available, missing, and error results plus payload, timing, and style counts, then asks the user to paste the table back. Use whenever the user asks to probe, test, or check what the Figma agent can do, which APIs are available, or whether scripts can do X, or asks for a capability probe or runtime check. Not for auditing or changing designs; optional, for skill authors: no skill depends on it, no end user needs it installed, and it can be removed from Figma once its table has been pasted back."
metadata:
  version: "1.2"
  author: Futuremotion Studio
  category: "Workflows"
  tags: "probe, capabilities, plugin api, runtime, skill authoring"
  applies-to: "workflow, documentation"
  runtimes: "figma-design, figma-make, figma-spec, mcp"
  target: mcp
license: MIT
compatibility: Runs in the Figma agent; the MCP edition runs the same probe through use_figma for comparison.
---

# Capability probe

Runs one script that tests which Plugin API surfaces the agent's script runtime exposes and returns a three-column table: API, Status (available, missing, or error), and Detail. The table goes to chat and nowhere else; the user pastes it back to whoever maintains their skills. In a Design or Make file the probe creates four temporary layers (one of them an embedded Spec) and removes them before it returns, attempts one client-storage write, shows one one-second toast, saves one version-history entry named fm-probe when the runtime allows it, and imports one library variable when a library is enabled. In a Spec file it only reads. It is a maintenance tool for skill authors: it reports what it observed and never adapts, retries, or works around a failed check (one rerun of the whole script after a size rejection is the single exception).

## When to use

- The user asks to probe, test, or check what the Figma agent can do.
- The user asks which Plugin APIs are available to scripts, or whether scripts can do a specific thing.
- A skill author wants fresh evidence for the capability reference after a Figma release.
- **Do not** use this to audit, fix, or change a design. It is optional: no other skill depends on it, end users never need it, and it can be removed from Figma once its table has been pasted back.

## Before you start

1. **Check the surface.** Run it in a Figma Design, Figma Make, or Figma Spec file; no selection is needed. In FigJam or Slides, say the probe needs a Design, Make, or Spec file and stop.
2. **Disclose and ask.** Ask, verbatim and as plain text (through a structured question tool when the runtime has one; the question card does not render Markdown). In a Design or Make file:
   > This probe creates and deletes four temporary layers (one frame, one auto-layout frame, one text layer, one embedded Spec), attempts to write one client-storage key (the write is expected to fail on current runtimes), shows one one-second toast, saves one version-history entry named fm-probe when the runtime allows it, and imports one library variable when a library is enabled. Nothing else changes. Run it? 1. Yes, 2. No
   In a Spec file:
   > In a Spec file this probe only reads: it tests which APIs exist and reads the document's line count. Nothing is created, written, or shown. Run it? 1. Yes, 2. No
   Wait for the answer. On 2, say nothing was run or changed and stop.

## Instructions

Ask one question at a time, wait for the answer, then act.

1. **Run the helper once.** Run the probe helper under Helper scripts exactly as written, one time, after the user answers 1; a second run is allowed only after a size rejection, as the target section says. Each target section below says how to run it on that runtime.
2. **Print the table exactly as returned.** One row per entry in `checks`, in the order returned, with the status and detail copied character for character. Append the two in-app experiment rows, omitted over MCP, then the four scalar lines. Use the output contract.
3. **Close with the paste-back.** Say, verbatim and as plain text:
   > Paste this table back to whoever maintains your skills so the capability reference can be updated. Nothing in your file was changed.
   Then stop.

## Output contract

Print the payload lengths, never the payload itself: the number the helper sent (`payloadBytesReturned`) and the length of `payloadSample` as you received it. If the sample was replaced by a truncation notice, write "truncated" in place of the received length.

```markdown
## Capability probe: <file name>
- Runtime: <Figma Design agent, Figma Make agent, or MCP>; script reports <runtime>; <date>

| API | Status | Detail |
| --- | --- | --- |
| <api> | <available, missing, or error> | <detail, or — when there is nothing to say> |

- Payload bytes: <payloadBytesReturned> sent, <received length> received; after a rerun add (first run rejected: <rejection text>)
- Walk time: <walkMs> ms
- Nodes walked: <nodesWalked>
- Style counts: text <n> · paint <n> · effect <n> · grid <n>
```

The table holds every entry in `checks`, then the two in-app experiment rows, omitted over MCP. A value the helper returned as null prints as "null". No row is added, merged, reworded, or reordered.

## Do and do not

### Report, never adapt

- **Do:** `figma.loadAllPagesAsync | missing | not a function`, printed as returned.
- **Do not:** Rerunning a failed check with a workaround and printing "available (via fallback)".

### One run, or two only after a size rejection

- **Do:** One helper call, one table, then the paste-back line; a second call, with `PAYLOAD` at 30000, only when the first was rejected for size.
- **Do not:** Running the helper a second time to confirm an error, or splitting it into one call per check.

## Examples

**Request:** "What can the Figma agent's scripts do in this file?" with nothing selected.
**Result:** The disclosure question. On 1, one helper run, the two in-app experiments, the table with its four scalar lines, and the paste-back line.

**Request:** "Probe the agent's APIs" and the user answers 2 to the disclosure question.
**Result:** "Nothing was run or changed." No helper call, no table.

## Common edge cases

- **No script-execution path is available.** Say so, then list every check under Helper scripts as a numbered question ("Is figma.getNodeByIdAsync available?") for the maintainer to answer. Run nothing else.
- **Figma Make file.** Run the same probe and name Figma Make in the Runtime line.
- **Figma Spec file.** Ask the Spec disclosure, run the same helper, and name Figma Spec in the Runtime line. The helper detects the Spec and skips every row that needs a canvas or a write; those rows print as missing with "skipped in a Spec file".
- **The user declines the disclosure.** Say nothing was run or changed and stop.

## Final gate: do not finish until every line is true

- [ ] The user answered 1 to the disclosure question before the helper ran, and it ran once, or twice only after a size rejection
- [ ] Every row came from the helper's result or from an experiment actually attempted, copied without change
- [ ] No layer named fm-probe remains on the current page, and the paste-back line was said

## Helper scripts

The probe helper is self-contained and returns one result object. Every check is wrapped so a throw records `error` with the first 120 characters of the error text; every temporary layer and the `fm-probe` client-storage key are removed in a `finally` block. Rows added in 1.2 call the API they name, because a member can be a function and still throw when called. The helper is written with top-level `await` and a final `return`, with no function wrapper: both script tools take the result from `return`, and a wrapped function that is never returned gives back nothing.

The probe helper is `scripts/probe.js` in this folder.

## MCP execution (Claude Code, Cursor, Codex)

Load the `figma-use` skill before any `use_figma` call. Ask for the file URL if none was given (a scratch file is best), call `create_session` for its key, and pass the returned `sessionId` on every later call. In a Design file the helper creates and removes layers, which makes its call a mutating one: also load `figma-generate-design` and pass `skillNames: "figma-use,figma-generate-design,fm-figma-capability-probe"`. In a Spec file (the URL path starts with `/spec/`) load `figma-spec` instead and pass `skillNames: "figma-use,figma-spec,fm-figma-capability-probe"`. Run the probe helper (`scripts/probe.js` in the coding-agent edition) once through `use_figma`. The helper is written the way `use_figma` runs code, with top-level `await` and a final `return`, so send it as written. Before running, set `PAYLOAD` to 30000, because `use_figma` rejects any return over 48,000 bytes and discards the run; record the rejection message, if one comes back, as the payload finding. Print the table without the two in-app experiment rows. On a `use_figma` error, report the error text as the result and do not retry.
