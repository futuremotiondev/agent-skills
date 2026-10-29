# Ideogram 3.0

Ideogram is a text-to-image model from the company Ideogram AI, founded by former Google Imagen researchers. The founding bet was that reliable in-image text rendering would be a distinct market, and three years later that bet has paid off. Ideogram 3.0 is the model people reach for when typography is mission-critical — movie posters, brand identity work, magazine covers, editorial illustrations with headlines, anything where the legibility of in-image text is the point rather than a decorative afterthought.

The prompting personality reflects this typographic focus. Ideogram 3.0 has internalized a specific *ordered* prompt structure through training, and the model's text-rendering accuracy is meaningfully sensitive to whether the prompt follows that order. Ideogram's own documentation specifies it explicitly: image summary, then subject with any quoted text, then pose, then setting, then lighting, then framing, then technical notes. The order is not a stylistic preference; it's a quality lever.

Ideogram also offers three rendering modes — Realistic, Design, and General — that bias the output toward photographic, graphic-design-poster, or all-purpose results respectively. The renderer should pick a mode based on the Visual DNA's `style.medium` field: photographic sources go to Realistic, graphic-design and typography-heavy sources go to Design, and everything else goes to General. Note the recommended mode in the prompt itself with a trailing clause, since the mode is set via the API but the model also responds to in-prompt cues.

## Canonical structure

A natural-sentence prompt with full punctuation, following the seven-section order. The full prompt is typically 60 to 140 words, longer than Seedream but shorter than Qwen-Image. Each section is a clause or short sentence; the seams are visible but should flow as a coherent brief.

The Image Summary is one sentence framing what kind of image this is. *"A vintage 1970s grindhouse-style movie poster composition"* or *"A studio product photograph for a luxury chrome sculpture"* or *"A hand-drawn anime feature-film background plate."* This section is unique to Ideogram and serves to set the model's mode-of-operation before specifics arrive.

The Subject (with any quoted text) names the central element and includes any literal in-image text in double quotes. *"The title \"FRAGMENTS\" appears in bold condensed all-caps sans-serif at the top of the composition, gold #C9A24E with slight letterpress impression. Beneath the title, a shattered chrome wolf at the apex of explosive break-apart dominates the central two-thirds of the frame."*

The Pose or Action is a sentence describing what the subject is doing. *"The wolf silhouette dissolves into mirror-polished fragments suspended midair, captured at the instant of outward arc."*

The Setting is a sentence placing the subject in an environment. *"The background is a deep blood-red gradient transitioning to pure black at the edges, with no horizon line or floor plane."*

The Lighting is a sentence covering direction, hardness, and color. *"Hard rim lighting from behind the wolf in cyan #00E0FF, deep crushed blacks elsewhere, subtle halation around the brightest highlights."*

The Framing is a sentence covering composition, camera angle, and aspect. *"2:3 portrait composition, eye-level three-quarter view, 50mm lens at f/4."*

The Technical notes are a closing sentence anchoring the mode and any final rendering choices. *"Design mode, vintage poster aesthetic with subtle paper texture overlay."*

## Parameters and conventions

Aspect ratio is set via the API parameter; common ratios (1:1, 2:3, 3:2, 16:9, 9:16, 4:5, 5:4) are supported. Include aspect inline in natural-language form in the Framing section as a soft anchor.

The Mode selection (Realistic, Design, General) is set via the API and also signaled inline at the end of the prompt. Realistic mode biases toward photographic output and is the right choice for photoreal sources. Design mode biases toward graphic-design output and is the right choice for typography-heavy posters, album covers, editorial illustrations, and any source where the composition reads as a designed layout. General mode is the all-purpose fallback for sources that don't fit cleanly into either.

The Magic Prompt feature is Ideogram's automatic prompt-expansion tool. For clone work, prefer to disable Magic Prompt and provide the fully-engineered prompt directly. Letting Magic Prompt rewrite a clone prompt produces inconsistent results between runs.

Quoted strings are mandatory for in-image text. Double quotes around literal text strings produce reliable typography. For multi-line text, put each line in its own quoted string and specify placement: *"The headline \"FRAGMENTS\" appears at the top, with \"a film by\" in smaller text below."*

Font specification works through *descriptive characteristics*, not named fonts. Ideogram cannot honor *"Helvetica Neue Bold Condensed"* but does honor *"bold condensed sans-serif."* The descriptive vocabulary that Ideogram recognizes well includes: bold sans, condensed sans, ornate serif, slab serif, art deco lettering, handwritten script, blackletter gothic, retro 1970s display, contemporary geometric sans, classical Roman serif, brush script.

Curved or stylized text paths (text that follows a curve, text that wraps a circle, text in arched form) work but with reduced reliability. For curved text, note in the prompt: *"the text follows a gentle upward arc"* and accept that the output may render the text on a straight baseline some fraction of the time.

Hex codes parse with high fidelity for both background colors and text colors. Pair color words with hex codes when fidelity matters.

No weighted parens. No SDXL syntax.

Negative prompts work via a separate API field. For the skill's output, the renderer should optionally emit `ideogram_3_negative` for clone variants that warrant negation.

## Worked before and after

Source: a vintage-poster composition with the title "FRAGMENTS" at the top, a shattered chrome wolf as the central image, deep red-to-black background.

❌ Universal prompt pasted unchanged:
*"A shattered chrome wolf at the apex of explosive break-apart, mirror-polished fragments suspended midair, set against a deep red-to-black background with the title FRAGMENTS at the top. Hard cyan rim light from behind. Studio product photography meets concept art. Portrait composition."*

This works but under-uses Ideogram. The title "FRAGMENTS" is not quoted, the seven-section order is jumbled, no mode is specified, and the typography characteristics are unspecified.

✅ Ideogram-idiomatic with the seven-section structure:
*"A vintage 1970s grindhouse-style movie poster composition. The title \"FRAGMENTS\" appears at the top of the composition in bold condensed all-caps sans-serif, gold #C9A24E with subtle letterpress impression and slight paper-grain texture; beneath the title, a shattered chrome wolf at the apex of explosive break-apart dominates the central two-thirds of the frame. The wolf silhouette dissolves into mirror-polished fragments suspended midair, captured at the instant of outward arc in roughly 40+ angular pieces. The background is a deep blood-red gradient transitioning to pure black at the edges, with no horizon line or floor plane. Hard rim lighting from behind the wolf in cyan #00E0FF, deep crushed blacks elsewhere, subtle halation around the brightest highlights. 2:3 portrait composition, eye-level three-quarter view, 50mm lens at f/4. Design mode, vintage poster aesthetic with subtle paper texture overlay."*

About 165 words. The seven sections are present and in order. The title is in double quotes with font characteristics and color. The mode is named at the end. This is what Ideogram trained to receive, and the output reflects it.

## Anti-patterns

Unquoted in-image text. *"The title FRAGMENTS appears at the top"* drops text accuracy substantially. Always quote.

Naming specific fonts. *"Helvetica Neue Bold Condensed"* is ignored or randomly substituted. Use descriptive characteristics.

Skipping the Image Summary section. Ideogram benefits from knowing the *kind* of image being requested before specifics arrive. Without the summary, the model has to infer category from the rest of the prompt, and the inference is less reliable than the explicit declaration.

Putting the Setting before the Subject. The seven-section order is not arbitrary. Following it produces better outputs than reordering, even when the reordered version reads more naturally to a human.

SDXL syntax, weighted parens, parameter flags. Same rule as elsewhere.

`::` weight syntax from older Midjourney. Ideogram parses this as literal text.

Long curved or stylized text paths. These work poorly. For decorative typography, prefer straight baselines and add the curve in a downstream design tool.

Treating Ideogram like a general-purpose photoreal model. It is competent there, but the typography focus means its real strength is in posters, covers, editorial illustration, brand identity work, and any source where text is a load-bearing element. For pure-photoreal work without text, Flux.2 and Imagen 4 may produce better results; route accordingly in `recreation_notes`.

## Edge cases

For multi-line text or text with mixed sizing, list each line in its own quoted string with explicit hierarchy: *"The headline \"FRAGMENTS\" appears at the top in the largest size; beneath it, the subhead \"a film by claire amelio\" appears at half size in matching font; at the bottom in small text, the credits \"in theaters september 2026\"."* Ideogram handles hierarchical text well when the hierarchy is explicit.

For text in Asian scripts (Chinese, Japanese, Korean), Ideogram is competent but slightly behind Qwen-Image and Seedream 4. Use the same double-quote convention and accept moderate fidelity. For typography-critical Asian-script work, route to Qwen-Image in `recreation_notes`.

For brand-identity work requiring exact font reproduction, Ideogram cannot honor named fonts but the descriptive vocabulary is rich enough to approximate most fonts in their visual character. Combine descriptive characteristics with reference imagery (Ideogram supports image-prompt inputs) to nudge toward a specific style. Note in `recreation_notes` that exact font reproduction requires post-generation typography work in a design tool.

For graphic-design compositions with no recognizable subject (pure typography, abstract layouts, brand identity systems), use Design mode and emphasize the layout and typography in the Subject section.

For photoreal sources with incidental text (a storefront sign in the background, a license plate, a book title on a shelf), use Realistic mode and put the incidental text in quotes but with placement instructions that match: *"a storefront sign in the upper-right reads \"FRAGMENTS\" in small condensed sans-serif lettering."*

For workflows where the user is iterating on layout, Ideogram's image-prompt input lets them attach a reference layout image. Note this in `recreation_notes` when the source is a layout the user wants to preserve.
