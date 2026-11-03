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
| `loadAllPagesAsync` fails | Reported not implemented by third parties; present in the 2026-11-03 probe, call untested | Feature-check; degrade to the current page and say so |
| `setPluginData` throws "not supported in this host runtime" | Plugin data is for private plugins only, in-app and over MCP (probe, 2026-11-03) | Use `setSharedPluginData` (round trip ok) or encode in layer names |
| `clientStorage.setAsync` throws "not a supported API" | Client storage is unsupported in-app and over MCP (probe, 2026-11-03) | Persist nothing; keep state in the chat |
| A gate renders as plain text instead of a card | The skill text did not name the structured question tool for that gate | Say "through a structured question tool when the runtime has one" in the core and name `ask_user_question` in `target:figma-app` |
| The agent offers presets at a free-text follow-up ("1. Choose rows 1-5") | The follow-up was not marked free text | Ask it "as a free-text question with no preset options" |
| A script result arrives cut short | In-app returns are truncated, not rejected, below 50,000 bytes | Return counts and capped rows; never a full node dump |
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
| 3 | Size limits | Figma enforces no body limit and its longest first-party skill is about 12k tokens; the spec recommends under 500 lines, and about 5k tokens is its coding-agent guidance | Keep 500 lines in every edition, about 5k tokens in the coding-agent edition, and under about 12k tokens in the Figma editions; justify longer with deterministic output |
| 4 | Auto-selection | "You must invoke" vs "invoked automatically"; no algorithm | `/name` is the contract; auto-trigger is tuned by evals |
| 5 | Community review | None documented for skills; MCP FAQ says no approval; plugins are reviewed | Assume immediate publication; self-review |
| 6 | Plan availability wording | "All plans" vs named lists vs Full-seat-only chat visibility | Say "needs edit access and the agent" |
| 7 | MCP portability of Community skills | "Run directly inside the Figma app" vs "work with Claude, Cursor, Codex"; July promise to serve in-app skills via MCP unverified | Portable only if tool-neutral; use the hybrid |
| 8 | `evaluate_script` contract | Undocumented; limits unknown; Advocates say not to assume the Plugin API | Feature-detect, cap batches, measure later, prose fallback |
| 9 | `show_widget` provenance | Figma's own example uses it; only leaked prompts describe the contract; the 2026-11-03 probe found it **missing** in the Figma Design agent while `ask_user_question` was available | Never the only path: numbered options in text, asked through `ask_user_question` where available; a widget picker is an optional extra |
| 10 | `node.query` / `node.set` / `figma.io.write` in-app | Documented for `use_figma`; zero in-app uses; `node.query` and `node.set` present in-app (probe, 2026-11-03, presence only, calls untested) | Do not rely on them in the figma-app section |
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
- AI credits are shown per response once you know where to look. Observed on a 30-page design system: about 10 credits to ask the scope question, 22 to 24 to audit a page whether it holds 842 or 1,937 auto-layout frames, 18 to apply five fixes, 4 to decline. Cost tracks reasoning, not canvas size. Runs took 18 to 56 s.
- An `evaluate_script`-style collection over 1,939 frames and 1,372 instances completes in under 2 s with a payload under 5 KB; a 2,000-frame cap is comfortable.
- `SLOT` is a live node type (Figma Slots) with auto-layout properties; state the counting rule in the skill. (Corrected in Round 3: the two Hero slots were measured in-app, since they appear as rows; the two-frame gap has another likely cause, see below.)
- The agent reads variable bindings on main components even when the skill's helper does not, and will name the token; make the helper match so the oracle and the report agree.
- The agent reads "never change sizes" as "preserve the rendered height of hug frames" and will silently revert a confirmed change to honour it. Define size change precisely and forbid silent reverts.

## Answers from Round 3 (fm-spacing-rhythm-audit 2.0 and fm-figma-capability-probe 1.0, 2026-11-03)

- **Decision-gate UI.** Cards with clickable options wherever the skill names the structured question tool; plain prose otherwise. The audit's mode and fix questions, which the master routes through `ask_user_question`, rendered as cards with lettered options (A, B, ...) and an "Add a custom response" option. The audit's scope question and the probe's disclosure, which did not name the tool, rendered as plain text and were answered by typing. Since then every gate in the examples, templates, and house style names the tool, with the plain-text wording as the fallback.
- **Free-text follow-ups.** After "3. Pick by row number" the follow-up showed as a card reading "Awaiting custom response", and the agent added presets ("1. Choose rows 1-5, 2. Choose rows 7-10") that the skill never defined and that would have snapped unrelated rows. Say "as a free-text question with no preset options".
- **Output lines live in the output contract.** A line defined only inside a step (the audit's "Matched but not offered") was printed in one run and dropped in the next. Put every report line in the output contract.
- **Script returns.** In-app, a 50,000-character return arrived truncated, not rejected; over MCP, `use_figma` rejects returns over 48,000 bytes. `setPluginData` and `clientStorage` throw in both runtimes; `setSharedPluginData` works; `figma.notify` returns; `show_widget` is missing in the Figma Design agent. The full table is in `agent-capabilities-and-tools.md`.
- **Credits.** No credit figure was shown in the chat UI during Round 3; eval logs record "not shown" rather than an estimate.
- **Timings.** Audit on a 12-node seed selection: 34 s to the mode question, 47 s to the report, 26 s to apply five bindings, 19 s to revert them. Audit of an 844-frame page: 17 s to the scope question, 17 s to the mode question, 49 s to the report. Probe: 1 m 23 s from the disclosure answer to the first card.
- **Frame counts can differ between runtimes.** The same collect code measured 842 frames and 618 bound values in-app against 844 and 622 over `use_figma` on the same page. The likely cause is two nested slot nodes the in-app walk does not reach; it is open (see the fm-spacing-rhythm-audit EVAL-LOG). Compare in-app counts against an MCP oracle with a tolerance of a few frames until it is settled.

## Open questions a live upload settles

- Whether extra frontmatter keys are kept, stripped, or rejected on upload.
- Any size cap on name, description, or body.
- What Export produces and whether frontmatter round-trips.
- Whether Markdown images render; links to layers do (see above).
- Whether `node.query` and `node.set` work under `evaluate_script` when called (both are present).

Record the answers in `EVAL-LOG.md` of the first skill you test and update this file.
