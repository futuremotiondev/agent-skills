# Taxonomy Design

How to turn "tag my library" into a set of facets, rule types, vocabularies, and prefixes that
stay useful for filtering after thousands of items. Read before drafting any rules.

## Contents

- [Start from retrieval questions](#start-from-retrieval-questions)
- [Choose the rule type for each facet](#choose-the-rule-type-for-each-facet)
- [State cardinality](#state-cardinality)
- [Prefixes and tag naming](#prefixes-and-tag-naming)
- [Vocabulary rules](#vocabulary-rules)
- [What not to tag](#what-not-to-tag)
- [Rule order](#rule-order)
- [Budgets](#budgets)
- [Anti-patterns seen in real libraries](#anti-patterns-seen-in-real-libraries)
- [Multiple presets and hierarchies](#multiple-presets-and-hierarchies)

## Start from retrieval questions

Tags exist to answer searches. Before choosing any tag, write down 5–10 searches the user will
actually run, then extract the dimensions (facets) they combine:

| Search the user runs                                | Facets it needs                                     |
| --------------------------------------------------- | --------------------------------------------------- |
| "Dark desktop dashboards with a Kanban board"       | Color Scheme, Device Type, Screen Type, UI Patterns |
| "Glassy macOS-style icons with a lettermark"        | Style, Design Language, Mark                        |
| "Backlit portraits at golden hour for lighting ref" | Genre, Lighting, Use Case                           |
| "Everything from Stripe"                            | Brand                                               |

Each facet should answer exactly one question ("What device is this for?", "How is it
rendered?"). If a facet's instruction needs "and" to describe its job, split it.

When the user supplies samples (a zip, a folder, Eagle items), look at 20–40 of them before
fixing the facet list. The facets should follow real variation in the collection: a facet on
which every sample gets the same value filters nothing.

## Choose the rule type for each facet

| Facet shape                                                | Rule type   | Tags type | Example facets                        |
| ---------------------------------------------------------- | ----------- | --------- | ------------------------------------- |
| Small closed set, one value per item                       | Tags        | Specific  | Color Scheme, Density, Framing, Scope |
| Small closed set, several values per item                  | Tags        | Specific  | Typeface, Platform, Presentation      |
| Open but conventional vocabulary                           | Tags        | Example   | UI Components, Subjects, Motif        |
| Proper nouns (unbounded)                                   | Tags        | N/A       | Brand, Location, Artist, Icon Set     |
| Rich detail too varied for tags; full-text search material | Description | —         | Summary, Detailed Description         |
| Opinion, analysis, or transcription                        | Description | —         | Design Notes, Visible Text, Prompt    |
| Messy file names the user wants fixed                      | Name        | —         | Name (only when asked; it's a rename) |

Guidance:

- **Specific** guarantees consistency (providers with strict schemas enforce the enum). Prefer
  it whenever the set can be listed in under ~40 values. Style, mood, and quality facets
  benefit most, because open adjective lists drift into synonyms.
- **Example** suits noun vocabularies that keep growing (components, objects). The model may
  add close matches, so the instruction must say to prefer listed terms.
- **N/A** is for names only. Always add a strict evidence rule and an empty-list condition, or
  the model will pad it with incidental mentions.
- **Descriptions are searchable.** Eagle's search covers the description text, so a well-ordered
  Detailed Description catches everything the tags don't. That's why tags can stay lean.
- **Name rules rename the item in Eagle.** Include one only when the user asks for renaming, and
  warn that it changes every processed item's name.

## State cardinality

Every tag rule's instruction says how many tags to return:

| Cardinality        | Wording to use                              | Typical facets                 |
| ------------------ | ------------------------------------------- | ------------------------------ |
| Exactly one        | "Return exactly one tag."                   | Density, Framing, Color Scheme |
| One, rarely more   | "Return one tag, or up to three if …"       | Screen Type, Device Type       |
| Bounded            | "Return 1–3 tags." / "Return up to three …" | Visual Style, Mood, Category   |
| Open               | "List …, usually 5–15 tags."                | UI Components, Subjects        |
| Every that applies | "Return every tag that applies."            | Typeface, Presentation         |
| Optional           | "… Return an empty list if …"               | Brand, Design System, Location |

This matters because the plugin labels every Specific list "Should be only one of these tags",
which models may read as "pick one" even for multi-select facets.

## Prefixes and tag naming

Eagle shows tags alphabetically in one flat list, so a prefix groups a facet's tags together and
disambiguates short values (`Scope: Full Page` instead of a bare `Full`).

- **Prefix** closed facets (Specific) and proper-noun facets (N/A): `Style:`, `Density:`,
  `Brand:`, `Platform:`. Bare values like `Dark`, `Full`, `None`, `Other`, or `Both` are
  meaningless in a shared tag list.
- **Don't prefix** open noun vocabularies (components, subjects, patterns). Those tags read
  naturally, stay short to type, and can be shared across presets.
- Prefix text: 1–2 words, Title Case, singular, no trailing colon (the plugin adds the colon and space).
  Keep Include Space on.
- **Keep existing prefixes** when optimizing a preset, so tags already in the library stay
  valid (`Device Type:` stays `Device Type:` even if you'd name it differently today).
- Suffix modifiers render without a colon (`Blue Accent`). They're rarely better than a prefix.
- Eagle **tag groups** are an alternative way to organize unprefixed tags. After a pilot run,
  offer to create one group per facet (see [library-integration.md](library-integration.md)).

## Vocabulary rules

- Title Case, singular nouns, US spelling. Brand casing is the only exception (iOS, macOS,
  shadcn/ui, GitHub), and the exceptions are named in Global Instructions.
- One concept per tag: no slashes (`Chip/Pill`), no commas (the editor splits on commas), and no
  "and" pairs unless the pair is the established name (`Black and White`).
- No synonyms in one list or across lists: `Switch` or `Toggle`, `Minimal` or `Minimalist`.
- Mutually exclusive values within single-choice facets; define borderline terms inside the
  instruction (`Compact = tight spacing, small type, many rows per view`).
- Balanced granularity: don't mix `Chart` with `Bar Chart`. Pick the level that answers the
  retrieval questions.
- Short: 1–3 words, rarely 4.
- Specific lists: 3–30 values (hard ceiling around 60). Example lists: 20–120 values.
- Reuse the library's existing vocabulary when it's sound. Check it with Eagle MCP before
  inventing new terms.
- Avoid catch-alls like `Other` and `Misc`; an empty list says the same thing without polluting
  the tag list. Keep `Other` only for a single-choice facet that must always have a value.

## What not to tag

- **Universal values.** If a tag would land on most items (`Button`, `Icon`, `Minimal` on a UI
  library, `English` on an English-only library), it can't narrow a search. The evidence from a
  real library: `Minimal` on 33 of 36 items, `Neutral` on 33, `Divider/Separator` on 33.
- **Hue.** Eagle already extracts color palettes and filters by color. Tag color *treatment*
  (Pastel, Neon, Monochrome) instead of hue names.
- **File facts Eagle already stores:** dimensions, orientation, format, file size, date, source
  URL, rating.
- **Things the model can't see** (who made it, when, why) unless the file name or visible text
  states them.
- **Vague praise** (`Clean`, `Modern`, `Professional`, `Beautiful`). Ban it in the instruction.

## Rule order

Order is prompt order and JSON output order. Models generate keys in order, so earlier rules act
as reasoning for later ones.

1. Short description (Summary or Caption).
2. Detailed description. This is where the model "looks carefully" before tagging.
3. Framing facets: what kind of item is this (Scope, Presentation, Genre, Container).
4. Content facets: what's in it (Screen Type, Patterns, Components, Subjects, Motif).
5. Context facets: Category, Brand, Location, Design System.
6. Style facets: Visual Style, Density, Color, Typeface, Lighting.
7. Analysis descriptions (Design Notes, Takeaways).
8. Long transcription (Visible Text, OCR) last, so a long output can't crowd out the tags.

A Name rule goes first when present, so the rename reflects the model's first impression and
the item's current name is still in context.

## Budgets

| Budget                     | Guideline                                                          |
| -------------------------- | ------------------------------------------------------------------ |
| Rules per preset (cloud)   | 6–20. Above ~22, fields start getting shallow or skipped.          |
| Rules per preset (local)   | 3–6. Each rule is a separate image request with no global text.    |
| Tags per item (all rules)  | Aim for 12–25. More than ~30 means universal or synonym tags.      |
| Description words per item | Summary ≤ 30; detailed 80–220; notes 2–4 bullets.                  |
| OCR / transcription        | The largest output cost. Include it only when text search matters. |

## Anti-patterns seen in real libraries

| Anti-pattern                                 | Symptom in Eagle                                                             | Fix                                            |
| -------------------------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------- |
| Open adjective list for style                | 30+ near-synonyms: Utilitarian, Functional, Utility-Focused, subdued/Subdued | Specific list of defined terms, 1–3 per item   |
| Universal example tags                       | Button, Icon, Header on nearly every item                                    | Drop them; instruct to skip ubiquitous basics  |
| Two rules for overlapping concepts           | Company and Brands both firing, duplicates                                   | Merge into one rule with a clear evidence test |
| Brand rule without an evidence test          | Brands from footer icons, dropdown values                                    | Tag only the product whose UI or asset it is   |
| Lowercase Specific values                    | `Typeface: sans-serif` among Title Case tags                                 | Title Case the enum values                     |
| Bare Specific values without prefix          | Tags named `Full`, `Partial`, `Both`                                         | Add a prefix or rename values                  |
| Description with title off after another one | Paragraph merges into the previous section                                   | Include Name as Title on                       |
| Yes/no question as an instruction            | "Is it dark mode?" → inconsistent values                                     | Ask for the value and define each option       |
| Unlabeled instructions                       | Values landing in the wrong field                                            | Start with `Rule Name:`                        |
| OS or platform leaking into style or brand   | `Windows`, `Desktop-Native`, `KDE Plasma` as styles                          | Dedicated Platform facet                       |

## Multiple presets and hierarchies

- **One preset per content type.** A UI screenshot, an icon, and a photo need different facets.
  Mixed libraries get several presets, each with its own skip tag, run on different selections
  or smart folders.
- **Versioned presets.** When replacing a preset, give the new one a new name and skip tag
  (`… v2`) so it can re-process items; see the migration notes in
  [library-integration.md](library-integration.md).
- **Hierarchies.** Eagle tags are flat. Model a hierarchy as two facets (`Category: Animal` plus
  `Subject: Dog`), or as a prefix per branch when branches have disjoint vocabularies. Don't
  encode paths like `Animal/Dog`.
- **Multilingual output.** To get tags in another language, say so in Global Instructions and
  write the vocabularies in that language. The appended "Tags should be title case." still
  applies, so specify casing for languages where Title Case is unusual.
