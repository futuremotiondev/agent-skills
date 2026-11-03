# Listing copy: fm-figma-capability-probe

## Identity

- **Name (slash command):** `fm-figma-capability-probe`
- **Display title:** Capability Probe
- **Category:** Workflows
- **Tags:** probe, capabilities, plugin api, runtime, skill authoring

## Tagline (under 80 characters)

See which Plugin APIs the Figma agent's scripts can use, in one table.

## Description (identical to frontmatter `description`)

Reports which Plugin API surfaces the Figma agent's script runtime exposes, as a table of available, missing, and error results plus payload, timing, and style counts, then asks the user to paste the table back. Use whenever the user asks to probe, test, or check what the Figma agent can do, which APIs are available, or whether scripts can do X, or asks for a capability probe or runtime check. Not for auditing or changing designs; optional, for skill authors: no skill depends on it, no end user needs it installed, and it can be removed from Figma once its table has been pasted back.

## Long description (Community page body)

**What it does.** Runs one script that tests about thirty Plugin API surfaces, from node lookup and variables to styles, images, plugin data, client storage, and text sizing, and prints a table of API, status, and detail. It also reports how much data a script can return, how long a page walk takes, and the file's style counts.

**How to use it.** Open any Design or Make file, type `/fm-figma-capability-probe`, and answer the one question it asks. It creates three temporary layers and one storage key, removes them before it finishes, shows one one-second toast, and changes nothing else. Paste the table back to whoever maintains your skills.

**What it will not do.** It does not audit, fix, or change designs. It is an optional tool for skill authors: no other skill depends on it, end users never need it installed, and you can remove it from Figma once its table has been pasted back.

## Example prompts (shown on the page)

1. "Probe what the Figma agent can do in this file"
2. "Which Plugin APIs are available to your scripts?"
3. "Test whether scripts can read plugin data here"

## Artwork

- **Thumbnail:** 1920 × 1080. The probe table as it appears in chat, with three rows visible (available, missing, error) and the four scalar lines below. Only text: `/fm-figma-capability-probe`.
- **Gallery:**
  1. The disclosure question as it appears in chat.
  2. The full table for a Figma Design file.
  3. The same table run over MCP, for comparison.
- **Video (optional):** 20 s, slash command to table.

## Support and contributors

- **Support contact:** [admin@futuremotion.studio](mailto:admin@futuremotion.studio)
- **Contributors:** Futuremotion Studio
- **License note:** Source: github.com/futuremotiondev/agent-skills, MIT

## Coding-agent channel

- Repo path: `figma/fm-figma-skill-creator/examples/fm-figma-capability-probe/dist/claude/fm-figma-capability-probe/SKILL.md`
- Community index PR title (figma/community-resources): `Add [skill] fm-figma-capability-probe`
- Repo topics: `figma`, `figma-mcp`

## Pre-publish checklist

- [x] Frontmatter description and listing description are identical
- [x] Tagline under 80 characters
- [x] Category chosen from the six
- [ ] Thumbnail shows the output
- [x] Validator passes on the upload edition with zero errors
- [ ] Trigger eval pass rate at or above 0.5 on the holdout set
- [ ] Live test logged in EVAL-LOG.md
