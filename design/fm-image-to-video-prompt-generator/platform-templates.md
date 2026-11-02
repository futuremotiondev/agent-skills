# Platform-Specific Prompt Templates

## Universal i2v Prompt Structure

All platforms share this base structure, which is then adapted to platform-specific requirements:

```
[Camera movement] as [subject performs specific action]. [Environmental motion]. [Atmosphere/pacing modifier].
```

The adaptation adds or removes elements: audio cues for Veo/Kling, force-reaction verbs for Runway Gen-4.5, effect keywords for Pika, emotion-first ordering for Minimax.

---

## Google Veo 3.1

### Formula

`[Cinematography] + [Subject] + [Action] + [Context] + [Style & Ambiance]`

Front-load the shot type. The first words of the prompt should name the camera behavior. This ensures Veo prioritizes framing before anything else.

### Constraints
- Maximum clip duration: 8 seconds
- Aspect ratios: 16:9 or 9:16 only
- Prompt adherence: 85-90% (highest of any platform)
- Optimal prompt length: 150-300 characters
- Supports native audio generation: dialogue, sound effects, ambient audio (48kHz stereo)
- Supports timestamp-segmented prompts for multi-beat sequences
- Supports JSON-formatted prompts for preventing concept bleed
- Cost: ~$1.20/clip (Fast tier), ~$0.40/clip (Standard tier)

### Audio Cue Integration
Veo 3.1 uniquely generates synchronized audio. Include audio direction when it adds value:
- Ambient: "sound of rain on glass," "distant traffic hum," "quiet room tone with clock ticking"
- Subject: "soft exhale," "footsteps on wet pavement," "fabric rustling"
- Environmental: "wind through trees," "water lapping," "thunder in the distance"

Do NOT include audio cues for every prompt. Only when sound meaningfully enhances the cinematic intent.

### Timestamp Format
For the Narrative archetype, use timestamp markers:
```
[0s] Opening state — establishing the scene and initial stillness or tension.
[3s] Inciting moment — something changes, shifts, catches attention.
[6s] Response/escalation — the subject or environment reacts.
[8s] Resolution or cliffhanger — a moment of arrival, or a question left open.
```

### JSON Format (for complex prompts with many elements)
When a prompt risks concept bleed — where the model confuses which descriptors belong to which elements — use JSON:
```json
{
  "camera": "Slow dolly forward, slight crane up",
  "subject": "figure at window",
  "action": "turns slowly toward camera, lifts cup",
  "environment": "rain intensifies on glass, steam rises",
  "style": "soft film grain, desaturated warm tones, shallow depth of field",
  "audio": "rain tapping glass, quiet room ambiance, soft exhale"
}
```
Note: Only recommend JSON format when the prompt has 4+ distinct elements that could bleed.

### Example (Standard)
"Slow dolly forward. The figure turns from the window, warm sidelight catching their profile. Steam curls from a cup in the foreground. Rain streaks the glass behind. Soft film grain, muted amber tones. Sound of rain and a quiet exhale."

### Example (Timestamp)
"[0s] Static. The figure sits motionless at the window, steam rising from an untouched cup. Rain taps the glass. [3s] Eyes shift — attention caught by something outside. [6s] A slow turn toward camera. Light shifts across the face. [8s] A quiet, knowing expression. The rain softens."

---

## Runway Gen-4 / Gen-4.5

### Formula

`[Subject action, 1-3 sentences] [Camera movement if needed] [Physics language for Gen-4.5]`

### Constraints
- Prompt length: 1-3 sentences maximum (shorter is better)
- Subject references: ALWAYS generic — "the subject," "she," "he," "the figure"
- Describe motion ONLY — never re-describe appearance
- No negative prompts supported
- Strongest character consistency across multiple shots
- Motion Brush available for selective area animation
- Gen-4.5 adds temporal sequencing and physics-aware generation

### Gen-4 vs Gen-4.5 Differences
Gen-4 prompts should be pure motion descriptions. Gen-4.5 adds:
- **Temporal sequencing:** "X occurs, then Y occurs" produces two distinct beats
- **Force-reaction physics:** Describing weight, momentum, resistance, gravity, and inertia improves physical realism
- **Material properties:** "heavy wool coat" produces different motion than "light silk" — specify material weight

### Example (Gen-4)
"The subject turns slowly toward camera, lifting a cup. Steam drifts upward. Soft focus shifts from background to face."

### Example (Gen-4.5)
"She steps forward — weight transfers through the heavy coat, fabric swinging with momentum. One hand reaches out, meeting resistance from the wind. Dust scatters from each footfall, caught in warm backlight."

---

## Kling AI (2.6 / 3.0)

### Formula

`[Narrative-motivated camera] [Subject action] [Atmospheric detail] [Optional: audio cue]`

### Constraints
- Optimal prompt length: 15-40 words
- Every camera movement MUST serve a narrative purpose — don't move the camera just because
- Supports negative prompts for both video and audio
- Supports timeline script syntax for beat-by-beat direction
- "Elements" feature for character consistency via reference images
- Strongest camera control of any platform — handles the widest range of movements reliably
- Best for cinematic and narrative content

### Negative Prompt Template
Always offer a negative prompt alongside the main prompt:
```
Negative: jittery motion, morphing face, distorted features, text, watermark, fast camera shake, abrupt transitions, overexposed, blurry
```
Audio negative (if audio cues are used):
```
Audio negative: music, singing, harsh noise, distortion, echo
```

### Example
"Camera eases forward as the figure's gaze sharpens — a realization crossing their face. Warm light deepens. Coffee steam rises between them and the lens. Room tone, a clock ticking."

---

## Pika (2.2 / 2.5)

### Formula

`[Cinema language shot type] [Subject motion] [Style or effect modifier]`

### Constraints
- Cinema language is treated as a first-class citizen — professional shot terminology works well
- Fastest iteration cycle: under 60 seconds per clip
- 7 aspect ratios supported (most of any platform)
- Unique creative effects (Pikaffects): inflate, melt, explode, squish, crush, deflate, dissolve, expand
- Pikaframes: keyframe transitions from 2-5 images
- Best for stylized, experimental, and rapid-iteration content

### Pikaffect Integration
When the Abstract archetype or user request calls for stylized effects, Pika's Pikaffects provide unique capabilities no other platform offers:
- **Inflate:** Object swells outward organically
- **Melt:** Forms liquefy and flow downward
- **Explode:** Controlled fragmentation outward
- **Squish:** Compression with material deformation
- **Crush:** Inward collapse with debris
- **Dissolve:** Gradual particle-based disappearance

### Example (Standard)
"Slow tracking shot through morning fog. The subject emerges into a shaft of warm light, pausing mid-stride. Droplets catch the light around them."

### Example (Pikaffect)
"The glass surface slowly melts, liquid light dripping downward and pooling on the dark surface below. Prismatic reflections shift as the form dissolves."

---

## Minimax / Hailuo

### Formula

`[Subject FIRST] [Subject action with emotional nuance] [Moderate camera movement] [Atmospheric context]`

### Constraints
- SUBJECT MUST APPEAR FIRST — the attention prioritization mechanism means the first-mentioned element gets the strongest generation focus
- Best at realistic human motion and micro-expressions
- Excels at: subtle smiles, nervous ticks, breathing patterns, eye movements, lip trembles, weight shifts, blinks, swallowing, eyebrow raises
- Complex or fast camera movements produce inconsistent results
- Moderate, controlled camera movements ONLY
- Static camera produces the best results on this platform
- Best for character-driven, emotionally nuanced, intimate content

### Micro-Expression Vocabulary (Minimax-specific)
These subtle cues produce Minimax's strongest results:
- "The faintest smile tugging at the corner of their mouth"
- "Eyes softening as tension leaves their shoulders"
- "A barely perceptible nod"
- "Gaze drifting downward, then slowly returning to camera"
- "The rhythm of breathing becomes visible"
- "Fingers tighten almost imperceptibly around the cup"
- "A slight swallow before speaking"
- "Eyebrows rise a fraction, then settle"

### Example
"A young woman exhales slowly, eyes softening as tension leaves her shoulders. Her fingers relax around the cup. Camera holds in medium close-up, barely drifting closer. Warm afternoon light, dust motes floating."

---

## Cross-Platform Adaptation Guide

When converting a single prompt to multiple platforms, follow this priority order:

1. **Start with the Veo 3.1 version** (most detailed, highest adherence)
2. **Strip for Runway:** Remove audio cues, condense to 1-3 sentences, genericize subject references, add physics language
3. **Trim for Kling:** Cut to 15-40 words, ensure camera is narrative-motivated, add negative prompt
4. **Rephrase for Pika:** Lead with cinema shot type, add effect keywords if stylized
5. **Reorder for Minimax:** Move subject to front, add emotional micro-expression detail, simplify camera to static or minimal movement
