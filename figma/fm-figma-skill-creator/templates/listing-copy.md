# Listing copy: <skill name>

Fill every field before publishing. Figma shows the description as the Community preview text and uses it for routing, so it must be the same sentence the frontmatter carries. Keep the tagline under 80 characters. Delete the guidance lines in angle brackets.

## Identity

- **Name (slash command):** `fm-<verb>-<object>`
- **Display title:** <Title Case, 2 to 5 words; what it does, not the team name>
- **Category:** <one of: Research and strategy · Generation · Brand · Design systems · Critique · Workflows>
- **Tags:** <3 to 6 lowercase nouns a searcher would type: e.g. spacing, audit, 8pt, layout>

## Tagline (under 80 characters)

<Verb + object + payoff. Example: "Audit spacing against a 4/8 pt grid and snap it in one pass.">

## Description (identical to frontmatter `description`)

<Paste the frontmatter description verbatim. Third person, names the output, quotes 3 trigger phrases, ends with "Not for X (use /y)".>

## Long description (Community page body)

<3 short paragraphs. Each under 60 words.>

**What it does.** <Output first: what appears in chat, what appears on canvas, what never changes.>

**How to use it.** <Select X, type `/fm-<verb>-<object>`, answer the one question it asks. Mention the surfaces it supports: Figma Design, Figma Make.>

**What it will not do.** <The boundary and the nearest other skill.>

## Example prompts (shown on the page)

1. "<prompt 1>"
2. "<prompt 2>"
3. "<prompt 3>"

## Artwork

- **Thumbnail:** 1920 × 1080, PNG or JPG. <What it shows: the output, not a logo. One frame of the skill's result with the slash command as the only text.>
- **Gallery (up to 9, 1920 × 1080 each):** <before/after pair, the question the skill asks, the final report, a Make screen if supported.>
- **Video (optional):** <under 30 s, the full run from selection to report.>

## Support and contributors

- **Support contact:** <email or URL>
- **Contributors:** <names or handles>
- **License note:** <e.g. "Source: github.com/futuremotiondev/agent-skills, MIT">

## Coding-agent channel (optional)

If also publishing the coding-agent edition:

- Repo path: `figma/<fm-verb-object>/SKILL.md`
- Install line: `npx skills add futuremotiondev/agent-skills --skill <fm-verb-object>`
- Community index PR title (figma/community-resources): `Add [skill] <fm-verb-object>`
- Repo topics: `figma`, `figma-mcp`

## Pre-publish checklist

- [ ] Frontmatter description and listing description are identical
- [ ] Tagline under 80 characters
- [ ] Category chosen from the six
- [ ] Thumbnail shows the output
- [ ] Validator passes on the upload edition with zero errors
- [ ] Trigger eval pass rate at or above 0.5 on the holdout set
- [ ] Live test logged in EVAL-LOG.md
