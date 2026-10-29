# Adobe Firefly — Image Model 4 / 5 Ultra

Adobe Firefly is Adobe's text-to-image family, currently shipping as Image Model 4 (the standard tier) and Image Model 5 Ultra (the higher-fidelity tier). Firefly is accessible through the Adobe Firefly web app, through the Creative Cloud applications (Photoshop's Generative Fill, Illustrator's Generative Recolor, Express's Generate Image), and through the Adobe Firefly API for developers.

Firefly's positioning in the market is fundamentally different from every other model in our lineup, and the prompting idiom reflects that positioning. Adobe trained Firefly exclusively on Adobe Stock content and openly-licensed data, and the company offers commercial-use indemnification on Firefly outputs — meaning Adobe will defend customers against IP claims arising from Firefly outputs used in commercial work. That legal guarantee is genuinely valuable for users in advertising, branding, and editorial work where exposure to copyright litigation is a real cost. The trade-off is that Firefly actively refuses prompts that would compromise the guarantee: named copyrighted artists, identifiable real public figures, branded characters, and trademark logos all trigger refusals.

The IP-cleaning reference file `references/firefly-ip-cleaning.md` handles the substitution logic. This model reference focuses on the prompting idiom itself, assuming the prompt has already been IP-cleaned. If the Visual DNA contains IP-sensitive content, run the IP cleaner first and use the cleaned version as input to this reference's templates.

## Canonical structure

A plain natural-language paragraph. No flag syntax, no parameter syntax, no structured labels. The paragraph is between 25 and 175 words; Adobe's own guidance recommends staying under 175. The structure follows the universal-prompt order: subject and action first, environment second, lighting third, camera fourth, style fifth, post-processing optional last.

Adobe's prompting documentation includes one unusual specific recommendation: **avoid the verbs "generate" and "create" in the prompt itself**. Those verbs read to Firefly's parser as meta-commands about the act of generation rather than as part of the description, and they push the model into a generic interpretation. So instead of *"Generate a shattered chrome wolf..."* or *"Create a poster featuring..."*, write the prompt as if the image already exists: *"A shattered chrome wolf..."* or *"A poster featuring..."*. The skill's renderer should run a final pass on the Firefly variant that strips any "generate" or "create" verbs.

The other Adobe-specific recommendation is to use *complete descriptive sentences* rather than fragments. *"A shattered chrome wolf, mid-explosion, against black void, magenta and cyan lighting, portrait"* under-uses Firefly. The same content as a complete sentence — *"A shattered chrome wolf is at the apex of explosive break-apart against a featureless matte-black void, illuminated by hard magenta rim light from behind and soft cyan accent fill from camera-right, in portrait composition"* — produces a noticeably more cohesive result.

## Parameters and conventions

Aspect ratio is set via the Firefly app's aspect-ratio selector or the API's `size` parameter. Firefly supports a range of common ratios including 1:1, 4:3, 3:4, 16:9, 9:16, and 3:2 / 2:3. Include the aspect in natural-language form inside the prompt as a soft anchor.

Composition Reference and Style Reference uploads are Firefly's two reference-image inputs. They're particularly useful for stylistic siblings — the user can upload the source as a Style Reference, then let the prompt vary only the subject token while Firefly carries the aesthetic from the reference image. Note this workflow recommendation in `recreation_notes` when the source has a distinctive aesthetic the user might want to preserve across siblings.

Hex codes parse but Firefly weights color words more heavily than codes. Pair them when fidelity matters: *"vibrant magenta #FF1F88."* For commercial brand-color work requiring exact hex fidelity, route to WAN 2.7, Imagen 4, or Flux.2 in `recreation_notes`.

Quoted strings render in-image text. Firefly's text rendering is moderate — slightly behind Ideogram and Qwen-Image, roughly equivalent to Flux.2 and Imagen 4. Use double quotes for any literal text.

No flag syntax. *"--ar 2:3"* parses as literal text and contaminates the output. The `--` character is not magic.

No SDXL syntax, no weighted parens.

No negation language in the prompt. Firefly does not have a separate negative-prompt field, and "no X" phrasing in the positive prompt has inconsistent effect. Phrase every constraint positively.

IP-clean content is mandatory. Specifically:

The prompt must not name any copyrighted artist, photographer, illustrator, or designer (run the IP cleaner from `references/firefly-ip-cleaning.md`).

The prompt must not name any real public figure (celebrity, politician, athlete) by name. Use descriptive identification instead.

The prompt must not name any branded character (Disney, Marvel, DC, Pixar, Nintendo, etc.) or franchise property. Use descriptive equivalents.

The prompt must not reference trademark logos, branded products by name, or specific commercial brands. Use descriptive equivalents.

If the Visual DNA contains any of these, the renderer must run the IP cleaner before emitting the Firefly variant, and `flagged_for_firefly` must be set to `true` in the output JSON.

## Worked before and after

Source: shattered chrome wolf, mid-explosion, matte black void, magenta rim from behind, cyan accent from camera-right, portrait 2:3.

❌ Prompt with "generate" verb and tag-fragment phrasing:
*"Generate an image of a chrome wolf, shattered, fragments, magenta and cyan lighting, dramatic, cinematic, portrait composition, by Annie Leibovitz."*

This fails Firefly on three counts. The "Generate" verb pushes the model into a generic interpretation. The tag-fragment phrasing under-uses Firefly's complete-sentence preference. And the artist reference will trigger an outright refusal.

✅ Firefly-idiomatic IP-clean version:
*"A shattered chrome wolf at the apex of explosive break-apart, with mirror-polished fragments suspended midair around the dissolving silhouette, set against a featureless matte-black studio void. The scene is illuminated by hard rim lighting from behind in vibrant magenta and a soft cyan accent fill from camera-right at 45 degrees. The composition uses a 50mm lens at f/4 with shallow depth of field, photographed at eye-level with a slight three-quarter view. Studio product photography aesthetic with editorial styling and high-contrast key lighting, in 2:3 portrait composition. Deep crushed blacks throughout, with subtle halation around the brightest magenta highlights and crisp specular treatment on the chrome fragments."*

About 115 words. No "generate" verb. Complete descriptive sentences. No artist reference. No flag syntax. No negation. This is the Firefly idiom executed cleanly. If the original Visual DNA's `style.photographer_or_artist_reference` was Annie Leibovitz, the cleaned version's equivalent is the phrase *"editorial styling and high-contrast key lighting"* — which captures the generative signal without the IP risk.

## Anti-patterns

The verbs "generate" and "create" in the prompt itself. Adobe's own guidance specifically recommends against these. The renderer should strip them.

Tag-fragment phrasing. *"chrome wolf, shattered, fragments, magenta"* under-uses Firefly. Use complete sentences.

Named copyrighted artists, photographers, illustrators, or designers. The model refuses. Run the IP cleaner from `references/firefly-ip-cleaning.md`.

Named real public figures. Same rule — use descriptive identification.

Named branded characters or franchise properties. Same rule — use descriptive equivalents.

Specific brand or product names. *"Coca-Cola bottle"* fails; *"a slim glass beverage bottle with a contoured silhouette"* works.

Flag syntax. *"--ar 2:3"* contaminates the output.

SDXL weighted parens, double-colon weights, tag-list quality stacks. Same rule as elsewhere.

Negation language. *"no text, no watermark, no extra fingers."* Either drop, or rewrite positively, or accept that the constraint has inconsistent effect in Firefly.

Prompts over 175 words. Firefly's attention falls off past this and the output becomes less coherent than a shorter version would have been. Trim.

Content that might trip Firefly's content policy: weapons-in-hand-aimed-at-people, gore, sexual content, content involving minors in adult contexts, anything that reads as overtly violent. Firefly's content filter is stricter than Midjourney's. If the source contains any of these, route to other models and note the refusal risk in `recreation_notes`.

## Edge cases

For typography-heavy sources, Firefly is moderate. Use quoted strings and accept ~70% fidelity. For typography-critical work, route to Ideogram or Qwen-Image in `recreation_notes`.

For commercial brand work requiring exact color fidelity, route to WAN 2.7, Imagen 4, or Flux.2 in `recreation_notes`. Firefly is fine for general commercial work but slightly behind the strongest hex-fidelity models.

For stylistic-sibling generation where the user wants the same aesthetic with different subjects, Firefly's Style Reference upload is the most efficient workflow. Recommend uploading the source as a Style Reference and varying only the subject in the prompt. This produces noticeably more consistent stylistic siblings than text-only prompting. Note this in `recreation_notes` when the variant set will include stylistic siblings.

For workflows requiring commercial-use indemnification, Firefly is the only model in our lineup that offers it. Note in `recreation_notes` that Firefly outputs come with Adobe's IP indemnity when used through paid Adobe accounts; outputs from other models do not.

For sources containing genuinely IP-sensitive content (a recognizable brand, a famous character, a public figure), the Firefly variant has been cleaned and the cleaning is documented in `recreation_notes`. The user can override the cleaning by passing the original artist/brand/figure name explicitly, but should be warned that Firefly will refuse and they should fall back to the cleaned version.

For workflows where the user is already in Photoshop and using Generative Fill, the same prompt idiom applies. Generative Fill is Firefly under the hood, and the IP rules, the no-"generate" rule, and the complete-sentence preference all apply identically.

For workflows where the user is in Adobe Express or Illustrator, the same idiom applies but the output is biased toward graphic-design aesthetics. The Style anchor in the prompt should reflect this: *"vector illustration with flat color blocks"* or *"design poster aesthetic with high-contrast typography"* rather than photographic descriptors.

For sources that look like Firefly outputs already (the characteristic Adobe Stock-like clean photoreal aesthetic), the cloning task is easiest with Firefly itself. The model recognizes its own outputs and reproduces them faithfully.
