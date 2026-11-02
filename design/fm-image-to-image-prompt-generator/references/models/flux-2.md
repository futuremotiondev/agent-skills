# Flux.2

Flux.2 launched in November 2025 and is the most significant prompting upgrade in the family. The text encoder is now a Mistral-3 24B vision-language model, which means Flux.2 understands not only long natural-language prose but also structured JSON input, semantic relationships between named entities, and multi-image references (up to 10 reference images per generation). Most importantly for clone work, Flux.2 has the strongest prompt adherence of any open-weights model as of early 2026, which means it will follow specific instructions about hex codes, lens lengths, and lighting directions more literally than its peers.

The trade-off with this fidelity is that Flux.2 will produce exactly what you ask for, including your mistakes. A vague prompt yields a vague image; an overspecified prompt with contradictory clauses produces a confused image. Flux.2 is the model where prompt discipline pays the most.

## Canonical structure

Two formats are equally valid and the renderer chooses based on whether structured precision is important for the variant. The natural-language paragraph form mirrors Flux.1's style but extends the comfortable length to about 150 words. The JSON object form is recommended whenever the Visual DNA already exists, because it gives consistent results across runs and is trivial to render deterministically from the schema.

The JSON form uses these fields, in roughly this order: `scene`, `subjects`, `style`, `color_palette`, `lighting`, `camera`, `aspect_ratio`, `post`. Additional fields can be added when relevant (`text`, `materials`, `environment`, `mood`). The Mistral-3 encoder is robust to field-name variation, but staying close to these names produces the most consistent results across the user base.

## Parameters and conventions

No parameter-flag syntax in the prompt string. Aspect ratio and other generation parameters are API-level.

Reference images attach via the API's `image_prompts` parameter (or equivalent). Up to 10 references are accepted. For clone work, attach the source image as the first reference. Flux.2 has a measurable improvement in fidelity when the source is provided as a reference image alongside the textual prompt, and this is the single most impactful workflow addition the user can make.

Hex codes parse natively in both formats. In JSON, use a `color_palette` array of hex strings. In prose, write the hex inline with the color word.

Quoted strings render in-image text more reliably than Flux.1. The renderer should put any text from `visual_dna.text_in_image.strings` in double quotes within the prompt.

No negative prompts. The official BFL prompting guide is explicit: Flux.2 does not support negative prompts, neither in a separate field nor through "no X" phrasing. Every constraint must be phrased positively in the main prompt.

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Flux.1 prompt pasted unchanged:
*"A shattered chrome wolf at the moment of explosive break-apart, mirror-polished fragments suspended in air around the silhouette, jet-black void background, hard rim light from behind in vibrant magenta #FF1F88, soft cyan #00E0FF accent glow on the fragment edges, studio product photography meets concept art, 50mm lens at f/4, eye-level three-quarter view, portrait 2:3 composition, deep crushed blacks with subtle halation on the brightest highlights."*

This works, but Flux.2 will produce a measurably better result with the JSON form because the structured fields let the encoder route information directly to the right attention heads.

✅ Flux.2 JSON form:
```json
{
  "scene": "shattered chrome wolf at the apex of explosive break-apart",
  "subjects": [{
    "type": "wolf",
    "material": "mirror-polished chrome with sharp specular highlights",
    "state": "exploding outward into 40+ angular fragments suspended in air",
    "position": "centered, slight front-on three-quarter view"
  }],
  "environment": "featureless matte-black studio void, no horizon line, no floor plane",
  "style": "studio product photography meets concept art, octane-render aesthetic",
  "color_palette": ["#0A0A0A", "#1A1A1A", "#D8D8D8", "#FF1F88", "#00E0FF"],
  "lighting": "hard rim light from directly behind in magenta #FF1F88, soft cyan #00E0FF accent fill from camera-right at 45 degrees",
  "camera": "50mm equivalent lens, f/4, eye-level, razor-thin depth of field on central fragments",
  "aspect_ratio": "2:3",
  "post": "deep crushed blacks, subtle halation around brightest magenta highlights, crisp fragment edges, no film grain"
}
```

✅ Flux.2 natural-language form (alternative when JSON is awkward):
*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette in roughly 40+ angular pieces, centered in a slight front-on three-quarter view against a featureless matte-black studio void with no horizon line or floor plane. Hard rim light from directly behind in vibrant magenta #FF1F88, soft cyan #00E0FF accent fill from camera-right at 45 degrees, the cyan painting reflective highlights along the fragment edges. Studio product photography meets concept art with octane-render-style specular treatment. 50mm lens at f/4, eye-level, razor-thin depth of field on the central fragments. Portrait 2:3 composition. Deep crushed blacks, subtle halation around the brightest magenta hits, no film grain."*

Both forms produce comparable results. The JSON form is preferred when emitting from this skill because the schema-to-JSON mapping is direct and the structure resists drift between runs.

## Anti-patterns

Negative prompts in any form. Not in a separate field, not as "no X" phrasing, not as "without Y." Flux.2 does not support them, and the phrasing wastes attention budget.

Weighted parens or SDXL syntax. Same rule as Flux.1.

Quality-tag stacks. Same rule as Flux.1. The "Ultra HD, 4K, cinematic composition" suffix that helps Qwen-Image actually slightly degrades Flux.2 by adding non-generative noise.

Contradictory descriptors. Flux.2 is so literal that contradictions confuse it badly. "Bright sunny day with deep moody shadows," "minimalist composition with extensive ornamental detail," "soft diffused light with hard edge shadows" — pick one side of each tension and commit. If you need both qualities to coexist, explain *how* they coexist: "soft overall ambient with one hard direct accent from above creating crisp shadow edges on the subject only."

JSON with empty or single-word fields. *"style": "cool"* tells Flux.2 nothing. The JSON form is only as strong as the substance you put in each field.

Prompts beyond ~180 words in prose form, or JSON objects with more than 12 fields. Attention falls off, and the structured fields start to compete with each other.

## Edge cases

Multi-image references. When the user wants to combine elements from multiple sources (e.g., "the wolf from this image but the color palette from this other image"), Flux.2 handles this natively. Recommend in `recreation_notes` that the user attach both sources via the API's `image_prompts` array.

Text rendering. Flux.2 is one of the strongest text-rendering models. Put any text from `visual_dna.text_in_image.strings` in quoted form. For long text (over 30 characters), break into multiple short quoted strings: *"Text reads \"FRAGMENTS\" in bold sans at the top, with \"a film by\" in small sans below."*

Aspect ratio. Flux.2 supports a wide range. Match the Visual DNA's `aspect_ratio` field exactly. Both the JSON's `aspect_ratio` field and the API parameter should be set; agreement between them is the reliable configuration.

Hands. Flux.2 is the best in the family at hand anatomy. For images where hands matter, the explicit-anatomy specification still helps but is less critical than in Flux.1.

Hyperreal vs. stylized. Flux.2 will produce hyperreal output by default unless told otherwise. For stylized sources, anchor the medium in the `style` field explicitly: *"oil painting on canvas with visible brushwork and impasto texture"* rather than *"painterly."* The literal anchor produces a more reliable stylized result.
