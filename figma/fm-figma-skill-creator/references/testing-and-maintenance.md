# Testing, iteration, and maintenance

Figma provides no linter, test harness, or template for in-app skills. The authoring aids are the
Start-from-scratch form, the agent itself ("Revise the attached skill.md file to fit my design
system", "Merge these two skills together"), and the Markdown editor. Figma's published loop is:
preview the draft, use it in chat, keep iterating by editing steps or opening the editor. The one
safety rule from the developer docs: test on a duplicate or example file, never a file you depend
on. Everything below adds structure to that loop.

## Static checks before any upload

```bash
node scripts/validate-figma-skill.mjs path/to/SKILL.md --edition master
node scripts/build-skill-editions.mjs path/to/SKILL.md --out dist/
node scripts/validate-figma-skill.mjs dist/<name>.figma.md --edition upload
node scripts/validate-figma-skill.mjs dist/<name>.paste.md --edition paste
node scripts/validate-figma-skill.mjs dist/claude/<name>/SKILL.md --edition coding-agent
```

Fix every error. Justify any warning you keep in the skill's notes. The validator encodes the
rules in `validate-figma-skill.mjs --rules`.

The `body-size` rule warns past 500 body lines in every edition, past about 5,000 estimated tokens
in the coding-agent edition, and past about 12,000 in the master, upload, and paste editions: 500
lines and 5,000 tokens are the Agent Skills spec's guidance for coding-agent context, while Figma
enforces no body limit and its longest first-party skill is about 12,000 tokens.

The `helper-placement` rule (master only) warns when a `javascript` fence sits inside a target
region, or a `// helper:` marker sits outside the core `## Helper scripts` section. The build
extracts helpers only from that section, so either one would ship a helper to one runtime only.

## The trigger eval (description quality)

The description is the only field every runtime routes on. Test it before testing the body.

1. Write about 20 queries in `templates/eval-queries.md`: 8 to 10 that should trigger the skill
   (varied wording, no slash command) and 8 to 10 near-miss negatives (adjacent tasks the skill
   must not claim).
2. Hold out about 40 percent for validation; tune on the rest.
3. In Figma, run each training query 3 times in a fresh chat on a duplicate file. Count a trigger
   rate of 0.5 or better as a pass per query; a negative that triggers is a fail.
4. Rewrite the description: add the phrases that failed to trigger, add a "Not for" clause for the
   negatives that triggered. Iterate about five times, then confirm on the held-out set.
5. Run the slash path separately; it must always work.

## The behaviour eval (body quality)

1. **Baseline first.** Run the same request without the skill and save the output. The skill is
   measured against the gap it closes.
2. Run the happy path on a duplicate file, then each edge case (nothing selected, wrong node type,
   several candidates, missing library or connector, unsupported feature).
3. Check the output contract line by line: counts, names, positions, "source unchanged".
4. Repeat one run three times and note the variance; tighten numeric rules where it varies.
5. Hover the AI credits icon under each completed prompt and record the cost; scope or cap steps
   that are expensive.
6. In Make, test in a fresh prompt (never the first prompt after a model switch).
7. Figma's own failure signal: if you edit the output more than doing the work would take, or
   ignore it, the skill is too generic. Add named rules and Do/Do-not examples, not adjectives.

Record each run in the skill's `EVAL-LOG.md` (date, edition, query, triggered, output quality 1 to
5, credits, notes).

## Live-test protocol for a new skill

1. Build editions, validate all three.
2. Upload `dist/<name>.figma.md`; confirm the review screen filled name and description.
3. Open a duplicate test file with a representative selection.
4. Run `/<name>` once; then run three natural-language triggers; then one negative.
5. Capture the chat transcript and a screenshot of any canvas output.
6. Export the skill from Manage skills and diff it against the upload edition to learn the
   export shape (it is undocumented).
7. Feed findings back into the master; rebuild; re-upload with "Publish changes" if published.

## Maintenance

- The Git master is the source of truth. Never edit the Figma copy as master; if someone edits it
  in-app, Export and merge by hand.
- Version in `metadata.version` (quoted string) in the master; Figma offers no version field,
  changelog, or rollback, only "Last updated".
- Keep one `SKILL.md` per skill. A second "upload surface" file per skill failed in practice for
  the largest public catalogue and was removed within days.
- Re-upload after each change; whether saved or exported copies receive updates is undocumented,
  so announce changes to the team.
- Review capability gates on every Figma release: each "Coming soon" row that becomes "Supported"
  makes a plan-only branch obsolete.
- Re-run the trigger eval after any description change and after Figma model updates.
