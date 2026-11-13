---
name: fm-write-a-plan
description: Use when writing or revising an implementation plan from a spec, design document, or requirements for a multi-step task, or when asked to add a glossary, summaries, a roadmap, or diagrams to an existing plan, in a project that plans with the superpowers plugin. Takes the place of superpowers:writing-plans wherever that skill is called for.
compatibility: Requires the superpowers plugin (superpowers:writing-plans). Plans stay executable by superpowers:subagent-driven-development and superpowers:executing-plans.
metadata:
  version: "1.0"
  author: "Futuremotion Studio"
---

# Write a plan

## Overview

This skill wraps `superpowers:writing-plans`. That skill writes the plan an implementer executes. This one adds what a person needs to read the same plan quickly: a summary of each part, a roadmap, diagrams, and a glossary, always in the same places under the same names.

The plan is read by two audiences. Executors read it with scripts: each task is cut out by its `Task` heading and handed to an implementer who sees nothing else. People read it top to bottom. The layout below serves both, and the check at the end proves the executors can still read it.

## When to use

- A spec, design document, or set of requirements needs an implementation plan.
- Another skill says to invoke `superpowers:writing-plans`. Use this skill in its place; it invokes that one itself.
- An existing plan needs the reader sections added or refreshed.

If `superpowers:writing-plans` is not available in this session, say that this skill needs the superpowers plugin and stop.

## Process

1. **Write the plan.** Invoke `superpowers:writing-plans` and follow it completely, including its Self-Review. Stop before its Execution Handoff.
2. **Collect the roadmap facts.** Read what is written down: the spec's own milestones or phases, the other files in the plan's folder and the spec's folder, a roadmap or backlog document if the project has one, and the project's notes or memory. Use only what you find.
3. **Add the reader sections** in the layout below.
4. **Run the check** below and fix what it reports.
5. **Hand over.** Carry out the Execution Handoff of `superpowers:writing-plans` exactly as that skill words it.

For an existing plan, do steps 2 to 4 and report what you added. Add only: when you notice a defect in the existing tasks, report it and leave the task as it is.

## Layout

Everything `superpowers:writing-plans` produced keeps its place and its exact name. The reader sections go in these four positions.

````markdown
# [Feature] Implementation Plan

> **For agentic workers:** ... (unchanged)

**Goal:** ... **Architecture:** ... **Tech Stack:** ... **Spec:** ... (unchanged)

## Glossary

| Term | Meaning |
| --- | --- |
| [term the plan uses] | [what it means in this project, in one or two sentences] |

## Global Constraints   (unchanged)

## Review Focus   (unchanged)

## At a Glance

[Two to five sentences: what exists when this plan is done, and the order of the work.]

| Part | Tasks | What it delivers |
| --- | --- | --- |
| [a part the spec names] | 1, 2 | [one sentence] |

[Diagram: how the parts connect]

[Diagram: which tasks depend on which]

## Roadmap

[One paragraph: what came before this plan, what this plan covers, what comes after.]

| Milestone | Tasks | What works when it is reached |
| --- | --- | --- |
| [name] | 1 to 3 | [something a person could try or see] |

---

## File Structure   (unchanged, when the plan has one)

### Task 1: [Component Name]

**Summary:** [One sentence: what this task delivers and why it comes here.]

**Files:** ... (unchanged from here to the end of the task)

### Task N: ...
````

## What goes in each section

| Section | Contents |
| --- | --- |
| Glossary | Every term the plan uses that a capable newcomer to this project would have to ask about: project names, file roles, process words, domain words. It goes directly after the `**Spec:**` line and before Global Constraints, so every term is defined before the constraints and the tasks use it. One table; above twenty terms, split it into a few tables, each introduced by a plain line such as `Testing terms:`. |
| At a Glance | The short paragraph, one table row per part of the system, and the diagrams. A reader who stops here knows what is being built and in what order. |
| Roadmap | Where this plan sits among the project's plans, then its milestones. A milestone is a point where something works that did not work before; give two to five. |
| At a Glance and Roadmap, position | Directly after Review Focus and before the horizontal rule that closes the plan's header. Every horizontal rule stays where `superpowers:writing-plans` put it. |
| Summary line | The first paragraph under every task heading, in bold, one sentence, with one blank line above it and one below. It is a line, never a heading. |

**Roadmap facts come from the page.** State what the documents you read in step 2 say, and name the document. When a document gives an item a status (decided, idea, shipped), use the document's word. When something later is likely but written nowhere, label it `proposed, not decided`. When you found no earlier or later plan, write `This plan stands alone.` and give only the milestones.

**The reader sections describe; the tasks decide.** A number, a name, or a signature appears in a task or in Global Constraints. The reader sections refer to it and do not restate it, so a later edit to a task cannot leave a stale copy above it. A Glossary entry says what a term means and, when the term has an exact shape, names the task or section that defines it.

## Diagrams

Mermaid, in fenced `mermaid` blocks, because it is plain text inside the plan and renders in GitHub and in editors. Give every plan the first two; add the others when the spec has what they show.

| Diagram | Mermaid type | Use it when |
| --- | --- | --- |
| How the parts connect | `flowchart LR` | Always. Parts as nodes, what passes between them on the arrows. |
| Task order | `flowchart LR` | Always. One node per task, labelled with its number and a short name; an arrow means "must finish before". Draw an arrow only where a task's Interfaces block consumes something an earlier task produces. |
| A decision | `flowchart TD` | The spec branches: modes, error paths, exit codes. |
| A conversation between parts | `sequenceDiagram` | Order of calls matters: a protocol, a request and its replies. |
| A lifecycle | `stateDiagram-v2` | Something moves through named states. |
| Stored data | `erDiagram` | The plan creates or changes tables or record shapes. |
| Several plans over time | `timeline` | The roadmap covers more than one plan. It goes in the Roadmap section. |

Keep each diagram under about fifteen nodes; split a larger one. Put any label that contains a bracket, colon, quote, or pipe inside double quotes: `A["Reporter (text or JSON)"]`. A diagram shows what the tasks already say and adds no requirement.

Use draw.io or another tool only when the person asks for it. Create the file with that tool, save it beside the plan, and link it from At a Glance; keep the two Mermaid diagrams as well, since they are the ones that render everywhere.

## The contract the executors rely on

These are facts about how plans are parsed, and the layout already respects them.

- A heading whose first word is `Task` followed by an id marks a task. Reader sections therefore never have a heading that starts with the word Task.
- A task's brief runs from its heading to the next task heading. The Summary line travels with its task. Anything placed after the last task is handed to that task's implementer, which is why every reader section sits before the first task.
- `Global Constraints`, the `**Spec:**` line, and each task's `**Interfaces:**` block are found by name.
- An unclosed code fence hides every task after it.

## Check

Run these on the finished file, with `PLAN` set to its path.

```bash
grep -nE '^#+[[:space:]]+Task[[:space:]]' "$PLAN"
grep -c '^\*\*Summary:\*\* ' "$PLAN"
awk '/^```/ { n++ } END { print (n % 2 == 0) ? "fences balanced" : "FENCE UNBALANCED" }' "$PLAN"
grep -c '^```mermaid' "$PLAN"
grep -nE '^## (Glossary|Global Constraints|Review Focus|At a Glance|Roadmap)$' "$PLAN"
awk '/^#+[[:space:]]+Task[[:space:]]/ { t = 1 } t && /^## / { print "SECTION AFTER A TASK: " $0 }' "$PLAN"
```

The plan passes when: the first command lists the real tasks and nothing else; the Summary count equals the number of tasks; fences are balanced; there are at least two Mermaid blocks; the five headings appear once each, in that order; and the last command prints nothing, or prints only a section that `superpowers:writing-plans` itself placed after the tasks.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| A summary written as a heading such as "Task 3 summary" | Make it the bold Summary line inside the task. |
| A roadmap that lists phases nobody wrote down | Cite the document, or label the item `proposed, not decided`. |
| A value copied from a task into At a Glance | Refer to the task; keep the value in one place. |
| A diagram that introduces a component no task builds | Remove the node or add the task. |
| The Glossary, or any other reader section, placed after the tasks | Move it before Task 1; the layout gives its place. |
| The handoff shortened or reworded | Use the wording of `superpowers:writing-plans`. |
