# UX Patterns Reference

Companion to the fm-product-design skill. Use these templates when the deliverable is a UX flow, onboarding, an empty state, a loading state, a form, or error handling.

## UX flow stage template

Document every flow stage by stage. A stage is complete only when all six parts and all four states are filled in.

```text
Stage N: <name>
  Entry Point : how the user arrives (deep link, nav item, notification, previous stage)
  Context     : what the user already knows, has, and wants at this moment
  Action      : the one thing the user does here (verb + object)
  Feedback    : the system's immediate response (a visible change within 100 ms)
  Outcome     : what the user has achieved when the stage ends
  Next Step   : where the flow goes next, and the natural way to get there
  States      : loading | empty | error | success (each described, none omitted)
  Decision    : branch conditions, if any, and where each branch leads
```

Rules:

- One primary action per stage. Secondary actions are visually quieter and never compete.
- Progress is visible whenever the flow has more than two stages (step indicator, "2 of 4", or a progress bar).
- Back never loses entered data. Save drafts when the user navigates away.
- Every stage that fetches data defines a skeleton, not just a spinner, when the layout is predictable.
- Define the metric before the flow: task completion rate, time to complete, drop-off per stage.

## Onboarding skeleton (first five minutes)

Screen 1: Promise

- One sentence stating what the user will get, in their words
- One image or short loop that shows the outcome, not the UI
- CTA: an outcome verb ("Start planning"), not "Create account"

Screen 2: Immediate action (value before signup)

- Let the user do one real thing with a real result
- Minimum data capture (email only, or nothing), and only if needed to continue
- Visible progress ("1 of 3")

Screen 3: Light personalization

- At most three questions
- Visual choices (chips, cards) instead of typed text
- Skip is always available and never punished

Screen 4: Aha moment

- The user completes something that works
- Genuine, brief acknowledgment ("You just [outcome]"), no confetti storm
- The next action is obvious and one tap away

Rules: value before signup; defer profile questions until after the aha moment; never request permissions (notifications, location) before showing why; define activation as "completed the aha moment in the first session" and report the metric with the design.

## Empty states

Four kinds, each with its own content.

| Kind       | When                                 | Content                                                            |
| ---------- | ------------------------------------ | ------------------------------------------------------------------ |
| First use  | Nothing created yet                  | Opportunity message, contextual illustration, primary CTA, one tip |
| No results | A filter or search returns nothing   | Restate the query, suggest broadening, clear-filters action        |
| Cleared    | The user emptied the list on purpose | Calm confirmation, undo if recent, a way to add more               |
| Error      | Data failed to load                  | What happened, retry action, fallback path                         |

Copy formula: "No [things] yet. [What creating one gets you]." followed by a verb CTA. Never "No items found" on its own.

## Loading and perceived performance

| Wait          | Treatment                                                                                        |
| ------------- | ------------------------------------------------------------------------------------------------ |
| Under 100 ms  | No indicator; the change itself is the feedback                                                  |
| 100 ms to 1 s | Subtle state change (pressed state, inline spinner)                                              |
| 1 s to 10 s   | Skeleton screen matching the final layout, or a determinate progress bar when the total is known |
| Over 10 s     | Progress with an estimate, a way to cancel or leave, and a notification when done                |

- Use optimistic UI for reversible actions (like, rename, reorder) and pessimistic UI for irreversible ones (pay, delete, send).
- Disable the triggering control and show its loading state immediately; prevent duplicate submissions.
- Prefer skeletons over spinners when the layout is predictable; use spinners only for unknown shapes.

## Forms

- Labels are persistent and visible, above or beside the field; placeholders carry format hints only ("MM/YY").
- One column; group related fields; order them the way people think about the data.
- Set the right keyboard and autofill: on the web use `type` and `autocomplete` (`cc-number`, `cc-exp`, `cc-csc`, `email`, `tel`, `one-time-code`); on iOS use `textContentType`; in React Native use `autoComplete`, `textContentType`, and `keyboardType`.
- Validate on blur, not on every keystroke; after the first error, re-validate on change so the fix is confirmed immediately.
- Errors combine text next to the field, an icon, and a color change; say what is wrong and how to fix it ("Card number should have 16 digits").
- Never ask for the same information twice in a flow (WCAG 3.3.7); prefill from known data.
- Financial and legal submissions get a review step or an undo window (WCAG 3.3.4).
- Submit buttons name the outcome, and the amount when there is one ("Pay $42.00").

## Error handling

Message formula: what happened, why (only if it helps), and how to fix it, in that order, in plain language.

| Situation                | Pattern                                                                            |
| ------------------------ | ---------------------------------------------------------------------------------- |
| Field validation         | Inline text under the field; focus moves to the first error on submit              |
| Failed action            | Toast or inline banner with retry; keep the user's input                           |
| Offline                  | Persistent banner; queue actions where safe; show what will sync                   |
| Not found or no access   | Full-page state with a way back and a way to request access                        |
| Destructive confirmation | Name the object, state the consequence, and make the safe option the default focus |

Never blame the user, never show a code alone, and never leave the user without a next action.
