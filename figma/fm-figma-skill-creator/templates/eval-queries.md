# Trigger eval queries: <skill name>

Twenty prompts. Ten should trigger the skill (positive), ten should not (negative). Hold out 40 percent (8 prompts, 4 positive and 4 negative) and never tune the description against them. Pass threshold on the holdout: 0.5 or better, with no negative false-trigger on a prompt that names another skill's job.

How to run: paste each prompt into the Figma agent in a file where the skill is available, without typing the slash command, and record whether the skill ran. In a coding agent, ask "which skill would you use for: <prompt>" and record the answer.

## Positive (should trigger)

| # | Prompt | Set | Expected | Result |
| --- | --- | --- | --- | --- |
| P1 | <Exact phrase from the description, e.g. "check the spacing on these cards"> | tune | trigger | |
| P2 | <Second quoted phrase> | tune | trigger | |
| P3 | <Third quoted phrase> | tune | trigger | |
| P4 | <Paraphrase with the object but not the verb> | tune | trigger | |
| P5 | <Paraphrase with the verb but a synonym for the object> | tune | trigger | |
| P6 | <Casual phrasing: "is this on grid?"> | tune | trigger | |
| P7 | <Long prompt where the request is buried mid-sentence> | holdout | trigger | |
| P8 | <Prompt that names the outcome, not the action: "I need this to pass the 8pt review"> | holdout | trigger | |
| P9 | <Prompt in a Make context, if supported> | holdout | trigger | |
| P10 | <Prompt with a typo in the key noun> | holdout | trigger | |

## Negative (should not trigger)

| # | Prompt | Set | Expected | Result |
| --- | --- | --- | --- | --- |
| N1 | <Nearest adjacent task named in "Not for X": e.g. "redesign this card layout"> | tune | no trigger | |
| N2 | <Same object, different intent: "export these cards as PNG"> | tune | no trigger | |
| N3 | <Same verb, different domain: "check the copy on these cards"> | tune | no trigger | |
| N4 | <Generic design request: "make a landing page"> | tune | no trigger | |
| N5 | <Question about the skill rather than a request: "what does the spacing audit do?"> | tune | no trigger | |
| N6 | <Prompt for a sibling fm- skill> | tune | no trigger | |
| N7 | <Unrelated Figma task: "rename these layers"> | holdout | no trigger | |
| N8 | <Prompt that mentions the keyword incidentally: "add some spacing between these two sections"> | holdout | no trigger | |
| N9 | <Prompt for a library task: "publish this component"> | holdout | no trigger | |
| N10 | <Prompt for code output: "write the CSS for this card"> | holdout | no trigger | |

## Scoring

- Tune set: 12 prompts. Iterate the description until all 12 pass or you can explain each failure.
- Holdout set: 8 prompts. Run once per description version. Record the rate below.

| Description version | Tune pass | Holdout pass | Notes |
| --- | --- | --- | --- |
| 1.0 | /12 | /8 | |
