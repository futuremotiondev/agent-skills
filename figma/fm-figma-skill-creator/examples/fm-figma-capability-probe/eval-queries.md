# Trigger eval queries: fm-figma-capability-probe

Twenty prompts. Ten should trigger the skill (positive), ten should not (negative). The holdout set is 8 prompts (4 positive, 4 negative) and is never used to tune the description. Pass threshold on the holdout: 0.5 or better, with no negative false-trigger on a prompt that names another skill's job.

How to run: in a scratch Figma Design file with the skill added, paste each prompt without the slash command and record whether the skill ran (the agent asks the disclosure question). In a coding agent, ask "which skill would you use for:" followed by the prompt and record the answer.

## Positive (should trigger)

| # | Prompt | Set | Expected | Result |
| --- | --- | --- | --- | --- |
| P1 | Probe what the Figma agent can do in this file | tune | trigger | |
| P2 | Which Plugin APIs are available to your scripts? | tune | trigger | |
| P3 | Test whether scripts can read plugin data here | tune | trigger | |
| P4 | Run a capability probe on the agent runtime | tune | trigger | |
| P5 | Check what the script runtime supports before I write a skill | tune | trigger | |
| P6 | can your scripts load all pages or not? | tune | trigger | |
| P7 | I maintain our team's Figma skills and after the last release some helpers broke, so before I touch them can you find out which APIs your scripts still have | holdout | trigger | |
| P8 | I need the table of supported and missing APIs for the capability reference | holdout | trigger | |
| P9 | Check which APIs your scripts can call in this Make file | holdout | trigger | |
| P10 | run the capabilty probe | holdout | trigger | |

## Negative (should not trigger)

| # | Prompt | Set | Expected | Result |
| --- | --- | --- | --- | --- |
| N1 | Audit the spacing on these cards | tune | no trigger | |
| N2 | Check these frames against our design system | tune | no trigger | |
| N3 | Write a Figma skill that audits colour contrast | tune | no trigger | |
| N4 | Make a landing page for a fintech app | tune | no trigger | |
| N5 | What does the capability probe skill do? | tune | no trigger | |
| N6 | Build a plugin that renames layers | tune | no trigger | |
| N7 | Rename these layers to match our convention | holdout | no trigger | |
| N8 | Test this prototype flow for usability issues | holdout | no trigger | |
| N9 | Check the copy on these screens for tone | holdout | no trigger | |
| N10 | Write the TypeScript for a Figma plugin that reads variables | holdout | no trigger | |

## Scoring

| Description version | Tune pass | Holdout pass | Notes |
| --- | --- | --- | --- |
| 1.0 | /12 | /8 | |
