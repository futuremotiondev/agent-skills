# Grok Imagine / Aurora — xAI

Grok Imagine is xAI's text-to-image surface, powered by the Aurora model and accessible through the Grok app and the xAI API. Aurora's architecture sets it apart from every other model in our lineup: it is autoregressive (mixture-of-experts), generating image tokens sequentially the way a large language model generates text tokens, rather than starting from noise and iteratively denoising like a diffusion model. This architectural choice has three direct consequences for prompting that you need to internalize before writing an Aurora prompt.

First, Aurora has no concept of seeds in the diffusion sense. There is no noise to seed; the model just begins generating tokens. So while Flux or SDXL prompts often pair with a seed for reproducibility, Aurora reproducibility comes from prompt stability rather than seed reuse.

Second, Aurora has strong text-rendering ability because rendering legible in-image text is essentially a sequential prediction task — exactly what autoregression is built for. Aurora's text-in-image quality is comparable to Ideogram and notably better than Midjourney v7, Flux.1, or Nano Banana.

Third, and most importantly for our prompting strategy, Aurora attends most strongly to the *earliest* tokens in the prompt. The model commits to early generation decisions and those decisions constrain later tokens. Long descriptive paragraphs with the most important content buried at the end produce worse results than short paragraphs with the most important content front-loaded. Front-loading discipline is the single biggest quality lever for Aurora prompts.

## Canonical structure

A short descriptive paragraph, one to three sentences, between 25 and 70 words. Anything longer wastes attention budget on tokens the model has already committed past.

The first sentence carries the subject, its state, and the environment. Everything load-bearing about the image goes here. *"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, set against a matte-black studio void."*

The second sentence covers lighting and color, plus camera if it fits. *"Hard magenta rim light from behind, soft cyan accent fill from camera-right, 50mm lens at f/4, eye-level three-quarter view."*

The third sentence, optional, handles any in-image text or final style anchor. *"Text reads \"FRAGMENTS\" in bold sans-serif, magenta on black, upper-left."*

The discipline is to make sure that if the model only attended to the first sentence, the result would still be a recognizable version of the source. Everything else is fine-tuning.

## Parameters and conventions

Aspect ratio is set via the API parameter, not in the prompt. Aurora does not accept `--ar` or any in-prompt flag syntax. For the skill's output, the renderer should optionally emit `grok_imagine_aspect_ratio` as a companion field in the per-model object, or note the aspect in `recreation_notes` for the user to set in their Grok session.

No seeds. The diffusion-era practice of pairing a prompt with a seed for reproducibility does not apply. For reproducibility, lock the prompt text and accept that exact pixel-for-pixel reproduction is not Aurora's strength.

No negative prompts. Aurora has no separate negative-prompt field and does not parse "no X" phrasing reliably. Phrase every constraint positively.

Hex codes parse, but Aurora weights color words more heavily. Pair them when fidelity matters: *"vibrant magenta #FF1F88."*

Quoted strings render in-image text at high fidelity, second only to Ideogram in our lineup. Always quote literal text. Aurora handles longer text strings (up to ~50 characters) noticeably better than most models, including curved or stylized text paths to a degree.

No weighted parens, no SDXL syntax, no quality-tag stacks.

Multi-subject scenes work cleanly when the subjects are introduced in the first sentence with explicit spatial anchoring. *"On the left, a chrome wolf at the apex of break-apart; on the right, a chrome cathedral undergoing the same transformation."* Aurora handles two or three subjects reasonably well. More than three gets unreliable.

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Universal prompt pasted unchanged (too long, important content buried mid-paragraph):
*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black studio void. Hard rim light from behind in vibrant magenta, soft cyan accent fill from camera-right at 45°. Shot on a 50mm lens at f/4, eye-level three-quarter view, razor-thin depth of field on the central fragments. Studio product photography meets concept art with octane-render specular highlights. Portrait composition, 2:3 aspect. Deep crushed blacks, subtle halation around the brightest magenta highlights, crisp fragment edges."*

This is 88 words. Aurora's attention drops sharply past the first 30 to 40 tokens (roughly 25 to 30 words). The "studio product photography meets concept art" anchor and the post-processing details at the end get under-weighted.

✅ Aurora-idiomatic with front-loading:
*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair around the dissolving silhouette, against a matte-black studio void. Hard magenta rim light from behind, soft cyan accent fill from camera-right, 50mm lens at f/4, eye-level three-quarter view. Studio product photography meets concept art."*

Forty-six words. The subject, its state, the environment, and the lighting are all in the first 30 words. The camera and the style anchor fit in the remaining budget. Aspect goes to the API parameter, not the prompt. Post-processing details are dropped because at 46 words they would still be under-attended and Aurora's defaults for crushed blacks and specular highlights are reasonable.

## Anti-patterns

Long descriptive paragraphs over 80 words. Aurora's attention falls off sharply past the first 40 tokens. Beyond 80 words, later content is essentially decorative.

Burying the subject. *"Set against a matte-black void, illuminated by hard magenta rim light from behind, is a shattered chrome wolf..."* The model has already committed to "matte-black void with magenta light" before it reaches the wolf. Always lead with the subject.

Quality words and resolution claims. *"Ultra HD,"* *"4K,"* *"hyperrealistic"* do not improve Aurora output. Drop.

Negative phrasing. Reword positively. Aurora silently drops or sometimes inverts negation.

SDXL syntax, weighted parens, parameter flags. Same rule as elsewhere.

Mentioning seeds, samplers, schedulers, or step counts. Aurora has none of these. The mentions parse as literal text noise.

Naming photographers or artists. Aurora's coverage of named artists is patchy. Use descriptive style language ("editorial portrait photographer with theatrical staging") instead of names.

Asking for specific named fonts in in-image text. Aurora cannot honor named font requests. Use descriptive font characteristics ("bold condensed sans," "elegant serif," "art deco lettering").

## Edge cases

For text-rendering-critical sources, Aurora is one of the strongest in the lineup. Use quoted strings and benefit from the autoregressive architecture's text strength. For text strings over 50 characters, break into two or three short quoted phrases and place them explicitly in the composition.

For multi-subject scenes with three or more subjects, Aurora struggles with spatial coherence. Either trim to two subjects in the Grok variant, or note in `recreation_notes` that the Aurora result may have spatial blending issues and recommend Flux.2 or Imagen 4 for multi-subject work.

For real-time content or current-events imagery, Grok's underlying connection to current X data gives it an edge on culturally-current references. The clone use case rarely needs this, but for sources referencing recent events or people, Aurora may produce more contextually-aware results.

For hands and complex anatomy, Aurora is moderate. The autoregressive architecture helps with text but does not particularly help with hands. For hand-critical images, add explicit anatomy specification ("five clearly delineated fingers, natural undistorted hand anatomy").

For abstract or non-representational sources, Aurora performs adequately but not as strongly as on representational sources. The autoregressive architecture seems to benefit from having a "subject" to commit to in the first tokens. For pure abstract work, route to Midjourney v7 or Flux.2 in `recreation_notes`.

For workflows where the user wants Grok Imagine specifically because of integration with the Grok app or X platform, the prompt itself is unchanged from the API form. Note in `recreation_notes` that the prompt works identically across surfaces.

When the source contains identifiable real people, Aurora may produce a likeness depending on the person's public-figure status. xAI's content policy is more permissive than Adobe Firefly's but less permissive than Midjourney's. Use descriptive identification when likeness might be problematic; the prompt usually works either way and the model decides.
