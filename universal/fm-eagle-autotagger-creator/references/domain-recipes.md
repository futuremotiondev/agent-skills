# Domain Recipes

Starter facet sets for common Eagle libraries. Treat each as a first draft: confirm the facets
against the user's retrieval questions and real samples, then expand the vocabularies. Full,
validated presets exist for the first three (see [examples](../examples/README.md)).

Kind codes: **D** description, **N** name, **S** tags Specific, **E** tags Example, **A** tags
N/A. Cardinality: `1` exactly one, `1–3` bounded, `all` every that applies, `0–n` optional.

## Contents

1. [UI design screenshots](#1-ui-design-screenshots)
2. [App icons](#2-app-icons)
3. [Photography reference](#3-photography-reference)
4. [UI icon sets and glyphs](#4-ui-icon-sets-and-glyphs)
5. [Logos and brand marks](#5-logos-and-brand-marks)
6. [Illustration and concept art](#6-illustration-and-concept-art)
7. [AI-generated images](#7-ai-generated-images)
8. [Typography and font specimens](#8-typography-and-font-specimens)
9. [Textures, patterns, and materials](#9-textures-patterns-and-materials)
10. [3D renders and models](#10-3d-renders-and-models)
11. [Posters and graphic design](#11-posters-and-graphic-design)
12. [Motion and video clips](#12-motion-and-video-clips)
13. [Product and e-commerce photos](#13-product-and-e-commerce-photos)
14. [Architecture and interiors](#14-architecture-and-interiors)
15. [Fashion](#15-fashion)
16. [Documents and text capture](#16-documents-and-text-capture)
17. [Game assets and sprites](#17-game-assets-and-sprites)
18. [Moodboards and color palettes](#18-moodboards-and-color-palettes)
19. [Character and pose reference](#19-character-and-pose-reference)
20. [Ads and social creatives](#20-ads-and-social-creatives)

## 1. UI design screenshots

Full preset: `examples/ui-design.preset.json` (18 rules). Facets: Summary, Detailed Description,
Scope, Presentation, Platform, Device Type, Screen Type, UI Patterns, UI Components, Product
Category, Brand, Design System, Visual Style, Density, Color Scheme, Typeface, Design Takeaways,
Visible Text.

Watch for: universal components (Button, Icon, Divider); the OS leaking into style or brand;
Brand picking up social icons and integration logos; Image Resolution must be Original.

## 2. App icons

Full preset: `examples/app-icons.preset.json` (14 rules). Facets: Summary, Container,
Background, Mark, Motif, Style, Palette, Effects, Detail, Design Language, App Category, Brand,
Icon Set, Design Notes.

Watch for: SVG icons need **Use Document Thumbnails** enabled; file names from icon themes
(`Adwaita Plus Apps Scalable Firefox-1024`, `linux.arc.96px@2x.apps.gimp`) carry the set and app
names, so keep `<NAME>` in Global Instructions; don't let a gradient background count as a
gradient rendering style.

## 3. Photography reference

Full preset: `examples/photo-reference.preset.json` (14 rules, includes a Name rule). Facets:
Name, Caption, Description, Genre, Subjects, People, Lighting, Framing, Camera Angle, Color,
Mood, Location, Use Case, Composition Notes.

Watch for: camera file names carry nothing; location guessing from architecture; tiny distant
figures counted as people.

## 4. UI icon sets and glyphs

Use for: SVG/PNG interface icons (Lucide, Phosphor, Material Symbols, custom sets).

Global gist: icon librarian cataloging single interface glyphs; file names usually hold the icon
name and set; SVGs need Use Document Thumbnails.

| Rule     | Kind | Card. | Prefix  | Starter vocabulary                                                                |
| -------- | ---- | ----- | ------- | --------------------------------------------------------------------------------- |
| Meaning  | E    | 1–3   | —       | Home, Search, Settings, User, Close, Add, Delete, Edit, Share, Download           |
| Style    | S    | 1     | Style   | Outline, Filled, Duotone, Two-Tone, Bold, Thin, Rounded, Sharp, Hand-Drawn, Color |
| Stroke   | S    | 1     | Stroke  | Hairline, Thin, Regular, Bold, None                                               |
| Corners  | S    | 1     | Corners | Rounded, Sharp, Mixed                                                             |
| Grid Fit | S    | 1     | Detail  | Minimal, Moderate, Detailed                                                       |
| Metaphor | E    | 0–3   | Object  | Gear, Magnifier, Bell, Envelope, Trash Can, Pencil, Heart                         |
| Icon Set | A    | 0–1   | Set     | (from file name only)                                                             |

Watch for: the "meaning" of a glyph (Settings) versus the object drawn (Gear) are different
facets and both are useful.

## 5. Logos and brand marks

Use for: logo inspiration boards, brand identity collections.

| Rule         | Kind | Card. | Prefix     | Starter vocabulary                                                                    |
| ------------ | ---- | ----- | ---------- | ------------------------------------------------------------------------------------- |
| Summary      | D    | —     | —          | One sentence: mark, type treatment, colors, industry                                  |
| Logo Type    | S    | 1–2   | Type       | Wordmark, Lettermark, Pictorial Mark, Abstract Mark, Mascot, Emblem, Combination Mark |
| Construction | S    | 1–3   | Build      | Geometric, Negative Space, Line, Monoline, Gradient, Hand-Drawn, Grid-Based, Modular  |
| Typography   | S    | all   | Type Style | Sans-Serif, Serif, Slab Serif, Script, Display, Monospace, Custom Lettering           |
| Industry     | E    | 1–2   | Industry   | Tech, Finance, Food, Fashion, Health, Education, Sports, Entertainment, Nonprofit     |
| Motif        | E    | 0–3   | Motif      | Leaf, Star, Arrow, Circle, Shield, Animal, Mountain, Wave                             |
| Brand        | A    | 0–1   | Brand      | (real brands only; empty for concepts)                                                |
| Design Notes | D    | —     | —          | Bullets on clever negative space, scalability, symbolism                              |

Watch for: concept logos on Dribbble have placeholder names; Brand must stay empty for them.

## 6. Illustration and concept art

| Rule        | Kind | Card. | Prefix  | Starter vocabulary                                                                           |
| ----------- | ---- | ----- | ------- | -------------------------------------------------------------------------------------------- |
| Summary     | D    | —     | —       | Subject, medium, style                                                                       |
| Description | D    | —     | —       | Subject, composition, palette, lighting, technique                                           |
| Medium      | S    | 1–2   | Medium  | Digital Painting, Vector, Pixel Art, Watercolor, Gouache, Ink, Pencil, Oil, Collage, 3D      |
| Style       | S    | 1–3   | Style   | Flat, Painterly, Line Art, Cel-Shaded, Isometric, Low Poly, Retro, Anime, Storybook, Surreal |
| Subject     | E    | 3–8   | —       | Character, Creature, Landscape, City, Interior, Vehicle, Robot, Food, Plant                  |
| Genre       | S    | 1–2   | Genre   | Fantasy, Sci-Fi, Horror, Slice of Life, Editorial, Children's Book, Technical                |
| Composition | S    | 1–2   | Framing | Close-Up, Portrait, Full Body, Wide Scene, Spot Illustration, Pattern                        |
| Mood        | E    | 0–3   | Mood    | Whimsical, Moody, Serene, Dramatic, Eerie, Cozy                                              |
| Use Case    | E    | 0–2   | Use     | Spot Illustration, Hero Art, Book Cover, Poster, Sticker, Icon Art                           |

Watch for: never ask the model to name the artist unless a signature or the file name says so.

## 7. AI-generated images

Use for: Midjourney, Stable Diffusion, Flux, or similar outputs.

| Rule      | Kind | Card. | Prefix  | Starter vocabulary                                                                 |
| --------- | ---- | ----- | ------- | ---------------------------------------------------------------------------------- |
| Prompt    | D    | —     | —       | Reconstructed text-to-image prompt (see template in instruction-writing.md)        |
| Subject   | E    | 2–6   | —       | Portrait, Landscape, Product, Creature, Architecture, Vehicle                      |
| Rendering | S    | 1–2   | Render  | Photoreal, Cinematic, 3D Render, Illustration, Anime, Painterly, Vector, Pixel Art |
| Lighting  | S    | 1–2   | Light   | Golden Hour, Studio, Neon, Volumetric, Rim Light, Overcast, Night                  |
| Camera    | S    | 1     | Shot    | Close-Up, Medium Shot, Wide Shot, Macro, Aerial, Isometric                         |
| Artifacts | S    | 0–3   | Flaw    | Extra Fingers, Garbled Text, Warped Geometry, Plastic Skin, Repetition             |
| Quality   | S    | 1     | Quality | Keeper, Usable, Reject                                                             |

Watch for: `<NAME>` often contains the original prompt; tell the model to use it. The Quality
facet is subjective; define each value.

## 8. Typography and font specimens

Use for: specimen images, type posters, lettering. Font files themselves need thumbnails.

| Rule           | Kind | Card. | Prefix   | Starter vocabulary                                                                      |
| -------------- | ---- | ----- | -------- | --------------------------------------------------------------------------------------- |
| Classification | S    | 1–2   | Class    | Sans-Serif, Serif, Slab Serif, Monospace, Script, Blackletter, Display, Handwritten     |
| Subclass       | E    | 0–2   | Subclass | Geometric Sans, Grotesque, Humanist Sans, Didone, Old Style, Transitional, Brush Script |
| Weight Range   | S    | all   | Weight   | Hairline, Light, Regular, Medium, Bold, Black                                           |
| Width          | S    | 1     | Width    | Condensed, Normal, Extended                                                             |
| Features       | E    | 0–4   | Feature  | Ligatures, Stencil, Inline, Outline, Variable, Italic, Small Caps                       |
| Mood           | S    | 1–2   | Voice    | Neutral, Friendly, Elegant, Technical, Playful, Brutal, Retro, Luxury                   |
| Font Name      | A    | 0–1   | Font     | Only when printed in the image or file name                                             |

Watch for: font identification from shapes alone is unreliable; restrict Font Name to visible
text or the file name.

## 9. Textures, patterns, and materials

| Rule     | Kind | Card. | Prefix   | Starter vocabulary                                                                   |
| -------- | ---- | ----- | -------- | ------------------------------------------------------------------------------------ |
| Material | E    | 1–2   | Material | Wood, Concrete, Metal, Paper, Fabric, Leather, Stone, Marble, Plastic, Glass, Rust   |
| Pattern  | S    | 0–2   | Pattern  | Stripes, Checks, Dots, Grid, Chevron, Herringbone, Floral, Geometric, Organic, Noise |
| Seamless | S    | 1     | Tiling   | Seamless, Not Seamless, Unclear                                                      |
| Surface  | S    | 1–2   | Surface  | Smooth, Rough, Worn, Glossy, Matte, Cracked, Woven, Grainy                           |
| Scale    | S    | 1     | Scale    | Macro, Close, Medium, Wide                                                           |
| Use Case | E    | 0–2   | Use      | Background, Overlay, 3D Material, Print Texture, Grunge Effect                       |

Watch for: "Seamless" can't be judged reliably from a single tile; allow Unclear.

## 10. 3D renders and models

| Rule        | Kind | Card. | Prefix   | Starter vocabulary                                                     |
| ----------- | ---- | ----- | -------- | ---------------------------------------------------------------------- |
| Subject     | E    | 1–4   | —        | Character, Product, Vehicle, Interior, Architecture, Prop, Abstract    |
| Style       | S    | 1–2   | Style    | Photoreal, Stylized, Low Poly, Clay, Toon, Voxel, Isometric, Wireframe |
| Materials   | E    | 0–3   | Material | Glass, Metal, Plastic, Fabric, Ceramic, Emissive                       |
| Lighting    | S    | 1–2   | Light    | Studio, HDRI, Soft Box, Rim Light, Volumetric, Neon, Daylight          |
| Background  | S    | 1     | Backdrop | Transparent, Solid, Gradient, Environment, Studio Sweep                |
| Render View | S    | 1     | View     | Front, Three-Quarter, Side, Top, Isometric, Close-Up                   |

## 11. Posters and graphic design

| Rule           | Kind | Card. | Prefix  | Starter vocabulary                                                                |
| -------------- | ---- | ----- | ------- | --------------------------------------------------------------------------------- |
| Summary        | D    | —     | —       | Purpose, key visual, type treatment                                               |
| Format         | S    | 1     | Format  | Poster, Flyer, Book Cover, Album Cover, Magazine Spread, Banner, Packaging, Card  |
| Layout         | S    | 1–2   | Layout  | Centered, Grid, Asymmetric, Full-Bleed Image, Type-Only, Collage, Split           |
| Type Treatment | S    | 1–2   | Type    | Big Type, Stacked, Rotated, Outline, Distorted, Serif Display, Minimal Text       |
| Style          | S    | 1–3   | Style   | Swiss, Brutalist, Retro, Psychedelic, Bauhaus, Minimalist, Grunge, Y2K, Editorial |
| Imagery        | S    | 1–2   | Imagery | Photo, Illustration, 3D, Abstract Shapes, Pattern, None                           |
| Visible Text   | D    | —     | —       | Headline and key copy only                                                        |

## 12. Motion and video clips

The plugin samples up to 60 frames and tells the model to describe the clip as a whole.

| Rule          | Kind | Card. | Prefix    | Starter vocabulary                                                                                  |
| ------------- | ---- | ----- | --------- | --------------------------------------------------------------------------------------------------- |
| Summary       | D    | —     | —         | What happens, start to end                                                                          |
| Motion Type   | S    | 1–3   | Motion    | Transition, Micro-Interaction, Loading, Scroll Effect, Text Animation, Logo Reveal, Parallax, Morph |
| Easing Feel   | S    | 1     | Feel      | Snappy, Smooth, Bouncy, Elastic, Linear, Slow                                                       |
| Content       | E    | 1–4   | —         | Button, Card, Menu, Modal, Chart, Logo, Character, Product                                          |
| Technique     | S    | 1–2   | Technique | 2D Motion, 3D, Frame-by-Frame, Live Action, Screen Recording, Kinetic Type                          |
| Duration Feel | S    | 1     | Length    | Loop, Short, Long                                                                                   |

Watch for: ffmpeg must be installed; clip length already lives in Eagle's metadata.

## 13. Product and e-commerce photos

| Rule       | Kind | Card. | Prefix   | Starter vocabulary                                                     |
| ---------- | ---- | ----- | -------- | ---------------------------------------------------------------------- |
| Product    | E    | 1–2   | —        | Sneaker, Watch, Bottle, Chair, Headphones, Bag, Phone, Skincare        |
| Shot Type  | S    | 1     | Shot     | Packshot, Lifestyle, Flat Lay, Detail, In-Hand, Model, Group, 360 View |
| Background | S    | 1     | Backdrop | White, Color, Gradient, Textured, Scene, Transparent                   |
| Lighting   | S    | 1–2   | Light    | Soft Box, Hard Light, Natural, Rim Light, Dramatic                     |
| Props      | S    | 1     | Props    | None, Minimal, Styled Scene                                            |
| Brand      | A    | 0–1   | Brand    | Only if the logo or packaging is legible                               |

## 14. Architecture and interiors

| Rule          | Kind | Card. | Prefix    | Starter vocabulary                                                                                      |
| ------------- | ---- | ----- | --------- | ------------------------------------------------------------------------------------------------------- |
| Space Type    | S    | 1     | Space     | Exterior, Interior, Aerial, Detail, Plan, Section, Render                                               |
| Building Type | E    | 1–2   | Building  | House, Apartment, Office, Museum, Library, Restaurant, Retail, Hotel, Bridge                            |
| Room          | E    | 0–2   | Room      | Living Room, Kitchen, Bedroom, Bathroom, Lobby, Workspace, Stair                                        |
| Style         | S    | 1–2   | Style     | Modernist, Brutalist, Minimalist, Scandinavian, Japandi, Industrial, Mid-Century, Classical, Parametric |
| Materials     | E    | 1–3   | Material  | Concrete, Timber, Brick, Glass, Steel, Stone, Plaster, Terrazzo                                         |
| Light         | S    | 1–2   | Light     | Daylight, Golden Hour, Night, Artificial, Overcast                                                      |
| Architect     | A    | 0–1   | Architect | Only if stated in file name or image                                                                    |

## 15. Fashion

The plugin's built-in "Fashion Inspiration" preset has sensible facets (Style, Item, Color,
Pattern/Texture, Season/Occasion, Era, Gender, Brand, Setting, Mood, Trend). Fix its weaknesses:
label instructions, Title Case and de-slash the prefixes (`Pattern/Texture` → `Pattern`), switch
Style and Mood to Specific lists, and give Brand an evidence test.

## 16. Documents and text capture

| Rule          | Kind | Card. | Prefix   | Starter vocabulary                                                                              |
| ------------- | ---- | ----- | -------- | ----------------------------------------------------------------------------------------------- |
| Document Type | S    | 1     | Doc      | Receipt, Invoice, Letter, Form, Slide, Article, Chart, Handwritten Note, Whiteboard, Screenshot |
| Summary       | D    | —     | —        | What the document is and its key point                                                          |
| Text          | D    | —     | —        | Full transcription preserving hierarchy                                                         |
| Language      | S    | all   | Language | English, Spanish, French, German, Japanese, Chinese, Korean                                     |
| Topics        | E    | 1–4   | Topic    | Finance, Travel, Health, Legal, Education, Work                                                 |

Watch for: only case where full transcription is the point; allow long outputs and raise
max output tokens in the provider settings.

## 17. Game assets and sprites

| Rule            | Kind | Card. | Prefix | Starter vocabulary                                                                      |
| --------------- | ---- | ----- | ------ | --------------------------------------------------------------------------------------- |
| Asset Type      | S    | 1     | Asset  | Character Sprite, Tileset, Item, UI Element, Background, Effect, Portrait, Sprite Sheet |
| Art Style       | S    | 1–2   | Style  | Pixel Art, Hand-Painted, Vector, Low Poly, Cel-Shaded, Isometric                        |
| Resolution Feel | S    | 1     | Pixel  | 8-Bit, 16-Bit, 32-Bit, HD                                                               |
| Perspective     | S    | 1     | View   | Side-Scroller, Top-Down, Isometric, Front                                               |
| Subject         | E    | 1–3   | —      | Knight, Slime, Tree, Chest, Potion, Sword, Coin                                         |
| Genre           | S    | 0–2   | Genre  | Fantasy, Sci-Fi, Horror, Cute, Retro                                                    |

## 18. Moodboards and color palettes

| Rule         | Kind | Card. | Prefix    | Starter vocabulary                                                 |
| ------------ | ---- | ----- | --------- | ------------------------------------------------------------------ |
| Summary      | D    | —     | —         | The feeling and visual language of the board                       |
| Palette Type | S    | 1     | Palette   | Monochrome, Analogous, Complementary, Triadic, Neutral, Multicolor |
| Temperature  | S    | 1     | Temp      | Warm, Cool, Balanced                                               |
| Treatment    | S    | 1–2   | Treatment | Pastel, Muted, Vibrant, Neon, Earthy, Dark                         |
| Theme        | E    | 1–3   | Theme     | Coastal, Desert, Urban, Retro Tech, Botanical, Luxury, Industrial  |
| Use Case     | E    | 0–2   | Use       | Branding, Interior, UI Theme, Packaging, Campaign                  |

Watch for: hue names duplicate Eagle's color filter; tag relationships and treatments instead.

## 19. Character and pose reference

| Rule     | Kind | Card. | Prefix  | Starter vocabulary                                                                 |
| -------- | ---- | ----- | ------- | ---------------------------------------------------------------------------------- |
| Pose     | E    | 1–3   | Pose    | Standing, Sitting, Walking, Running, Jumping, Crouching, Lying, Reaching, Fighting |
| View     | S    | 1     | View    | Front, Three-Quarter, Profile, Back, Top-Down, Low Angle                           |
| Framing  | S    | 1     | Framing | Full Body, Three-Quarter Body, Waist Up, Bust, Hands, Face                         |
| People   | S    | 1     | People  | One, Two, Group                                                                    |
| Action   | E    | 0–2   | Action  | Dance, Martial Arts, Sports, Everyday, Dramatic                                    |
| Lighting | S    | 1     | Light   | Soft, Hard, Rim, Studio, Natural                                                   |
| Clothing | E    | 0–3   | Wear    | Casual, Formal, Armor, Swimwear, Athletic, Costume                                 |

Watch for: keep descriptions anatomical and neutral.

## 20. Ads and social creatives

| Rule     | Kind | Card. | Prefix   | Starter vocabulary                                                            |
| -------- | ---- | ----- | -------- | ----------------------------------------------------------------------------- |
| Format   | S    | 1     | Format   | Feed Post, Story, Carousel Slide, Banner, Thumbnail, Display Ad, Email Header |
| Hook     | S    | 1–2   | Hook     | Product Shot, Testimonial, Offer, Before and After, Meme, Question, Stat      |
| Layout   | S    | 1     | Layout   | Text Over Image, Split, Collage, Type-Only, UI Mockup                         |
| CTA      | S    | 0–1   | CTA      | Shop Now, Learn More, Sign Up, Download, Book Now, None                       |
| Brand    | A    | 0–1   | Brand    | Only the advertiser                                                           |
| Copy     | D    | —     | —        | Headline, subhead, CTA text verbatim                                          |
| Industry | E    | 1     | Industry | E-commerce, SaaS, Food, Fitness, Finance, Travel, Beauty                      |
