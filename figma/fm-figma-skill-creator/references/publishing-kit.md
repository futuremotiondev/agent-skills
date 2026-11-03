# Publishing kit: team, organization, Community, and the coding-agent channel

## Where to publish

Manage skills > select skill > More actions > Publish.

| Destination | Who sees it | Fields | Review |
| --- | --- | --- | --- |
| Private: team | Members of the team the current file belongs to ("You can publish only to the team where the file is located or to the whole organization") | Name, description | None |
| Private: organization | Everyone in the organization | Name, description | None |
| Figma Community | Everyone; listing at `figma.com/community/skill/<id>/<slug>` | Name, description (shown as Preview text), tagline, category, thumbnail plus up to 9 images or videos (1920 x 1080 recommended; "You can use the Community file cover frame preset"), additional contributors (need a Community account and view or edit access to the file), support contact (email or website), tags (shown on pages; entry field unverified) | None documented for skills (plugins have review; the MCP FAQ says "no approval process") |

Updating goes through "..." > Manage skill > Publish changes, which also lets you edit name and
description. A rename shows only to others. Unpublishing keeps the skill for you and removes it for
others. Deleting a published skill removes it for everyone, so Export first.

Consumers see a page with the type label "Skill", likes and users, Try it out, the Preview
carousel and text, the line-numbered Instructions with Copy to clipboard, tags, comments, "Last
updated", and the support contact. They use Try in (pick a file) or Save; saved skills appear under
the Figma Community tab in Manage skills.

## Category hubs

Research and strategy · Generation · Brand · Design systems · Critique · Workflows. (Figma's FAQ
prose names a seventh, handoff, that has no hub; pick the closest of the six.)

## Listing copy

Write the listing the way the strongest skills do: a one-sentence promise that names the output,
then what it needs, then what it is not for.

| Field | Formula | Example |
| --- | --- | --- |
| Name | `fm-<verb>-<object>`, specific, prefixed | `fm-spacing-rhythm-audit` |
| Tagline | Output in under 80 characters | "Off-grid padding and gaps, ranked, with the exact fix." |
| Description (Preview text) | The frontmatter description: capability, triggers, exclusion. It doubles as the routing text, so keep the requirement phrasing | "Audits the selected frames against a 4/8 pt spacing rhythm... Use whenever... Not for..." |
| Category | One of the six hubs | Critique |
| Tags | 3 to 5 nouns users would search | spacing, audit, layout, design system |
| Support contact | A monitored address or page | support email or GitHub issues URL |

Avoid plan lists in the listing ("works on Professional and above"); say "needs edit access and
the Figma agent" instead, because Figma's own pages disagree on plan wording.

## Artwork

- **Thumbnail**: 1920 x 1080. Show the output, not a logo: the ranked report in chat, or the new
  frame next to the source. Figma's own covers are text-on-colour tiles; popular third-party
  skills show the result on the canvas.
- **Up to 9 more images or videos**: before/after, each edge case handled, the slash command in the
  prompt box, the output contract. Most skills ship one image; the most-used ships ten.
- Build the frames in a Figma Design file with the Community cover frame preset, keep text large
  (the card is small in the listing), export PNG at 1x (1920 x 1080). Reuse the brand kit under
  `.assets/` for consistent colour and type.
- Keep a `listing/` folder in the skill repo with the final PNGs and the copy, so "Publish changes"
  is a copy-paste job.

## Pre-publish checklist

- [ ] Validator passes on the upload edition; no frontmatter beyond name and description.
- [ ] Name is prefixed, specific, lowercase-hyphen; not already in your team or org.
- [ ] Description starts with the output, has quoted trigger phrases, and a "Not for" clause.
- [ ] Trigger eval and behaviour eval logged; happy path and edge cases run on a duplicate file.
- [ ] Credits per run recorded; expensive steps are scoped or confirmed.
- [ ] No secrets, internal URLs, or client data in the body (chats are visible to collaborators).
- [ ] Capability gates match today's "Supported / Coming soon" table.
- [ ] Listing copy, thumbnail, and preview images prepared; support contact monitored.
- [ ] License decided (Community pages show the Community Free Resource License; the coding-agent
      channel prefers CC0 or MIT).

## The coding-agent channel

The same Git repository can serve external agents. Distribute the coding-agent edition with
`npx skills add <owner>/<repo>` (the CLI discovers `skills/<name>/SKILL.md` or folders declared in
`skills.sh.json`). To be listed in Figma's curated index, open a PR to
`github.com/figma/community-resources` under `agent_skills/` with the PR title
`Add [skill] NAME`, GitHub topics `figma` and `figma-mcp`, a name that does not start with "Figma",
and a CC0 or MIT license. The index is separate from the Community library and listing there does
not place the skill in Figma's Community.
