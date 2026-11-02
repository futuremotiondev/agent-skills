---
name: fm-product-design
description: "Use when designing, critiquing, or systematizing product UI/UX: design systems, design tokens, visual identity, UX flows, onboarding, accessibility (WCAG 2.2 AA), voice UI, or Figma handoff."
risk: safe
source: community
date_added: '2026-03-06'
author: renat
tags:
- design
- ux
- design-systems
- design-tokens
- accessibility
- figma
- voice-ui
tools:
- claude-code
- antigravity
- cursor
- gemini-cli
- codex-cli
---

# Product Design: Apple-Level Craft

## Overview

Apple-level product design as an operating discipline: proprietary visual language, design systems and tokens, UX flows, onboarding, accessibility, motion, voice interfaces, prototyping, and developer handoff. The skill turns a design request into a defined deliverable with an explicit shape, verifiable numbers (contrast ratios, target sizes, type and spacing scales), and stated trade-offs, so the output can be built and reviewed rather than admired.

> "Design is not just what it looks like and feels like. Design is how it works."
> Steve Jobs

## When to Use This Skill

- Designing, redesigning, or reviewing a screen, flow, component, or an entire product UI
- Building a design system, a component library structure, or design tokens (color, type, spacing, radius, shadow, motion) with light and dark modes
- Defining a visual identity or brand language for a product: palette, typography, logo rules, imagery, motion personality
- Critiquing a mockup, a described screen, or an implemented UI, including "does this feel right" requests
- Reviewing accessibility or running a WCAG 2.2 AA audit at design time
- Designing onboarding, empty states, loading states, error handling, forms, or a voice and conversational interface
- Structuring Figma files, prototypes, or a design-to-development handoff
- Symptoms: inconsistent spacing or colors across screens, "it looks generic or AI-generated", low-contrast text, icon-only actions, unclear hierarchy, users dropping off during onboarding

## Do Not Use This Skill When

- The design is fixed and the task is implementation only (use `frontend-design` or a framework skill)
- The task is marketing copy, growth, pricing, or analytics rather than product UX (see Related Skills)
- A formal WCAG conformance report with assistive-technology testing is required (use `accessibility-compliance-accessibility-audit`)
- The user wants a single color or font suggestion with no product context; answer directly

## How It Works

### Step 1: Establish context before designing

In a codebase, look for a theme or token source (`tailwind.config.*`, `theme.*`, CSS custom properties, a `tokens/` folder, Figma variable exports), a component library, brand guidelines, and platform targets. From the user, confirm the inputs below.

| Input                | Why it matters                                     | If missing                                           |
| -------------------- | -------------------------------------------------- | ---------------------------------------------------- |
| Product and audience | Sets tone, density, and the accessibility baseline | Infer from the request and state the inference       |
| Platforms            | iOS, Android, web, desktop, and voice change rules | Assume web plus mobile and say so                    |
| Existing system      | Never invent tokens or components that exist       | Propose a minimal system and flag the gap            |
| Brand constraints    | Palette, type, and logo rules bound the solution   | Use neutral placeholders; never borrow another brand |
| Accessibility target | WCAG 2.2 AA is the default floor                   | Design to AA and note where AAA is cheap             |
| Success measure      | Critique and onboarding need a metric              | Propose one (task completion rate, activation rate)  |

Ask at most three questions, and only when the answer would change the deliverable materially. Otherwise proceed and open the deliverable with an "Assumptions" block.

### Step 2: Pick the mode

Match the request to one mode from the Modes table. Composite requests run modes in sequence (a new product runs Visual Identity, then Design System, then UX Flow).

### Step 3: Produce the deliverable in its contract shape

Fill every slot of the mode's output shape; write "Not applicable" rather than dropping a slot. Use real values (hex, px, ms, ratios), not adjectives. Every color pair used for text or essential UI carries its contrast ratio, computed with `scripts/contrast.py` or an equivalent tool, never estimated. When a value needed for a ratio was not provided, list the pair under Open questions instead of substituting a guess.

### Step 4: Run the quality gates

Check the deliverable against the UI Critique Checklist and the Quick Reference numbers. Anything that fails a gate is fixed or listed under "Known gaps" with a reason.

### Step 5: Close with trade-offs and next steps

End with the trade-offs the recommendation makes, what still needs user testing or engineering validation, and the single highest-leverage next action.

## Modes and Output Contracts

| Mode            | Trigger phrases                          | Required output shape                                                                                                                                              |
| --------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Design Critique | critique, review, feedback, audit the UI | Assumptions; findings ordered by severity, each with Observation, Principle, Impact, Recommendation, Trade-off; what works; prioritized next steps; open questions |
| Design Tokens   | tokens, theme, palette, dark mode        | Primitive, semantic, and component tiers; light and dark values; contrast table; naming rules; platform export notes; JSON                                         |
| Design System   | design system, component library         | Folder structure; token tiers; component inventory with states; pattern docs; governance and versioning                                                            |
| UX Flow         | flow, journey, user path, steps          | Entry, Context, Action, Feedback, Outcome, Next Step per stage; loading, empty, error, and success states per stage; decision points; success metric               |
| Onboarding      | onboarding, first run, activation        | Screen-by-screen skeleton with goal, content, CTA, skip path, and the activation metric it moves                                                                   |
| Accessibility   | accessibility, a11y, WCAG, screen reader | WCAG 2.2 AA criteria table with status (pass, fail, verify), evidence, and fix; keyboard and screen-reader notes                                                   |
| Voice UX        | voice, Alexa, assistant, conversational  | Persona and tone; response structure; error and silence handling; sample scripts for first use, return, misunderstanding, exit                                     |
| Visual Identity | brand, identity, look and feel, logo     | Concept statement; palette with roles and contrast; type system; logo rules; imagery; motion personality; do and don't list                                        |

Every deliverable, whatever the mode, also ends with Trade-offs, Known gaps, and Next step (Steps 4 and 5). Severity scale for critiques and audits: Blocker (prevents task completion or fails a WCAG A or AA criterion), Major (measurable friction or inconsistency), Minor (polish with a clear fix), Nit (taste).

## Design Principles

### Ten Apple-inspired principles

A working synthesis of Apple's design culture, not an official list.

1. Radical simplicity: remove everything that is not essential
2. Material honesty: every element exists for a reason and looks like what it does
3. Restraint is a decision: less, chosen deliberately, reads as more
4. Systemic coherence: everything belongs to one system
5. Details are felt even when they go unnoticed
6. Function defines form: aesthetics serve the purpose
7. Durability: design that ages well beats design that trends
8. Accessibility by default, never as an add-on
9. Continuity across screens: one unified experience
10. Delightful surprise: the unexpected that charms without distracting

### Cognitive design

- Near-zero cognitive load: the user should never have to think about the interface
- Clear affordances: what is tappable looks tappable, and what is disabled looks disabled
- Immediate feedback: every action gets a visible response within 100 ms
- Error prevention over error messages: constrain input so mistakes are hard to make
- Recognition over recall: show options instead of making users remember them
- Progressive disclosure: reveal complexity only when it is needed

## Quick Reference: Numbers That Matter

| Area              | Rule                                                                                                                                                                    |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Text contrast     | 4.5:1 for body text; 3:1 for large text (24 px regular or 18.66 px bold) (WCAG 1.4.3)                                                                                   |
| Non-text contrast | 3:1 for component boundaries, focus rings, and icons that carry meaning (WCAG 1.4.11)                                                                                   |
| Target size       | 24x24 CSS px minimum (WCAG 2.5.8 AA); 44x44 pt on iOS (HIG); 48x48 dp on Android (Material); 44x44 is the safe default                                                  |
| Focus             | Visible focus on every interactive element (2.4.7); focus never fully hidden by sticky UI (2.4.11)                                                                      |
| Body type         | 16 px web minimum; 17 pt iOS default; 16 sp Android; line-height 1.4 to 1.6; measure 45 to 75 characters                                                                |
| Headings          | Line-height 1.1 to 1.25; pick one modular scale ratio (1.2 to 1.333) and keep it                                                                                        |
| Spacing           | 4 px base grid; 8 px rhythm for components; 16 to 24 px content gutters                                                                                                 |
| Radius            | One family (for example 4, 8, 12, 16, full); nested radii shrink inward                                                                                                 |
| Motion            | Micro-interactions 100 to 150 ms; standard transitions 200 to 300 ms; complex or spatial 300 to 500 ms; ease-out for entrances, ease-in for exits; honor reduced motion |
| Feedback latency  | Under 100 ms feels instant; over 1 s needs a progress indicator; over 10 s needs a way out                                                                              |
| Reflow and zoom   | Usable at 320 CSS px width and 200 percent zoom without horizontal scrolling (1.4.10, 1.4.4)                                                                            |
| Forms             | Persistent visible labels; placeholder is never the only label; errors identified in text, not color alone (1.3.1, 1.4.1, 3.3.1)                                        |
| Dragging          | Every drag interaction has a single-pointer alternative (2.5.7)                                                                                                         |
| Re-entry          | Never ask for the same information twice in one flow (3.3.7)                                                                                                            |

## Design System Structure

```text
design-system/
├── tokens/
│   ├── primitives.json    # raw palette, type scale, spacing scale (no meaning)
│   ├── semantic.json      # roles: text.primary, surface.raised, border.focus
│   ├── components.json    # button.primary.bg, input.border.error
│   └── modes/             # light.json, dark.json, high-contrast.json
├── components/
│   ├── atoms/             # Button, Input, Icon, Badge, Checkbox
│   ├── molecules/         # Card, FormField, NavItem, Toast
│   └── organisms/         # Header, Sidebar, Modal, DataTable
├── patterns/
│   ├── onboarding.md      # first run
│   ├── empty-states.md    # nothing here yet
│   ├── loading.md         # skeletons, spinners, optimistic UI
│   ├── errors.md          # validation, recovery, offline
│   └── forms.md           # layout, labels, validation timing
└── guidelines/
    ├── voice-tone.md      # product voice, microcopy
    ├── imagery.md         # photography, illustration, icon style
    ├── motion.md          # durations, easing, choreography
    └── accessibility.md   # WCAG 2.2 AA commitments, testing
```

Token tiers: primitives hold raw values with no meaning (`blue.500`), semantic tokens assign roles (`color.text.primary`), and component tokens bind roles to parts (`button.primary.bg`). Components consume semantic or component tokens only. The full token architecture, naming rules, dark-mode method, platform export rules, and a complete JSON example are in [references/design-tokens.md](references/design-tokens.md).

## UX Patterns

A UX flow is documented stage by stage: Entry Point, Context, Action, Feedback, Outcome, Next Step, with loading, empty, error, and success states per stage. Onboarding follows a four-screen skeleton (promise, immediate value, light personalization, aha moment) with a skip path on every screen and one activation metric. Empty states show an opportunity, not an absence. Templates, recipes, and form rules (labels, keyboards, autofill, error messages) are in [references/ux-patterns.md](references/ux-patterns.md).

## Voice and Conversational UX

Voice interfaces have zero visual load, so brevity, reversibility, and varied phrasing carry the experience. Responses follow Hook (optional), Core answer, then Action or question. Confirmations are reserved for irreversible actions, and silence gets about two seconds before the assistant offers help. Principles, the error recovery ladder, and sample scripts are in [references/voice-ui.md](references/voice-ui.md).

## Critique Framework

Every finding uses five parts: Observation (what is there, without judgment), Principle (which principle or criterion is being tested), Impact (what it costs the user, with a number when possible), Recommendation (a concrete alternative), Trade-off (what the alternative gives up).

### UI critique checklist

- [ ] Visual hierarchy is clear: the eye knows where to go first, second, third
- [ ] Contrast meets 4.5:1 for text and 3:1 for UI components
- [ ] Touch targets are at least 44x44 pt on mobile and 24x24 CSS px on web
- [ ] Every input has a persistent visible label; placeholders are hints only
- [ ] Interactive states are defined: default, hover, active, focus, disabled, loading
- [ ] Errors are identified in text, placed next to the field, and say how to fix them
- [ ] Loading, empty, and error states exist for every data-driven view
- [ ] Layout follows the design system's tokens and spacing grid
- [ ] Responsive behavior is defined mobile-first and reflows at 320 CSS px
- [ ] Keyboard navigation, focus order, ARIA roles, and screen-reader labels are specified
- [ ] The primary action is unmistakable, reachable, and labeled with a verb
- [ ] Progress is visible in multi-step flows
- [ ] Perceived performance is handled: skeletons, optimistic UI, sub-100 ms feedback
- [ ] Motion has purpose and respects reduced-motion preferences

The full critique template, the WCAG 2.2 AA audit table, and a worked critique are in [references/critique-and-audit.md](references/critique-and-audit.md). A complete visual-identity deliverable, including a contrast repair, is in [references/worked-example-auri.md](references/worked-example-auri.md).

## Tooling and Process

| Tool                            | Use                                                                     |
| ------------------------------- | ----------------------------------------------------------------------- |
| Figma and FigJam                | UI design, variables as tokens, prototyping, Dev Mode handoff, journeys |
| Tokens Studio, Style Dictionary | Token authoring and multi-platform export (CSS, iOS, Android, Tailwind) |
| Storybook, Zeroheight           | Component state coverage and design system documentation                |
| Lottie                          | Production animation exported from After Effects or Figma               |
| Mobbin                          | Real-product pattern reference                                          |
| WebAIM, Stark, `contrast.py`    | Verify every text and UI color pair                                     |

Verify a color pair from the skill folder:

```bash
python scripts/contrast.py "#374151" "#FFFFFF"
```

Five-day design sprint: Monday understand (research, interviews, define the problem); Tuesday diverge (crazy 8s, sketches, lightning demos); Wednesday decide (vote, storyboard); Thursday prototype (high fidelity in Figma); Friday test (five users, insights, iterate).

## Examples

### Example 1: Critique finding

```markdown
### 1. [Blocker] Placeholder text is the only field label

- Observation: The four card fields show gray (#B0B0B0) placeholder text on white and no label.
- Principle: Recognition over recall; WCAG 1.3.1, 1.4.3, 3.3.2.
- Impact: Placeholders vanish on input, so users lose the field's meaning mid-entry. #B0B0B0 on #FFFFFF is 2.2:1, below the 4.5:1 minimum.
- Recommendation: Add persistent labels above each field in #374151 (10.3:1) and keep placeholders for format hints such as "MM/YY".
- Trade-off: Adds about 20 px of height per field; the form may need to scroll on small devices.
```

### Example 2: Semantic token excerpt with light and dark values

```json
{
  "color": {
    "text": {
      "primary": {
        "$type": "color",
        "$value": "{color.gray.900}",
        "$extensions": { "mode": { "dark": "{color.gray.50}" } }
      }
    },
    "action": {
      "primary": {
        "$type": "color",
        "$value": "{color.brand.600}",
        "$extensions": { "mode": { "dark": "{color.brand.400}" } }
      }
    }
  }
}
```

The accompanying contrast table lists each pair, for example `text.primary` on `surface.default`: 17.7:1 light, 19.3:1 dark.

## Best Practices

- ✅ Start from the existing system and extend it before inventing
- ✅ State assumptions up front instead of stalling on questions
- ✅ Give numbers: hex, px, ms, ratios, and the WCAG criterion being applied
- ✅ Design all states: default, hover, focus, active, disabled, loading, empty, error, success
- ✅ Ship dark mode as its own semantic mapping with its own contrast checks, never as an inversion
- ❌ Don't use placeholder text as the only label, or color as the only signal of state
- ❌ Don't carry a worked example's palette, name, or copy into a different product
- ❌ Don't present a critique as a flat list of opinions without severity, impact, or trade-offs

## Common Pitfalls

- **Problem:** The deliverable looks generic (purple gradient, everything rounded, stock illustration).
  **Solution:** Derive palette and type from the product's audience and content; name the one distinctive idea the identity is built on and let everything else stay quiet.
- **Problem:** Tokens are a flat list of hex values with no roles, or CSS strings a native app cannot consume.
  **Solution:** Build primitive, semantic, and component tiers; store unitless numbers and per-platform shadows; let the export layer add units.
- **Problem:** Dark mode fails contrast or looks muddy.
  **Solution:** Map each semantic token to a dark value independently, lighten the brand color one or two steps, raise surfaces with lighter tints instead of shadows, and recheck every pair.
- **Problem:** Accessibility is a checkbox at the end.
  **Solution:** Bake the Quick Reference numbers into the first draft and run the audit table before presenting.
- **Problem:** Onboarding asks for signup before showing value.
  **Solution:** Move the first real action before registration and defer profile questions until after the aha moment.

## Related Skills

- `ux-flow` - Deeper screen-structure and navigation patterns (progressive disclosure, hub-and-spoke)
- `ui-tokens` - Token pipeline and export tooling details
- `fixing-accessibility` and `accessibility-compliance-accessibility-audit` - Remediation in code and formal conformance audits
- `frontend-design` - Implementing the design in code once it is specified
- `brand-guidelines` and `mobile-design` - Company brand rules and platform-specific iOS and Android conventions
- `voice-agents` - Building the voice agent behind a voice UX
- `analytics-product`, `growth-engine`, `monetization`, `product-inventor` - Companion product skills from the same series

## Limitations

- Design reasoning only: it does not render mockups or run user tests. Contrast ratios are computed from stated hex values and must be recomputed whenever a value changes.
- It reviews designs as described; it cannot see a screenshot unless one is provided, and an audit here is not a formal WCAG conformance claim.
- Platform guidance reflects Apple HIG, Material, and WCAG 2.2 as of 2026; check for newer platform releases when precision matters.
- Stop and ask when brand constraints, platform targets, or the success measure are missing and the answer would change the deliverable.
