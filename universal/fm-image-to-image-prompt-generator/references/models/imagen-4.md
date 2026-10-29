# Imagen 4 — Google DeepMind

Imagen 4 is Google DeepMind's text-to-image flagship, accessible through Vertex AI's Generative AI API and the Gemini API. The family includes three tiers: Imagen 4 (standard), Imagen 4 Ultra (higher fidelity, slower), and Imagen 4 Fast (faster, slightly lower fidelity). The prompting idiom is identical across the three tiers; the choice is a latency-versus-quality decision made at the API call.

Imagen 4 has the most idiosyncratic structural prompt format in our lineup — the SCULPT framework. SCULPT stands for *Subject, Context, Use, Look, Photographic choices, Technical constraints*, though Google's most recent documentation uses a slightly modified version that adds Lighting as a distinct line and drops Use. The model's T5-XXL text encoder attends to each labeled clause as a separate semantic unit, so a SCULPT-formatted prompt routes information directly to the right attention heads, the same way Qwen-Image's labeled categories do but with a different label vocabulary.

The other distinguishing fact about Imagen 4 is that it has a *separate* `negative_prompt` API field that genuinely works. Unlike Z-Image's silent drop, Flux.2's outright refusal, or the inverted-result risk in Nano Banana, Imagen 4 handles negative prompts cleanly and substantially. The renderer should split negative content out of the positive prompt and route it to the companion field; this is the only model in our lineup where building a substantial negative prompt is consistently worth the effort.

## Canonical structure

Two formats are equally valid and the renderer picks based on the source's complexity. The natural-language paragraph form works for simple sources; the SCULPT framework works better for complex sources with multiple specified elements.

The SCULPT form looks like this:

```
Subject: [main subject, action or state, materials, fine detail]
Context: [setting, background, atmospheric elements, supporting subjects]
Look: [overall aesthetic, medium, style anchor, art movement if applicable]
Photographic choices: [angle, framing, lens, aperture, depth of field, perspective]
Lighting: [direction, hardness, color, hex codes if relevant, mood]
Technical constraints: [aspect ratio, resolution intent, post-processing notes]
```

Each label is followed by a colon and the relevant content on the same logical line. Multiple sentences within one section are fine; the labels are the structural commitment.

The natural-language paragraph form is the same content flowing as one or two paragraphs without labels. For sources where every section would carry similar weight, the paragraph form reads more naturally to humans without losing meaningful Imagen performance.

## Parameters and conventions

Aspect ratio is set via the API's `aspectRatio` parameter. Supported ratios are limited: 1:1, 4:3, 3:4, 16:9, 9:16. **Imagen 4 does not support 2:3, 3:2, 4:5, 5:4, 21:9, or 9:21.** When the Visual DNA's `aspect_ratio` is one of these unsupported values, snap to the nearest supported ratio (2:3 → 3:4, 3:2 → 4:3, 5:4 → 4:3, 21:9 → 16:9, etc.) and add a note to `recreation_notes` indicating the snap.

The renderer should optionally emit `imagen_4_aspect_ratio` and `imagen_4_negative` as companion fields in the per-model object for the user's API call. Both of these go to API parameters, not into the positive prompt string.

In-image text rendering is supported but with hard limits: **maximum 25 characters per quoted phrase, maximum 3 quoted phrases per image**. Phrases must be in quotes. Curved or stylized text paths are not supported reliably; use horizontal baselines. For sources exceeding these limits, route to Ideogram or Qwen-Image in `recreation_notes` while still emitting a serviceable Imagen variant with trimmed text.

Hex codes parse with high fidelity. Imagen 4's color rendering is on par with WAN 2.7 and Flux.2. Pair color words with hex codes when fidelity matters.

The positive prompt should contain no negation language. Route negatives to the `negative_prompt` API field. Common Imagen negative-prompt content: *"blurry, distorted, low quality, watermark, signature, text overlay, extra fingers, deformed hands."*

No weighted parens. No SDXL syntax. No flag syntax. The SCULPT labels are the only structural commitment.

The "Look" section of SCULPT is where named artist references, art-movement references, and render-engine names go. Imagen handles named photographer and artist references well for common Western names (Crewdson, Leibovitz, Avedon, Hopper, Klimt, Rothko) but less reliably for Asian and contemporary commercial names. For uncertain references, use descriptive style language instead.

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Unstructured paragraph that ignores SCULPT and uses 2:3 aspect:
*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black studio void. Hard rim light from behind in vibrant magenta, soft cyan accent fill from camera-right at 45 degrees. Shot on a 50mm lens at f/4, eye-level three-quarter view, razor-thin depth of field on the central fragments. Studio product photography meets concept art with octane-render specular highlights. Portrait 2:3 composition, deep crushed blacks, subtle halation around the brightest magenta highlights."*

This is a fine paragraph but it's a Flux-style brief, not an Imagen-style brief. The 2:3 aspect is also unsupported by Imagen 4.

✅ Imagen-idiomatic SCULPT form with aspect snapped to 3:4:

```
Subject: A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, the silhouette still recognizable in profile.
Context: Featureless matte-black studio void background, no horizon line, no floor plane, controlled deep crushed blacks throughout the frame.
Look: Studio product photography meets concept art, octane-render aesthetic with crisp specular treatment and sharp fragment edges, controlled magenta-and-cyan accent palette.
Photographic choices: Eye-level, slight three-quarter view, 50mm lens at f/4, razor-thin depth of field on the central fragments.
Lighting: Hard magenta #FF1F88 rim light from directly behind, soft cyan #00E0FF accent fill from camera-right at 45 degrees, subtle halation around the brightest magenta specular hits.
Technical constraints: 3:4 portrait aspect ratio (snapped from source's 2:3), no in-image text, no watermarks.
```

With companion fields:
- `imagen_4_aspect_ratio`: `3:4`
- `imagen_4_negative`: `blurry, distorted, low quality, watermark, signature, text overlay, extra fragments outside the silhouette boundary, chromatic aberration on the fragment edges`

And a note in `recreation_notes`: *"Imagen 4 does not support 2:3 aspect; the variant has been adjusted to 3:4. For exact 2:3 output, use Flux.2, Seedream 4, or Midjourney v7."*

## Anti-patterns

Using 2:3 or other unsupported aspect ratios. Imagen 4's `aspectRatio` parameter accepts only 1:1, 4:3, 3:4, 16:9, 9:16. Set the parameter to a supported ratio and note the snap in `recreation_notes`.

Putting negation language in the positive prompt. *"No watermark, no text, no extra fingers"* should move to the `negative_prompt` field. Imagen 4 handles the separate field cleanly; mixing the two produces inconsistent results.

In-image text over 25 characters per phrase or more than 3 quoted phrases per image. Imagen 4 will truncate or omit the excess. Route long-text sources to Ideogram or Qwen-Image.

Curved or stylized text paths. Use horizontal baselines.

SDXL syntax, weighted parens, flag syntax. Same rule as elsewhere.

Long unstructured paragraphs over ~200 words. The SCULPT form has effectively no length limit at the section level, but a single unstructured paragraph that long produces less coherent output than the same content in SCULPT sections.

Specifying samplers, schedulers, or step counts. Imagen 4 has its own internal sampling and does not expose these as user-controllable parameters.

Naming specific fonts. Use descriptive characteristics. Imagen 4 cannot honor named fonts beyond very generic categories.

## Edge cases

For typography-heavy sources, Imagen 4 is competent within the 25-character / 3-phrase limit. Beyond the limit, route to Ideogram or Qwen-Image. Even within the limit, prefer Ideogram for sources where typography is the *primary* visual content.

For sources with unsupported aspect ratios (2:3, 3:2, 4:5, 5:4, 21:9, 9:21), snap to the nearest supported ratio and note in `recreation_notes`. The snap from 2:3 to 3:4 is mild (a 12.5% width-to-height shift) and the visual composition usually transfers cleanly. The snap from 21:9 to 16:9 is more aggressive and may require subject-position adjustment in the prompt.

For complex multi-subject compositions, the SCULPT form scales well. The Subject section can describe multiple subjects with spatial anchoring: *"Subject: On the left, a chrome wolf at the apex of break-apart; on the right, a chrome cathedral undergoing the same transformation; both subjects centered vertically, separated horizontally by 30% of frame width."*

For sources with subtle photographic post-processing (specific film stock emulation, period camera character, particular grade), the Look section is the place to anchor: *"Look: Studio product photography with Kodak Portra 400 color science, mild halation in highlights, subtle grain pattern."*

For commercial brand work requiring exact hex fidelity, Imagen 4 is among the strongest. Pair color words with hex codes throughout the Lighting and Look sections.

For sources requiring multiple specific technical constraints (specific aspect, specific resolution, no text, no watermarks, specific color grade), the Technical constraints section can carry a long list of comma-separated constraints: *"Technical constraints: 16:9 widescreen, 4K resolution intent, no in-image text, no logos, no watermarks, controlled depth of field, no atmospheric haze, crisp microcontrast."*

For workflows where the user is choosing between Imagen 4, Imagen 4 Ultra, and Imagen 4 Fast: Standard is the default for clone work, Ultra is worth the latency for final renders where fidelity matters most, and Fast is for rapid prompt exploration. Note tier recommendations in `recreation_notes` based on the user's needs.

For sources that look like Imagen outputs already (the characteristic Imagen "look" of clean photoreal lighting and slightly idealized geometry), the cloning task is easiest with Imagen itself. The model recognizes its own outputs and reproduces them faithfully.
