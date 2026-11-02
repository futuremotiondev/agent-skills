---
name: fm-image-to-video-prompt-generator
description: Generate image-to-video (i2v) prompts from a source image. Analyzes composition, lighting, depth, mood, and motion potential, then produces 5 cinematically-crafted prompts across distinct archetypes (cinematic, abstract, narrative, subtle, dynamic) optimized for Veo 3.1, Runway Gen-4, Kling AI, Pika, or Minimax. Use when the user provides an image and wants video generation prompts, mentions i2v, image-to-video, Veo, Runway, Kling, or asks to animate a still image.
---

# Image to Video (I2V) Prompt Director

Generate 5 diverse, motion-focused prompts from any source image for use with image-to-video generators.

## Core Principle

**The image IS the visual. Prompts describe only what CHANGES.** Never re-describe what's visible in the source image. Focus exclusively on motion, camera behavior, temporal evolution, and atmospheric transformation.

## Quick Start

1. User provides an image (file path, pasted image, or URL)
2. Analyze the image using the structured schema in [analysis-schema.md](analysis-schema.md)
3. Generate 5 prompts, one per archetype, following the rules in [prompt-archetypes.md](prompt-archetypes.md)
4. If the user specifies a platform, format prompts using templates in [platform-templates.md](platform-templates.md)
5. If the user specifies a platform, also consult [camera-taxonomy.md](camera-taxonomy.md) for reliability-ranked movements
6. Output as structured JSON (schema below) or formatted markdown depending on context

## Instructions

### Step 1: Analyze the Image

Examine the source image with chain-of-thought reasoning. Produce a structured analysis covering: scene type, subjects and motion potential, camera angle, focal length feel, depth of field, framing, lighting (direction, quality, source, temperature), dominant colors, mood, style, elements with natural motion potential, implied motion, and static anchors. See [analysis-schema.md](analysis-schema.md) for the full schema and field definitions.

Key analysis priorities for i2v:
- **Motion potential** is the most important field — rank elements by how visually impactful their motion would be
- **Implied motion** catches frozen action, wind evidence, motion blur that the prompt should work WITH, not against
- **Static anchors** prevent the prompt from animating things that should stay still (architecture, ground plane, solid objects)

### Step 2: Generate Prompts

Produce exactly 5 prompts, one per archetype. See [prompt-archetypes.md](prompt-archetypes.md) for detailed archetype definitions, constraints, and examples.

Every prompt must satisfy ALL of these constraints:
- Focuses on motion, not appearance
- Contains exactly ONE primary camera movement (or explicit "static")
- Contains ONE primary subject motion + ONE secondary environmental motion
- Length: 50–300 characters (sweet spot: 100–200)
- Uses active kinetic verbs (glides, drifts, swirls, settles, ripples, lifts, shifts)
- Includes at least one pacing/temporal word (slowly, gradually, suddenly, gently)
- References subjects generically ("the figure," "the subject," "she") — never re-describes appearance
- Does not contradict the source image's framing, lighting, style, or implied motion
- Camera movement comes from Tier 1 or Tier 2 in [camera-taxonomy.md](camera-taxonomy.md)

### Step 3: Platform Optimization (if requested)

When the user specifies a target platform, reformat prompts following the platform-specific templates in [platform-templates.md](platform-templates.md). Key differences:
- **Veo 3.1**: 5-part formula, front-load shot type, audio cues, timestamp segments
- **Runway Gen-4**: 1-3 sentences, generic subject references, force-reaction physics for Gen-4.5
- **Kling AI**: 15-40 words, narrative-motivated camera, negative prompts supported
- **Pika**: Cinema language first-class, Pikaffects for stylized content
- **Minimax**: Subject-first ordering critical, excels at micro-expressions

### Step 4: Output

**JSON output** (preferred for programmatic use):

```json
{
  "analysis": {
    "scene_type": "indoor",
    "subjects": [{"description": "figure at window", "position": "center-left", "motion_potential": "high"}],
    "camera_angle": "eye-level",
    "focal_length_feel": "normal_50mm",
    "depth_of_field": "shallow",
    "framing": "medium-close-up",
    "lighting": {"direction": "side", "quality": "soft", "source": "natural", "temperature": "warm"},
    "dominant_colors": ["amber", "deep blue", "warm gray"],
    "mood": {"primary": "contemplative", "secondary": "intimate"},
    "style": "cinematic",
    "motion_potential": ["steam from cup", "hair movement", "light shift", "rain on window"],
    "implied_motion": "none",
    "static_anchors": ["furniture", "wall", "window frame"]
  },
  "prompts": {
    "cinematic": {"text": "...", "camera_movement": "slow_dolly_forward", "camera_tier": 1},
    "abstract": {"text": "...", "camera_movement": "static", "camera_tier": 1},
    "narrative": {"text": "...", "camera_movement": "slow_push_in", "camera_tier": 1},
    "subtle": {"text": "...", "camera_movement": "static", "camera_tier": 1},
    "dynamic": {"text": "...", "camera_movement": "tracking", "camera_tier": 2}
  },
  "platform_variants": {}
}
```

**Markdown output** (for conversational use): Present the analysis as a concise 8-12 line brief, followed by the 5 labeled prompts, followed by a platform targeting question.

## Conflict Prevention

Six rules prevent prompt-image conflicts. See [prompt-archetypes.md](prompt-archetypes.md) section "Conflict Prevention Rules" for full details. Summary:
- Match framing (don't prompt wide for a close-up source)
- Respect implied motion (work with momentum, not against it)
- Maintain lighting continuity (evolve, don't contradict)
- Preserve style coherence (reinforce, don't override)
- Reference subjects generically
- Keep temporal evolution gradual

## Requirements

- Vision/multimodal capability (Claude Sonnet 4.6+ or Opus 4.6)
- No external dependencies — all reference data is in companion files

## Reference Files

- [analysis-schema.md](analysis-schema.md) — Structured image analysis schema with field definitions
- [prompt-archetypes.md](prompt-archetypes.md) — Five archetype definitions, constraints, examples, and conflict rules
- [camera-taxonomy.md](camera-taxonomy.md) — Reliability-ranked camera movements with prompt patterns
- [platform-templates.md](platform-templates.md) — Platform-specific formatting rules and templates
- [motion-vocabulary.md](motion-vocabulary.md) — Curated verb/noun vocabulary for subject, environmental, and temporal motion
