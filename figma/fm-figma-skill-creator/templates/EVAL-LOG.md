# EVAL-LOG: <skill name>

One entry per test session. Newest first. Record facts, not impressions: the prompt, the selection, what the agent did, what it should have done, and the change made in response.

## Open questions this skill can settle on upload

Tick and record the answer the first time the upload edition goes through Figma's "Add skill" dialog. Copy the answers into `references/troubleshooting.md` of fm-figma-skill-creator.

- [ ] Extra frontmatter keys (`metadata`, `license`) on upload: kept / stripped / rejected: ____
- [ ] Name or description length limit hit: yes / no (lengths tried: ____)
- [ ] Body size limit hit: yes / no (lines / bytes tried: ____)
- [ ] Markdown images or links render in the instructions view: yes / no
- [ ] `node.query` / `node.set` work under `evaluate_script`: yes / no / not tried
- [ ] Export produces: ____ (format, whether frontmatter round-trips)

## Entry template

### <YYYY-MM-DD> · v<description version> · <surface: Figma Design | Figma Make | Claude Code>

- **Edition tested:** <upload | paste | coding-agent>
- **File and selection:** <file name; what was selected; node count>
- **Prompt:** "<verbatim>"
- **Triggered:** <yes by slash | yes by auto | no>
- **What the agent did:** <steps, in order, with counts>
- **What it should have done:** <only where different>
- **Output contract met:** <yes | no: which part>
- **Source changed:** <no | yes: what>
- **Credits consumed (if visible):** <n>
- **Defects:** <numbered; each with symptom and the instruction line that should have prevented it>
- **Change made:** <the edit to SKILL.md, or "none">
- **Re-test needed:** <yes | no>

## Entries

### <YYYY-MM-DD> · v1.0 · <surface>

- **Edition tested:**
- **File and selection:**
- **Prompt:**
- **Triggered:**
- **What the agent did:**
- **What it should have done:**
- **Output contract met:**
- **Source changed:**
- **Credits consumed (if visible):**
- **Defects:**
- **Change made:**
- **Re-test needed:**
