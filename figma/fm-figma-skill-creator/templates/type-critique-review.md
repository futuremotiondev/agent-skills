---
name: fm-<lens>-critique
description: Critiques the selected frames, flow, or Make screen through <the lens: e.g. "a conversion-focused product lens">, returning at most five findings ranked P0 to P3 with visible evidence and one concrete change each. Use whenever the user asks to "critique this", "review this design", "give feedback on", "what would <persona> say", or wants a design review before a share-out. Not for applying fixes (use /fm-<fix-skill>) and not for copy-only reviews (use /fm-ux-writing-review).
metadata:
  version: "1.0"
  author: "Futuremotion Studio"
  category: "<one of the six Community categories>"
  tags: "<comma-separated, lowercase>"
  applies-to: "<pattern and surface>"
  runtimes: "figma-design, figma-make, mcp"
---

# <Lens> critique

Reviews one coherent target and returns actionable findings. The output is a report in chat. This skill is read-only: it never reparents, edits, locks, or restyles the frames under review, and it does not redesign unless the user asks for a follow-up.

Three principles matter more than the template: every finding carries visible evidence, every recommendation names what should move, change, shrink, grow, or be clarified, and severity reflects user impact, not taste.

## When to use

- The user asks for a critique, review, audit, or feedback on selected frames, a flow, a component set, or a Make screen.
- The user names the lens ("review this like <persona>", "<lens> pass").
- **Do not** use this to make changes. If the user asks to fix something after the critique, name the highest-leverage finding and ask for confirmation before editing (use /fm-<fix-skill> if one exists).

## Before you start

1. **Check the surface.** Figma Design: critique the selected layers. Figma Make: critique the current screen's navigation, states, and feedback paths. A screenshot or reference with no editable context: critique what is visible and say so.
2. **Resolve the target.** Use the selection. If nothing is selected, ask, verbatim (through a structured question tool when the runtime has one; plain text otherwise):
   > Nothing's selected. 1. Review the current page, or 2. select the frames you want reviewed?
   If the target is too broad (a whole product, brand, and system at once), narrow to one surface and state the boundary.
3. **Confirm the lens inputs.** <Persona notes, product goal, audience, constraints.> If a stated constraint is missing, say so and ask; never assume the audience.

## Instructions

1. **Read before judging.** Walk the selected frames; collect what each screen is for, the primary action, the states shown, and the components and styles used. Skip hidden layers unless asked.
2. **Apply the lens, in order.** <Lens item 1: question to ask of the work.> <Lens item 2.> <Lens item 3.> <Lens item 4.> <Lens item 5.>
3. **Score each candidate finding.** P0 blocks the primary task or creates serious misunderstanding; P1 likely harms comprehension, conversion, accessibility, or completion; P2 noticeable quality issue; P3 polish. Drop anything without visible evidence.
4. **Keep the five strongest.** Prefer fewer, stronger findings. List rejected candidates in one line each so the user sees what was considered.
5. **Verify.** Re-check each cited layer name and value against the canvas before reporting.

## Output contract

```markdown
## Critique: <target>
- Target: <frame names>
- User and task assumption: <one line>
- Evidence available: <selection / screenshot / Make screen>
- Confidence: <high / medium / low and why>

## What is working
- <1 to 3 specific, concrete points>

## Findings
| Priority | Problem | Evidence (layer, value) | User impact | Recommended change |
| --- | --- | --- | --- | --- |

## Improve first
- <The single highest-leverage change and why.>

## Rejected candidates
- <One line each.>

## Questions or assumptions
- <Only if needed.>
```

Report only this. No canvas changes. Confirm at the end that no layer was modified.

## Do and do not

### Name the change, not the virtue

- **Do:** "Move the primary CTA above the fold: 'Start trial' sits at y=1,420 on a 1,080-tall viewport."
- **Do not:** "Improve the hierarchy."

### Evidence over inference

- **Do:** "Body text #767676 on #FFFFFF measures 4.5:1 only at 16 px; the 12 px caption fails."
- **Do not:** "Accessibility looks weak."

### Taste is labelled

- **Do:** "Taste call, not a defect: the illustration style reads playful next to a formal headline."
- **Do not:** Presenting a preference as a P1.

## Examples

**Request:** "Critique this onboarding flow" with three frames selected.
**Result:** The report above with up to five findings, the "Improve first" line, and no canvas edits.

**Request:** "Fix the worst one" after the critique.
**Result:** Name the P0 and ask for confirmation of the exact change before editing; if the user confirms, hand off to /fm-<fix-skill> or apply the single narrow edit and report it.

## Common edge cases

- **Wrong node type or an instance only.** Say what is selected and ask whether to review it alone or its parent frame.
- **No supported findings.** Say so, name the remaining uncertainty, and stop. Do not invent issues.
- **Make screen.** Separate Design issues from Make behaviour issues (navigation, empty, error, loading states).
- **Persona lens.** Frame it as "a <persona>-style critique" and flag questions that need the real stakeholder.

## Final gate: do not finish until every line is true

- [ ] Every finding has evidence read from the canvas
- [ ] At most five findings, each with one concrete change
- [ ] Severity reflects user impact, not taste
- [ ] No layer was modified
