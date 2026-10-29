---
name: fm-i2i-clone-prompt-generator
description: Generates clone, sibling, and stochastic-variant text-to-image prompts from a reference image, tuned for 13 popular T2I models. Use whenever the user uploads or references an image and wants to recreate, clone, mimic, replicate, riff on, reverse-engineer, or generate variations of it. Triggers include "create a prompt to clone this image", "create a prompt that will generate this image", "recreate this image,", "clone this image", "make this in Midjourney", "make this in firefly", "make this in adobe firefly", "give me a firefly prompt to recreate this image", "give me prompts for this", "variations of this image", "convert image to prompt", "convert this image to prompts", "what prompt would make this", "what prompt would generate this image", "image to prompt", "same style different subject", "I2I", "image-to-image", or any mention of prompts for Midjourney, Flux, Nano Banana, Gemini Image, Seedream, Ideogram, Imagen, Firefly, Qwen-Image, Z-Image, Grok Imagine, WAN, or Kling. Outputs structured JSON with 5 clone prompts, 6 stylistic siblings (same aesthetic, different subject), 8 stochastic variants (named-axis nudges), 3-5 universal/portable prompts, and per-model tuned variants. Always prefer this skill over describing the image when generation prompts are the goal.
---

# Image-to-Image Clone Prompt Generator

## The one rule

**Prompts are instructions, not descriptions.** This is the cardinal rule of this skill, and almost every failure mode flows from breaking it. A description tells a human what the image *is*; an instruction tells a text-to-image model what to *generate*. The two are subtly different grammatical objects, and they cannot be used interchangeably.

Wrong (description): *"This is a photograph of a chrome sphere on a black background, lit dramatically with magenta highlights."*

Right (instruction, written in Midjourney v7 idiom): *"polished chrome sphere centered on matte black void, hard rim light from camera-left, magenta accent highlights, studio product photography --ar 1:1 --s 250"*

The description is true and useless. The instruction reproduces the image. The whole skill exists to keep Claude on the right side of that line.

There is a second related failure mode: re-describing the image inside the prompt as if narrating it. Phrasings like *"the image shows…"*, *"in this scene we can see…"*, or *"the composition features…"* are pure description and waste the prompt's token budget on metadata the target model neither needs nor will use correctly. Every word in an emitted prompt must contribute generative information.

## When to use this skill

Activate this skill whenever the user attaches an image (or references one already in context) and the goal is to produce prompts that recreate it, vary it, or riff on it. Common signals:

The user says "recreate this," "give me a prompt for this," "make this in [model name]," "image to prompt," "reverse the prompt," "I want variations of this," or names a target model alongside an image. The user uploads an image with no question — assume they want clone prompts and confirm only if the context is genuinely ambiguous. The user is iterating on a prior generation and wants to push it in a stylistic direction while keeping a reference's structure.

Do not activate when the user wants pure image description for accessibility, alt text, content moderation, or visual question-answering. Those are description tasks; this skill does the opposite job.

## Workflow

The full pipeline runs in four stages. Do them in order. Do not skip stages even when the user seems impatient; the schema-first approach is what makes the per-model rendering reliable.

**Stage 1 — Extract Visual DNA.** Read `references/visual-dna-schema.md` and fill the schema as a single JSON object based on the input image. The Visual DNA is the only place in the workflow where description is permitted, because it lives inside the system and never reaches the user. Prefer hex codes, focal lengths, f-stops, and Kelvin temperatures over adjectives wherever you can — numbers survive translation between model idioms, adjectives do not.

**Stage 2 — Render the universal/portable prompts.** Read `references/universal-portable.md`. Produce 3 to 5 model-agnostic natural-language prompts using the Visual DNA. These are the prompts the user can paste into anything new (a model that did not exist when this skill was written) and get a reasonable result.

**Stage 3 — Render the 19 core variants × 13 models.** This is where the bulk of the work happens. Produce:
  - 5 verbatim-style clone prompts (intent-identical, phrasing-varied attempts at the same image)
  - 6 stylistic-sibling prompts (same recipe, different subject in the `sibling_axis` slot identified in Visual DNA)
  - 8 near-identical stochastic variants (one named axis nudged per variant; the axes are listed in `references/output-contract.md`)

For each of those 19 variants, render one prompt per target model by consulting the matching `references/models/<model>.md` file. **You do not need to load all 13 model files at once.** If the user requested only Midjourney and Flux, load only those two files. If the user did not specify, load all 13.

**Stage 4 — Self-check, IP-clean, and validate.** Read `references/self-check-protocol.md` and run the checklist against your output. Pay particular attention to the Adobe Firefly path, which has IP-cleaning requirements documented separately in `references/firefly-ip-cleaning.md`. If the input image contains any identifiable real person, artist signature style, branded character, trademark logo, or otherwise IP-sensitive content, run the IP cleaner before emitting the Firefly variants and set `flagged_for_firefly: true` in the output.

## Reference file routing table

This is the navigation guide. Load files on demand, not preemptively.

`references/visual-dna-schema.md` — Load first, every time. Defines the JSON structure that the rest of the pipeline reads.

`references/output-contract.md` — Load when you are about to emit the final JSON, to verify the exact shape. The contract specifies field names, types, counts, and ordering.

`references/universal-portable.md` — Load during Stage 2.

`references/models/<model>.md` — Load during Stage 3, **only** for the models the user asked for (or all 13 if unspecified). Each file is self-contained: canonical structure, parameter syntax, worked before/after example, anti-patterns, edge cases.

`references/taxonomy-controlled-vocab.md` — Load when the Visual DNA extraction needs to settle on a value for `style.medium`, `lighting.mood`, `materials.surface`, or similar enumerated fields and you want the canonical synonym list. Most extractions do not need this file; load it only when the image is genuinely difficult to classify.

`references/firefly-ip-cleaning.md` — Load whenever the Visual DNA contains an artist reference, photographer reference, named real person, branded character, or trademark logo. The file is the substitution lookup.

`references/examples-good-vs-bad.md` — Load when you are uncertain whether a prompt you have drafted is instruction-style or description-style. The file is 40+ paired before/after examples organized by source-image genre.

`references/self-check-protocol.md` — Load at Stage 4, every time. The protocol is the validation checklist that catches the most common failure modes before they reach the user.

`scripts/validate-output.py` — Run after emitting the JSON if a Python interpreter is available. The script validates the structure against the contract and reports any schema violations.

`assets/example-visual-dna.json` — A complete worked example. Reference it if you need a concrete anchor for what a high-quality extraction looks like.

## The 13 target models, at a glance

This is not the prompt template — that lives in each model's reference file. This is the one-line idiom summary so you can pick the right file and remember each model's flavor at a glance.

**Midjourney v7** — Short image-language phrases, parameter flags trailing (`--ar`, `--s`, `--c`, `--sref`, `--oref`, `--no`). Image-language compression rewarded over full sentences. Open `references/models/midjourney-v7.md`.

**Flux.1** — Natural-language paragraph, 30–80 words, subject-first, no weight syntax, no reliable negative prompts. Open `references/models/flux-1.md`.

**Flux.2** — Either the same paragraph style as Flux.1 *or* a structured JSON object with named fields. Mistral-3 24B text encoder. No negative prompts. Open `references/models/flux-2.md`.

**Nano Banana / Gemini 2.5 Flash Image** — Conversational descriptive paragraph in photographic terminology. Google's rule: "describe the scene, don't just list keywords." Open `references/models/nano-banana.md`.

**WAN 2.x (Alibaba)** — `[Subject] [Scene] [Aesthetic] [Style]`, full sentences, bilingual English/Chinese, accepts hex codes. Open `references/models/wan-2x.md`.

**Seedream 4.0 (ByteDance)** — Coherent natural-language sentence: `subject + action + environment + style + lighting + camera`. Concise beats ornate. Double-quoted strings for in-image text. Open `references/models/seedream-4.md`.

**Kling Image** — Same idiom as Seedream, with implied-motion clause when the image is dynamic. Treats stills as potential video first frames. Often `null` for pure abstract or static product images. Open `references/models/kling-image.md`.

**Grok Imagine / Aurora (xAI)** — Short descriptive paragraph (1–3 sentences). Autoregressive, attends to early tokens. No seeds, no negative prompts. Open `references/models/grok-imagine.md`.

**Qwen-Image 2.0** — Long, detailed, structured prompt with labeled categories (Subject / Environment / Lighting / Camera / Style). Double-quoted strings for in-image text. Append the magic suffix `, Ultra HD, 4K, cinematic composition.` Open `references/models/qwen-image.md`.

**Z-Image / Z-Image-Turbo** — Detailed natural-language with `guidance_scale = 0.0`. **Zero negation language allowed.** Every constraint must be phrased positively. Open `references/models/z-image.md`.

**Ideogram 3.0** — Natural sentences with explicit order: image summary → subject (with any quoted text) → pose → setting → lighting → framing → technical. Typography-strong. Open `references/models/ideogram-3.md`.

**Imagen 4 (Google DeepMind)** — Either natural paragraph or SCULPT framework (`Subject: … Context: … Look: … Photographic choices: … Lighting: … Technical constraints: …`). Negative prompts go in a separate field, not the positive string. Open `references/models/imagen-4.md`.

**Adobe Firefly (Image Model 4 / 5 Ultra)** — Plain natural language, no flag syntax, no negative wording, ≥3 words, IP-clean. Commercially-safe, trained on licensed data. Open `references/models/adobe-firefly.md`. **Always also run the IP cleaner in `references/firefly-ip-cleaning.md` for this path.**

## Output: where to read the contract

The final output is a single JSON object. Its exact shape — field names, ordering, nullable fields, the eight named stochastic-variant axes, the model-key vocabulary — is specified in `references/output-contract.md`. Read that file before emitting the final response. The validation script in `scripts/validate-output.py` enforces the same contract programmatically; run it whenever a Python interpreter is available.

## When the user asks for a subset

Common subset requests and how to handle them:

*"Just give me Midjourney prompts"* — Skip the per-model rendering for the other 12 models and emit only `midjourney_v7` in each variant's `per_model` object, leaving the other keys as `null`. Still produce all 19 variants (5 clone + 6 sibling + 8 stochastic) and the universal/portable set unless the user also restricted variant count.

*"Show me the Visual DNA only"* — Run Stage 1, emit just the `visual_dna` field of the contract, and stop. Do not render prompts.

*"Just clone prompts, skip variants"* — Emit only the 5 verbatim clones across all 13 models (or the subset the user named), and the 3–5 universal/portable prompts. Set `stylistic_siblings` and `stochastic_variants` to empty arrays.

*"More variations, fewer clones"* — Honor the user's requested counts. If they ask for 20 stochastic variants, produce 20 by cycling the named axes and combining axes for the later variants (e.g., `lighting_angle + palette_shift`).

## Failure modes to watch for

Before emitting, verify that none of these have crept in. The self-check protocol catches all of them, but knowing them up front prevents the rework.

The Midjourney string contains no `--ar` parameter. Always emit `--ar` matching the Visual DNA's `aspect_ratio`. Without it, Midjourney defaults to 1:1 and the result is unintentionally cropped.

The Flux.2 string exceeds ~150 words. Later tokens lose attention weight; trim aggressively to the most generative phrases.

The Z-Image string contains "no", "without", "avoid", "free of", or any negation. Run the positivity rewrite from `references/models/z-image.md` before emitting.

The Firefly string contains an artist name, celebrity name, branded character, or trademark logo. Run the IP cleaner, then re-emit.

The Imagen 4 prompt contains "no X" inside the positive string instead of using the separate `negative_prompt` field. Move the negation to the right field.

The Qwen-Image prompt is missing the magic suffix `, Ultra HD, 4K, cinematic composition.` Append it.

The sibling subjects are too similar to each other or to the original. If the source is "chrome wolf," the six siblings should be six clearly different subjects (cathedral, motorcycle, eagle, tree, mask, dancer — not wolf, fox, dog, hound, jackal, coyote). Diversity along the subject axis is what makes the sibling set useful.

The stochastic variants are not labeled with their `shifted_axis`. Every stochastic variant must declare which one of the eight axes is being nudged, so the user can decide which axis to explore further.

## A note on the source image

You will receive the image as an attachment in the conversation. Examine it directly — do not ask the user to describe it back to you. Your vision capability is the foundation of the whole workflow; if it cannot see the image clearly enough to extract the Visual DNA, say so explicitly and ask for a higher-resolution attachment rather than guessing.

If the image arrived via a URL the user pasted, fetch it through the appropriate tool. If the image is a screenshot of a generation interface (Midjourney's grid, Stable Diffusion's UI), extract the Visual DNA from the *generated image content*, not from the UI chrome around it.
