# WAN 2.x — Alibaba Tongyi Wanxiang

WAN, sometimes stylized "Wan" or "万相" in Chinese contexts, is Alibaba's text-to-image and video generation family from the Tongyi Wanxiang (通义万相) lab. The currently generally-available text-to-image checkpoint is `wan2.6-t2i`, accessible through Alibaba Cloud Model Studio. WAN 2.7 was announced in April 2026, adding a "Thinking Mode" that lets the model plan composition before rendering and improving brand-accurate color rendering. The prompting idiom is identical between 2.6 and 2.7, so this reference covers both.

WAN is bilingual at the encoder level. Chinese-language prompts often produce slightly better results on Chinese-cultural subjects (traditional architecture, calligraphy, regional cuisines, classical paintings); English prompts produce slightly better results on Western-cultural subjects (American urban environments, European film aesthetics, contemporary fashion). For most clone work the source determines the bias, and the renderer should default to English unless the Visual DNA indicates a Chinese-cultural source. Note this only in `recreation_notes` when it's relevant.

The model also exposes a `prompt_extend=True` API parameter that runs a short user prompt through an internal Qwen language model to expand it before generation. For clone work this should be set to `False` and we should provide the fully-engineered prompt directly. Letting `prompt_extend` rewrite your carefully-built prompt is a recipe for losing the specific hex codes and lens specifications you put in.

## Canonical structure

`[Subject Description] [Scene Description] [Aesthetic Control] [Style Suffix]`. Full sentences, not labeled categories. The four sections flow as one paragraph but each carries a specific job.

The Subject Description is one sentence naming the subject, its action or state, and its material if relevant. *"A shattered chrome wolf at the moment of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette."*

The Scene Description is one sentence placing the subject in an environment. *"Featureless matte-black studio void with no horizon line and no floor plane."*

The Aesthetic Control is one or two sentences covering lighting, camera, and color. *"Hard rim light from directly behind in magenta #FF1F88, soft cyan #00E0FF accent fill from camera-right at 45 degrees; eye-level three-quarter view, 50mm lens at f/4, shallow depth of field with razor-thin focus on the central fragments."*

The Style Suffix is one short clause naming the medium, aspect, and resolution intent. *"Studio product photography meets concept art, 2:3 portrait composition, Ultra HD, 4K."*

The four sections concatenate without explicit labels. WAN's encoder is trained on this implicit structure and parses it correctly even without delimiters between sections.

## Parameters and conventions

The aspect ratio goes in the prompt as natural language and also in the API's `size` parameter. WAN 2.6 supports sizes up to 2048×2048 with various ratios. Snap to the nearest supported size matching the Visual DNA's `aspect_ratio`: for 2:3, use 1024×1536 or 1344×2048; for 16:9, use 1920×1088; for 1:1, use 1024×1024 or 2048×2048.

Hex codes parse reliably. WAN 2.7 specifically improved brand-accurate hex rendering, so pairs of color words and hex codes (*"magenta #FF1F88"*) produce more faithful colors than color words alone.

Quoted strings for in-image text. WAN handles bilingual text reasonably; both English in double quotes and Chinese in 双引号 work. For text-heavy sources, WAN is competent but slightly behind Qwen-Image, Seedream, and Ideogram.

The `Ultra HD, 4K` suffix in the Style Suffix section is a magic phrase WAN has internalized as a quality cue. Always include it for clone work. The Chinese equivalent `超清，4K` works identically when prompting in Chinese.

No weighted parens. WAN treats them as literal text. To emphasize a feature, restate it once with more specific descriptive treatment.

Negative prompts work via a separate `negative_prompt` API parameter. The positive prompt should not contain "no X" phrasing; route negatives to the API field. For the skill's output JSON, the renderer should optionally emit a `wan_2_6_negative` companion field in the per-model object when negatives are warranted (e.g., "blurry, distorted, low quality"). Most clone prompts do not need a negative prompt because the positive prompt is already well-specified.

WAN 2.7's Thinking Mode is activated via the API parameter `thinking_mode=True`. When active, the model plans composition before rendering, producing measurably better results for complex multi-subject compositions. For clone work involving busy or layered sources, recommend the user enable Thinking Mode in `recreation_notes`.

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Universal natural-language version pasted without structure:
*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair, set against a matte-black void with hard magenta rim light from behind and cyan accent from camera-right, 50mm lens at f/4, eye level, portrait composition."*

This works in WAN, but it under-uses the model's structural training. The Aesthetic Control and Scene Description blur together, and the Style Suffix is absent.

✅ WAN-idiomatic with the implicit four-section structure:
*"A shattered chrome wolf at the moment of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette in roughly 40+ angular pieces. Featureless matte-black studio void background with no horizon line or floor plane. Hard rim light from directly behind in magenta #FF1F88, soft cyan #00E0FF accent fill from camera-right at 45 degrees; eye-level three-quarter view, 50mm lens at f/4, razor-thin depth of field on the central fragments; deep crushed blacks with subtle halation around the brightest magenta highlights. Studio product photography meets concept art, 2:3 portrait composition, Ultra HD, 4K."*

The four sections are present and ordered. The hex codes are paired with color words. The magic suffix is appended. This produces a noticeably more faithful clone than the unstructured version.

## Anti-patterns

Skipping the Style Suffix. The `Ultra HD, 4K` cue is a quality multiplier in WAN. Omitting it produces softer, less-detailed output.

Letting `prompt_extend=True` rewrite the prompt. Always set this parameter to False for clone work. The internal Qwen expansion will replace specific hex codes with vague color words and replace specific lens specs with generic photographic vocabulary.

Mixing languages in one prompt aggressively. Light borrowing of a Chinese cultural term ("a wabi-sabi tea ceremony, 茶道") works. Switching back and forth between English and Chinese sentences produces inconsistent results. Pick one primary language.

Over-relying on negative prompts. WAN's negative prompt support exists but works best for broad-stroke exclusions ("blurry, low quality, distorted faces"), not fine-grained ones ("no extra fingers on the left hand"). For fine-grained constraints, phrase positively in the main prompt.

Setting `size` to non-supported dimensions. WAN's API will return an error for unsupported sizes. Stick to the published size list for `wan2.6-t2i`.

Using SDXL or Midjourney syntax. Same rule as elsewhere — parameter flags, weighted parens, and bracketed emphasis all parse as literal text.

## Edge cases

For Chinese-cultural subjects, prompt in Chinese when the user is comfortable doing so. The improvement is real but modest, on the order of 10 to 20 percent on subjective fidelity tests. Note in `recreation_notes` that a Chinese-language prompt is available on request when the source has Chinese cultural content (traditional Chinese painting, hanfu, Chinese architecture, etc.).

For text-heavy sources, use quoted strings and accept moderate fidelity. Route the user to Qwen-Image, Seedream, or Ideogram for the strongest text rendering via `recreation_notes`.

For sources requiring brand-accurate color (corporate logos, packaging design, branded product photography), use WAN 2.7 with hex codes rather than WAN 2.6. WAN 2.7's color rendering is measurably more faithful, and the difference matters for commercial color fidelity. Note the recommendation in `recreation_notes` when the Visual DNA contains specific brand colors.

For multi-subject compositions (more than three subjects with spatial relationships), enable WAN 2.7's Thinking Mode in the API. The composition-planning step substantially improves spatial coherence. The skill's emitted prompt is the same either way; the user enables Thinking Mode at the API level.

When the source is a screenshot of a Midjourney grid or other AI-generated reference, treat the *generated content* as the source and ignore the UI chrome around it. WAN does not need to know the image came from another model.
