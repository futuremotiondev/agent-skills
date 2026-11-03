# Troubleshooting, contradictions, and open questions

## Symptoms and fixes

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Skill does not appear in the `/` menu | The menu shows only a handful; team skill not reachable (known issue); guest account (silent plan-role gating) | Type the name after `/`; use Add context > Skills > Use skills; confirm the user is a member with edit access |
| Skill never auto-triggers | Description written as a restriction ("only when...") or without the user's phrases | Rewrite as a requirement with quoted phrases; run the trigger eval |
| Second skill in the prompt is ignored | Only the first skill mentioned runs | One skill per prompt; point to others with "Not for X (use /y)" |
| Skill ignored on the first prompt in Make | Known issue after a model switch | Send a plain prompt first, then the skill |
| Instructions start with a visible `---` block in the editor | Pasted frontmatter in Start from scratch | Use the paste edition (no frontmatter) or delete the block |
| Listing name and body `name:` differ | Frontmatter left in the body | Remove it from the Figma edition |
| Agent edits the source frame | No "work on a duplicate" rule | Add the never-touch-source rule and a duplicate step |
| Agent audits the whole file and burns credits | No scope gate | Add the selection gate with a verbatim question |
| Output varies between runs | Adjective rubrics, no verify step | Numeric thresholds, read-back step, output contract, cap |
| Agent claims it wired a prototype or exported assets | Instruction touches a "Coming soon" or unsupported capability | Capability gate: plan-only wording |
| `evaluate_script` results missing or truncated | Output limits; `console.log` used; node ids stale | Use `return`; smaller batches; re-fetch nodes by id per call |
| Text nodes come out with extreme heights | `characters` set before `resize` | `resize(width, 16)`, then `textAutoResize = 'HEIGHT'`, then `characters` |
| Measurements read 0 | Read in the same call that built the node | Measure in a later call |
| `loadAllPagesAsync` fails | Not implemented in-app | Feature-check; degrade to the current page and say so |
| Plugin data reads empty | `setPluginData`/`getPluginData` silently unavailable | Use `setSharedPluginData` or encode in layer names |
| Font substitution | Agent substituted when a font failed to load | Rule: report the failure, never substitute |
| Skill works in Figma but not in Claude Code | Body names in-app tools | Move them into `target:figma-app`; add the MCP section |
| Skill works in Claude Code but not in Figma | References, scripts, or MCP tool names in the core | Flatten and move to `target:mcp` |
| Validator reports a marker without a close | Unbalanced `<!-- target:x -->` | Add `<!-- /target -->` |
| Credits exhausted mid-run | Long skill, bulk generation, whole-file scope | Scope, cap, warn before expensive steps |

## Contradictions between sources, with the working rule

| # | Topic | Evidence | Working rule |
| --- | --- | --- | --- |
| 1 | Frontmatter on upload vs paste | Upload shows name and description for review; paste keeps the block as text; Figma's own example ships two blocks | Upload edition with one clean block; paste edition with none |
| 2 | Extra frontmatter keys | Figma silent; one Qredence skill ships `compatibility` without issue | Strip from the Figma edition until an upload test proves tolerance |
| 3 | Size limits | None published; spec recommends under 500 lines; Figma's longest skill is 9,160 words | Aim under 500 lines; justify longer with deterministic output |
| 4 | Auto-selection | "You must invoke" vs "invoked automatically"; no algorithm | `/name` is the contract; auto-trigger is tuned by evals |
| 5 | Community review | None documented for skills; MCP FAQ says no approval; plugins are reviewed | Assume immediate publication; self-review |
| 6 | Plan availability wording | "All plans" vs named lists vs Full-seat-only chat visibility | Say "needs edit access and the agent" |
| 7 | MCP portability of Community skills | "Run directly inside the Figma app" vs "work with Claude, Cursor, Codex"; July promise to serve in-app skills via MCP unverified | Portable only if tool-neutral; use the hybrid |
| 8 | `evaluate_script` contract | Undocumented; limits unknown; Advocates say not to assume the Plugin API | Feature-detect, cap batches, measure later, prose fallback |
| 9 | `show_widget` provenance | Figma's own example uses it; only leaked prompts describe the contract | In-app pickers only, with numbered-options fallback |
| 10 | `node.query` / `node.set` / `figma.io.write` in-app | Documented for `use_figma`; zero in-app uses | Do not rely on them in the figma-app section |
| 11 | FigJam and Slides timing | Closed beta; staff say Design only | Surface check; plan-only otherwise |
| 12 | Agent "only in Figma Design" vs skills in Make | Agent FAQ scopes Design; skills docs cover Design and Make | Branch by product |
| 13 | Category count | Six hubs vs "seven categories" in FAQ prose | Pick the closest of the six |
| 14 | Community skill license | "Community Free Resource License" seen in one scrape, not in another | Check the page before copying third-party skills into an MIT repo |
| 15 | Chat visibility scope | "Anyone with access" vs "Full seat and edit access" | Keep secrets out |
| 16 | "Use the Figma MCP" inside an in-app example | Figma's own example says it for reads | Loose naming; write "read the selected frame" |
| 17 | Export format and update propagation | Export exists; shape and propagation undocumented | Git master; re-publish and announce |
| 18 | Name collisions and the tags field | No rule; tags shown but field undocumented | Prefix names; add tags if offered |
| 19 | Images and links in the body | No source | Text, tables, and code only |

## Answers from the first live upload (fm-spacing-rhythm-audit, 2026-11-02)

- Upload accepted a file whose frontmatter held only `name` and `description`; both fields were prefilled. Whether extra keys survive is still untested.
- A body of about 190 lines with three fenced JavaScript blocks uploaded without a size complaint.
- The Start-from-scratch form enforces a description of 1,024 characters or fewer (observed 2026-11-02). That is the same ceiling the spec sets and the validator's `description-length` rule checks; the paste route reads name and description from the form fields, not from the body.
- Chat output renders Markdown tables, bold, and layer references as clickable node links (`figma-node-link`, and a grouped variant for several nodes). The agent produces these links on its own when the output names layers.
- Questions are shown in a response card that does not render Markdown: `**1. Option**` appears with literal asterisks. Write verbatim questions as plain text.
- Results matched the `evaluate_script` helpers' logic exactly, including tie-breaks, but the chat does not show whether the helper ran or the agent re-implemented it.
- No AI-credit counter is visible in the Figma UI on a Starter-tier team; runs of 24 to 45 s per step.
- The agent reads "never change sizes" as "preserve the rendered height of hug frames" and will silently revert a confirmed change to honour it. Define size change precisely and forbid silent reverts.

## Open questions a live upload settles

- Whether extra frontmatter keys are kept, stripped, or rejected on upload.
- Any size cap on name, description, or body.
- What Export produces and whether frontmatter round-trips.
- Whether Markdown images render; links to layers do (see above).
- Whether `node.query` and `node.set` work under `evaluate_script`.

Record the answers in `EVAL-LOG.md` of the first skill you test and update this file.
