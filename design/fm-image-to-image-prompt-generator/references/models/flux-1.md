# Flux.1

Flux.1 from Black Forest Labs ships in three variants — `[pro]`, `[dev]`, and `[schnell]` — but they share the same prompting idiom. Flux.1 was the first major T2I model to credibly handle long natural-language instructions rather than CLIP-style tag soup. It uses a T5-XXL text encoder alongside CLIP-L, and T5 is trained on prose. The practical implication is that Flux.1 rewards prose and punishes keyword stacks. Writing a Flux.1 prompt is closer to writing a sentence to a thoughtful designer than tagging a stock photo.

The trade-off compared to Flux.2 is that Flux.1 has a smaller text encoder (the larger one is in Flux.2), so it benefits from being slightly more compact. Aim for 30 to 80 words, with the most generative content front-loaded.

## Canonical structure

A single natural-language paragraph. Comma-separated clauses are fine but each clause should be a meaningful unit of art direction. Subject first, environment second, lighting third, camera fourth, style fifth, post-processing sixth, aspect last (as natural-language phrase, not a flag).

The paragraph reads like a creative brief. Imagine you have hired a photographer or a 3D artist for one shot and you have one paragraph to tell them what to make.

## Parameters and conventions

Flux.1 has no parameter-flag syntax in the prompt string. Aspect ratio, steps, guidance scale, and seed are API parameters, not prompt text.

The aspect ratio goes inside the prompt as natural language: *"portrait composition, 2:3 aspect"* or *"square format"* or *"widescreen 16:9 cinematic crop."* Even though the API also takes a numeric aspect, including the phrase in the prompt helps the model commit to the composition.

Hex codes parse cleanly. Write `#FF1F88` inline and Flux.1 will interpret it correctly when paired with a color word: *"vibrant magenta #FF1F88."* Do not write hex codes without the accompanying color word; raw hex with no context sometimes gets read as part of a serial number rather than a color.

Quoted strings render as in-image text but less reliably than Flux.2, Ideogram, or Qwen-Image. Reserve text rendering for short strings (under 15 characters) and accept some failure rate.

No weight syntax. Parens like `(chrome:1.4)` are SDXL conventions and parse as literal text in Flux. The way to emphasize something in Flux is to mention it more prominently — put it earlier in the prompt, give it more specific descriptive treatment, or restate it once with more detail.

No reliable negative prompts. The `[dev]` variant accepts a `negative_prompt` API field but Flux's reliance on it is weak. Phrase constraints positively in the main prompt. "Sharp focus, clean edges, no halation" — keep the "sharp focus, clean edges" part, drop "no halation," or restate as "matte highlights with no glow spread."

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ SDXL-flavored tag stack:
*"(chrome wolf:1.4), shattered, fragments, octane render, masterpiece, best quality, 8k, ultra detailed, trending on artstation, cinematic lighting, dramatic, magenta and cyan lighting, portrait"*

Flux's T5 encoder reads this and gets confused. The weighted parens become literal text. The quality tags add noise. The hex-less color words are vague.

✅ Flux.1-idiomatic:
*"A shattered chrome wolf at the moment of explosive break-apart, mirror-polished fragments suspended in air around the silhouette, jet-black void background, hard rim light from behind in vibrant magenta #FF1F88, soft cyan #00E0FF accent glow on the fragment edges, studio product photography meets concept art, 50mm lens at f/4, eye-level three-quarter view, portrait 2:3 composition, deep crushed blacks with subtle halation on the brightest highlights."*

Sixty-eight words. Subject first, environment second, lighting third (with hex codes), style fourth, camera fifth, aspect sixth, post-processing last. Every word generative.

## Anti-patterns

Weighted parens, square-bracket emphasis, double-colon weights from Stable Diffusion 1.5 and SDXL. Drop entirely.

Quality-tag stacks ("masterpiece, best quality, 8k, ultra detailed, hyperrealistic"). These actively degrade Flux output by competing with the substantive content for attention budget.

Mentioning the sampler, scheduler, step count, or guidance scale in the prompt text. These are API parameters, not prompt content. Including them produces no generative effect and wastes tokens.

Long paragraphs exceeding ~120 words. Flux.1's attention falls off past about 100 tokens (~75 words). Beyond that, later content competes with earlier content for limited attention budget and the result is less coherent than a shorter prompt would have been.

Generic style references like "trending on artstation." Drop. These are SDXL-era and parse as either literal noise or low-signal stylistic anchors that produce homogenized output.

Pronouns referring to the image. "It has a shattered wolf. It is rendered in chrome." Flux parses this as awkward grammar that reduces coherence. Write directly: "A shattered chrome wolf."

## Edge cases

Text rendering. When `visual_dna.text_in_image.present` is true and the string is under 15 characters, include it in double quotes near the front of the prompt: *"A vintage poster with the title \"FRAGMENTS\" in bold sans-serif at the top..."*. For longer text, note in `recreation_notes` that Flux.1 may render the text unreliably and recommend Flux.2 (better) or Ideogram/Qwen-Image (best) instead.

Multiple subjects. Flux.1 handles two or three subjects with explicit positional anchoring: *"on the left, a chrome wolf; on the right, a chrome cathedral."* More than three subjects gets mushy. Note in `recreation_notes` and consider trimming subjects to the most important ones.

Aspect ratio in API vs prompt. Include the aspect in the natural-language form (*"portrait 2:3"*) and trust the user to also set the API parameter. The combination is more reliable than either alone.

Hands and feet. Flux.1 is the best of the early-2025 cohort on hand anatomy but still fails sometimes. For images where hands are central, add explicit anatomy specification: *"both hands visible, five clearly delineated fingers each, natural undistorted hand anatomy."*

Photoreal vs stylized. Flux.1 handles photoreal sources by default. For stylized sources (illustration, anime, oil painting), explicitly anchor the medium: *"hand-drawn anime illustration in Makoto Shinkai feature-film style"* or *"oil painting on canvas with visible brushwork."* Without the anchor, Flux.1 drifts toward photoreal.
