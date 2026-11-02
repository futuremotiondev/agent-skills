# Midjourney v7

Midjourney v7 went default on June 17, 2025, and it represents a meaningful shift from earlier versions. Where v5 wanted shotgun keyword stacks and v6 accepted both keyword and natural-language styles, v7 has moved firmly toward image-language: short, evocative phrases written like a photographer's brief, with the heavy lifting done by parameter flags rather than by literary prose. Long descriptive paragraphs still work, but they actually produce *worse* results than tight image-language because v7's attention model dilutes signal across long token sequences.

This is the single most idiosyncratic model in the lineup. Treat its template as orthogonal to the natural-language family; do not transfer prose-style habits from Flux or Nano Banana into Midjourney without removing them first.

## Canonical structure

```
<short subject phrase>, <medium/style cues>, <lighting>, <composition keywords> --ar <ratio> --s <0-1000> --c <0-100> [--sref <url|code>] [--oref <url> --ow <0-1000>] [--no <suppression list>]
```

The prose portion is comma-separated phrases, not sentences. No articles ("the," "an," "a") unless they buy disambiguation. No verbs unless the action is the subject. Imagine you are writing a film slate: terse, declarative, every word loaded.

The parameter portion follows the prose with no comma between. Parameters are space-separated. The values for `--ar`, `--s`, and `--c` are numbers without units (so `--ar 2:3`, not `--ar 2:3 portrait`; `--s 250`, not `--s 250stylize`).

## Parameters and conventions

The `--ar` flag sets aspect ratio. Match the Visual DNA's `aspect_ratio` field exactly. Common values: `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`. Without `--ar`, v7 defaults to 1:1, which usually crops the source's composition.

The `--s` (stylize) flag runs 0 to 1000, default 100. Lower values produce tighter prompt fidelity at the cost of "Midjourney aesthetic." Higher values lean into the model's house style. For clone work, **lower is better**: use `--s 100` or `--s 150` as the baseline. Use `--s 250–400` for the universal/portable feel if the source is already very Midjourney-ish. Avoid `--s 500+` for clone work; the output drifts.

The `--c` (chaos) flag runs 0 to 100, default 0. Higher values produce more variation across the four-image grid v7 returns. For clone work, keep `--c` low (`--c 0` to `--c 15`) so the variations stay close to the target. For the stochastic-variant set in the output, `--c 25` to `--c 40` is reasonable since the goal there is intentional variation.

The `--sref` flag accepts either an image URL or a numeric "style reference code" from the Midjourney community library. For clone work, **encourage the user to attach the source image as `--sref`** in their actual Midjourney session. The prompt itself can include `--sref <source_url>` if the user has hosted the source somewhere, or leave it for the user to add manually. Include a note in `recreation_notes` advising users to add `--sref` when running the prompt.

The `--oref` (Omni Reference) plus `--ow` flag is v7's replacement for the older `--cref`. Use it when the source contains a specific subject that should be preserved across variations — a face, a creature, a product. `--ow` runs 0–1000; higher values lock the reference more tightly. Use `--ow 400–600` for moderate fidelity, `--ow 800+` for tight subject lock.

The `--no` flag is a soft suppression, not a true negative prompt. Use it sparingly. Good `--no` values: `text watermark logo signature`. Bad `--no` values: `blurry low quality bad anatomy`. The first set targets unwanted visual elements; the second is SD1.5 muscle memory and produces no measurable improvement.

The `--niji` flag activates the anime-tuned mode. Use only when `visual_dna.style.medium` is `anime` or `illustration` with an anime aesthetic. Do not combine `--niji` with `--style raw` or photographic prompts.

The `--style raw` flag reduces v7's automatic aesthetic processing. Useful for photoreal sources where you want the prompt's specifications to dominate over Midjourney's house style. For most clone work involving photoreal sources, **add `--style raw`**.

The `--weird` flag is locked off in v7 and should not be used.

## Worked before and after

Source: shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended in air, matte black void, magenta rim light from behind, cyan accent from camera-right, 2:3 portrait.

❌ Universal natural-language version pasted directly:
*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black studio void. Hard rim light from behind in vibrant magenta, soft cyan accent fill from camera-right, 50mm lens at f/4, eye-level three-quarter view, studio product photography meets concept art."*

This will produce a decent Midjourney result, but it under-uses the model. Too many words, no parameters, no `--ar`, no `--s` tuning.

✅ Midjourney v7-idiomatic:
*"shattered chrome wolf, mid-explosion fragments suspended in air, mirror polished surface, matte black void background, hard rim light from behind in magenta, cyan accent fill from camera-right, octane render, studio product photography --ar 2:3 --s 200 --c 10 --style raw --no text watermark"*

Differences worth noting: no articles, no "the," no "a." Compressed clauses. Parameters trailing in a single flag block. `--style raw` because the source is photoreal/3D and we want the prompt's specifications to dominate. `--s 200` is a moderate stylize that respects the source without going flat. `--c 10` provides minor in-grid variation across the four returned images.

## Anti-patterns

Long descriptive sentences. v7 attends best to the first 60–80 tokens. After that, signal decays. If your prompt is over ~25 words of prose before the parameters, compress it.

SDXL weighted parens. Constructions like `(chrome:1.4)` parse as literal text in v7. Drop them.

Quality-word stacks. "masterpiece, best quality, 8k, ultra detailed, trending on artstation" actively degrades v7 output. v7 has internalized "good" as the default; the explicit prompt should focus on the *specific* qualities you want, not generic quality words.

Putting `--no` to work on hand anatomy. "no extra fingers, no bad hands, no distortion" produces no measurable improvement in v7's hand rendering. The model is bad at hands regardless; use `--oref` of a reference hand image, or render at higher `--s` and accept that some grids will have hand issues.

Naming specific fonts in text prompts. v7 cannot honor named font requests. Use descriptive font characteristics: "bold condensed sans-serif," "ornate art deco lettering," "handwritten script."

Mixing `--niji` with photographic prompts. The aesthetic modes are exclusive. Pick one.

Setting `--ar` to non-standard ratios. v7 supports a wide range of ratios, but extremes like `1:5` or `5:1` produce unstable results. Stick to the snap-to ratios in the schema.

## Edge cases

When `visual_dna.text_in_image.present` is true and the source contains 25+ characters of legible text, add a note to `recreation_notes`: *"Midjourney v7 may render long text strings unreliably; consider Ideogram, Qwen-Image, Seedream, or Imagen for the text-heavy variants."* Still emit the Midjourney variant — the user may want the comparison — but advise the alternative.

When `visual_dna.recreation_difficulty.notes` contains `"contains_real_person"`, the v7 prompt can name the person (Midjourney will produce a likeness, with varying accuracy). Add a note to `recreation_notes` flagging that likeness accuracy varies and the user may need `--oref` of a reference photo to lock the face.

When `visual_dna.style.medium` is `graphic_design` with heavy typography, the v7 variant will be the weakest in the output set. Render it anyway for completeness, but route the user's expectations to Ideogram and Qwen-Image in `recreation_notes`.

When the Visual DNA's aspect ratio is `21:9` or `9:21` (ultrawide or ultratall), v7 supports these but produces best results with `--s` in the lower range (`--s 100` or so) to keep the composition disciplined.

When the source is an existing AI-generated image with characteristic AI tells (uncanny hands, smeared microdetail, surface-only physics), the cloning task is easier rather than harder. Lean on `--style raw` and `--oref <source_url>` heavily; the model recognizes its own outputs and reproduces them faithfully.
