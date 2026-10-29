# Qwen-Image / Qwen-Image-2.0 / Qwen-Image-2512 — Alibaba

Qwen-Image is Alibaba's text-to-image flagship from the Qwen family, with the most recent generally-available checkpoint being Qwen-Image-2.0 (sometimes named Qwen-Image-2512 in some inference providers' catalogs). The model is accessible through DashScope, WaveSpeed, and other inference partners. Qwen-Image has the most distinctive prompting personality in our entire lineup, and treating it the same way you treat Seedream or WAN will leave most of its capability on the table.

Two facts about Qwen-Image drive everything in this reference. First, the model was explicitly designed and benchmarked for *long, structured, labeled prompts*. Alibaba's evaluation papers showed roughly a thirty-percent quality improvement when the prompt was organized into labeled categories (Subject:, Environment:, Lighting:, etc.) versus the same content in unstructured prose. No other model in our lineup shows that magnitude of structured-prompt benefit. Second, Qwen-Image is the strongest typography-rendering model in our lineup, especially for Chinese characters but also for English. Alibaba's benchmarks show English in-image text accuracy jumping from roughly sixty-five percent to ninety-six percent when the literal text is wrapped in double quotes in the prompt. That's the difference between unreadable scribbles and legible typography.

The renderer's job is to take advantage of both properties: structure the prompt into labeled categories, quote any literal text, and append the magic suffix Alibaba documents as a quality multiplier.

## Canonical structure

A multi-line labeled-category block, with each category on its own line, followed by the magic suffix. The categories are: Subject, Environment, Lighting, Camera, Style, and optionally Post or Text-in-Image when those are relevant.

```
Subject: [subject description, action or state, materials, fine detail]
Environment: [background, setting, atmospheric elements]
Lighting: [direction, hardness, color, hex codes, key/fill/rim balance]
Camera: [angle, framing, lens, aperture, depth of field]
Style: [medium, aesthetic anchor, render engine if applicable]
Post: [grain, halation, vignette, color grade — only when relevant]
, Ultra HD, 4K, cinematic composition.
```

The magic suffix `, Ultra HD, 4K, cinematic composition.` appears at the very end as a single concatenated tail. The Chinese equivalent `, 超清，4K，电影级构图.` works identically when prompting in Chinese. The suffix has internalized meaning in Qwen-Image's training and produces a measurable quality lift on virtually every clone.

Length is not a constraint the way it is in Aurora or Seedream. Qwen-Image accepts up to about 1,000 tokens and rewards verbosity. A 300-word labeled-category block produces a better result than a 100-word version of the same content. Lean into the specification budget; this is the one model where over-specifying actively helps.

## Parameters and conventions

Aspect ratio is set via the API's `size` parameter. Qwen-Image supports a wide range of sizes including up to 2048×2048. Include aspect in natural language inside the Camera or Post category as a soft anchor (e.g., *"2:3 portrait composition"*), and set the API size to match.

Hex codes parse with high fidelity. Qwen-Image weights both color words and hex codes correctly, and pairing them produces the most reliable color output: *"magenta #FF1F88."*

Quoted strings are mandatory for in-image text. Double-quoted English strings produce ~96% accuracy. Chinese characters in 双引号 (double quotes) work identically. For multi-line text, put each line in its own quoted string and specify placement: *"The headline \"FRAGMENTS\" appears in the upper-left in bold condensed all-caps sans-serif, magenta #FF1F88 on black. Below it, in smaller font, \"a film by\" appears in lowercase serif."*

The magic suffix is mandatory. Always append `, Ultra HD, 4K, cinematic composition.` to English prompts and `, 超清，4K，电影级构图.` to Chinese prompts. The suffix is one phrase, not a tag list, and the comma at the start matters — it separates the suffix from the preceding category.

The recommended CFG (classifier-free guidance) is around 4.5 and the recommended step count is around 50. These are API parameters set by the user; the renderer does not include them in the prompt. Note the recommended configuration in `recreation_notes` for users who haven't run Qwen before.

Negative prompts work via a separate API parameter and Qwen-Image actually respects them better than most modern models. Common negative-prompt content: *"blurry, distorted, low quality, watermark, signature, extra fingers, deformed hands."* For the skill's output, the renderer should optionally emit `qwen_image_negative` as a companion field when negation is warranted.

No weighted parens. The labeled-category structure is the emphasis mechanism — putting something in its own labeled line gives it more weight than restating it.

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Short Seedream-style prompt:
*"A shattered chrome wolf bursting apart into mirror-polished fragments suspended midair, set against a matte-black studio void. Studio product photography meets concept art. Hard magenta rim light from behind, soft cyan accent fill from camera-right. 50mm lens, f/4, eye-level three-quarter view, 2:3 portrait composition."*

This is fifty-three words and works in Seedream perfectly. In Qwen-Image, it under-uses the model. The unstructured prose loses the thirty-percent quality lift the labeled-category structure provides, and the missing magic suffix loses another measurable quality increment.

✅ Qwen-Image-idiomatic with labeled categories and magic suffix:
```
Subject: A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette in roughly 40+ angular pieces, each fragment showing crisp specular highlights and subtle reflections of the magenta and cyan environment lighting.
Environment: Featureless matte-black studio void background, no horizon line, no floor plane, deep crushed blacks throughout.
Lighting: Hard rim light from directly behind the subject in vibrant magenta #FF1F88, soft cyan #00E0FF accent fill from camera-right at 45 degrees, controlled spill, subtle halation around the brightest magenta specular hits.
Camera: Eye-level, slight three-quarter view, 50mm lens at f/4, razor-thin depth of field on the central fragments, 2:3 portrait composition.
Style: Studio product photography meets concept art, octane-render aesthetic with crisp specular treatment and sharp fragment edges.
Post: Deep crushed blacks, no film grain, no chromatic aberration, sharp focus on central elements.
, Ultra HD, 4K, cinematic composition.
```

About 175 words. Every category does load-bearing work. The Subject category has the detail Qwen rewards; the Lighting category has both color words and hex codes; the Style category names a specific aesthetic anchor; the magic suffix closes the prompt. This produces measurably better output than the Seedream version pasted into the same model.

## Anti-patterns

Skipping the magic suffix. The single most common mistake. The suffix is a quality multiplier that costs almost nothing to include and adds a measurable lift.

Unquoted text. *"The headline FRAGMENTS appears..."* drops text accuracy from ~96% to ~65%. Always use double quotes.

Short prompts under 60 words. Qwen-Image is the one model in our lineup where conciseness is a *detriment*. Use the full specification budget.

Conflating Subject and Environment. Each label is a separate attention bucket. Pushing environment content into the Subject line under-uses the structure. *"Subject: A chrome wolf in a dark void"* is wrong; the void belongs in Environment.

Naming specific fonts. Qwen-Image can render text accurately but cannot honor named font requests beyond descriptive characteristics. Use *"bold condensed sans-serif"* not *"Helvetica Neue Bold Condensed."*

SDXL syntax, weighted parens, parameter flags. Same rule as elsewhere.

Mixing English and Chinese in one prompt without intent. If the source is Chinese-cultural, write the whole prompt in Chinese including the magic suffix. If the source is Western, write the whole prompt in English. Code-switching produces inconsistent results.

## Edge cases

For text-heavy sources, Qwen-Image is the strongest choice in our lineup, slightly ahead of Ideogram on Chinese text and roughly equivalent on English text. Always use double quotes, specify font character, and place the text in the composition explicitly. For typography-critical sources, route the user to Qwen-Image first in `recreation_notes`.

For Chinese-cultural sources, prompt in Chinese. Qwen-Image's Chinese-prompt performance on Chinese-cultural subjects is the best in the lineup, and the improvement over an English prompt is substantial — roughly 25 to 40 percent on subjective fidelity tests for subjects like traditional Chinese painting, calligraphy, regional architecture, and hanfu costume.

For commercial brand work, Qwen-Image's hex color fidelity is on par with WAN 2.7 and Imagen 4. Pair color words with hex codes in the Lighting and Post categories.

For multi-subject compositions, the labeled-category structure scales well. Put each subject's description in the Subject category with explicit spatial anchoring: *"Subject: On the left, a chrome wolf at the apex of break-apart; on the right, a chrome cathedral undergoing the same transformation. Both subjects centered vertically, separated horizontally by 30% of frame width."*

For extreme aspect ratios like 21:9 or 9:21, Qwen-Image supports them but produces slightly softer composition than at common ratios. The labeled-category structure helps maintain composition discipline. Note any aspect concerns in `recreation_notes`.

For workflows requiring strict reproducibility, Qwen-Image is more deterministic than most diffusion models at the same CFG and step count. Locking the prompt text plus a seed reproduces outputs more reliably than in Flux or Midjourney.

For the rare case where the user wants a *short* Qwen-Image prompt, the labeled-category structure can be compressed to two or three lines while preserving the labels and the magic suffix. Even the compressed form outperforms unstructured prose of the same length.
