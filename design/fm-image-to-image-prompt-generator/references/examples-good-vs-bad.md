# Good vs. Bad: Prompt Examples Library

Every example here is a side-by-side comparison of the wrong way (description) and the right way (instruction) to convert the same Visual DNA into a prompt. The pairs are organized from simplest to most subtle, so you can read them in order and build the intuition layer by layer. Load this file when you have drafted a prompt and are uncertain which side of the line it falls on.

## Table of Contents

1. The Core Distinction — three foundational pairs
2. Common Phrasing Traps — six pairs showing typical mistakes
3. Per-Model Idiom Drift — five pairs catching cross-model contamination
4. Subject-Specific Failure Modes — five pairs by source-image genre
5. The Subtle Cases — six pairs where the line is hardest to see
6. Multi-Sentence Compositions — five pairs for long-form prompts
7. Reading the Diagnosis — guidance on which sentence patterns predict description-mode failure

---

## 1. The Core Distinction

These three pairs establish the principle. Every later pair is a variation on this same disease, so read these slowly.

**Example 1.1.** Same image: a chrome sphere on a black background, lit from behind in magenta.

❌ *"This is a photograph of a polished chrome sphere sitting on a featureless black surface. The lighting is dramatic, coming from behind the sphere, and creates a vibrant magenta highlight on its upper edge."*

✅ *"Polished chrome sphere on a matte black void, hard rim light from directly behind in magenta #FF1F88, studio product photography, 85mm lens at f/8, square crop."*

The wrong version is a third-person description of an artifact that already exists. The right version is a forward-looking creation brief. Notice how the right version compresses information that the wrong version expands: "the lighting is dramatic, coming from behind" becomes "hard rim light from directly behind." Description tends to expand; instruction tends to compress.

**Example 1.2.** Same image: a portrait of an old woman in window light.

❌ *"The image shows an elderly woman seated near a window, her face turned slightly toward the camera. The natural light from the window illuminates the left side of her face, creating soft shadows on the right side. Her expression is contemplative."*

✅ *"Portrait of an elderly woman, head turned three-quarters toward camera, soft northern window light from camera-left, contemplative expression, 85mm lens at f/2.8, shallow DOF, medium-close framing."*

Almost every word of the wrong version is description. The right version assumes the model will *create* the scene and tells it the spec sheet for doing so. Removing "the image shows" buys back enough budget to add the lens, aperture, and framing — all of which are far more generative.

**Example 1.3.** Same image: an abstract geometric composition.

❌ *"We can see an abstract composition built from overlapping triangles and squares in various shades of blue and orange. The shapes appear to float against a textured cream-colored background."*

✅ *"Abstract geometric composition: overlapping translucent triangles and squares in cobalt #1B4F8C and burnt-orange #D97A2B, floating against a warm cream paper-texture background, flat graphic design style, square format."*

"We can see" is a description fingerprint. So is "appear to." The right version drops the observer entirely and speaks directly to the production: hex codes, named medium, format.

---

## 2. Common Phrasing Traps

These six pairs cover the most common ways description-mode language creeps in even when you think you are writing instruction-mode.

**Example 2.1.** The "features" trap.

❌ *"The composition features a central focal point with radial symmetry, surrounded by detailed ornamental elements."*

✅ *"Centered subject with radial symmetry, ornamental Art Nouveau border elements, balanced detail density."*

"Features" is description's signature verb. Replacing it with no verb at all usually works.

**Example 2.2.** The "showing" trap.

❌ *"A photograph showing a cyclist mid-jump over a rocky trail, with motion blur in the background."*

✅ *"Cyclist mid-jump over rocky trail, motion blur in background, panning shot 1/30 shutter, 24mm lens, low-angle action sports photography."*

"Showing" is a description verb. The right version names the photographic technique (panning shot, 1/30 shutter) that *produces* the motion blur, rather than describing the result.

**Example 2.3.** The narrator's-mood trap.

❌ *"The scene has a melancholic atmosphere with the soft afternoon light filtering through the curtains."*

✅ *"Melancholic mood, soft afternoon light filtering through gauzy curtains from camera-left, low-key fill, 3200K warm temperature, faded muted palette."*

Both versions say the scene is melancholic. The right version tells the model how to *produce* melancholy: specific light direction, fill ratio, color temperature, palette. The wrong version trusts the model to interpret "melancholic atmosphere" correctly, which it probably will, but inconsistently across runs.

**Example 2.4.** The "appears to be" trap.

❌ *"The subject appears to be made of liquid metal, dripping slowly while maintaining its overall human form."*

✅ *"Humanoid figure rendered in flowing chrome mercury, slow viscous drip from extremities, mirror-polished surface holds general silhouette, T-1000 liquid metal aesthetic, studio product photography."*

"Appears to be" is hedged description. The right version asserts the material and gives the model concrete reference language (T-1000, flowing chrome mercury) that anchors the visual.

**Example 2.5.** The art-criticism trap.

❌ *"A bold and innovative use of negative space creates a sense of solitude, with the small figure dwarfed by the vast minimalist landscape."*

✅ *"Single small figure in lower-third of frame, vast minimalist landscape, 85% negative space, low contrast, soft overcast light, wide composition emphasizing isolation."*

The wrong version is the kind of writing you find on a museum placard. It tells a human how to appreciate the image; it does not tell a model how to make it. The right version makes "solitude" a measurable property (figure in lower-third, 85% negative space).

**Example 2.6.** The "you can see" trap.

❌ *"On the left side you can see a figure walking away, while on the right side there's a building with neon signs glowing in the rain."*

✅ *"Figure walking away in left third of frame, building with glowing neon signs in right two-thirds, rain-slicked street, blade-runner aesthetic, wide cinematic composition."*

Spatial direction language ("on the left side," "on the right side") is fine; the framing verb is what changes. "You can see X on the left" describes; "X in the left third of frame" instructs.

---

## 3. Per-Model Idiom Drift

Description-vs-instruction is only one axis of failure. The other is using the wrong model's idiom — phrasing that works in Midjourney leaking into Flux, or Stable Diffusion tag soup leaking into anything modern. These five pairs catch the most common drift.

**Example 3.1.** SDXL tag soup leaking into Flux.

❌ *"chrome wolf, shattered, fragments, octane render, masterpiece, best quality, 8k, ultra detailed, trending on artstation, cinematic lighting, dramatic"*

✅ *"A shattered chrome wolf at the moment of explosive break-apart, mirror-polished fragments suspended in air around the silhouette, octane-render-style 3D, jet-black void background, hard rim light from behind in magenta, soft cyan accent glow, 50mm lens at f/4, portrait 2:3 crop."*

Flux is not a CLIP-text-encoder model. Comma-separated tag stacks confuse it. Quality words ("masterpiece, best quality, 8k") degrade its output by adding noise. The right version is a natural-language paragraph that Flux's Mistral-3-based text encoder parses cleanly.

**Example 3.2.** Midjourney parameter flags leaking into Imagen.

❌ *"Shattered chrome wolf, explosive break-apart, fragments mid-flight --ar 2:3 --s 250 --c 15 --no text watermark"*

✅ *"Subject: A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair.\nContext: Featureless matte-black studio void.\nLook: Studio product photography meets concept art.\nPhotographic choices: Eye-level three-quarter view, 50mm lens at f/4.\nLighting: Hard magenta rim light from behind, soft cyan accent fill from camera-right.\nTechnical constraints: 3:4 portrait aspect."*

Imagen ignores `--` parameters; they parse as literal text inside the prompt and contaminate the output. The right version moves aspect ratio to the SCULPT block's `Technical constraints` and moves negative concepts to the separate `negative_prompt` API field (not shown).

**Example 3.3.** Weighted parens leaking into Nano Banana.

❌ *"(shattered chrome wolf:1.4), (mirror polished:1.2), (octane render:1.1), magenta lighting, cinematic"*

✅ *"A photorealistic medium shot of a shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black void. The scene is illuminated by a hard rim light from behind in vibrant magenta and a soft cyan accent fill from camera-right, creating a tense, cinematic atmosphere. Shot on an 85mm lens at f/4 at eye level."*

Nano Banana wants conversational descriptive prose. Weighted parens are SDXL-era and parse as literal text. The right version reads like an art-direction note.

**Example 3.4.** Universal prompt leaking model-specific syntax.

❌ *"A shattered chrome wolf... --ar 2:3, Ultra HD, 4K, cinematic composition, no text"*

✅ *"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair, set against a matte-black void. Hard rim light from behind in vibrant magenta, soft cyan accent fill from camera-right, 50mm lens at f/4, eye-level three-quarter view, portrait composition, studio product photography meets concept art."*

The wrong version mixes Midjourney's `--ar` with Qwen-Image's magic suffix and a negative-form clause. The right version stays clean for all models.

**Example 3.5.** Negative prompt leaking into the positive field.

❌ *"A clean portrait of a young woman, soft window light, no blurriness, no extra fingers, no distortion, no text, no watermark."*

✅ *"A clean portrait of a young woman, soft northern window light from camera-left, sharp focus on the eyes, natural undistorted facial proportions, five clearly delineated fingers, smooth uninterrupted skin, no overlay graphics, 85mm lens at f/2.8."*

"No blurriness" can invert in some models. "No extra fingers" is a clue the model is being asked to do something it is bad at; the right version specifies the positive constraint ("five clearly delineated fingers"). Note: Imagen and Stable Diffusion accept negative prompts via a separate field; the rule above is specifically for the positive prompt string.

---

## 4. Subject-Specific Failure Modes

Different source-image genres produce different kinds of description drift. These five pairs cover the most common.

**Example 4.1.** Portrait subject.

❌ *"A close-up portrait photograph of a middle-aged man with weathered features, his expression conveying wisdom and weariness, looking directly at the camera with intense blue eyes."*

✅ *"Close-up portrait, middle-aged man with weathered skin texture, deep facial lines, three-day stubble, direct camera gaze, intense blue eyes, contemplative expression, soft northern window light from camera-left, low-key fill, 85mm lens at f/1.4, razor-thin DOF on the eyes."*

The wrong version describes the man's interiority ("conveying wisdom and weariness"). T2I models cannot render interiority directly; they can only render the *outward signals* of it. The right version translates "wisdom and weariness" into observable features: weathered skin texture, deep facial lines, stubble, contemplative expression. The expression is named once, and the lighting does the rest.

**Example 4.2.** Architectural subject.

❌ *"The image shows a magnificent Gothic cathedral facade with intricate stonework details, soaring spires reaching toward the heavens, and beautiful stained glass windows."*

✅ *"Gothic cathedral facade, twin spires, central rose window with stained glass, ornate stonework with tracery and gargoyles, low-angle hero shot, blue-hour twilight, warm interior light glowing through stained glass from within, 24mm wide lens, slight architectural distortion, dramatic deep-blue sky."*

"Soaring toward the heavens" is description; "low-angle hero shot, 24mm wide lens" produces the same visual effect via the camera technique that creates it.

**Example 4.3.** Food / still-life subject.

❌ *"A beautifully plated dish of fresh sushi with various types of fish artfully arranged on a wooden board, accompanied by wasabi and pickled ginger, photographed in a moody dark style."*

✅ *"Sushi plate on dark walnut wood board: salmon nigiri, tuna sashimi, hamachi crudo, all arranged in a loose diagonal, dab of wasabi and pickled ginger top-left, overhead camera angle, single soft window light from camera-right, dark moody food photography, deep blacks, selective focus on the front sushi piece, 50mm lens at f/2.8."*

"Beautifully plated" and "artfully arranged" do nothing generatively. The right version names the specific dishes, the arrangement geometry, and the lighting setup.

**Example 4.4.** Landscape subject.

❌ *"A breathtaking landscape photograph of mountains at sunset, with vibrant colors reflecting off a perfectly still alpine lake in the foreground."*

✅ *"Alpine landscape, jagged mountain ridge in midground, perfectly still glacial lake in foreground reflecting the ridge, golden-hour direct sunlight from camera-left at low angle, 24mm wide lens at f/11 for deep DOF, polarizing filter saturation, warm-orange sky #F4A045 grading to deep-blue zenith #1C3F66, 16:9 widescreen."*

"Breathtaking" is editorial. "Vibrant colors" is unspecified. The right version gives the specific hex codes for the warm-to-cool sky gradient, the camera technique (polarizing filter, deep DOF aperture), and the time-of-day directionality.

**Example 4.5.** Anime / illustration subject.

❌ *"An anime-style illustration of a young woman with long flowing pink hair, wearing a sailor outfit, with a magical sparkly background showing off her energy."*

✅ *"Anime character illustration in Makoto Shinkai feature-film style, young woman with waist-length pink hair flowing as if in a slight breeze, wearing a navy-and-white sailor-collar school uniform, soft particle-magic sparkles drifting around her, hyper-detailed cityscape background, golden-hour soft fill, painterly cel-shading, hand-drawn anime aesthetic."*

"Showing off her energy" is description. The right version names a specific style anchor (Makoto Shinkai aesthetic) and translates "magical sparkly background" into specific renderable elements (soft particle-magic sparkles drifting, hyper-detailed cityscape, golden-hour fill).

---

## 5. The Subtle Cases

These six pairs are the hardest to call. The "wrong" version is not obviously wrong; it can produce decent output. The "right" version is just measurably better, usually by being more specific about *production* and less about *appearance*.

**Example 5.1.** Specifying mood with vs. without mechanics.

⚠️ *"A nostalgic photograph of a child's bedroom from the 1990s, with soft afternoon light coming through the window."*

✅ *"Child's bedroom interior, 1990s period detail (lava lamp, Lisa Frank poster, beanie babies on the shelf, CRT television), soft afternoon light filtering through gauzy curtains from camera-right, 35mm film grain, kodak portra 400 color science, slight chromatic aberration, dust motes in the light beam, 35mm lens at f/2.8."*

The first version is not exactly wrong, but it leans on "nostalgic" to do work the prompt is not equipped to do. The right version translates "nostalgic" into the specific period details and film-stock characteristics that produce nostalgia.

**Example 5.2.** Naming a style vs. naming the producer of the style.

⚠️ *"A film-noir style portrait of a detective in a dark trench coat."*

✅ *"Detective portrait, dark trench coat, fedora pulled low, hard side light from camera-right creating venetian-blind shadow on his face, low-key fill, deep blacks, monochrome with deep contrast, smoke drifting from a lit cigarette, medium-close framing, large-format 1940s look."*

"Film-noir style" is fine — it carries signal. The right version is better because it tells the model the *components* of film noir, which makes it more reliable across models that may not have a strong "film noir" cluster in their training data.

**Example 5.3.** Material specification.

⚠️ *"A reflective glass surface."*

✅ *"Polished glass surface, near-zero roughness, refractive index 1.5, slight green-tint perimeter, faint internal stress-pattern caustics, sharp specular reflections, anti-reflective coating."*

The first version produces a reflective glass surface, in some interpretation of what that means. The right version produces a *specific* reflective glass surface every time.

**Example 5.4.** Lighting hardness.

⚠️ *"Dramatic lighting."*

✅ *"Hard key light from camera-right at 45°, no fill, deep falloff to shadow, single-source studio strobe with grid, sharp specular highlights."*

"Dramatic lighting" is whatever the model has clustered under that phrase. The right version is one specific setup.

**Example 5.5.** Hands.

⚠️ *"A hand holding a coffee cup."*

✅ *"Right hand visible from the wrist down holding a white ceramic coffee mug by the handle, thumb visible, index finger through the handle, three remaining fingers curled around the handle from the side, natural undistorted hand anatomy, no extra fingers, mug held at chest height, eye-level perspective."*

Hands are the model's most reliable failure point. The first version produces three-fingered chrome stumps half the time. The right version, with explicit anatomy specification, increases the success rate considerably.

**Example 5.6.** Text in image.

⚠️ *"A vintage movie poster with a bold title at the top."*

✅ *"Vintage 1970s grindhouse-style movie poster with the title \"FRAGMENTS\" in bold condensed sans-serif all-caps at the top of the composition, the title text colored gold #C9A24E with a slight letterpress impression, beneath a moody illustration of a shadowy figure."*

The first version produces unreadable scribbles where the title should be. The right version (a) uses double quotes around the literal text, (b) specifies the font character, (c) gives a specific color, (d) places the text in the composition. Even text-strong models like Ideogram and Qwen need this level of specification to render text reliably.

---

## 6. Multi-Sentence Compositions

When the prompt is more than a single sentence, description-mode drift can hide between sentences. These five pairs show how to keep instruction-mode discipline across longer compositions.

**Example 6.1.** Nano Banana three-clause structure.

❌ *"This is a photorealistic shot of a shattered chrome wolf. The wolf is in the middle of exploding into many pieces. The lighting is dramatic and cinematic, with magenta and cyan highlights."*

✅ *"A photorealistic medium shot of a shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black void. The scene is illuminated by a hard rim light from behind in vibrant magenta and a soft cyan accent fill from camera-right, creating a tense, cinematic atmosphere. Shot on an 85mm lens at f/4, eye level. Deep blacks, controlled magenta-and-cyan accent palette, subtle halation around the brightest specular highlights."*

The wrong version starts each sentence with description ("This is," "The wolf is," "The lighting is"). The right version flows the production from subject → environment → lighting → camera → post in connected clauses, never restating the existence of the image.

**Example 6.2.** Qwen-Image labeled-category form.

❌
*"Subject: There is a shattered chrome wolf in the image.\nEnvironment: The background is matte black.\nLighting: The lighting is dramatic with magenta and cyan tones."*

✅
*"Subject: A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette.\nEnvironment: Featureless matte-black studio void, no horizon line, no floor plane.\nLighting: Hard rim light from directly behind the subject in magenta #FF1F88, soft cyan #00E0FF accent fill from camera-right at 45°."*

The wrong version uses each labeled-category line to say the image *has* something. The right version uses each line to say what *to produce* in that category. Same structure, very different output.

**Example 6.3.** Imagen SCULPT form.

❌
*"Subject: A man.\nContext: He is in a room.\nLook: The look is moody.\nPhotographic choices: Shot with a camera.\nLighting: Window light.\nTechnical constraints: Vertical format."*

✅
*"Subject: A middle-aged man with weathered skin and a contemplative expression, seated in a high-backed leather chair.\nContext: A dimly lit study with bookshelves and a single lit table lamp on a side table.\nLook: Moody chiaroscuro portrait in the tradition of Dutch Golden Age painting.\nPhotographic choices: 85mm lens at f/2, razor-thin focus on the eyes, eye-level three-quarter view, medium-close framing.\nLighting: Soft northern window light from camera-left as key, lamp practical as warm fill, deep falloff to background.\nTechnical constraints: 3:4 portrait aspect ratio."*

The wrong version's labels are filled with placeholders. The right version's labels are filled with specifications. The Imagen SCULPT structure assumes you will fill each line with substance.

**Example 6.4.** Flux.2 JSON form.

❌
```json
{"scene": "a wolf shattering", "subjects": [{"type": "wolf"}], "style": "cool", "lighting": "good"}
```

✅
```json
{
  "scene": "shattered chrome wolf mid-explosion",
  "subjects": [{
    "type": "wolf",
    "material": "mirror-polished chrome, sharp specular highlights",
    "state": "exploding outward into 40+ angular fragments",
    "position": "centered, slight front-on three-quarter"
  }],
  "style": "studio product photography meets concept art",
  "color_palette": ["#0A0A0A", "#D8D8D8", "#FF1F88", "#00E0FF"],
  "lighting": "hard rim light from behind, controlled cyan accent fill from camera-right",
  "camera": "50mm equivalent, f/4, eye-level, slight low-angle",
  "aspect_ratio": "2:3",
  "post": "deep blacks, slight halation around magenta highlights, no film grain"
}
```

The wrong version's fields are empty calories. The right version's fields are dense with generative signal. Flux.2's JSON form is only as good as the substance you put in each field.

**Example 6.5.** Ideogram ordered-clauses form.

❌ *"A poster for the band Fragments. It shows their logo at the top. They have a dark moody vibe. Make it look cool."*

✅ *"A vintage 1970s grindhouse-style poster composition. The title \"FRAGMENTS\" appears at the top in bold condensed all-caps sans-serif, gold #C9A24E with slight letterpress impression. Beneath the title, a shattered chrome wolf at the apex of explosive break-apart dominates the central two-thirds of the frame. The background is a deep blood-red gradient to black. Hard rim lighting from behind the wolf in cyan, deep crushed blacks elsewhere. 2:3 portrait composition, Design mode."*

The wrong version is the briefing a novice would give to a designer. The right version is the briefing an art director would give to the same designer.

---

## 7. Reading the Diagnosis

When you have drafted a prompt and want to spot description-mode contamination quickly, scan for these patterns. Their presence is the most reliable signal that the prompt is in description mode.

Verbs that locate the speaker outside the image: *shows, depicts, features, displays, presents, contains, includes.* Replace with no verb or with a production verb (*emerges, rises, illuminates, dominates*).

Phrases that reference the image's existence: *the image, the photograph, the scene, the composition, the artwork, this is a [type] of.* Drop entirely.

Hedged language: *appears to, seems to, looks like, has a sense of.* Replace with direct assertion.

Editorial appreciation: *beautifully, magnificently, dramatically, hauntingly, breathtakingly, evocatively.* Replace with the specific technical property that produces the effect.

Second-person observation: *you can see, you'll notice, observe how, look at how.* Drop entirely or replace with spatial descriptor (*in the left third of frame*).

Interpretive claims: *conveys, evokes, suggests, captures, embodies, represents.* These are valid in the `meta.overall_intent` seed but never in an emitted prompt. Replace with the outward signals that produce the interpretation.

Past tense, completed action: *was lit, was photographed, was rendered, was painted.* Switch to present-tense rendering instructions (*lit by, photographed with, rendered in, painted in*).

The one-line test: if any single sentence in the prompt would work as a museum placard or photo caption, that sentence is in description mode and must be rewritten. If every sentence reads as a directive to a production team, the prompt is in instruction mode.
