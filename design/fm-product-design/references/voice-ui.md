# Voice and Conversational UX Reference

Companion to the fm-product-design skill for voice assistants, smart-speaker skills, in-app voice, and chat assistants.

## Principles

1. Zero visual load: the user hears, so every word costs attention, and brevity is the design
2. Easy reversibility: undo is always available and always cheap
3. Optional confirmation: confirm only irreversible actions (payments, deletions, sending)
4. Response variety: never the same phrase twice in a session; keep at least three variants per prompt
5. Silence is fine: wait about two seconds before offering help, then offer once
6. One question at a time: never stack questions in a single turn
7. Front-load the answer: the core answer comes before caveats or options

## Response structure

```text
[Optional hook] + [Core answer] + [Action or question]
```

Keep responses under about eight seconds of speech (roughly 20 to 25 words) unless the user asked for detail.

| Situation        | Weak                                                                      | Strong                                                 |
| ---------------- | ------------------------------------------------------------------------- | ------------------------------------------------------ |
| Misunderstanding | "Sorry, I didn't understand what you said. Could you please repeat that?" | "I didn't catch that. Try saying it another way?"      |
| Direct question  | "Sure! I can help with that. The answer to your question is..."           | "[Direct answer]. Want the details?"                   |
| Long list        | Reads all seven options                                                   | "There are seven. The top two are A and B. Want more?" |
| Confirmation     | "Are you sure you want to proceed with this action?"                      | "Send $50 to Sam? Say yes or no."                      |

## Error recovery ladder

1. Reprompt briefly with a hint ("Which day? For example, Tuesday.")
2. Rephrase with two or three concrete options
3. Offer a fallback (send to phone, show on screen, save for later)
4. Exit gracefully and keep the context for next time

Never repeat the identical error message twice in a row.

## Latency and silence

- Anything over one second gets an earcon or a short filler ("Checking...").
- Long tasks say what will happen ("This takes about a minute. I'll let you know.").
- Silence after a prompt: wait about two seconds, offer help once, then end the turn politely.

## Persona and tone

Define the persona in three lines before writing scripts: who it is, how it speaks (register, warmth, humor level), and what it never does. Keep the persona consistent across first use, return, error, and exit.

## Sample scripts

Replace the assistant name and domain; keep the shape.

```text
First use:
"Hi, I'm [Name]. Ask me anything, from business decisions to creative ideas. What can I help with today?"

Return (known user):
"Welcome back. Last time we were on [topic]. Want to pick that up?"

Misunderstanding:
"I didn't catch that. Try it another way?"

Irreversible action:
"[Action with the key detail]? Say yes to confirm."

Exit:
"Anytime you need me, just ask. Talk soon."
```

## Testing voice scripts

- Read every line aloud; rewrite anything you stumble on.
- Time responses; cut anything over eight seconds that was not requested.
- Confirm every prompt has at least three phrasing variants.
- Run the misunderstanding path three times in a row and confirm the ladder escalates.
