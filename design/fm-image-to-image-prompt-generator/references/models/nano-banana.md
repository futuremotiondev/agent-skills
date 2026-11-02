# Nano Banana / Gemini 2.5 Flash Image

Nano Banana is Google's text-to-image and image-editing model, released in 2025 as part of the Gemini family and marketed under the codename "Nano Banana" because of its earliest leaked checkpoints. The underlying model is Gemini 2.5 Flash Image. As of late 2025, Google also offers Nano Banana Pro (powered by Gemini 3 Pro Image), which adds 4K output, real-time web grounding, and broader aspect-ratio support including 21:9. For clone work, the standard Nano Banana model is sufficient and is what this reference targets unless a user explicitly asks for the Pro variant.

The single most important fact about Nano Banana is that it was trained heavily on multi-turn image editing conversations. The model has internalized a conversational register — it responds best to prompts that read like an art-direction note from a creative director to an illustrator, not like a keyword-tagged stock-photo annotation. Google's prompting guide is explicit on this point: *"Describe the scene, don't just list keywords."* Treat that line as the cardinal rule for this model.

## Canonical structure

A descriptive paragraph in photographic terminology, typically three to five sentences. Each sentence does a different job in the brief. The structure is loose enough that you don't have to follow the order rigidly, but the *roles* should all be present.

The first sentence introduces the shot type and subject, e.g. *"A photorealistic medium close-up of [subject], [action or state], set in [environment]."* The shot type is a real photographic term — extreme close-up, medium close-up, medium shot, medium wide, wide shot, establishing shot — not a flag.

The second sentence describes the lighting, e.g. *"The scene is illuminated by [light source description], creating [mood or quality]."* This is where you specify direction, hardness, color, and time-of-day if relevant.

The third sentence covers the camera and lens, e.g. *"Shot on a [focal length] lens at [aperture], [angle and framing]."* Nano Banana parses photographic vocabulary literally and will adjust depth of field, perspective compression, and angle accordingly.

The fourth sentence, when present, handles color and post-processing, e.g. *"Color palette emphasizes [hex codes or color descriptors], with [grade or post note]."* This is also where you put any in-image text instruction.

The fifth sentence, when present, names the medium or style anchor, e.g. *"Studio product photography aesthetic"* or *"Hand-drawn editorial illustration in [stylistic register]."*

## Parameters and conventions

No parameter-flag syntax. All control lives in the prose.

Aspect ratio is preserved automatically from any attached reference image, which is a major workflow advantage for clone work. The user attaches the source image to the Nano Banana session, and the model defaults to the source's aspect without needing to be told. Include an aspect specification in the prompt only when you want to *change* the aspect away from the source's native ratio. If the user is generating from text alone with no reference image attached, do specify the aspect in natural language — for example, *"vertical 9:16 mobile format"* or *"widescreen 16:9 cinematic crop."*

Photographic vocabulary parses literally. Phrases like *"50mm lens at f/4,"* *"three-quarter view at eye level,"* *"shallow depth of field with razor-thin focus on the foreground,"* and *"35mm film grain with subtle halation"* all map to specific visual choices in the output. Lean on this.

Hex codes parse, but with weaker fidelity than Flux.2 or Qwen-Image. When a specific hex color matters, mention it in two ways — by name and by code — so the model has redundancy: *"vibrant magenta accent (#FF1F88)."*

Quoted strings render in-image text. Nano Banana is among the more reliable text-rendering models, second only to Ideogram and Qwen-Image. Use double quotes around any literal text from `visual_dna.text_in_image.strings`.

Negative prompts are not supported. Phrase every constraint positively in the prose. *"Crisp clean fragment edges with no halation drift"* becomes *"crisp fragment edges with sharp specular highlights."* The model ignores or sometimes inverts "no X" phrasing.

Conversational follow-up is the model's native idiom. For workflows where the user iterates ("now make the lighting warmer," "shift the camera angle lower"), Nano Banana handles these multi-turn edits natively. The clone prompts the skill emits are first-turn prompts, but users may follow up in Nano Banana directly. Note this in `recreation_notes` when it's relevant.

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Keyword-stack approach pasted from Stable Diffusion habit:
*"chrome wolf, shattered, fragments, octane render, magenta lighting, cyan accent, dramatic, cinematic, portrait, dark background, photorealistic"*

This produces a Nano Banana result of varying quality. The model can extract a recognizable image from the keywords, but it under-uses the conversational register the model was trained for, and the output is noticeably less specific than what the model is capable of producing.

✅ Nano Banana-idiomatic:
*"A photorealistic medium shot of a shattered chrome wolf at the apex of an explosive break-apart, with mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black studio void. The scene is illuminated by a hard rim light from directly behind in vibrant magenta and a soft cyan accent fill from camera-right, creating a tense, cinematic atmosphere with deep crushed blacks and crisp specular highlights. Shot on an 85mm lens at f/4 at eye level, with razor-thin depth of field on the central fragments. The color palette is dominated by jet-black and mirror-silver with the magenta rim and cyan accent as the only saturated notes. Studio product photography aesthetic with octane-render-style fragment treatment."*

The difference is not subtle. The conversational version gives Nano Banana the kind of brief it was trained to follow, and the result reflects the model's full capability.

## Anti-patterns

Bare keyword lists. Even when each individual word is a strong signal, the comma-separated tag-stack format under-uses Nano Banana's natural-language strength. If you find yourself writing four or more consecutive comma-separated noun phrases without verbs or articles, restructure into prose.

SDXL or Midjourney parameter flags. *"--ar 2:3"* parses as literal text in Nano Banana, contaminating the output. The `:` and `--` characters are not magic; they're just punctuation.

Weighted parens like `(chrome:1.4)`. Same rule. These read as literal text.

Mentioning Stable Diffusion samplers, schedulers, or step counts in the prompt. These belong to other models' API parameters and have no meaning in Nano Banana.

Negation phrasing in the positive prompt. "No text," "without watermarks," "avoid blurriness." Rewrite positively or drop. Nano Banana sometimes inverts these phrases and produces exactly what you said you didn't want.

Over-long paragraphs (over ~180 words). Nano Banana's attention is robust but not infinite. Beyond about 180 words, later content competes with earlier content. Most clone prompts should be 60 to 140 words.

Prompts written in third-person past tense ("the image was photographed by," "the scene was lit"). Nano Banana wants present-tense or atemporal language ("photographed with," "lit by"). Past tense reads as description of an existing artifact rather than instruction for a new one.

## Edge cases

When the user is generating without a reference image attached, always include the aspect ratio in natural language. Without either an attached source or explicit aspect language, Nano Banana defaults to roughly 1:1, which usually crops the intended composition.

When the source contains a specific real person, Nano Banana will sometimes produce a likeness and sometimes refuse, depending on how the person is named or described. Use descriptive identification ("a stadium musician with weathered features mid-performance") rather than naming the person directly. Add a note to `recreation_notes` if likeness fidelity matters.

When the source contains heavy in-image text, Nano Banana is competent but not best-in-class. For typography-heavy sources, route the user's expectations toward Ideogram, Qwen-Image, and Imagen via `recreation_notes`, while still emitting a serviceable Nano Banana variant with quoted text.

When the user has Nano Banana Pro access (Gemini 3 Pro Image), aspect ratios extend to 21:9 ultrawide and 9:21 ultratall, output goes to 4K, and the model can pull current information through web grounding (useful for generating images that reference recent events or people, though the cloning task rarely needs this). Note Pro availability in `recreation_notes` only when the Visual DNA's aspect ratio is one of the wider formats Pro adds, or when the source contains a culturally-current reference that benefits from grounded knowledge.

For multi-turn editing workflows, the first-turn prompt should be a complete clone brief. Subsequent turns can be short directives like *"now shift the rim light to back-left 30°"* or *"warm the overall color temperature by 500K"*. Note in `recreation_notes` that Nano Banana is well-suited for this iterative refinement style, in case the user wants to push the output further after the first generation.
