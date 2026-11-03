# Listing copy: fm-spacing-rhythm-audit

## Identity

- **Name (slash command):** `fm-spacing-rhythm-audit`
- **Display title:** Spacing Rhythm Audit
- **Category:** Design systems
- **Tags:** spacing, audit, 8pt, padding, auto layout, handoff

## Tagline (under 80 characters)

Find every off-grid padding and gap, then snap them in one confirmed pass.

## Description (identical to frontmatter `description`)

Audits the selected frames against a 4/8 pt spacing rhythm and lists every off-grid padding and gap with the exact value, the nearest on-grid value, and a severity from P0 to P3; it snaps values only after the user confirms. Use whenever the user asks to check the spacing, audit spacing, find off-grid padding or gaps, clean up the spacing, or asks whether a layout follows the 8 pt grid or the spacing scale. Not for restructuring layouts or converting frames to auto layout; it measures and snaps auto-layout padding and gaps only.

## Long description (Community page body)

**What it does.** Reads the padding and gaps of every auto-layout frame in your selection, compares each value with a 4/8 pt rhythm, and returns a ranked table: layer path, property, current value, nearest on-grid value, delta, and a P0 to P3 priority. Values inside main components rank highest; values inside instances point you at the main component; values bound to variables are reported, never overwritten. Nothing changes until you say so.

**How to use it.** Select the frames, type `/fm-spacing-rhythm-audit`, and read the table. The skill then asks one question: apply all, apply P0 and P1 only, pick rows, or none. After applying it re-reads every changed value and reports what was verified. Works in Figma Design; in Figma Make it returns the allowed spacing values as a checklist.

**What it will not do.** It does not add auto layout, move layers, change sizes or constraints, or touch variable bindings. If you need a layout rebuilt, use a layout skill first and run this audit after.

## Example prompts (shown on the page)

1. "Check the spacing on these cards"
2. "Is this layout on the 8pt grid?"
3. "Find off-grid padding before handoff"

## Artwork

- **Thumbnail:** 1920 × 1080. A single card component on the left with two padding values called out in red (18, 13), the audit table on the right with the same two rows and their fixes (16, 12). Only text: `/fm-spacing-rhythm-audit`.
- **Gallery:**
  1. Before and after of one card with the values annotated.
  2. The scope question as it appears in chat.
  3. The full report table for a four-card selection.
  4. The "After fixes" block with verified counts.
- **Video (optional):** 25 s, selection to report to confirmed snap.

## Support and contributors

- **Support contact:** [admin@futuremotion.studio](mailto:admin@futuremotion.studio)
- **Contributors:** Futuremotion Studio
- **License note:** Source: github.com/futuremotiondev/agent-skills, MIT

## Coding-agent channel

- Repo path: `figma/fm-figma-skill-creator/examples/fm-spacing-rhythm-audit/dist/claude/fm-spacing-rhythm-audit/SKILL.md`
- Community index PR title (figma/community-resources): `Add [skill] fm-spacing-rhythm-audit`
- Repo topics: `figma`, `figma-mcp`

## Pre-publish checklist

- [x] Frontmatter description and listing description are identical
- [x] Tagline under 80 characters
- [x] Category chosen from the six
- [ ] Thumbnail shows the output
- [x] Validator passes on the upload edition with zero errors
- [ ] Trigger eval pass rate at or above 0.5 on the holdout set
- [ ] Live test logged in EVAL-LOG.md
