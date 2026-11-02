---
description: Create a new Architecture Decision Record with the next number
allowed-tools: [Read, Write, Edit, Glob, Bash]
---

Create the next Architecture Decision Record in `Context/adr/`.

Title: $ARGUMENTS

Steps:

1. Glob `Context/adr/NNNN-*.md` and find the highest existing number (ignore `README.md`).
2. Increment by 1 and zero-pad to 4 digits.
3. Slugify the title: lowercase, hyphens for spaces, strip punctuation.
4. Write `Context/adr/NNNN-<slug>.md` using the Nygard template:

   ```markdown
   # ADR-NNNN: <title>

   ## Status

   Accepted — <today>

   ## Context

   <what situation or constraint prompts this decision?>

   ## Decision

   <what are we doing?>

   ## Consequences

   ### Positive

   - ...

   ### Negative

   - ...

   ## Alternatives considered

   ### <alternative 1>

   Rejected because...
   ```

5. If the conversation above contains enough context, pre-fill Context, Decision, Consequences, and Alternatives from what was discussed. If not, leave them as `<...>` placeholders for the user.
6. If this decision supersedes an earlier ADR, update the earlier ADR's `## Status` line to `Superseded by ADR-NNNN` — change nothing else in it.
7. Update `Context/adr/README.md` — add a row to the index table at the bottom.
8. Report the created path.

Follow the tone and structure of the existing ADRs in `Context/adr/`.
