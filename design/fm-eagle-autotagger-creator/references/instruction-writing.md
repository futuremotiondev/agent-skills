# Writing Instructions

Patterns for Global Instructions and every kind of rule instruction. The model reads Global
Instructions once, then each rule as one numbered line with its tag list appended (see
[plugin-internals.md](plugin-internals.md)).

## Contents

- [Global Instructions](#global-instructions)
- [Anatomy of a rule instruction](#anatomy-of-a-rule-instruction)
- [Templates by rule kind](#templates-by-rule-kind)
- [Style rules](#style-rules)
- [Before and after](#before-and-after)
- [Local-provider variant](#local-provider-variant)

## Global Instructions

Target 150–320 words, in this order:

1. **Role and library purpose.** Who is cataloging, for what library, and why accuracy matters
   ("the metadata a designer will use to filter thousands of …").
2. **What the item is.** The expected content type and format quirks (transparent PNG, rendered
   SVG, screen recording, tall full-page capture).
3. **File-name hint** with the `<NAME>` placeholder, what it usually contains in this library, and
   a rule to ignore IDs and never let it override the image.
4. **Tagging rules** shared by every tag rule (the block below).
5. **Writing rules** shared by every description.
6. **Casing exceptions** for brands and platforms.

Reusable tagging-rules block (adapt the examples to the domain):

```text
Tagging rules (apply to every tag list):
- Tag only what is clearly visible. Never guess; an empty list is better than a wrong tag.
- Prefer the terms in each rule's list. Add a new tag only when no listed term fits, using the standard industry name.
- One tag per concept: no synonyms, plurals, or variants of a tag you already chose. Use singular nouns and US spelling.
- Skip anything true of nearly every item unless it is the focus of the image. A tag that applies to everything is useless as a filter.
- Each concept belongs in exactly one rule; don't repeat a tag across rules.
- Keep official capitalization for product and brand names (iOS, shadcn/ui, GitHub).
```

File-name hint pattern:

```text
File name: <NAME>
The file name may contain the product or site name (e.g. "4kimagecompressor_GEm9DF6msB" suggests 4K Image Compressor). Treat it as a hint only: ignore random IDs and never let it override what the image shows.
```

Only use `<DESCRIPTION>` when the existing description holds human-written context (source,
client, notes) worth reading. On re-runs it also contains earlier AI output.

## Anatomy of a rule instruction

One paragraph, 40–140 words, built from these parts in order (skip parts that don't apply):

| Part            | Purpose                                            | Example                                                    |
| --------------- | -------------------------------------------------- | ---------------------------------------------------------- |
| Label           | Maps the numbered line to its JSON key             | `Density:`                                                 |
| Task            | The one question this facet answers                | `How tightly is information packed?`                       |
| Cardinality     | Overrides the plugin's "only one" list label       | `Return exactly one tag.`                                  |
| Definitions     | Pins down borderline values                        | `Compact = tight spacing, small type, many rows per view.` |
| Scope           | What to look at and what to ignore                 | `Ignore decorative backgrounds behind mockups.`            |
| Evidence test   | For names and inferences                           | `Use the file name, logos, and window titles as evidence.` |
| Empty condition | When returning nothing is correct                  | `Return an empty list if the domain is unclear.`           |
| Format          | Length, bullets, casing for descriptions and names | `2–4 bullet points, each starting with "- ".`              |

Don't restate the tag list inside the instruction; the plugin appends it. Refer to specific
values only when defining or contrasting them.

## Templates by rule kind

Replace angle-bracket slots; keep the structure.

### Specific, single value

```text
<Name>: <Question>? Return exactly one tag. <Value A> = <definition>. <Value B> = <definition>. <Value C> = <definition>.
```

### Specific, several values

```text
<Name>: <Question>? Return every tag that applies (usually one or two). <Value> = <definition>. <Value> = <definition>. Never combine <X> with <Y>.
```

### Example, open vocabulary

```text
<Name>: List the <things> that are clearly visible and meaningful, usually <m>–<n> tags. Use the most specific accurate name (<specific> rather than <generic>). Skip <ubiquitous things> unless the image is focused on them. Return an empty list if <condition>.
```

### N/A, proper nouns

```text
<Name>: Name the <entity> this item belongs to, using its official name and capitalization (e.g., <A>, <B>). Use <evidence sources> as evidence. Do not tag <incidental mentions>. Return an empty list for <unknown or generic cases>.
```

### Short description

```text
<Name>: Write one sentence of at most <n> words that tells a <audience> what this is at a glance: <element 1>, <element 2>, and the single most distinctive <trait>. Lead with the subject. Example: "<one realistic sentence>"
```

### Long description for search

```text
<Name>: Write <m>–<n> words in <k> short paragraphs for full-text search. (1) <aspect>: <what to cover>. (2) <aspect>: <what to cover>. (3) <aspect>: <what to cover>. Be factual and don't transcribe long text.
```

### Notes or analysis

```text
<Name>: Write <m>–<n> bullet points, each starting with "- ", on <what makes it worth saving>. If there is an obvious weakness, add one bullet for it. Be specific to this item and avoid generic praise like "clean and modern".
```

### Text transcription (OCR)

```text
<Name>: Transcribe the meaningful visible text in reading order, grouped by region, one item per line. Summarize long paragraphs in square brackets instead of copying them, include only the first three items of long repeated lists, and keep the original language and capitalization. If there is no readable text, return an empty string.
```

### Name rule (rename)

```text
Name: Write a descriptive file name of <m>–<n> words in Title Case: <subject>, <setting>, and one distinctive <quality>. Keep meaningful words from the current file name, drop camera codes, IDs, and dates, and don't add a file extension. Use only letters, digits, spaces, and hyphens. If the current name is already descriptive, return it unchanged.
```

### Prompt reconstruction (AI-generated images)

```text
Prompt: Write a text-to-image prompt of <m>–<n> words that would recreate this image: subject, composition, medium or rendering style, lighting, color palette, and mood, in comma-separated phrases from most to least important. Don't name living artists.
```

## Style rules

- Imperative voice, present tense, concrete nouns.
- Ask for the **value**, never a yes/no ("Is it dark mode?" produces `Yes`-shaped answers).
  Write "Which color scheme …? Return exactly one tag."
- Define terms with `=` inline; one short clause each.
- Give one realistic example for descriptions, drawn from the target domain.
- Say what to ignore (mockup backgrounds, logos inside photos, tiny distant figures).
- Numbers beat adjectives: "at most 30 words", "usually 5–15 tags".
- Avoid "etc." chains and long parenthetical lists; the tag list already carries the vocabulary.
- No markdown headers inside instructions (the plugin already uses `##`). Plain sentences and
  quoted examples only.
- Straight quotes inside instructions are fine in JSON when escaped (`\"`); the validator checks
  the file parses.

## Before and after

Original default "Aesthetic Adjectives" rule:

```text
Adjectives to describe the aesthetic. These adjectives should be design focused — the kind of adjectives you would use to describe it to a knowledgeable designer friend. Do not use general adjectives like 'clean'.
```

Problems: no label, no cardinality, open Example list of five adjectives, no definitions. It
produced about 30 near-synonyms across 36 items.

Rewrite (Specific list of 32 defined styles, prefix `Style`):

```text
Visual Style: Choose the 1–3 terms that most distinctively characterize this design's look, the words that would set it apart in a grid of other interfaces. Don't pick a term that describes nearly every modern UI: use Minimalist only for exceptionally sparse layouts with generous empty space, and Utilitarian only for function-first tools with plain, default-looking controls. Color terms (Pastel, Neon, Muted, Monochrome, etc.) describe the overall palette, not a single accent.
```

Original default "Color Scheme" rule: `Is it dark mode, light mode, or both?`

Rewrite:

```text
Color Scheme: Return exactly one tag. Light or Dark describes the dominant background of the UI itself; ignore decorative backgrounds behind mockups and individual dark or light sections. Use Both only when the image deliberately shows the same UI in light and dark variants.
```

## Local-provider variant

For Ollama and LM Studio the plugin sends each rule alone, **without Global Instructions**. When
the user targets a local model:

- Keep the preset to 3–6 rules.
- Fold the essential context into each instruction: one clause of role ("In this app icon, …"),
  the evidence rule, and the empty-list condition.
- Prefer Specific lists; small local models follow closed lists far better than open ones.
- Drop `<NAME>`-dependent logic (it isn't available per rule).
- Keep descriptions short; small models loop or truncate on long ones.
