# Visual DNA Schema

The Visual DNA is the structured intermediate representation that bridges the vision step and the per-model rendering step. It is the *only* place in the workflow where description is permitted, because it lives inside the system and never reaches the user as output. Every downstream prompt is rendered from this object.

The schema is biased toward numbers over adjectives. Hex codes, focal lengths, f-stops, and Kelvin temperatures survive translation between model idioms; adjectives like "dramatic" or "vibrant" do not. When you have a choice between "warm light" and "3200K key light, CTO-gel-warm," choose the latter.

## Filling the schema

Examine the input image directly and fill every field you can confidently determine. Mark uncertainty by setting `meta.confidence` below 0.7 and leaving lower-confidence fields as `null` rather than guessing. A null field is recoverable downstream (the renderer drops it); a wrong field poisons every variant. When you genuinely cannot decide between two enum values, pick the one closer to the image's intent and lower your confidence rating accordingly.

The vision pass should not output the Visual DNA as text in the final response. It is internal state. The final response carries only what the output contract specifies.

## The schema

The schema below is given in TypeScript notation for compactness. Every field is optional except `subject.primary` and `aspect_ratio`, because some images legitimately have no identifiable artist reference, no in-image text, no practical light sources, and so on. When in doubt, omit.

```ts
type VisualDNA = {
  meta: {
    overall_intent: string;            // One sentence describing the image's generative goal.
                                       // Used as a seed for rendering; never appears in any
                                       // emitted prompt verbatim.
    estimated_genre:
      | "photoreal_portrait"
      | "photoreal_product"
      | "photoreal_landscape"
      | "3d_render"
      | "concept_art"
      | "illustration"
      | "graphic_design"
      | "anime"
      | "mixed_media"
      | "abstract";
    confidence: number;                // 0..1. Lower this when uncertain.
  };

  subject: {
    primary: string;                   // e.g. "shattered chrome wolf"
    secondary?: string[];              // Supporting subjects, in priority order.
    pose_or_action?: string;           // e.g. "mid-leap, head turned camera-left"
    facial_expression?: string;        // Only when a face is present and readable.
    wardrobe_or_surface?: string;      // What the subject is wearing or made of.
    sibling_axis: string;              // CRITICAL. The noun in `primary` that can be swapped
                                       // to generate stylistic siblings. For "shattered chrome
                                       // wolf" this is "wolf"; siblings will swap it with
                                       // "cathedral", "motorcycle", etc. while keeping the
                                       // rest of the recipe.
  };

  composition: {
    framing:
      | "extreme_close"
      | "close"
      | "medium_close"
      | "medium"
      | "medium_wide"
      | "wide"
      | "extreme_wide";
    angle:
      | "eye_level"
      | "low_angle"
      | "high_angle"
      | "overhead"
      | "dutch"
      | "worms_eye"
      | "birds_eye";
    rule_of_thirds_focal: {            // Normalized 0..1 position of the focal point.
      x: number;                       // 0 = left edge, 1 = right edge.
      y: number;                       // 0 = top edge, 1 = bottom edge.
    };
    depth_layers: ("foreground" | "midground" | "background")[];
    negative_space_pct: number;        // 0..100, the fraction of the frame that is empty/void.
    symmetry: "none" | "bilateral" | "radial" | "rule_of_thirds";
  };

  camera: {
    lens_mm: number;                   // Emulated focal length: 24, 35, 50, 85, 135, etc.
    aperture_fstop: number;            // Emulated f-stop: 1.4, 2.8, 4, 5.6, 8, 11.
    shutter_implied?: string;          // e.g. "1/250", "1/2000 freeze motion", "long_exposure".
                                       // Null if motion is not relevant.
    depth_of_field: "razor_thin" | "shallow" | "medium" | "deep";
    perspective: "normal" | "telephoto_compression" | "wide_distortion" | "anamorphic";
    sensor_or_film?: string;           // e.g. "full_frame_digital", "kodak_portra_400",
                                       // "cinestill_800t", "medium_format".
  };

  lighting: {
    key_direction:
      | "front"
      | "side_left"
      | "side_right"
      | "back"
      | "top"
      | "bottom"
      | "three_quarter";
    key_hardness: "hard" | "medium" | "soft" | "diffused";
    fill_ratio: number;                // 0..1. 0 = no fill (high contrast), 1 = even illumination.
    rim_present: boolean;
    practicals?: string[];             // Visible in-frame light sources.
                                       // e.g. ["neon_sign", "monitor_glow", "campfire", "candle"].
    color_temp_kelvin: number;         // 1800 (candlelight) to 10000 (overcast blue).
                                       // 5600 is daylight, 3200 is tungsten.
    time_of_day?: string;              // e.g. "golden_hour", "blue_hour", "high_noon",
                                       // "studio_no_time" for indoor/abstract.
    mood: string;                      // Short adjective phrase. Used only as a seed.
  };

  materials: Array<{
    surface: string;                   // e.g. "polished_chrome", "brushed_aluminum",
                                       // "ceramic_glaze", "raw_concrete", "wet_skin".
    roughness: number;                 // 0..1, PBR convention. 0 = mirror, 1 = chalk.
    metallic: number;                  // 0..1, PBR convention. 0 = dielectric, 1 = metal.
    refractive: boolean;               // True for glass, water, ice, clear plastic.
    texture_notes?: string;            // e.g. "subtle scratches", "fingerprint smudges",
                                       // "hammered finish".
  }>;

  palette: {
    dominant_hex: string[];            // Up to 5 hex codes, in descending area coverage.
                                       // e.g. ["#0A0A0A", "#D8D8D8", "#FF1F88"].
    accent_hex?: string;               // Single accent that pops against the dominants.
    contrast: "low" | "medium" | "high" | "extreme";
    grade:
      | "neutral"
      | "warm"
      | "cool"
      | "split_toned"
      | "teal_orange"
      | "monochrome"
      | "bleach_bypass"
      | "cross_processed";
  };

  style: {
    medium:
      | "photography"
      | "3d_render"
      | "digital_painting"
      | "oil_painting"
      | "watercolor"
      | "illustration"
      | "mixed_media"
      | "graphic_design";
    render_engine_hint?:               // Best guess at the renderer if 3d_render.
      | "octane"
      | "redshift"
      | "cycles"
      | "unreal"
      | "vray"
      | "blender_eevee"
      | "none";
    photographer_or_artist_reference?: string;
                                       // Null if no identifiable style. Be conservative;
                                       // do NOT name a specific artist unless the resemblance
                                       // is unmistakable. Generic "studio product photographer"
                                       // is safer than a specific name.
    art_movement?: string;             // e.g. "art_deco", "bauhaus", "vaporwave",
                                       // "japanese_ukiyo_e", "synthwave".
    motion_lines?: boolean;            // True only for illustration with anime-style action lines.
  };

  post_processing: {
    film_grain: number;                // 0..1
    chromatic_aberration: number;      // 0..1
    halation_bloom: number;            // 0..1, halation = colored glow around highlights.
    vignette: number;                  // 0..1
    sharpness: "soft" | "natural" | "crisp" | "ultra_sharp";
    color_grade_notes?: string;        // e.g. "lifted blacks, rolled-off highlights, teal/orange".
  };

  text_in_image: {
    present: boolean;
    strings?: string[];                // Exact text content if legible.
    font_character?: string;           // e.g. "bold_condensed_sans", "ornate_serif",
                                       // "handwritten_script", "art_deco_lettering",
                                       // "monospace_pixel".
                                       // Do NOT name specific fonts — most T2I models cannot
                                       // honor named font requests.
  };

  aspect_ratio:
    | "1:1"
    | "2:3"
    | "3:2"
    | "3:4"
    | "4:3"
    | "4:5"
    | "5:4"
    | "9:16"
    | "16:9"
    | "21:9"
    | "9:21";

  recreation_difficulty: {
    overall: number;                   // 0..1. Higher = harder to reproduce reliably.
    notes: string[];                   // Flags. Use one or more of:
                                       // "contains_real_person"
                                       // "specific_artist_style"
                                       // "branded_character"
                                       // "trademark_logo"
                                       // "small_legible_text"
                                       // "long_legible_text"
                                       // "complex_hands"
                                       // "specific_face"
                                       // "curved_text_path"
                                       // "fine_typography"
                                       // "extreme_detail_density"
  };
};
```

## How each field flows into the renderers

Some downstream renderers use only a subset of the schema. This is the routing map.

The `aspect_ratio` field becomes Midjourney's `--ar`, Imagen's `aspectRatio` parameter, and a literal text clause in prompts for models without flag syntax (Flux, Nano Banana, Firefly).

The `palette.dominant_hex` array becomes inline hex literals (`#FF1F88`) in Flux, Flux.2, WAN, Qwen, and Imagen. Midjourney does not parse hex well; for Midjourney these become color words ("magenta," "cyan") plus the `--c` (chaos) parameter.

The `camera.lens_mm` and `camera.aperture_fstop` translate to literal "50mm lens, f/4" phrasing in every model. This is one of the most prompt-portable signals you can emit.

The `lighting.color_temp_kelvin` becomes Kelvin literals for Flux/Imagen/WAN ("3200K key light"), and adjective form ("warm tungsten") for Midjourney/Firefly.

The `subject.sibling_axis` is the swap point for the six stylistic-sibling variants. Pick this field deliberately during extraction — the value chosen here determines how interesting the sibling set is.

The `recreation_difficulty.notes` flags drive routing decisions. If `"contains_real_person"` is set, the Firefly variant must avoid the real-person identifier. If `"small_legible_text"` or `"long_legible_text"` is set, route a note into `recreation_notes` for Midjourney v7 (weak text) and prefer Ideogram, Qwen, Seedream, or Imagen for that variant.

## The `meta.overall_intent` field

This is the single most important freeform field. It is one sentence that encapsulates what the image is *for* — its emotional/commercial/aesthetic purpose. Examples:

For the Fracture image (chrome geometric fragments mid-explosion): *"Hypermodern abstract product/cover artwork conveying controlled chaos and luxury via mirror-polished chrome geometry."*

For a Wes-Anderson-style symmetrical hotel facade: *"Stylized travel-poster shot leaning on perfect bilateral symmetry and pastel period-detail aesthetic."*

For a Crewdson-style suburban night scene: *"Cinematic large-format tableau suggesting narrative tension in mundane setting via diffuse practicals and cool deep-blue ambient."*

The intent sentence is *not* a description of what is visible. It is a one-line creative brief. The renderers do not output it verbatim; they use it to ensure the rendered prompts share the right *vibe* across variants.

## Common extraction mistakes

These come up enough to warrant calling out:

Setting `style.photographer_or_artist_reference` too eagerly. The Visual DNA model will sometimes confidently identify "in the style of Gregory Crewdson" or "Annie Leibovitz lighting" when the image is merely *Crewdson-adjacent*. Be conservative. The downstream effect of an over-eager artist reference is that the prompt becomes brittle (Firefly refuses, Imagen translates poorly, Chinese-origin models often have no coverage for the named artist) while sacrificing the generative signal of the actual visual properties.

Picking the wrong `sibling_axis`. The sibling axis must be a noun whose substitution preserves the rest of the recipe's interest. For "shattered chrome wolf," the axis is "wolf" (good — siblings work). For "chrome wolf at sunset on a beach," the axis could be "wolf" or "sunset on a beach"; pick the more central element. Test mentally: would substituting `cathedral` for the axis still produce an interesting image with the same recipe? If yes, the axis is good.

Filling `materials` with every material visible. Limit to the materials that define the image's look — usually 1–3. A chrome-fragment image's `materials` array should contain `polished_chrome` and possibly `glass_shards`, not also `air`, `void_background`, `studio_floor`.

Treating `aspect_ratio` as a guess. Look at the actual aspect ratio of the input image and snap to the nearest supported value. A 1024×1536 input is `2:3` (not "portrait"). A 1920×1080 input is `16:9`. When the input is non-standard (e.g. 1500×1200), snap to the nearest contracted ratio and note the snap in `meta.overall_intent` if it matters.

Recording `text_in_image.strings` as paraphrase. If the image contains the word "FRAGMENTS" in bold sans-serif, the string is `"FRAGMENTS"` — exact text, exact casing. Most T2I models that can render text need the literal string in quotes.
