# Worked Example: Auri Visual Identity

A complete Visual Identity deliverable for Auri, a voice assistant, translated from the original author's brief. It shows the contract shape and how a contrast check changes a palette. Treat it as a pattern to follow, never as values to reuse: a different product gets its own concept, palette, and copy.

## Concept statement

Auri is intelligence with human warmth. Not a robot, a presence. The identity communicates approachable sophistication: precise, calm, and a little playful.

## Palette with roles and contrast

| Role                   | Name              | Hex     | Contrast                              | Verdict                                                  |
| ---------------------- | ----------------- | ------- | ------------------------------------- | -------------------------------------------------------- |
| Brand mark             | Auri Purple       | #6C63FF | 4.3:1 on white                        | Large text and UI only; fails 4.5:1 for body text        |
| Brand text and buttons | Auri Purple Dark  | #5A52E0 | 5.7:1 on white; 5.7:1 with white text | Body-size text, links, and primary buttons in light mode |
| Brand text on dark     | Auri Purple Light | #8F88FF | 5.8:1 on graphite                     | Body-size text and links in dark mode                    |
| Accent                 | Auri Pink         | #FF6B9D | 2.7:1 on white                        | Decorative only; never text or essential UI              |
| Surface                | Pure White        | #FFFFFF | Not applicable                        | Light-mode surface                                       |
| Ink and dark surface   | Soft Graphite     | #1A1A2E | 17.1:1 with white text                | Text in light mode; surface in dark mode                 |

What the check changed: the original brief used #6C63FF for everything. It passes for large text and component boundaries (3:1) but not for body-size text (4.5:1), so the deliverable adds a darker step for text and buttons in light mode and a lighter step (#8F88FF, 5.8:1) for text on graphite in dark mode. Pink is demoted to accents and gradients. Auri Purple on graphite is 4.0:1, so on dark surfaces it is reserved for large text and UI.

## Type system

| Role                 | Face                              | Weight and size       | Notes                  |
| -------------------- | --------------------------------- | --------------------- | ---------------------- |
| Display and headings | Inter (SF Pro on Apple platforms) | Bold 700; 48/36/28 px | Line-height 1.1 to 1.3 |
| Body                 | Inter                             | Regular 400; 16 px    | Line-height 1.6        |
| Mono and technical   | JetBrains Mono                    | Regular 400; 14 px    | Code, IDs, timestamps  |

## Logo rules

- Form: a stylized audio wave that forms the letter "A"
- Color: purple to pink gradient, left to right; solid Auri Purple Dark on light backgrounds when gradients are unavailable
- Negative space: suggests a microphone or an ear
- Variants: light and dark versions defined; a monochrome version for print
- Minimum size: 24 px for the icon, 120 px for the full lockup
- Clear space: the height of the "A" on all sides

## Imagery

Abstract sound waves and soft gradients; no stock photos of robots or headsets. Illustrations use the palette at 60 percent tint. Photography is warm and people-first.

## Motion personality

Calm and responsive: 150 ms ease-out for micro-interactions, 250 ms ease-in-out for transitions, and one spring (400 ms, `cubic-bezier(0.34, 1.56, 0.64, 1)`) reserved for the aha moment. Reduced-motion settings disable the spring.

## Voice scripts

The assistant's first-use, return, misunderstanding, and exit lines follow the shapes in the voice reference, with the name "Auri" and a warm, direct register. Full templates are in the voice reference file of this skill.

## Do and don't

- ✅ Use Auri Purple Dark for text and buttons, Auri Purple for large marks, pink for accents
- ✅ Keep generous white space; the identity breathes
- ❌ Don't put pink text on white
- ❌ Don't use the gradient on small type
- ❌ Don't reuse any of these values for a different product
