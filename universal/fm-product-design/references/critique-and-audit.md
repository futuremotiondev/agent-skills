# Critique and Accessibility Audit Reference

Companion to the fm-product-design skill for the Design Critique and Accessibility modes.

## Critique template

Copy this skeleton and fill every slot.

```markdown
## Design Critique: <screen or flow>

### Assumptions
- Platform(s):
- Audience and context:
- Existing system or brand constraints:
- Success measure:

### Findings (ordered by severity)

#### 1. [Blocker | Major | Minor | Nit] <short title>
- Observation: what is there, stated neutrally
- Principle: the design principle or WCAG criterion being tested
- Impact: what it costs the user, with a number where possible
- Recommendation: a concrete alternative with values
- Trade-off: what the alternative gives up

### What works
- Keep these, and say why

### Prioritized next steps
1. Blockers first, then majors, grouped by effort to fix

### Open questions
- Only questions whose answers would change a recommendation

### Known gaps and next action
- What could not be verified from the description and needs a build, a screenshot, or a user test
- The single highest-leverage next action
```

## Severity definitions

| Severity | Meaning                                                    | Examples                                                                        |
| -------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Blocker  | Prevents task completion or fails a WCAG A or AA criterion | Unlabeled inputs, 2:1 text contrast, primary action unreachable                 |
| Major    | Measurable friction, ambiguity, or inconsistency           | Icon-only primary action, no loading state, inconsistent spacing across screens |
| Minor    | Polish with a clear fix and limited impact                 | Misaligned baseline, radius mismatch, weak empty-state copy                     |
| Nit      | Taste; label it as such                                    | Preferring a different illustration style                                       |

## Heuristics to sweep

Run these in order and note which one each finding maps to.

1. Visibility of system status
2. Match between the system and the real world
3. User control and freedom (undo, back, cancel)
4. Consistency and standards (platform conventions and the design system)
5. Error prevention
6. Recognition over recall
7. Flexibility and efficiency (shortcuts, sensible defaults)
8. Aesthetic and minimalist design
9. Help users recognize, diagnose, and recover from errors
10. Help and documentation, in context

## WCAG 2.2 AA audit table

Copy this table into the deliverable. Status is one of pass, fail, or verify (needs a running build or assistive technology to confirm). Evidence names the element and the measured value.

| Criterion | Name                                      | What to check                                                          | Status | Evidence | Fix |
| --------- | ----------------------------------------- | ---------------------------------------------------------------------- | ------ | -------- | --- |
| 1.1.1     | Non-text content                          | Every image and icon has alt text or is marked decorative              |        |          |     |
| 1.3.1     | Info and relationships                    | Labels are programmatically tied to inputs; headings are real headings |        |          |     |
| 1.3.4     | Orientation                               | Works in portrait and landscape                                        |        |          |     |
| 1.3.5     | Identify input purpose                    | Autocomplete or content type set on personal-data fields               |        |          |     |
| 1.4.1     | Use of color                              | State and errors are not conveyed by color alone                       |        |          |     |
| 1.4.3     | Contrast (minimum)                        | 4.5:1 body text, 3:1 large text                                        |        |          |     |
| 1.4.4     | Resize text                               | Usable at 200 percent                                                  |        |          |     |
| 1.4.10    | Reflow                                    | No horizontal scroll at 320 CSS px                                     |        |          |     |
| 1.4.11    | Non-text contrast                         | 3:1 for component boundaries, focus rings, meaningful icons            |        |          |     |
| 1.4.12    | Text spacing                              | Layout survives increased line and letter spacing                      |        |          |     |
| 1.4.13    | Content on hover or focus                 | Tooltips are dismissible, hoverable, persistent                        |        |          |     |
| 2.1.1     | Keyboard                                  | Everything is operable by keyboard                                     |        |          |     |
| 2.1.2     | No keyboard trap                          | Focus can always leave a component                                     |        |          |     |
| 2.2.1     | Timing adjustable                         | Timeouts can be extended or turned off                                 |        |          |     |
| 2.3.1     | Three flashes or below                    | Nothing flashes more than three times per second                       |        |          |     |
| 2.4.3     | Focus order                               | Focus order matches reading order                                      |        |          |     |
| 2.4.4     | Link purpose (in context)                 | Link text makes sense on its own                                       |        |          |     |
| 2.4.6     | Headings and labels                       | Headings and labels are descriptive                                    |        |          |     |
| 2.4.7     | Focus visible                             | Visible focus indicator on every control                               |        |          |     |
| 2.4.11    | Focus not obscured (minimum)              | Sticky headers or footers never fully hide the focused element         |        |          |     |
| 2.5.1     | Pointer gestures                          | Multipoint or path gestures have a single-pointer alternative          |        |          |     |
| 2.5.2     | Pointer cancellation                      | Actions fire on the up event or can be aborted                         |        |          |     |
| 2.5.3     | Label in name                             | Visible label text is part of the accessible name                      |        |          |     |
| 2.5.7     | Dragging movements                        | Drag actions have a non-drag alternative                               |        |          |     |
| 2.5.8     | Target size (minimum)                     | Targets are at least 24x24 CSS px or adequately spaced                 |        |          |     |
| 3.1.1     | Language of page                          | Language is declared                                                   |        |          |     |
| 3.2.1     | On focus                                  | Receiving focus does not change context                                |        |          |     |
| 3.2.2     | On input                                  | Changing a control does not change context unexpectedly                |        |          |     |
| 3.2.6     | Consistent help                           | Help mechanisms appear in the same place across pages                  |        |          |     |
| 3.3.1     | Error identification                      | Errors are described in text                                           |        |          |     |
| 3.3.2     | Labels or instructions                    | Inputs have labels and required-format instructions                    |        |          |     |
| 3.3.3     | Error suggestion                          | Errors suggest a fix                                                   |        |          |     |
| 3.3.4     | Error prevention (legal, financial, data) | Review, confirm, or undo for high-stakes submissions                   |        |          |     |
| 3.3.7     | Redundant entry                           | Previously entered information is prefilled or selectable              |        |          |     |
| 3.3.8     | Accessible authentication (minimum)       | No cognitive test without an alternative; paste is allowed             |        |          |     |
| 4.1.2     | Name, role, value                         | Custom controls expose name, role, and state                           |        |          |     |
| 4.1.3     | Status messages                           | Toasts and live updates are announced to assistive technology          |        |          |     |

Notes:

- WCAG 2.2 removed 4.1.1 Parsing; do not cite it.
- AAA criteria worth adopting when cheap: 1.4.6 contrast 7:1, 2.4.13 focus appearance, 2.5.5 target size 44x44, 2.3.3 animation from interactions (reduced motion).

## Worked critique: mobile checkout screen

Input as described by the user: a top bar with a back arrow and the title "Checkout"; four stacked fields (card number, expiry, CVV, name) with light gray (#B0B0B0) placeholder text as the only label on white; "Pay $42.00" is a 32x32 arrow icon in the top right of the top bar; invalid fields get a red border only; tapping Pay gives no feedback for 2 to 3 seconds; there is no step indicator; React Native on iOS and Android.

```markdown
## Design Critique: Mobile checkout

### Assumptions
- Platforms: iOS and Android via React Native; no web target.
- Audience: general consumers, first-time and returning buyers.
- Existing system: none referenced; recommendations use neutral values.
- Success measure: checkout completion rate and payment error rate.

### Findings (ordered by severity)

#### 1. [Blocker] Placeholder text is the only label, at 2.2:1 contrast
- Observation: Four fields show #B0B0B0 placeholder text on #FFFFFF with no label.
- Principle: Recognition over recall; WCAG 1.3.1, 1.4.3, 3.3.2.
- Impact: #B0B0B0 on white is 2.2:1 (minimum 4.5:1). Once typed, the field's meaning disappears; expiry and CVV look alike when filled.
- Recommendation: Persistent labels above each field in #374151 (10.3:1); placeholders only for format hints ("MM/YY", "123").
- Trade-off: About 20 px more height per field; the form may scroll on small phones.

#### 2. [Blocker] The primary action is a 32x32 icon in the top bar
- Observation: "Pay $42.00" is an arrow icon, 32x32, top right, next to the back arrow.
- Principle: Affordance and target size; iOS HIG 44x44 pt, Material 48x48 dp, WCAG 2.5.8.
- Impact: Below both platform minimums; the control does not say "pay" or show the amount; it sits beside a navigation control, inviting mis-taps on a money action.
- Recommendation: Full-width bottom button, 48 pt tall, labeled "Pay $42.00", in the thumb zone; disabled until the fields validate.
- Trade-off: Less visual quiet at the bottom; needs safe-area handling on iOS.

#### 3. [Blocker] Errors are shown by a red border only
- Observation: Invalid fields change border color to red with no text.
- Principle: WCAG 1.4.1, 3.3.1, 3.3.3.
- Impact: Users with color-vision deficiency cannot detect the state, and nobody learns what is wrong.
- Recommendation: Inline message under the field ("Card number should have 16 digits") plus an icon; move focus to the first error on submit.
- Trade-off: Extra height only while an error is present.

#### 4. [Blocker] No feedback for 2 to 3 seconds after Pay
- Observation: The button does not change while the request is in flight.
- Principle: Immediate feedback; any wait over 1 s needs an indicator.
- Impact: Repeat taps risk duplicate charges; trust drops at the exact moment money moves.
- Recommendation: On tap, disable the button, swap the label for a spinner and "Processing...", and block resubmission until the response returns.
- Trade-off: None material.

#### 5. [Major] No indication of position in the checkout
- Observation: No step indicator; the title is the generic "Checkout".
- Principle: Visibility of system status; continuity across screens.
- Impact: Users do not know whether more steps follow payment, which raises abandonment.
- Recommendation: "Step 2 of 3" under the title, or rename to "Review and pay" if this is the last step.
- Trade-off: Minor chrome.

#### 6. [Major] Keyboards and autofill are not specified
- Observation: No mention of numeric keyboards or autofill for the card fields.
- Principle: Error prevention; WCAG 1.3.5.
- Impact: Alphabetic keyboards on numeric fields increase errors and time on task.
- Recommendation: `keyboardType="number-pad"` with `textContentType` and `autoComplete` set to the card number, expiry, and security code values.
- Trade-off: None material.

### What works
- A single-column layout with four fields keeps the form short.

### Prioritized next steps
1. Fix findings 1 to 4 before release.
2. Add the step indicator and keyboard settings in the same sprint.
3. Measure completion rate and error rate before and after.

### Open questions
- Is this the final step, or does an order review follow? The answer decides finding 5.

### Known gaps and next action
- Focus order, screen-reader labels, and the Pay button's real hit area need a build to verify.
- Next action: ship findings 1 to 4 together, then measure completion rate for two weeks.
```
