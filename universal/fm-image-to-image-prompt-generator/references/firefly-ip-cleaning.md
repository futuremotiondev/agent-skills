# Firefly IP Cleaning

Adobe Firefly is the only model on the list that actively refuses prompts naming copyrighted artists, real public figures, branded characters, or trademark logos. The other twelve models will produce a result of varying quality; Firefly returns nothing usable. This file is the substitution lookup that converts IP-sensitive language into descriptive equivalents that capture the same aesthetic signal without triggering a refusal.

A secondary use: when the Visual DNA extraction has tentatively identified a specific artist but the resemblance is only partial, prefer the descriptive substitute from this file across *all* paths, not just Firefly. Specific artist names work unevenly across the non-Firefly models too — Imagen tends to over-stylize them, the Chinese-origin models have patchy coverage, and Midjourney can lean too hard into a stylized homage that loses the source's actual visual properties.

## When to run the cleaner

Run the IP cleaner whenever any of these conditions hold:

- `visual_dna.style.photographer_or_artist_reference` is non-null.
- `visual_dna.recreation_difficulty.notes` contains any of: `"contains_real_person"`, `"specific_artist_style"`, `"branded_character"`, `"trademark_logo"`, `"specific_face"`.
- The image contains visible logos, trademarked product designs, or copyrighted character likenesses (Disney, Marvel, DC, Nintendo, Star Wars, anything similar).
- The image is recognizably in the style of a contemporary commercial artist whose name appears in the Visual DNA notes.

When the cleaner runs, set `flagged_for_firefly` to `true` in the output and add a one-sentence note to `recreation_notes` explaining what was substituted.

## How to apply the substitutions

The substitutions below are organized by category. For each entry, the *triggering* element is on the left and the *Firefly-safe replacement* is on the right. When applying:

The replacement goes only into the `adobe_firefly` string. The other twelve model strings keep the original language unless a stronger reason exists to strip it (e.g., the model is known to refuse the artist as well).

The replacement must preserve the *generative signal* of the original. "Studio portrait photographer with theatrical staging" is a stronger replacement for "Annie Leibovitz" than "a famous photographer" — the former carries the visual signal, the latter is dead weight.

The replacement is descriptive, not evocative. "An editorial fashion photographer with high production values and a moody color palette" works; "a photographer with that one famous celebrity portrait vibe" does not.

When you do not know the safe substitute, default to: `[medium] [genre] with [one signature visual property] and [one signature lighting property]`. For example: `"editorial portrait photography with theatrical staging and dramatic top-down lighting"`.

## Photographer substitutions

Annie Leibovitz → *"editorial portrait photographer with theatrical staging, high production value, and dramatic key lighting"*

Gregory Crewdson → *"large-format cinematic tableau photographer with mundane settings, uncanny diffuse lighting, and narrative ambiguity"*

David LaChapelle → *"hyper-saturated editorial photographer with surreal pop staging and high-key color grading"*

Tim Walker → *"whimsical fashion photographer with elaborate fantasy sets and soft window light"*

Helmut Newton → *"high-contrast monochrome fashion photographer with hard side light and graphic composition"*

Richard Avedon → *"large-format portrait photographer with stark white backgrounds and soft frontal light"*

Cindy Sherman → *"staged self-portrait photographer with cinematic costume work and uncanny character studies"*

Steve McCurry → *"documentary travel photographer with saturated National Geographic color and natural directional light"*

Nan Goldin → *"intimate documentary photographer with available indoor light and snapshot framing"*

Wolfgang Tillmans → *"observational still-life photographer with diffuse natural light and casual composition"*

Wong Kar-wai (cinematic style) → *"saturated neon-and-emerald moody nighttime cinematography with hand-held intimacy"*

Roger Deakins (cinematic style) → *"naturalistic cinematic lighting with sculpted depth and warm-cool color separation"*

Emmanuel Lubezki (cinematic style) → *"available-light cinematography with extended-take naturalism and golden-hour bias"*

## Painter & illustrator substitutions

Norman Rockwell → *"mid-century narrative illustration with warm interior light and gentle social storytelling"*

Edward Hopper → *"American realist painting with hard-edged geometric shadow and lonely contemporary spaces"*

Salvador Dalí → *"surrealist oil painting with crystalline detail and dreamlike juxtaposition"*

René Magritte → *"surrealist Belgian painting with deadpan everyday objects and clean blue skies"*

Mark Rothko → *"colorfield painting with luminous overlapping color blocks and rough edges"*

Jackson Pollock → *"abstract expressionist painting with drip-action paint and chaotic energy"*

Roy Lichtenstein → *"pop-art comic illustration with hard ben-day dots and primary colors"*

Andy Warhol → *"pop-art screenprint with bold flat color separations and repetitive iconography"*

Gustav Klimt → *"Art Nouveau decorative painting with gold-leaf flat patterns and ornamental detail"*

Alphonse Mucha → *"Art Nouveau poster illustration with ornamental hair, botanical borders, and pastel palettes"*

Hayao Miyazaki / Studio Ghibli → *"hand-drawn anime feature aesthetic with painterly backgrounds, soft natural light, and pastoral whimsy"*

Makoto Shinkai → *"hyper-detailed anime cityscape style with cinematic skies, lens flares, and emotional luminosity"*

Moebius (Jean Giraud) → *"clean-line European comic illustration with crystalline detail and surreal architecture"*

Greg Rutkowski → *"high-fantasy concept art with painterly oil rendering and atmospheric depth"* (note: avoid this name everywhere, not just Firefly — it has been over-used in training data and produces homogenized output)

H. R. Giger → *"biomechanical airbrush painting with chitinous textures, monochrome palette, and uncanny anatomy"*

Beeple (Mike Winkelmann) → *"dystopian 3D digital art with high-contrast lighting and architectural megastructures"*

Yoshitaka Amano → *"watercolor fantasy character illustration with ethereal pale palettes and elongated figures"*

## Director / cinematographer substitutions

Wes Anderson → *"film director with rigorous bilateral symmetry, pastel period detail, and front-on staging"*

Stanley Kubrick → *"film director with one-point perspective, wide-angle distortion, and clinical symmetry"*

David Lynch → *"surreal cinema with red-curtained interiors, smoky atmosphere, and uncanny dream logic"*

David Fincher → *"film direction with cool-toned color grade, low-key lighting, and obsessive geometric framing"*

Quentin Tarantino → *"film direction with saturated color, low-angle shots, and 1970s-grindhouse texture"*

Christopher Nolan → *"film direction with practical-effects realism, IMAX scale, and architectural geometric framing"*

Denis Villeneuve → *"film direction with monumental scale, atmospheric haze, and muted earthen palettes"*

Hayao Miyazaki (as film direction, not painting) → *"hand-drawn anime feature direction with painterly backgrounds and naturalistic light"*

Akira Kurosawa → *"black-and-white classic Japanese cinema with deep-focus composition and dynamic motion staging"*

## Celebrity & public-figure substitutions

When the source clearly contains a recognizable public figure, the Firefly path should not name them. Use:

A specific celebrity by name → *"a [descriptive role: musician/actor/athlete] with [one identifying physical feature: short dark hair / weathered face / etc.] in [setting]"*

A specific politician by name → Decline. Politicians are off-limits on most models including Firefly; emit nothing for political figures.

A specific athlete in uniform → *"an athlete in generic [sport] uniform, [pose], [setting]"*. The sport context survives, the league/team trademark goes.

A historical figure long dead → Usually fine across all paths, including Firefly. Leonardo da Vinci, Napoleon, Cleopatra — Firefly accepts these. Modern public figures are the issue.

## Brand & trademark substitutions

Brand and trademark substitutions are categorical — when in doubt, generalize.

Specific car brand (Ferrari, Lamborghini, Porsche) → *"exotic sports car with [one descriptive feature: sweeping side intakes / low slung silhouette]"*

Specific fashion brand (Chanel, Gucci, Prada) → *"high-fashion editorial styling with [descriptive period or aesthetic note]"*

Specific tech brand (Apple, Tesla, Google) → *"minimalist consumer technology product design with [descriptive material note: brushed aluminum / matte black plastic]"*

Specific sports league (NBA, NFL, Premier League) → Generic sport with no team identification.

Specific franchise character (Mickey Mouse, Iron Man, Pikachu, Mario, etc.) → Decline to render these as the literal character. If the user wants "a chrome Pikachu," redirect to "a chrome creature with large pointed ears, expressive eyes, and a friendly humanoid posture." This applies across *all* paths, not just Firefly — most models will produce a degraded version even when they don't refuse, and the legal exposure is real.

## When the user explicitly wants the artist reference preserved

Some users will say *"I know Firefly might refuse but please include the artist name anyway."* In that case:

Include the artist name in the Firefly variant.

Set `flagged_for_firefly` to `true`.

Add a note to `recreation_notes`: *"Firefly variant retains the artist reference per user instruction; Firefly may refuse this prompt. Use the cleaned version above if Firefly refuses."*

Also produce a parallel cleaned version and put it in `recreation_notes` as a fallback the user can substitute.

## When in doubt

Default to the descriptive substitute. The descriptive form costs almost nothing in generative power for a reasonable resemblance, and it produces a Firefly result the user can actually use. The named artist form, when Firefly refuses, produces a hard zero. Asymmetric costs favor cleaning.
