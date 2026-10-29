# Controlled Vocabulary & Taxonomy Disambiguation

This file resolves ambiguity in the Visual DNA schema's enumerated fields. Load it only when an image is genuinely on the boundary between two values and you need a tiebreaker. Most extractions never need this file; it is the reference manual for hard cases.

## On the photography / 3d_render / digital_painting boundary

This is the most consequential `style.medium` decision. The same image can read three ways, and each tag pushes the downstream prompts in a different direction. The deciding question is not "what was the image actually made with?" — Claude rarely has access to that ground truth — but "what *medium* should the recreating model believe it is producing?"

If the image has photographic depth of field, photographic specular highlights with real sensor halation, plausible lighting that obeys real-world inverse-square falloff, and material surfaces that read as physically present, tag it as `photography` even if you suspect it was rendered. Photography is the most legible medium signal across every T2I model, and the recreating prompt will work better with the photographic framing.

If the image has perfect specular highlights, no atmospheric haze, every fragment rendered with equal sharpness regardless of distance, perfectly clean color separations, and material properties that read as "ideal chrome" or "ideal glass" rather than dusty real chrome and fingerprinted real glass, tag it as `3d_render`. The Fracture image in the user's reference set is a textbook 3d_render — perfectly clean fragments, no atmospheric falloff, hyperreal mirror finish.

If the image has visible brushstroke texture, paper grain, painterly color blending, or any sign that color was placed by a human hand rather than emitted by a sensor or shader, tag it as `digital_painting`. When in doubt between digital_painting and illustration, lean digital_painting if the work has photoreal lighting and perspective, illustration if it is more stylized or graphic.

The `mixed_media` tag is for genuinely hybrid pieces — collage compositions, photo-illustration combinations, photographs with painted overlays. Use it sparingly; most "mixed media" candidates are actually one of the above with light post-processing.

## On the abstract / concept_art / illustration boundary

`abstract` means there is no recognizable subject. Pure shape, color, texture, no nameable object. The Fracture image is *not* abstract — it has a clear (if dissolving) subject. Mark Rothko paintings are abstract.

`concept_art` is for narrative-implied compositions: a character, vehicle, environment, or object presented as if from a film or game pre-production document. Visual storytelling is implicit; the image suggests a world even if there is no story being told.

`illustration` is broader — any deliberately stylized rendering of a recognizable subject that does not aim for photoreal credibility. Editorial illustration, children's book art, magazine spot illustration, comic art, manga, vector art all go here.

The `graphic_design` tag is for compositions where the primary subject is typography, layout, or pure design — a movie poster where the typography carries the image, an album cover where the layout is the art, a brand identity composition. If you find yourself reaching for `graphic_design`, also fill `text_in_image` carefully and consider whether the Ideogram and Qwen-Image variants should be the strongest in the final output set.

## On lighting direction

The `key_direction` field is the source of more confusion than it should be. The reference is the camera, not the subject. "Camera-left" means light is coming from the camera's left side as the camera looks at the subject. "Side_left" therefore means the key is on the camera's left.

When the key is roughly between camera-left and camera-front (anywhere from -45° to -15° relative to the camera-subject axis), use `three_quarter` and note "from camera-left" in the lighting clause if it matters.

When the key is roughly between camera-front and camera-right (anywhere from +15° to +45°), use `three_quarter` and note "from camera-right."

The pure cardinal values (`side_left`, `side_right`, `back`, `front`, `top`, `bottom`) are for lighting setups that read as deliberately cardinal: side light at -90° for hard side lighting, back light at exactly 180° for silhouettes, top light for high noon or harsh overhead, bottom light for horror/uplighting.

For the Fracture image's lighting setup — the magenta rim from behind and the cyan fill from camera-right at 45° — the `key_direction` is `back` (the magenta is the brighter, more directional source and reads as the key). The cyan fill is documented separately as a clause in the lighting prose, not as a second key field.

## On color temperature

The Kelvin scale is non-intuitive for those who have not done color grading. Memorize these anchor points:

- 1800K: candlelight, deep amber.
- 2700K: incandescent household bulb, warm yellow.
- 3200K: tungsten studio light, warm but more neutral.
- 4000K: cool fluorescent.
- 5000-5600K: midday daylight, neutral.
- 6500K: overcast daylight, slightly cool.
- 8000K: deep shade, blue.
- 10000K: clear blue sky, very cool blue.

When the image is lit with colored gels (the magenta and cyan in the Fracture image, the orange and teal of a Wes Anderson interior, the green-and-red of a David Fincher scene), pick the underlying Kelvin of the *white* fill or ambient and document the colored sources as named `practicals` or in the lighting prose. The Fracture image's underlying white-balance is roughly studio-neutral (5000K), with the magenta and cyan as gelled accents.

## On photographer and artist references

The `style.photographer_or_artist_reference` field is the one place in the schema where over-confident extraction does the most damage. The Visual DNA model will sometimes pattern-match an image to an artist whose work it knows well and emit a name. This is wrong when the resemblance is partial.

The test for emitting a specific name: would a serious enthusiast of that artist's work look at this image and immediately identify it as theirs? If the answer is "yes, unmistakably," emit the name. If the answer is "it has some elements that remind me of them," do not. Leave the field `null` or emit a descriptive style category instead.

Safer descriptive substitutes that read well across all models:

For someone you might want to call "Annie Leibovitz" but are not 100% sure: `"editorial portrait photographer with theatrical staging and high production value"`.

For someone you might want to call "Gregory Crewdson": `"large-format cinematic tableau photographer with mundane settings and uncanny lighting"`.

For someone you might want to call "Wes Anderson": `"film director with rigorous bilateral symmetry and pastel period detail"`.

For someone you might want to call "Hayao Miyazaki / Studio Ghibli": `"hand-drawn anime feature aesthetic with painterly backgrounds and soft natural light"`.

For someone you might want to call "Greg Rutkowski": *do not.* This name appears in too many training-data prompts and produces homogenized output. Use `"high-fantasy concept art with painterly oil rendering"` instead.

## On surface materials

The `materials[].surface` field accepts free-form strings, but a controlled vocabulary makes the renderers more consistent. Prefer these canonical forms:

`polished_chrome`, `brushed_chrome`, `aged_chrome` — descending order of reflectivity.

`mirror_glass`, `frosted_glass`, `tinted_glass`, `prismatic_glass` — by transparency and finish.

`raw_concrete`, `polished_concrete`, `weathered_concrete` — by surface state.

`brushed_aluminum`, `anodized_aluminum`, `raw_aluminum` — by finish.

`liquid_mercury`, `liquid_metal_chrome`, `flowing_chrome` — for chromatic fluid surfaces that hold shape.

`smooth_ceramic`, `glazed_ceramic`, `raku_ceramic`, `unglazed_terracotta` — by ceramic finish.

`silk_satin`, `matte_silk`, `crinkled_silk` — by fabric finish.

`wet_skin`, `dry_skin`, `oiled_skin`, `painted_skin` — for figure work.

The PBR-convention numerics (`roughness` 0-1 and `metallic` 0-1) are the more important fields; the surface string is the human label. When the labels conflict, trust the numerics — they survive translation between model idioms better.

## On framing terminology

The `composition.framing` enum maps to standard cinematographic terms. Anchor points:

`extreme_close`: a single eye fills the frame, or a single detail at high magnification.

`close`: head-and-shoulders for portraits, single-object detail shot for products.

`medium_close`: head to mid-chest, or a full small object.

`medium`: head to waist, or a single subject with a small amount of context.

`medium_wide`: head to knees, or a subject with environment readable.

`wide`: full figure, environment dominates frame.

`extreme_wide`: figure tiny in a vast landscape, or no figure at all in environment shots.

The Fracture image is `medium` — the subject (the cluster of fragments) occupies the central two-thirds of the frame, with a visible-but-empty void around it on all sides.

## On the `mood` field

The `lighting.mood` field is the one truly subjective entry in the schema. It is a short adjective phrase, used as a seed for rendering, never emitted verbatim. Useful seeds and what they imply downstream:

`"tense and cinematic"` — the renderers will tilt toward shallow DOF, controlled contrast, deliberate negative space.

`"warm and intimate"` — softer fill ratios, golden-hour temperature bias, closer framing.

`"clinical and detached"` — even illumination, high key, flat color contrast, broad DOF.

`"melancholic and atmospheric"` — diffused soft key, low contrast, cool color temperature, atmospheric haze.

`"explosive and dynamic"` — hard rim lights, high contrast, motion implications, asymmetric composition.

`"serene and contemplative"` — soft natural daylight, balanced fill, classical composition, deep DOF.

The Fracture image's mood is best captured as `"controlled chaos, hypermodern"`. The renderers translate that into prompts about "explosive break-apart with controlled fragmentation" and "luxury product photography meets concept art."
