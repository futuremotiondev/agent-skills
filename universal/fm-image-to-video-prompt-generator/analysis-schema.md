# Image Analysis Schema

## Structured Analysis Fields

When analyzing an input image for i2v prompt generation, reason through each field using chain-of-thought. Output as JSON when in programmatic mode, or as a concise brief in conversational mode.

### Scene Context

**scene_type** — `indoor | outdoor | abstract | hybrid | studio`
The primary environment classification. "Hybrid" covers transitional spaces (doorways, windows, porches). "Studio" covers controlled setups with backdrops. "Abstract" covers non-representational imagery (patterns, textures, AI art without a clear scene).

### Subjects

**subjects** — Array of objects:
```json
{
  "description": "short identifier — 'woman at desk', 'cat on windowsill'",
  "position": "frame position — center, center-left, lower-right, etc.",
  "posture_state": "seated leaning forward, standing with arms crossed, mid-stride",
  "motion_potential": "high | medium | low — how naturally could this subject move?",
  "motion_notes": "specific movement opportunities — 'could turn head', 'hand near cup could lift it'"
}
```

### Background Layers

**background_layers** — Separate analysis of depth planes:
```json
{
  "foreground": "elements closest to camera — table edge, railing, blurred leaves",
  "midground": "primary action zone — where the subject lives",
  "background": "furthest elements — sky, distant buildings, bokeh lights",
  "depth_cues": "what creates the sense of depth — size difference, blur gradient, atmospheric haze, overlapping forms"
}
```

### Camera & Optics

**camera_angle** — `eye-level | low-angle | high-angle | bird's-eye | worm's-eye | Dutch | overhead`
Estimate based on the vertical relationship between camera and subject. Eye-level is the most common and often the hardest to distinguish from slightly-above.

**focal_length_feel** — `ultra-wide (<18mm) | wide (18-35mm) | normal (35-50mm) | short-telephoto (50-85mm) | telephoto (85mm+) | macro`
Vision LLMs cannot reliably identify exact focal lengths. Estimate the *feel*: exaggerated perspective = wide, compression/flattened depth = telephoto, natural proportions = normal. When uncertain, default to "normal."

**depth_of_field** — `shallow (visible bokeh, soft background) | moderate (background slightly soft) | deep (everything sharp)`
Look for bokeh balls, blur gradients, and edge sharpness differences between foreground and background.

**framing** — `extreme-close-up | close-up | medium-close-up | medium | medium-wide | wide | extreme-wide`
Based on how much of the primary subject is visible. ECU = partial face/detail. CU = face/head. MCU = head to chest. Medium = waist up. MW = knees up. Wide = full body with environment. EW = subject small in frame.

### Lighting

**light_direction** — `front | side | back | rim | top | bottom | ambient/diffused | multi-source`
Determine by examining shadow direction, highlight placement, and catch lights in eyes/reflective surfaces.

**light_quality** — `hard (sharp shadows, defined edges) | soft (gradual shadows, diffused) | mixed`
Hard light comes from small/distant sources (direct sun, spot). Soft light from large/close sources (overcast sky, large window, diffuser).

**light_source** — `natural (sun/sky) | artificial (lamp/neon/screen) | mixed | fire/candle | unknown`
If identifiable, name the specific source: "warm lamp from frame-right," "blue screen glow from below," "golden hour sun from behind."

**color_temperature** — `warm (amber/golden, ~3000K) | neutral (white, ~5500K) | cool (blue, ~7000K+) | mixed`
Overall cast of the light, not the subject colors.

### Color & Mood

**dominant_colors** — List 3-5 dominant hues by visual weight. Use specific names: "dusty rose" not "pink," "deep teal" not "blue-green," "burnt sienna" not "brown."

**mood** — Primary + secondary:
```json
{
  "primary": "the dominant emotional register — contemplative, tense, serene, joyful, melancholic, mysterious, intimate, powerful, lonely, chaotic",
  "secondary": "the undertone or counterpoint — a secondary emotional note that adds complexity"
}
```

**style** — `photorealistic | cinematic | editorial | painterly | anime/illustrated | graphic-design | documentary | vintage/retro | surreal | mixed`
If a recognizable production aesthetic is present, note it: "Blade Runner neon noir," "Wes Anderson symmetry," "70s Kodachrome warmth."

### Motion Assessment (MOST IMPORTANT SECTION)

**motion_potential** — Ranked list from highest to lowest visual impact:
```json
[
  {"element": "steam from coffee cup", "impact": "high", "type": "environmental", "notes": "natural, subtle, always looks good"},
  {"element": "subject's hair", "impact": "high", "type": "subject", "notes": "implies wind or movement, very cinematic"},
  {"element": "curtain behind subject", "impact": "medium", "type": "environmental", "notes": "gentle billow would add depth"},
  {"element": "light through window", "impact": "medium", "type": "atmospheric", "notes": "shifting light creates temporal feeling"}
]
```

**implied_motion** — Evidence of motion frozen in the frame:
```json
{
  "present": true,
  "type": "wind evidence — hair and fabric displaced to the right",
  "direction": "right-to-left wind",
  "prompt_implication": "prompts should work WITH this wind direction, not against it"
}
```

**static_anchors** — Elements that should NOT move in any prompt:
```json
["building structure", "ground plane", "furniture", "text/signage", "architectural elements"]
```
Moving these creates uncanny, physics-breaking results in every current i2v model.

## Analysis Quality Signals

A good analysis produces prompts that feel *inevitable* — like the motion was always implied by the image. A poor analysis produces generic prompts that could apply to any image. Test your analysis by asking: "Would someone who hasn't seen the image know what makes THIS image unique from the analysis alone?"

## Temperature Guidance

When using this schema for API calls:
- Temperature 0.0-0.2 for the analysis step (consistency and accuracy matter)
- Temperature 0.6-0.8 for prompt generation (creativity matters)
- Temperature 0.3-0.5 for platform formatting (accuracy with some variation)
