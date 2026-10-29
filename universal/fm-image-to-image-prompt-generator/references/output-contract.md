# Output Contract

This is the exact JSON shape the skill emits. Read this file before producing the final response. The validator script in `scripts/validate-output.py` enforces this contract programmatically.

The contract has six top-level fields, in this order: `visual_dna`, `universal_prompts`, `clone_prompts`, `stylistic_siblings`, `stochastic_variants`, `recreation_notes`, and `flagged_for_firefly`. Emit them in that order so the user sees the structure progressing from foundation to specifics.

## Top-level shape

```ts
type Output = {
  visual_dna: VisualDNA;                          // The full schema from references/visual-dna-schema.md
  universal_prompts: string[];                    // 3 to 5 model-agnostic portable prompts
  clone_prompts: { variants: CloneVariant[] };    // exactly 5
  stylistic_siblings: { variants: SiblingVariant[] };    // exactly 6
  stochastic_variants: { variants: StochasticVariant[] }; // exactly 8
  recreation_notes: string[];                     // Free-form notes about per-model caveats
  flagged_for_firefly: boolean;                   // True if any IP cleaning occurred
};
```

## The three variant shapes

All three variant types share a common skeleton. They differ only in their identifier fields and what each variant's `natural_language` should contain.

```ts
type CommonVariantFields = {
  natural_language: string;             // The model-agnostic natural-language version.
                                        // Renderers may use this as a fallback when
                                        // their model-specific template fails.
  per_model: PerModelMap;               // Per-target-model rendered strings.
  rationale: string;                    // One sentence explaining what this variant achieves.
};

type CloneVariant = CommonVariantFields & {
  index: 1 | 2 | 3 | 4 | 5;             // Position in the clone set.
};

type SiblingVariant = CommonVariantFields & {
  index: 1 | 2 | 3 | 4 | 5 | 6;         // Position in the sibling set.
  sibling_subject: string;              // The swapped subject for this sibling, e.g. "cathedral".
};

type StochasticVariant = CommonVariantFields & {
  index: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8; // Position in the stochastic set.
  shifted_axis: StochasticAxis;         // Which of the eight named axes is nudged.
  shift_description: string;            // One short sentence describing the specific nudge,
                                        // e.g. "key light rotated to camera-right 45°".
};

type StochasticAxis =
  | "framing_nudge"          // Crop a hair tighter/wider or shift focal point.
  | "lighting_angle"         // Rotate the key light position.
  | "palette_shift"          // Replace one accent hex with an analogous color.
  | "fragment_density"       // Increase or decrease structural detail/element count.
  | "lens_change"            // Swap lens_mm by ±20-50mm.
  | "depth_of_field"         // Open or close aperture by 2-3 stops.
  | "color_temperature"      // Shift Kelvin by ±1500K.
  | "negative_space";        // Increase or decrease negative_space_pct by 15-25%.
                             // Note: "perspective" was an early candidate, dropped in favor of
                             // lens_change which has more reliable per-model support.
```

## The PerModelMap

This is the per-model rendered output for every variant. Thirteen keys, all required (use `null` only for Kling when the source image is genuinely incompatible with motion framing).

```ts
type PerModelMap = {
  midjourney_v7: string;                // Full prompt including parameters: "subject ... --ar 2:3 --s 250"
  flux_1: string;                       // Natural-language paragraph, 30-80 words.
  flux_2: string;                       // EITHER natural-language paragraph OR JSON object as a string.
                                        // If JSON, the string must be valid JSON when parsed.
  nano_banana: string;                  // Conversational descriptive paragraph.
  wan_2_6: string;                      // [Subject] [Scene] [Aesthetic] [Style] structure.
  seedream_4: string;                   // subject + action + environment + style + lighting + camera.
  kling_image: string | null;           // Same as seedream_4 plus implied-motion clause.
                                        // Null when source is pure static abstract/product.
  grok_imagine: string;                 // 1-3 sentence descriptive paragraph.
  qwen_image: string;                   // Multi-line labeled categories + magic suffix.
  z_image: string;                      // Detailed natural-language, ZERO negation language.
  ideogram_3: string;                   // Image summary → subject → pose → setting → lighting →
                                        // framing → technical. Modes: Realistic / Design / General.
  imagen_4: string;                     // EITHER natural paragraph OR SCULPT framework block.
                                        // Separately, the renderer may emit `imagen_4_negative`
                                        // and `imagen_4_aspect_ratio` for the API parameters.
  adobe_firefly: string;                // Plain natural language, IP-clean, ≥3 words.
};
```

When a user has requested a subset of models (e.g., "just Midjourney and Flux"), the keys for unrequested models should be `null` rather than omitted. This keeps the JSON shape consistent for downstream consumers and makes it obvious which models were intentionally skipped.

## The `visual_dna` field

This is the full Visual DNA object exactly as specified in `references/visual-dna-schema.md`. Emit it in full, even when the user did not ask for it; it is the most useful piece of debug context and lets advanced users hand-edit the recipe and re-prompt.

## The `universal_prompts` field

Three to five strings. Each is a self-contained natural-language prompt that any modern T2I model will parse reasonably. These prompts:

Avoid all parameter-flag syntax (no `--ar`, no `::`).

Avoid model-specific magic phrases (no Qwen's "Ultra HD, 4K, cinematic composition" suffix, no Midjourney's "in the style of" namedropping).

Include the aspect ratio as natural language ("portrait composition" or "16:9 widescreen") rather than a flag.

Are between 40 and 90 words.

Read like art-direction notes from a creative director to a junior designer — confident, specific, no hedging.

## The `recreation_notes` field

Free-form string array. Use this to flag per-model caveats the user should know about before pasting prompts. Common entries:

- `"Source contains 38 characters of legible text; Midjourney v7 may render this unreadably. Prefer Ideogram, Qwen-Image, Seedream, or Imagen for the text-heavy variants."`
- `"Kling Image variants are null because the source is a static product shot with no implied motion."`
- `"Source image strongly resembles work by [artist]. Firefly variants have substituted descriptive style language for legal safety; Midjourney and Flux retain the artist reference."`
- `"Aspect ratio 9:21 is not supported by Imagen 4 (max 16:9 or 9:16); the Imagen variant has been adjusted to 9:16."`

Keep notes short and actionable. The user should be able to skim them in 30 seconds.

## The `flagged_for_firefly` field

Boolean. Set to `true` when the IP cleaner ran and made any substitution to the Firefly path. Set to `false` when the source image required no cleaning. The presence of this flag drives the UI's "Flagged for Firefly" banner in the eventual Next.js app.

## Variant counts are firm

The contract specifies exactly 5 clone variants, exactly 6 sibling variants, and exactly 8 stochastic variants. Do not emit 4 or 7 because you "ran out of meaningful variation." If you struggle to find a 5th distinct clone phrasing, lean harder on word-order changes and structural reshuffling — the goal is five different *attempts* at the same image, not five visually different outputs. If you struggle to find a 6th sibling subject, broaden the candidate noun pool (industrial → organic → architectural → mythological → biological).

The only exception: if the user explicitly requests a different count ("give me 10 stochastic variants"), honor the request and emit exactly that many.

## Universal prompt count

3 to 5 universal prompts. Pick the count based on the image's complexity. A simple, focused image (single subject, clean background, one lighting setup) gets 3 universals — there are not that many genuinely different ways to phrase the same brief. A complex image with multiple subjects, layered post-processing, and a distinctive style gets 5 universals so each one can foreground a different aspect (subject-first, lighting-first, style-first, etc.).

## Worked example

A minimal valid output object, with most of the per-model strings collapsed to ellipsis for readability:

```json
{
  "visual_dna": { /* full Visual DNA object */ },
  "universal_prompts": [
    "A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black void. Hard rim light from behind in vibrant magenta, soft cyan accent fill from camera-right. 50mm lens at f/4, eye-level three-quarter view, portrait composition, studio product photography meets concept art.",
    "...",
    "..."
  ],
  "clone_prompts": {
    "variants": [
      {
        "index": 1,
        "natural_language": "A shattered chrome wolf...",
        "per_model": {
          "midjourney_v7": "shattered chrome wolf, fragments mid-explosion ... --ar 2:3 --s 250",
          "flux_1": "A shattered chrome wolf at the moment of explosive break-apart...",
          "flux_2": "{\"scene\": \"shattered chrome wolf...\", ...}",
          "nano_banana": "A photorealistic medium shot of a shattered chrome wolf...",
          "wan_2_6": "A shattered chrome wolf. Featureless matte-black studio void...",
          "seedream_4": "A shattered chrome wolf bursting apart into mirror-polished fragments...",
          "kling_image": "A shattered chrome wolf at the apex of explosive break-apart, fragments captured at 1/2000 freeze-frame...",
          "grok_imagine": "A shattered chrome wolf at the apex of explosive break-apart...",
          "qwen_image": "Subject: A shattered chrome wolf...\nEnvironment: Featureless matte-black studio void...\n...",
          "z_image": "A shattered chrome wolf at the apex of explosive break-apart, the silhouette clearly recognizable as a wolf in profile...",
          "ideogram_3": "A shattered chrome wolf composition. The wolf silhouette dissolves into mirror-polished fragments suspended midair...",
          "imagen_4": "Subject: A shattered chrome wolf...\nContext: Featureless matte-black studio void...\n...",
          "adobe_firefly": "A shattered chrome wolf at the apex of explosive break-apart..."
        },
        "rationale": "Verbatim clone attempt #1, leading with subject."
      }
      /* indices 2 through 5 */
    ]
  },
  "stylistic_siblings": {
    "variants": [
      {
        "index": 1,
        "sibling_subject": "cathedral",
        "natural_language": "A shattered chrome cathedral...",
        "per_model": { /* same shape, sibling_subject swapped into every prompt */ },
        "rationale": "Architectural sibling — preserves chrome+fragments recipe with monumental subject."
      }
      /* indices 2 through 6 */
    ]
  },
  "stochastic_variants": {
    "variants": [
      {
        "index": 1,
        "shifted_axis": "lighting_angle",
        "shift_description": "Key rim light rotated from straight-back to back-left 30°.",
        "natural_language": "A shattered chrome wolf ... rim light from back-left 30° in magenta ...",
        "per_model": { /* same shape */ },
        "rationale": "Tests how a 30° rotation in key direction reads against the chrome surface."
      }
      /* indices 2 through 8, each shifted_axis distinct or labeled "compound" if multi-axis */
    ]
  },
  "recreation_notes": [
    "Kling Image variants emitted, source contains explicit motion implication."
  ],
  "flagged_for_firefly": false
}
```

## Common contract violations

Counts wrong: emitting 4 clones or 7 siblings. Validator rejects.

Per-model key missing: omitting `flux_2` because the user said "just Flux." Always include both, set the un-requested one to `null`.

Per-model value with embedded markdown or JSON syntax outside its declared format: e.g., wrapping the Midjourney prompt in code fences. The values are plain strings.

`flagged_for_firefly` always `false`: indicates the IP cleaner never ran, which is wrong if the Visual DNA's `recreation_difficulty.notes` includes any IP-sensitive flag.

Stochastic variants with duplicate `shifted_axis` and no `compound` indicator: each of the 8 must declare its distinct axis, or be explicitly labeled as a compound shift in `shift_description`.

Universal prompts containing `--ar` or model-specific magic suffixes. They are portable; they must read clean.
