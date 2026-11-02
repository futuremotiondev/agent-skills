# Prompt Archetypes & Conflict Prevention

## The Five Archetypes

Each archetype explores a fundamentally different creative direction from the same source image. The goal is meaningful diversity — five options the user would actually choose between — not five tonal variations of the same idea.

### 🎬 Cinematic

**Intent:** Professional film language. The viewer should feel like they're watching a shot from a well-produced short film or commercial.

**Camera:** Tier 1 preferred. Slow dolly forward, crane reveal, or deliberate slow pan. One movement only.

**Required elements:**
- A named shot type from professional cinematography (dolly, crane, steadicam, rack focus)
- One lens/optical detail (shallow DOF shift, anamorphic flare, rack focus between planes)
- One production aesthetic cue (film grain, specific color grade, motivated practical lighting)

**Tone:** Controlled, deliberate, polished. Every element serves a purpose.

**Length target:** 150–250 characters.

**Example for a portrait at a rain-streaked window:**
"Slow dolly forward. The figure turns slightly, catching warm sidelight. Focus racks from rain droplets on glass to her profile. Steam curls from a cup below frame. Subtle film grain, muted warm tones."

---

### 🎨 Abstract / Artistic

**Intent:** Non-literal, texture-driven, visually surprising. The motion should feel like it belongs in a gallery installation or experimental music video. Prioritize the unexpected.

**Camera:** Static or imperceptibly slow drift. The camera should not compete with the visual transformation.

**Required elements:**
- Material or sensory transformation (colors bleeding, light refracting, surfaces rippling, forms dissolving)
- Poetic/sensory language rather than technical terms
- At least one element of visual surprise — something the user wouldn't have expected from looking at the image

**Tone:** Dreamlike, hypnotic, poetic. Defamiliarize the familiar.

**Length target:** 80–180 characters.

**Example for the same portrait:**
"Colors slowly bleed outward from her silhouette like watercolor in rain. Light refracts through the glass into shifting prismatic bands. Everything softens at the edges. Breathing pace."

---

### 📖 Narrative / Story Beat

**Intent:** Structure the motion as a micro-story with a beginning, middle, and end. The 5-8 second clip should feel like it has an emotional arc — a moment of change, realization, or decision.

**Camera:** Any Tier 1-2 movement that serves the story. Camera movement should be motivated by the narrative beat (push in for intimacy/revelation, pull back for isolation/context).

**Required elements:**
- A clear temporal structure with at least 3 beats
- Emotional escalation or shift across the beats
- When targeting Veo 3.1, use timestamp markers: [0s], [3s], [6s], [8s]
- When targeting other platforms, use sequence words: "first...then...finally" or "begins...shifts to...settles into"

**Tone:** Purposeful, emotionally grounded. Every movement tells the story.

**Length target:** 180–300 characters (longest archetype).

**Example for the same portrait:**
"[0s] Still. Distant gaze, untouched cup steaming. Rain taps glass. [3s] Eyes shift — something outside catches her attention. Shoulders tense. [6s] A slow exhale. Shoulders drop. She lifts the cup. [8s] The faintest smile. Rain intensifies."

---

### 🧘 Subtle / Cinemagraph

**Intent:** Near-stillness with one or two isolated motion elements. The result should feel like a living photograph — elegant, meditative, and endlessly watchable on loop.

**Camera:** MUST be completely static. No movement whatsoever. The camera is a window, not a participant.

**Required elements:**
- Explicit declaration of camera stillness ("camera entirely motionless," "locked-off frame")
- Exactly 1-2 moving elements, named specifically
- Explicit declaration that everything else is frozen ("background perfectly static," "all other elements still")
- The moving elements should be small, organic, and natural (breathing, steam, a single strand of hair, a flickering light, rippling water)

**Tone:** Meditative, contemplative, precise. Less is more.

**Length target:** 50–150 characters (shortest archetype).

**Example for the same portrait:**
"Camera motionless. Only the slow curl of steam from the cup and the faintest rise of her shoulders with each breath. Everything else frozen. Rain static on the glass."

---

### ⚡ Dynamic / Energetic

**Intent:** Maximum controlled kinetic energy. The viewer should feel motion, momentum, and physical forces. This archetype pushes the boundaries of what i2v can handle while staying within reliable parameters.

**Camera:** Tier 1-2 only — even dynamic content needs reliable camera work. Tracking shots, fast dolly, or motivated handheld. The camera should feel active but controlled, not chaotic.

**Required elements:**
- Physical force language (momentum, weight, resistance, gravity, impact, tension)
- Atmospheric particles activated by the motion (dust kicked up, water droplets, fabric whipping, sparks)
- Maximum 2-3 simultaneous motion elements (more causes coherence breakdown)
- Explicit speed cue — this is the one archetype where motion can be faster, but still controlled

**Tone:** Visceral, kinetic, impactful. You should almost feel the motion.

**Length target:** 120–220 characters.

**Example for the same portrait:**
"She stands abruptly — chair scrapes back. Coat swings with the momentum. Rain outside intensifies, streaking the glass. Camera tracks her movement with subtle handheld energy. Cup steams violently in the disturbed air."

---

## Conflict Prevention Rules

### Rule 1: Match Framing
The prompt's implied shot scale must match the source image. A close-up source image must not prompt for a "wide establishing shot" or "full body reveal." A wide shot must not prompt for "extreme close-up detail."

**What to do instead:** Work within the existing framing, or prompt for gradual transitions that start from the current framing. "Camera slowly widens, revealing more of the room" works from a medium shot. A jump from close-up to wide does not.

### Rule 2: Respect Implied Motion
If the source image contains frozen fast motion (motion blur, windswept hair, action poses, splashing liquid), the prompt must work WITH that momentum, not reverse or ignore it.

**What to do instead:** Continue the implied motion's direction. If hair is blown right, the breeze should continue rightward. If a subject is mid-stride, the prompt should continue forward motion, not freeze them.

### Rule 3: Maintain Lighting Continuity
The prompt must not contradict the established lighting. A warmly-lit golden hour scene should not suddenly become cold fluorescent. A high-key studio shot should not become a noir shadow play.

**What to do instead:** Evolve the existing lighting. "Golden light gradually deepens toward amber as shadows lengthen" works. "Warm light shifts to cold blue" does not — unless explicitly requested as a creative choice and flagged as a potential conflict.

### Rule 4: Preserve Style Coherence
A photorealistic source image should not be prompted into anime style. An illustration should not be prompted into photorealism. Style transformation is a different task than i2v prompting.

**What to do instead:** Reinforce and enhance the existing style. Add style-appropriate texture (film grain for cinematic, brush stroke animation for painterly), color shifts within the palette, or characteristic artifacts of the style.

### Rule 5: Generic Subject References
Never re-describe what a subject looks like in the prompt. The image provides the visual. Saying "the woman with brown hair in a blue dress turns" wastes prompt tokens and can cause the model to re-interpret the subject's appearance.

**What to do instead:** Use "the figure," "the subject," "she," "he," "they," or a role reference ("the musician," "the dancer") that doesn't re-describe appearance.

### Rule 6: Gradual Temporal Evolution
Environmental changes (time of day, weather, season) should be gradual and believable within the clip's duration (typically 5-8 seconds). Jumping from noon to midnight or summer to winter within one clip produces incoherent results.

**What to do instead:** Evolve within a plausible timespan. "Shadows shift slightly as a cloud passes over" works. "Day turns to night" in 8 seconds does not. The exception is the Abstract archetype, where non-literal transformations are permitted and expected.

---

## Archetype Selection Guidance

For specific image types, some archetypes naturally work better than others:

**Portraits / People:** Cinematic and Narrative are strongest. Subtle excels when the subject's expression is compelling. Dynamic works when posture implies potential energy.

**Landscapes / Environments:** Abstract and Subtle are strongest (atmospheric motion shines). Cinematic works with crane/aerial movements. Narrative is weakest (harder to build story without a character).

**Still Life / Objects:** Subtle and Abstract are strongest. Cinematic works with macro-style push-ins. Dynamic is weakest (objects breaking physics looks bad).

**Action / Sports:** Dynamic is strongest. Cinematic works well. Subtle is weakest (contradicts the energy of the source).

**Abstract / AI-Generated Art:** Abstract is strongest (matches the source energy). All others can work but should lean into the existing aesthetic rather than imposing realism.

Always generate all 5 archetypes regardless of image type, but note in your analysis which 1-2 archetypes are best suited for the specific image.
