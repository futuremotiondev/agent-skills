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
| A script result arrives cut short | In-app, a return carrying a 50,000-character sample did not arrive whole; the same return measured 52,907 bytes over MCP, so the in-app limit is somewhere below that total | Return counts and capped rows; never a full node dump |
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
- **Script returns.** In-app, a return carrying a 50,000-character sample did not arrive whole; the same return measured 52,907 bytes over MCP, so the in-app limit is somewhere below that total. Over MCP, `use_figma` rejects returns over 48,000 bytes. `setPluginData` and `clientStorage` throw in both runtimes; `setSharedPluginData` works; `figma.notify` returns; `show_widget` is missing in the Figma Design agent. The full table is in `agent-capabilities-and-tools.md`.
- **Credits.** Credits were not recorded in Round 3; see testing-and-maintenance step 5 for where to read them; the eval logs say so rather than estimate.
- **Timings.** Audit on a 12-node seed selection: 34 s to the mode question, 47 s to the report, 26 s to apply five bindings, 19 s to revert them. Audit of an 844-frame page: 17 s to the scope question, 17 s to the mode question, 49 s to the report. Probe: 1 m 23 s from the disclosure answer to the first card.
- **Frame counts can differ between runtimes.** The same collect code measured 842 frames and 618 bound values in-app against 844 and 622 over `use_figma` on the same page. The likely cause is two nested slot nodes the in-app walk does not reach; it is open (see the fm-spacing-rhythm-audit EVAL-LOG). Compare in-app counts against an MCP oracle with a tolerance of a few frames until it is settled.

## Pitfalls from the v2 Plan 1 run (2026-11-02 to 2026-11-03)

Extracted from the run's ledger, task reports, review reports, and live observations after Plan 1 merged. Each row is something a skill author, implementer, or tester got wrong once or nearly did. Process and Windows tooling pitfalls that are not specific to Figma skills live in the repo's `CONTRIBUTING.md`.

### Figma runtime and the MCP bridge

| Symptom | Cause | Rule |
| --- | --- | --- |
| `use_figma` returns `Return value exceeds the 48000-byte limit ... Canvas edits from this run were not committed` and the writes are gone | The limit applies to the whole return and the run is rolled back | Never pair a large return with writes (seed, apply, revert); return counts and capped rows; the probe over MCP sets `PAYLOAD = 30000` |
| A collect that fit on the test file overflows on a real system | Payload was estimated from the test file; a 100-variable, 4-mode system returns 60 to 86 KB when every token and id is included | Estimate worst case from per-entry byte averages (a token about 164 B, a row about 292 B); return `tokenCount`, `candidateValues`, `spacingCollection`, `matchedCollections`, `libraryTokens` only; drop per-token id lists from the shipped helper |
| An oracle run measures the wrong page or nothing | `use_figma` starts every call on the file's first page | Switch with `await figma.setCurrentPageAsync(page)` inside the same call as the walk; throw on an unknown page name |
| A helper fence sent as written returns no result | `use_figma` runs top-level `await` and reads `return`; the in-app form is an IIFE | Drop the first `(async () => {` and last `})();` lines, keep `let MODE` before the body, and send the body |
| `use_figma` is rejected before any code runs | The tool schema requires a `description` argument; the figma-use skill does not say so | Always pass `description`, `code`, `fileKey`, and `skillNames` |
| Every file reads as "Document"; setting the name throws `Setting the document name is currently not supported` | `figma.root.name` is not exposed over `use_figma` | Identify files by key; `create_new_file` applies `fileName`; never verify a file name through a script |
| A probe's "one-second toast" lasts 1 ms | `figma.notify` `timeout` is in milliseconds | Write `{ timeout: 1000 }`; probe `notify` as a call check, since a presence check cannot see a throw |
| The probe runtime line reads `unknown` | One property getter threw inside a shared `try`; `figma.mode` reads `unknown` in both runtimes | Read `editorType`, `mode`, and `apiVersion` in separate `try` blocks; the line cannot tell in-app from MCP, so the agent names the runtime |
| A seeded collection has mode "Mode 1", variables with `ALL_SCOPES`, and a second mode with unexpected values | API defaults: the first mode is "Mode 1", scopes default to all, `addMode` does not guarantee copied values | Rename the first mode right after creating the collection; set scopes explicitly on every variable including aliases; set every variable's value for a new mode explicitly; read the seed back |
| Reverting an instance row leaves the layer overridden | The helper restores values, not "reset override" state | Say so in the revert report; test in-app before promising a clean undo on instances |
| Helpers avoid `?.` and `??` | ES2020 support in the in-app sandbox was unverified | Both ran in-app in Round 3 (the revert helper); still parse every fence with `new Function` before shipping |
| Every MCP step is blocked at session start | The `figma-desktop` server refuses connections; the remote `figma` server works | Use the remote server; load `figma-use` before `use_figma` and `figma-create-new-file` before `create_new_file`; call `create_session` with the file key before any file tool |

### In-app agent behaviour

| Symptom | Cause | Rule |
| --- | --- | --- |
| A fix on an instance row changes a main component on another page and every instance file-wide | Instance values inherit from the main component, which is the correct place to fix | Print the blast-radius sentence before the fix question ("Rows 8-10 point to main components outside the current page ...") and check it appears in test runs |
| On a large page the bind opportunities appear only as a per-token summary and "All" does not bind them | Individual opportunity rows are listed only at 50 frames or fewer | The footer says "To bind these, select 50 frames or fewer and run the audit again"; never promise bulk binding on a large selection |
| A host question tool cannot show five concept cards | Claude Code's question tool allows four options and adds Other itself | Offer cards 1 to 4 as options and say "Card 5 is the wildcard: choose Other and type 5"; the plain-text footer question stays canonical |
| The probe's disclosure says it writes a client-storage key, but nothing is written | The call errors in both runtimes; the disclosure is verbatim and describes the attempt | Known mismatch; confirm after a run that no `fm-probe` layer or key remains |
| An ideation deck cites a "landscape gap" with a count of 3 or 4 | "Gap" was undefined | A gap is a grid cell with a count of 0 or 1; cite the recon `counts`, never the capped naming sample, as a population |
| Deck "Does" lines warn `description-lead` | The first sentence passed 250 characters; the deck author never ran the validator | State the limit in the card template and run `validate-figma-skill.mjs --description "<line>"` on every Does line before showing the deck |
| A recon proof on an empty file "passes" | Nothing was there to observe; sample output lines were invented | Run recon on the seed file and mark sample lines "illustrative unless drawn from Observed" |

### Builder and validator

| Symptom | Cause | Rule |
| --- | --- | --- |
| A helper stays inline in the coding-agent edition | The marker is not exactly `// helper: <name>` (`^[a-z][a-z0-9-]*$`) on the fence's first line, or the fence sits outside the core `## Helper scripts` section | Watch stderr for `build warning: ... is not a valid helper marker`; `//helper:` without the space prints nothing; check the validator tail `helpers: n scripts` and that the coding-agent edition has no `javascript` fences |
| `build error: helper "x" has no code`, a duplicate name, or an unclosed fence stops the build | Deliberate guards | A marker-only fence is an error; the revert helper's `// enhancement: revert begin/end` region wraps the whole IIFE, so a pack that strips revert must remove the whole fence |
| A script hand-added under `dist/claude/<name>/scripts/` vanishes | The builder prunes every `.js` it did not write and reports `pruned n stale` | Never hand-edit `dist/`; regenerate from the master |
| The coding-agent edition ships a different `author` or `version` than the master | `overlay.claude.yaml` metadata wins in the merge | After a rebuild, compare `author:` and the six metadata keys between master and `dist/claude/<name>/SKILL.md` |
| A description containing `word: word` breaks the frontmatter | YAML reads `key: value` inside an unquoted scalar | Double-quote any description that contains a colon |
| `--description` exits 2 or splits the text | The flag takes the description text, not a file; multi-word text must be one argument | Run from the skill folder: `node scripts/validate-figma-skill.mjs --description "<text>"`, escaping inner double quotes |
| Running the validator on the creator's own `SKILL.md` reports dozens of errors | The creator is a coding-agent skill, not a Figma master | Check the creator with `--description` and markdownlint only; templates run with `--allow-placeholders` and show exactly two warnings, `name-format` and `description-angle` |
| A one-sentence addition trips `body-size` | Blank lines count toward the 500-line gate and the line gate binds long before the token gate; `wc -l` differs from the validator's body count | Re-run the validator on every edition after any prose edit; merge standalone one-line paragraphs; the audit master sits at 497 of 500 and its cut list (examples to three, do-and-do-not to four rules, merged edge cases, one-line helper comments, two-sentence MCP paragraph) runs before any new directive; helpers are never cut |
| The build accepts a top-level-await helper that was never run in-app | The parse check tries `new Function` and then the async constructor | Only the IIFE form is verified in-app; prefer it for in-app editions until a probe row says otherwise |
| 0 warnings, but the description has no real boundary or uses "Lets designers ..." | `NOT_FOR` accepts any "does not"; the voice pattern misses some forms | Treat 0 warnings as necessary, not sufficient: read the last sentence for a "Not for ..." boundary and imperative voice; re-run the 88-skill corpus after any rule change |
| `html-comments` warnings in Figma editions, or bracketed tags rendering as text | Separable prose was marked with HTML comments or brackets | Mark prose units with the fixed phrase (`Token mode:`, `Revert:`) at the start of the unit and code with `// enhancement: <name> begin/end`; lines inside the fenced report template are exempt |
| A pack strip breaks the master | The tag scope rule was never written down | A block-start tag covers the block including list continuation lines; a mid-block tag covers to the sentence end; stripping revert removes the whole fence; keep `let MODE` outside the region; the `previous` capture in apply stays in the core because revert needs it |
| The coding-agent edition reads "Run `scripts/x.js` ... through your script path" four times in a row | Pointer text replaces fences one for one | Prefer "The collect helper is `scripts/collect.js` in this folder"; budget the context cost of scripts separately from the body gate |
| `description-lead` warning after adding a trigger clause | The first sentence passed 250 characters | Add new trigger clauses as their own sentence |

### Oracle and fixtures

| Symptom | Cause | Rule |
| --- | --- | --- |
| The oracle drifts from the shipped helper | Hunks were edited in one place only | The oracle equals the master fence except the declared hunks (no IIFE, preamble, MODE preset, `MAX_ROWS = Infinity`, selection clear, restore block); diff them after every helper change and regenerate the oracle |
| A compare fails on `tokens` or `unbound[].ids` | The oracle returns the full lists; the shipped helper returns `tokenCount` and no ids | Compare shared fields only; match an example id against the oracle's id list, not for equality, because walk order differs |
| `expected.json` cannot name its own commit | The fixture is written after the commit it describes | `masterCommit` is a placeholder until the compare script pins a real hash |
| The oracle throws `SELECTION name "X" matches N top-level nodes` | A seed node was renamed or duplicated | Keep the twelve seed names unique and unchanged; restore edits after a proof (`Token card` padding left back to 8, unbound) |
| The mock harness passes but Figma behaves differently | The mock models the author's assumptions (it kept a binding on a raw write) | Label mock numbers as sanity checks; prove every write path over `use_figma` |
| markdownlint fails on `tests/fixtures/*.md` | The fixtures are verbatim agent output with `<figma-node-link>` elements | Exclude `**/tests/fixtures/**` from lint; never edit a fixture |
| Discover and collect walk the file twice | The mode question needs token names before collect | `let MODE = "discover"` returns tokens only and falls back to rhythm when none exist; observed cost is flat at 22 to 24 credits per page audit regardless of canvas size |

### Helper rules that reviews had to restore

These are design rules in `fm-spacing-rhythm-audit`'s collect helper. Each was broken once by a plausible edit, so check them whenever the helper changes.

- A spacing candidate is a FLOAT in the spacing collection whose scopes include GAP, or whose name matches `/space|spacing/i` and not `/letter|\bline[-\s]?(height|spacing)\b|paragraph/i`. The earlier `/letter|line|paragraph/i` excluded `Space/inline/200`.
- The spacing collection is elected by candidate count, not variable count; other matched collections appear in `matchedCollections` with a reason and in the "Matched but not offered" line.
- A value held only by an alias passes, counts in `aliasMatched`, and is never snapped or offered.
- Zero is never a bind suggestion and passes in both modes. The maximum bind distance is 4.
- Token mode skips negative values; rhythm mode keeps the v1.3 behaviour (-6 snaps to -8). Changing either is a ruling, not a drive-by.
- Apply fetches the variable first and calls only `setBoundVariable` for bind fixes; a failed bind leaves the node untouched and lands in skipped with the error text. Revert guards a non-numeric `previous` before any write, keeps each row's failure local, and re-reads after every write.
- Decided 2026-11-03 for Plan 2: an on-rhythm value with no equal token but a candidate within 4 ranks P3 as a bind opportunity, excluded from "P0 and P1 only"; the mode question shows the positive span plus a negatives clause ("2 to 160 px, plus negative tokens to -24").

## Open questions a live upload settles

- Whether extra frontmatter keys are kept, stripped, or rejected on upload.
- Any size cap on name, description, or body.
- What Export produces and whether frontmatter round-trips.
- Whether Markdown images render; links to layers do (see above).
- Whether `node.query` and `node.set` work under `evaluate_script` when called (both are present).

Record the answers in `EVAL-LOG.md` of the first skill you test and update this file.
