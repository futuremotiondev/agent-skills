# Self-Check Protocol

Run this checklist as Stage 4 of the workflow, after rendering all variants but before emitting the JSON. Each item has a quick remedy. Catching these before they reach the user is the difference between a skill that feels reliable and one that feels brittle.

The protocol is grouped by failure category. Work through each group in order. When a check fails, fix it and re-run that group; do not proceed until the group passes.

## Group 1 — Shape and counts

**Check 1.1.** The output JSON has exactly the seven top-level fields specified in `references/output-contract.md`: `visual_dna`, `universal_prompts`, `clone_prompts`, `stylistic_siblings`, `stochastic_variants`, `recreation_notes`, `flagged_for_firefly`. Missing any field is a contract violation. Remedy: add the missing field with a sensible default (`null` or `[]` or `false`).

**Check 1.2.** `clone_prompts.variants` has exactly 5 entries. Not 4, not 6, unless the user explicitly asked for a different count. Remedy: produce additional phrasing-different attempts at the same image, or trim duplicates.

**Check 1.3.** `stylistic_siblings.variants` has exactly 6 entries, each with a distinct `sibling_subject`. Two siblings cannot both be `"wolf"` or both be `"cathedral"`. Remedy: broaden the candidate noun pool (industrial → organic → architectural → mythological → biological) until six distinctly different subjects emerge.

**Check 1.4.** `stochastic_variants.variants` has exactly 8 entries, each declaring a `shifted_axis` from the enumerated set. If two variants share the same axis, the second must explicitly note it is a compound shift in `shift_description`. Remedy: re-assign axes so all 8 are unique, or label compound shifts clearly.

**Check 1.5.** `universal_prompts` has between 3 and 5 entries. Remedy: produce additional foregroundings (subject-led, style-led, lighting-led, palette-led, camera-led) if short; trim the weakest if over.

## Group 2 — Per-model coverage

**Check 2.1.** Every variant's `per_model` object contains all 13 keys: `midjourney_v7`, `flux_1`, `flux_2`, `nano_banana`, `wan_2_6`, `seedream_4`, `kling_image`, `grok_imagine`, `qwen_image`, `z_image`, `ideogram_3`, `imagen_4`, `adobe_firefly`. Missing keys break the contract even when the user only asked for a subset. Remedy: add the missing keys with `null` value.

**Check 2.2.** For the 13 keys, only `kling_image` may legitimately be `null` (when the source image is genuinely incompatible with motion framing — a pure static product, a flat abstract composition with no implied dynamism). All other keys must contain non-empty strings. Remedy: render the missing model prompt by re-reading the relevant `references/models/<model>.md` file.

**Check 2.3.** When the user requested a subset of models, every *un*-requested key is `null` (not omitted, not empty string, not a fallback prompt). Remedy: walk the keys and set un-requested ones to `null` explicitly.

## Group 3 — Per-model idiom

**Check 3.1.** Every `midjourney_v7` string ends with at least an `--ar` parameter. Most should also include `--s` and/or `--c`. The aspect ratio in `--ar` matches `visual_dna.aspect_ratio`. Remedy: append the missing flags.

**Check 3.2.** Every `flux_1` string is between 30 and 80 words. Remedy: trim or expand.

**Check 3.3.** Every `flux_2` string is either (a) a natural-language paragraph under 150 words *or* (b) a valid JSON object as a string (it must parse as JSON when read). Remedy: validate JSON parsability, or trim word count.

**Check 3.4.** Every `nano_banana` string reads as a descriptive paragraph in photographic terminology. No bare keyword stacks ("chrome, wolf, neon, dramatic"), no flag syntax (`--ar`). Remedy: rewrite as a single coherent paragraph.

**Check 3.5.** Every `wan_2_6` string has visible structure: subject clause, scene clause, lighting/camera clause, style clause. Remedy: re-render from the WAN template.

**Check 3.6.** Every `seedream_4` string is concise (not over-ornate). Quoted strings used for any in-image text. Remedy: trim adjective stacks; add quotes around literal text.

**Check 3.7.** Every `kling_image` string either contains implied-motion language ("at the apex of," "captured mid-arc," "motion frozen at 1/2000") or is `null`. A non-null Kling prompt without motion implications will not produce a usable still. Remedy: add motion clause or null the field.

**Check 3.8.** Every `grok_imagine` string is between 1 and 3 sentences. No flag syntax, no seeds, no negative wording. Remedy: trim, drop disallowed elements.

**Check 3.9.** Every `qwen_image` string contains labeled categories (Subject:, Environment:, Lighting:, Camera:, Style:) and ends with `, Ultra HD, 4K, cinematic composition.` or its Chinese equivalent. Quoted strings used for any in-image text. Remedy: re-structure into labeled categories, append the magic suffix.

**Check 3.10.** Every `z_image` string contains ZERO instances of the words `no`, `not`, `without`, `avoid`, `free of`, `lacking`, `absent`. Search the string. Even one instance is a failure because Z-Image silently drops negative prompts entirely. Remedy: rewrite every negative clause as a positive constraint. "No extra fingers" becomes "five clearly delineated fingers." "Without text" becomes "clean composition with no overlay elements." "Avoid distortion" becomes "natural undistorted proportions."

**Check 3.11.** Every `ideogram_3` string follows the explicit ordering: image summary → subject (with any quoted text) → pose → setting → lighting → framing → technical. Modes pick from Realistic / Design / General. Remedy: re-render from the Ideogram template.

**Check 3.12.** Every `imagen_4` string is either a natural paragraph OR a SCULPT block (`Subject: ... Context: ... Look: ... Photographic choices: ... Lighting: ... Technical constraints: ...`). No negative wording in the positive string. Any in-image text is ≤25 characters and there are ≤3 quoted phrases. Remedy: move negatives to the separate `imagen_4_negative` field (note in `recreation_notes`), trim text length.

**Check 3.13.** Every `adobe_firefly` string is plain natural language, no flag syntax, ≥3 words, and IP-clean (passes the IP cleaner check in Group 4). Remedy: rewrite to plain prose, run IP cleaner if needed.

## Group 4 — IP and content safety

**Check 4.1.** If `visual_dna.style.photographer_or_artist_reference` contains a specific person name, the Firefly variant has substituted that name with descriptive style language per `references/firefly-ip-cleaning.md`. Remedy: run the IP cleaner, replace the name in Firefly only, leave Midjourney and Flux paths intact.

**Check 4.2.** If `visual_dna.recreation_difficulty.notes` contains `"contains_real_person"`, `"branded_character"`, `"trademark_logo"`, or `"specific_artist_style"`, the Firefly variant has been cleaned and `flagged_for_firefly` is set to `true`. Remedy: clean, set flag.

**Check 4.3.** If the source image likely contains a real public figure (celebrity, politician, athlete), the per-model strings *other* than Firefly do not name them by full name. Use descriptive identification ("a stadium musician in mid-performance, mic in left hand") instead of "[Name] performing at [Venue]." This is partly for safety, partly because likeness rendering is unreliable everywhere and the prompt does better with descriptive framing. Remedy: rewrite the identifying clause.

**Check 4.4.** No prompt contains weapons-aimed-at-people, gore, explicit sexual content, or content involving minors in adult contexts. If the source image contains any of these, decline to emit prompts for that source. The skill is not equipped to handle these cases safely.

## Group 5 — Aspect ratio handling

**Check 5.1.** The `--ar` parameter in `midjourney_v7` matches `visual_dna.aspect_ratio` exactly.

**Check 5.2.** The aspect ratio is mentioned in natural-language form somewhere in `flux_1`, `flux_2`, `nano_banana`, `wan_2_6`, `seedream_4`, `grok_imagine`, `qwen_image`, `z_image`, `adobe_firefly`. "2:3 portrait" or "portrait composition" is fine; "tall vertical" is acceptable; complete silence on aspect ratio is not, because those models default to square and the result is unintentionally cropped.

**Check 5.3.** For `imagen_4`, the aspect ratio is one of the supported values (1:1, 4:3, 3:4, 16:9, 9:16). If the source's aspect is 2:3, 3:2, 4:5, 5:4, 21:9, or 9:21, the Imagen variant has been adjusted to the nearest supported ratio (3:4 or 4:3 in most cases) and a note has been added to `recreation_notes`. Remedy: adjust the Imagen aspect and add the note.

**Check 5.4.** For `ideogram_3` and `adobe_firefly`, the aspect ratio is set in natural-language form because both APIs accept the ratio as a separate parameter rather than reading it from the prompt. Remedy: include the natural-language ratio clause.

## Group 6 — Text rendering coverage

**Check 6.1.** If `visual_dna.text_in_image.present` is `true`, every legible string from `text_in_image.strings` appears in double quotes in: `flux_2`, `seedream_4`, `qwen_image`, `ideogram_3`, and `imagen_4` (text strength models). It may or may not appear in `midjourney_v7`, `flux_1`, `nano_banana`, `wan_2_6`, `kling_image`, `grok_imagine`, `z_image`, `adobe_firefly`. Remedy: insert quoted text into the text-strength variants if missing.

**Check 6.2.** If `recreation_difficulty.notes` contains `"small_legible_text"` or `"long_legible_text"`, a note has been added to `recreation_notes` advising the user that text rendering reliability differs across models. Remedy: add the note.

## Group 7 — Stochastic variant quality

**Check 7.1.** Each of the 8 stochastic variants has a `shift_description` that is a specific, actionable statement of the change. "Slightly different lighting" is too vague. "Key rim light rotated from straight-back to back-left 30°, magenta direction shifted accordingly" is specific. Remedy: rewrite the shift_description.

**Check 7.2.** Each stochastic variant's prompt actually contains the language reflecting its shifted axis. If `shifted_axis` is `"lens_change"` and `shift_description` says "swap 50mm to 85mm," the prompt should contain "85mm lens" — not still say "50mm." Remedy: re-render the prompt with the shift applied.

**Check 7.3.** The 8 stochastic variants collectively cover at least 5 of the 8 named axes. If three of the variants are all `lighting_angle` and the other five are all `palette_shift`, the user has lost most of the value of the stochastic set. Distribute the axes for breadth. Remedy: re-assign axes, re-render.

## Group 8 — Final cosmetic

**Check 8.1.** No prompt contains literal markdown syntax (no `**bold**`, no `# headers`, no `>` blockquotes, no `*italic*` outside Qwen-Image's labeled-category structure where the colons serve as separators). T2I models render markdown as literal text. Remedy: strip markdown.

**Check 8.2.** No prompt contains the words "the image shows," "in this scene," "the composition features," "we can see," "this is a [type] of," or other description-of-existing-image phrasings. These are description, not instruction. Remedy: rewrite to forward-looking generation language.

**Check 8.3.** No prompt contains placeholders like `[insert subject here]` or `<SUBJECT>` or `{lighting}`. The renderer must have substituted everything. Remedy: substitute.

**Check 8.4.** No prompt contains the literal Visual DNA enum value (e.g., `"key_direction": "back"`). The Visual DNA is internal; prompts use the natural-language version ("rim light from directly behind"). Remedy: humanize.

## After the protocol passes

The output is ready to emit. If a Python interpreter is available, also run `scripts/validate-output.py` for the programmatic shape check. Then emit the JSON in the order specified in the contract: `visual_dna` first, then `universal_prompts`, then the three variant sets, then `recreation_notes`, then `flagged_for_firefly`. The user expects to see the foundation (Visual DNA) before the specifics, even though the JSON could in principle be in any field order.
