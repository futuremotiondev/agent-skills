# Z-Image / Z-Image-Turbo — Tongyi-MAI

Z-Image is a text-to-image model from Alibaba's Tongyi-MAI project, released in late 2025. The standard checkpoint is Z-Image; the speed-optimized variant is Z-Image-Turbo. Both are accessible through Hugging Face's `Tongyi-MAI` organization and through partner inference providers. Z-Image has one architectural property that distinguishes it from every other text-to-image model in our lineup, and that property is the single most important fact to internalize before prompting it.

Z-Image runs with `guidance_scale = 0.0`. In a normal diffusion model, classifier-free guidance pushes the output simultaneously toward the positive prompt and away from the negative prompt, with the guidance scale controlling how strongly that pull happens. When guidance is zero, both directions collapse to zero weight, and the negative prompt has *no effect at all*. Z-Image was deliberately designed this way because guidance-zero training produces faster inference and more natural-looking outputs without the over-saturated, over-contrasted look that high-guidance diffusion can produce.

The consequence for prompting is total: every constraint Z-Image needs to honor must be expressed positively in the main prompt. There is no negative-prompt field to fall back on. *"No extra fingers"* does nothing. *"Without text overlays"* does nothing. *"Avoid distortion"* does nothing. Every "no X" must be rewritten as a positive "with X" or "five clearly delineated X" or "natural undistorted X." The self-check protocol explicitly searches for negation language in the Z-Image variant before emitting it, and you should run that check before this reference's templates are considered correct.

The model is bilingual (English and Chinese) like the other Alibaba models. Z-Image also exposes an optional Prompt Enhancer — `huggingface.co/spaces/Tongyi-MAI/Z-Image-Turbo/blob/main/pe.py` — that runs a short prompt through an internal reasoning model to expand it. For clone work, prefer providing the fully-engineered prompt directly rather than relying on the enhancer.

## Canonical structure

A detailed natural-language description, 40 to 120 words, in a single flowing paragraph or two compact paragraphs. Like Qwen-Image, Z-Image rewards verbosity, but unlike Qwen-Image, Z-Image does not benefit from labeled-category structure — flowing prose performs as well or better than labeled blocks. The discipline is positivity: every clause is a positive constraint.

The structure follows the universal-prompt order: subject and action first, environment second, lighting third (with hex codes when fidelity matters), camera fourth, style fifth, post-processing last. Aspect ratio is set via the API parameter and named inline in natural-language form.

Where Z-Image differs from other natural-language models is in how constraints are phrased. Instead of *"no halation,"* write *"clean specular highlights with matte falloff."* Instead of *"without blurriness,"* write *"sharp focus throughout, crisp fragment edges."* Instead of *"no text or watermarks,"* write *"clean composition with no overlay elements"* — but even better, just don't mention overlay elements at all and trust the model not to add them, since the absence of mention is itself a positive constraint.

## Parameters and conventions

Aspect ratio is set via the API's `width` and `height` parameters. Z-Image-Turbo supports common ratios at standard resolutions. Include aspect in natural language inside the prompt as a soft anchor: *"2:3 portrait composition."*

Hex codes parse reliably and Z-Image weights them on par with color words. Pairing them produces the most consistent output: *"magenta #FF1F88."*

Quoted strings render in-image text. Z-Image's text rendering is competent but not best-in-class — slightly behind Qwen-Image and Ideogram, roughly equivalent to Seedream 4 and Imagen 4 in our lineup. Use double quotes.

**No negative prompts.** Negative-prompt API fields are silently dropped. Negation language in the positive prompt is parsed but inverted with low reliability. The only safe practice is to phrase everything positively.

No weighted parens. No SDXL syntax. No quality-tag stacks.

For Z-Image-Turbo specifically, inference is faster (4–8 steps) at the cost of some quality. The clone prompt is identical between Z-Image and Z-Image-Turbo; the choice is at the API call. Note the recommendation in `recreation_notes` based on the user's latency-vs-quality preference.

## The positive-rephrasing toolkit

This is the most important practical section in the reference. When the Visual DNA or the natural-language draft contains a negative constraint, use these positive rephrasings. The general rule is: state the positive condition that produces the absence of the negative.

*"No extra fingers"* becomes *"five clearly delineated fingers per hand, natural undistorted hand anatomy."*

*"No text"* becomes *"clean composition with no overlay graphics"* — or, more commonly, just don't mention text at all and trust the default.

*"No watermark"* becomes *"clean image with no overlay elements"* — or just drop.

*"No distortion"* becomes *"natural undistorted proportions, accurate anatomy."*

*"No blurriness"* becomes *"sharp focus, crisp edges."*

*"No halation"* becomes *"clean specular highlights with matte falloff."*

*"No film grain"* becomes *"smooth tonal gradients, digital sensor cleanliness."*

*"Without people in the background"* becomes *"empty background environment, no human figures."* The "no" here is acceptable because Z-Image parses simple subject-presence constraints reliably; what it cannot parse is graded or attribute-level negation.

*"Avoid jpeg artifacts"* becomes *"clean uncompressed visual quality, smooth color gradients."*

*"Not photorealistic"* becomes naming the medium directly: *"hand-drawn illustration"* or *"oil painting on canvas."*

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Universal prompt with negation language pasted unchanged:
*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair, set against a matte-black studio void with no horizon and no floor plane. Hard magenta rim light from behind, soft cyan accent fill from camera-right. 50mm lens at f/4, sharp focus, no blurriness, no halation, no film grain, no extra fragments beyond the silhouette boundary, clean fragment edges with no chromatic aberration. Studio product photography meets concept art."*

Six instances of "no" in one prompt. Z-Image silently drops every one of them. The output is closer to the result you'd get without those clauses, but worse, the model wastes attention budget parsing the clauses that have no effect.

✅ Z-Image-idiomatic with positive rephrasing:
*"A shattered chrome wolf at the apex of explosive break-apart, the silhouette still recognizable as a wolf in profile, mirror-polished fragments suspended midair around the dissolving form in roughly 40+ angular pieces. Featureless matte-black studio void background, deep crushed blacks throughout, empty surrounding space. Hard rim light from directly behind in vibrant magenta #FF1F88, soft cyan #00E0FF accent fill from camera-right. 50mm lens at f/4, eye-level three-quarter view, razor-thin depth of field on the central fragments, sharp focus with crisp fragment edges, clean specular highlights with matte falloff. Studio product photography meets concept art. 2:3 portrait composition. Smooth tonal gradients."*

Every constraint is positive. *"No horizon and no floor plane"* becomes *"empty surrounding space."* *"No blurriness"* becomes *"sharp focus with crisp fragment edges."* *"No halation"* becomes *"clean specular highlights with matte falloff."* *"No film grain"* becomes *"smooth tonal gradients."*

## Anti-patterns

Negation language anywhere in the prompt. The single most important rule. Search for "no", "not", "without", "avoid", "free of", "lacking", "absent" before emitting. Even one instance is a failure because Z-Image silently drops the clause and wastes the attention budget.

Relying on the negative-prompt API field. It exists but is silently ignored. Do not write to it.

Short prompts under 40 words. Z-Image, like Qwen-Image, rewards detail. Under-specifying produces softer, less-detailed output.

Quality-tag stacks. *"Masterpiece, best quality, 4K, hyperrealistic"* do not improve Z-Image. Drop.

SDXL syntax, weighted parens, parameter flags. Same rule as elsewhere.

Treating Z-Image like Flux.2. The natural-language style is similar but the negative-prompt rules are categorically different. Habits from Flux.2 prompting (like dropping "no" phrases into the prompt confidently because Flux.2 just ignores them) produce subtly worse outputs in Z-Image because the dropped clauses still consume attention.

Using the Prompt Enhancer on already-engineered prompts. The enhancer replaces specific hex codes with vague color words and replaces specific lens specs with generic photographic vocabulary. For clone work, provide the engineered prompt directly and skip the enhancer.

## Edge cases

For text-heavy sources, Z-Image is moderate. Use quoted strings and accept ~70-80% text accuracy. For typography-critical sources, route to Qwen-Image or Ideogram in `recreation_notes`.

For Chinese-cultural sources, prompt in Chinese. Z-Image's Chinese-prompt performance is strong, comparable to Qwen-Image on most Chinese-cultural subjects.

For sources requiring fine control of unwanted elements (e.g., a portrait where the user wants no jewelry, no eyeglasses, no makeup), Z-Image cannot honor these constraints through negation. The only workaround is to specify the desired positive state explicitly: *"clean unadorned face, no facial accessories, smooth bare skin."* Even then, the "no" inside "no facial accessories" is technically a negation, but in this specific case Z-Image parses simple presence constraints somewhat reliably. The more robust phrasing is: *"clean unadorned face, smooth bare skin"* — letting the absence be implied by the positive description.

For sources with complex hand anatomy, Z-Image is moderate. The positivity rule forces explicit anatomy specification: *"both hands visible, five clearly delineated fingers each, natural undistorted proportions, hands held at chest height."* This level of specification helps every model but is mandatory for Z-Image.

For the Z-Image-Edit variant (the image-to-image refinement model in the Z-Image family), prompts read as positive change instructions: *"Keep the wolf silhouette and lighting identical; transform the cyan accent fill into a red-orange #FF6B35 accent fill, preserve all other elements."* Note this idiom in `recreation_notes` when the user is likely to iterate.

For workflows where the user has Z-Image-Turbo for fast iteration and Z-Image-base for final renders, the same prompt works in both. Recommend Turbo for rapid prompt exploration and Z-Image-base for final outputs in `recreation_notes`.
