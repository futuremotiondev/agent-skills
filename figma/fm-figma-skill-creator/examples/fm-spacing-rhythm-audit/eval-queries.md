# Trigger eval queries: fm-spacing-rhythm-audit

Twenty prompts. Ten should trigger the skill (positive), ten should not (negative). The holdout set is 8 prompts (4 positive, 4 negative) and is never used to tune the description. Pass threshold on the holdout: 0.5 or better, with no negative false-trigger on a prompt that names another skill's job.

How to run: in a duplicate Figma Design file with the skill added, paste each prompt without the slash command and record whether the skill ran (the agent names it, or the output follows the audit table). In a coding agent, ask "which skill would you use for:" followed by the prompt and record the answer.

## Positive (should trigger)

| # | Prompt | Set | Expected | Result |
| --- | --- | --- | --- | --- |
| P1 | Check the spacing on these cards | tune | trigger | |
| P2 | Audit spacing on the selected frames | tune | trigger | |
| P3 | Find any off-grid padding or gaps in this screen | tune | trigger | |
| P4 | Is this layout on the 8pt grid? | tune | trigger | |
| P5 | Clean up the spacing in this component before handoff | tune | trigger | |
| P6 | Does this follow our spacing scale? | tune | trigger | |
| P7 | Before I send this to the devs I want to be sure none of the paddings in the pricing table are weird numbers, can you go through them | holdout | trigger | |
| P8 | I need this to pass the design-system review, the gaps keep getting flagged | holdout | trigger | |
| P9 | which of these paddings aren't multiples of 4 | holdout | trigger | |
| P10 | audit the spacng in the selected frame | holdout | trigger | |

## Negative (should not trigger)

| # | Prompt | Set | Expected | Result |
| --- | --- | --- | --- | --- |
| N1 | Convert these frames to auto layout | tune | no trigger | |
| N2 | Export these cards as PNG at 2x | tune | no trigger | |
| N3 | Check the copy on these cards for tone | tune | no trigger | |
| N4 | Make a landing page for a fintech app | tune | no trigger | |
| N5 | What does the spacing audit skill do? | tune | no trigger | |
| N6 | Critique this onboarding flow | tune | no trigger | |
| N7 | Rename these layers to match our convention | holdout | no trigger | |
| N8 | Add some spacing between these two sections | holdout | no trigger | |
| N9 | Publish this component to the team library | holdout | no trigger | |
| N10 | Write the CSS for this card with the right padding | holdout | no trigger | |

## Scoring

| Description version | Tune pass | Holdout pass | Notes |
| --- | --- | --- | --- |
| 1.0 | /12 | /8 | |
