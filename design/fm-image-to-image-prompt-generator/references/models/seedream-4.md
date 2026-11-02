# Seedream 4.0 — ByteDance

Seedream 4.0 is ByteDance's text-to-image flagship, accessible through the BytePlus ModelArk API and via WaveSpeed and other inference providers. It's the successor to Seedream 3.0 and arrives with a fundamentally different prompting personality than its predecessor. Where 3.0 rewarded long ornate prompts in the SDXL tradition, 4.0 actively penalizes adjective stacking. ByteDance's official guidance is direct: *"Seedream 4 understands prompts better than 3.0 and rewards precision, not adjective stacking."* Internalize this; it's the rule that distinguishes a working Seedream 4 prompt from one that under-uses the model.

Seedream is bilingual at the encoder level (English and Chinese), and like WAN it slightly favors English on Western subjects and Chinese on Chinese-cultural subjects. The model has unusually strong text rendering — among the top three in the lineup alongside Qwen-Image and Ideogram — and double-quoted strings produce reliable in-image typography in either language.

## Canonical structure

A coherent natural-language sentence built on the pattern: *subject + action + environment + style + lighting + camera*. The whole thing is usually 35 to 80 words. Where a Flux.2 prompt might be 100 to 150 words with carefully-layered specification, a Seedream 4 prompt of the same image is more compact and the specifications are leaner.

Subject and action come first. *"A shattered chrome wolf bursting apart into mirror-polished fragments suspended midair."*

Environment second, as a short clause. *"Featureless matte-black studio void background."*

Style third, named compactly. *"Studio product photography meets concept art."*

Lighting fourth, with direction and color but minimal adjective burden. *"Hard magenta rim light from behind, soft cyan accent fill from camera-right."*

Camera fifth. *"50mm lens, f/4, eye-level three-quarter view, 2:3 portrait composition."*

Optional sixth clause for in-image text or post-processing, only when relevant. *"Deep blacks, controlled magenta and cyan accents."*

The full sentence reads as one continuous brief. Avoid breaking into multiple sentences unless the content genuinely justifies it. Seedream's encoder attends most cleanly to a single coherent thought.

## Parameters and conventions

The aspect ratio goes inline as natural language (*"2:3 portrait composition"*) and is also set via the API's `size` parameter. The two should agree.

Hex codes parse, but Seedream weights *named* colors slightly higher than hex codes. For maximum fidelity, pair the color word with the hex: *"magenta #FF1F88."* For lower-effort prompts, the color word alone is fine and the result will be reasonable.

Quoted strings render in-image text reliably. Seedream 4 supports both English and Chinese typography rendering at high fidelity. The quotes are mandatory for accurate rendering; unquoted text gets paraphrased or omitted. Example: *"The headline \"FRAGMENTS\" appears in the upper-left in bold condensed all-caps sans-serif, magenta on black."*

No weighted parens. No SDXL syntax. No quality-tag stacks. Seedream 4 trained on cleaner prompts than earlier diffusion models and treats these artifacts as noise.

Negative prompts work via a separate API parameter. The positive prompt should be clean of negation language. Route any "no X" content to the negative field via a companion field in the per-model object.

For image editing (the i2i variant of Seedream), prompts read as instructions to a specific change: *"Keep the wolf silhouette and lighting identical; replace the cyan accent with a red-orange #FF6B35 accent."* Clone work is mostly text-to-image, but note the editing idiom in `recreation_notes` when the user might want to refine an output.

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Adjective-stacked SDXL-style:
*"A breathtakingly stunning, magnificently shattered, mirror-polished, hyper-detailed chrome wolf with intricately fragmented pieces, dramatically suspended in midair, set against a beautifully dark, moody, atmospheric matte-black void background, with cinematically dramatic, vibrantly intense magenta rim lighting and gorgeously soft cyan accent illumination, photorealistically rendered in stunning 4K ultra HD detail."*

This is what Seedream 4 specifically penalizes. The encoder finds "chrome wolf" and "matte-black void" and treats the modifier chains as low-priority padding. Worse, the modifier chain crowds out attention that could have gone to specific lens and lighting setup data. The output is a generic chrome wolf, less specific than the disciplined version would have produced.

✅ Seedream 4-idiomatic:
*"A shattered chrome wolf bursting apart into mirror-polished fragments suspended midair, set against a featureless matte-black studio void. Studio product photography meets concept art. Hard magenta #FF1F88 rim light from behind, soft cyan #00E0FF accent fill from camera-right. 50mm lens, f/4, eye-level three-quarter view, 2:3 portrait composition. Deep crushed blacks, controlled magenta and cyan accents."*

Fifty-three words. Every word carries generative weight. The encoder gets clean signal on subject, environment, style, lighting (with both color words and hex codes), camera, aspect, and post in compact clauses.

## Anti-patterns

Adjective stacking. The most consequential anti-pattern for this model. If you find yourself writing three or more consecutive adjectives without a noun between them, trim.

Vague pronouns. *"Make it nicer,"* *"give it more energy,"* *"that thing should pop."* Seedream parses these as low-signal noise. Specify what "nicer" means in concrete visual terms.

Cramming multiple edits into one instruction. Seedream's image-editing mode handles one edit per prompt best. *"Make the wolf chrome and the background red and add fog and shift the lighting to warm"* often produces only partial application. Break into sequential edits.

Tag-list phrasing. *"chrome, wolf, shattered, fragments, magenta, cyan, octane"* under-uses the model. Restructure into a coherent sentence.

Quality words and resolution claims. *"Ultra HD,"* *"4K,"* *"hyperrealistic,"* *"masterpiece"* — Seedream 4 does not respond to these the way WAN or Qwen-Image does. Drop them. The Seedream output quality is determined by the API's resolution parameter, not by claims in the prompt.

Long prose paragraphs (over ~120 words). Seedream's attention drops off faster than Flux.2's. Beyond about 100 words, later content competes destructively with earlier content.

## Edge cases

For typography-heavy sources, Seedream 4 is one of the best performers. Always use double quotes around literal text, specify font character ("bold condensed sans," "elegant serif," "handwritten script"), and place the text in the composition explicitly ("in the upper-left," "centered at the top"). Seedream 4 renders text more accurately than Midjourney v7, Flux.1, Nano Banana, WAN, and Grok Imagine.

For Chinese-cultural subjects, prompt in Chinese when the user is comfortable. The improvement is noticeable on subjects like traditional Chinese painting, calligraphy, regional architecture, and hanfu costume. Note Chinese-prompt availability in `recreation_notes` when relevant.

For commercial brand work requiring exact hex fidelity, Seedream 4 is solid but slightly behind WAN 2.7 and Imagen 4. Pair color words with hex codes and verify the output. For high-stakes commercial use, recommend WAN 2.7 in `recreation_notes`.

For sources with extreme detail density (architectural ornament, fractal patterns, fine micropattern fabric), Seedream 4 handles them better than Flux.1 or Grok but slightly behind Flux.2 and Imagen 4. The disciplined prompt structure helps; over-modified prompts make this case noticeably worse.

For multi-turn workflows where the user wants to iterate on an output, Seedream's image-editing mode is competent and follows the *"keep X, change Y"* idiom cleanly. Note this in `recreation_notes` when the user is likely to refine.

For aspect ratios outside the common 1:1, 2:3, 3:2, 16:9, 9:16, Seedream supports a wide range via the `size` parameter, but extreme ratios like 21:9 sometimes produce softer composition. Stick to the snap-to ratios in the Visual DNA schema when possible.
