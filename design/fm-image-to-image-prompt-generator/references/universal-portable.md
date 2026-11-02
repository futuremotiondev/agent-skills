# Universal & Portable Prompts

Universal prompts are the model-agnostic baseline. They are what the user pastes when they want to try a new T2I model that did not exist when this skill was written, or when they want a "house style" prompt that runs cleanly in many places without per-model massaging. The cost of generality is that they will not be the *best* prompt in any single model — that is the job of the per-model variants — but they will be a *competent* prompt in all of them.

Aim for three to five universal prompts per image. Use three when the image is simple and focused (one subject, one lighting setup, one clear style); use five when the image is multi-layered (multiple subjects, complex post-processing, distinctive style choices) so each universal can foreground a different aspect.

## The recipe

Every universal prompt should be a single paragraph between roughly 40 and 90 words. Shorter and you starve modern T2I models of the signals they want; longer and you start to lose attention weight on later tokens in autoregressive models like Grok Aurora.

The paragraph follows this internal structure, but the seams should not be visible. A universal prompt reads as one fluent block of art direction, not as a labeled checklist.

The first clause is the subject and its state. Use a concrete noun phrase, not a category. "A shattered chrome wolf at the apex of explosive break-apart" is concrete; "an abstract metallic composition" is a category and produces wildly different results across models.

The second clause is the environment. Even when the environment is "no environment," say so explicitly: "set against a featureless matte-black studio void." Models default to *something* if you do not specify, and that default varies by model and is rarely what you want.

The third clause is the lighting. Use direction, hardness, color in that order. "Hard rim light from behind in vibrant magenta, soft cyan accent fill from camera-right" is exact. "Dramatic neon lighting" is vague.

The fourth clause is the camera language. Lens in millimeters, f-stop, angle. "50mm lens at f/4, eye-level three-quarter view" is portable across every modern T2I model because every modern model has trained on enough photographic metadata to understand it.

The fifth clause is the style and medium. "Studio product photography meets concept art" or "octane-render-style 3D" or "watercolor on cold-press paper." Be specific about the medium even when the image is abstract; the medium signal anchors the model's rendering choices for everything else.

The sixth clause is the aspect ratio, expressed in natural language. "Portrait composition" or "16:9 widescreen" or "tall vertical poster format." Universal prompts do not use parameter flags, so the aspect goes inline.

The final clause is the post-processing summary, if it matters. "Deep blacks, subtle halation around magenta highlights, no film grain" or "warm cinematic grade, mild teal-orange split tone." Skip this clause when the post is minimal.

## What to omit

Universal prompts deliberately exclude several things that work well in some models but break others.

No parameter flags. Anything starting with `--` belongs in the Midjourney variant, not here.

No weight syntax. Constructions like `(chrome:1.4)` are SDXL-era and parse as noise in everything except Stable Diffusion checkpoints.

No model-specific magic phrases. Qwen-Image's `, Ultra HD, 4K, cinematic composition` suffix is its own variant's job. The universal stays clean.

No negative wording. "Not blurry, no extra fingers, avoid weird hands" is a footgun: it works in Imagen via the separate `negative_prompt` field, it is silently dropped by Z-Image, and it can occasionally invert in Midjourney. Phrase every constraint positively. "Sharp focus" is better than "not blurry." "Five clearly delineated fingers" is better than "no extra fingers."

No artist names *unless* the artist reference is genuinely central to the image and the user has indicated they want it. Even then, prefer descriptive style language. "Studio product photographer with a moody high-contrast eye" reads cleanly everywhere; "in the style of [specific photographer]" produces uneven results and fails outright in Firefly.

No "masterpiece, best quality, 8k, ultra detailed, trending on artstation" tag soup. This is SD1.5 muscle memory and degrades every modern model's output.

## Differentiation across the 3-5 universals

When emitting more than one universal, vary the *foregrounding*, not the underlying content. The five universals for the same image should all reproduce the same image; they should just lead with different aspects of it. A useful pattern:

The first universal leads with subject and action. *"A shattered chrome wolf at the apex of explosive break-apart, fragments suspended midair..."*

The second universal leads with style and medium. *"Studio product photography meets concept art: a shattered chrome wolf..."*

The third universal leads with lighting and mood. *"Hard magenta rim light cuts through a matte-black studio void to silhouette a shattered chrome wolf..."*

The fourth universal leads with palette. *"A composition built on jet-black, mirror-silver, and electric magenta: a shattered chrome wolf..."*

The fifth universal leads with camera and framing. *"Eye-level three-quarter view, 50mm lens at f/4, razor-thin focus on a shattered chrome wolf..."*

Each one is a complete prompt by itself. The variety helps the user pick whichever framing best matches the model they end up running it in — some models pick up subject-first prompts faster, others respond better to style-first.

## Worked example

For the Fracture image (chrome shattered geometric forms, mid-explosion, against a dark void with magenta and cyan accents, portrait 2:3 aspect):

*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black studio void. Hard rim light from behind in vibrant magenta, soft cyan accent fill from camera-right at 45°. Shot on a 50mm lens at f/4, eye-level three-quarter view, razor-thin depth of field on the central fragments. Studio product photography meets concept art with octane-render specular highlights. Portrait composition, 2:3 aspect. Deep crushed blacks, subtle halation around the brightest magenta highlights, crisp fragment edges."*

That paragraph is 88 words, packs every Visual DNA field that matters, uses no model-specific syntax, and will produce a recognizable variation of the source in Midjourney, Flux, Flux.2, Nano Banana, Seedream, Ideogram, Imagen, Firefly, Qwen-Image, Z-Image, Grok Imagine, and WAN without modification. It is the *baseline*; the per-model variants will do better in their respective targets, but this universal is the safety net.
