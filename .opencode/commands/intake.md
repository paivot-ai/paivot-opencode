---
name: intake
description: Capture UX/visual/functional feedback and turn it into a prioritized backlog
---

# Intake -- Feedback to Backlog

Collect user feedback about the current state of the product, then delegate to the
Sr. PM agent to create properly structured stories.

## Phase 1: Collect Raw Feedback

Say: "Ready for feedback. Describe each issue -- include screenshots if you have them. Say 'that's all' when done."

For each issue the user describes:
1. Acknowledge it in your own words to confirm understanding
2. Ask clarifying questions if the desired outcome is ambiguous
3. Record it in a running list (DO NOT create nd issues yet)

Keep collecting until the user says "that's all" or equivalent.

## Phase 2: Gather Context Before Delegating

Before spawning the Sr. PM agent, YOU must gather context and pass it in the prompt.

### 2a. Fetch vault knowledge

```bash
pvg notes read "Session Operating Mode"
pvg notes read "<project-name>"
# TODO: pvg notes addresses by full path; if these are not at vault root use the
# full path. The `follow` semantic has no pvg equivalent yet -- fall back to vlt.
```

### 2b. Detect the project's tech stack

Identify the language, framework, and platform from the codebase.

### 2c. Build the skill mapping

Based on the detected stack, determine which skills apply.

## Phase 3: Delegate to Sr. PM Agent

Spawn `@paivot-sr-pm` with:
1. The complete list of raw feedback items
2. The project name and working directory
3. All vault knowledge fetched in Phase 2a
4. The tech stack and applicable skills
5. Any DESIGN.md, ARCHITECTURE.md paths if they exist

**DO NOT create stories yourself.** The Sr. PM produces higher quality stories.

## Phase 4: Present Backlog for Triage

After the Sr. PM returns, present the backlog:

```
| # | Priority | Story | Type | Depends On |
|---|----------|-------|------|------------|
```

Ask: "This is the proposed backlog and order. Want to reorder, cut, merge, or add anything before execution begins?"

## Phase 5: Execute

Execution belongs to `/piv-loop`, not to intake. Intake's scope ends at
feedback capture + Sr PM backlog creation + user triage.

Once the user approves the backlog:

1. Report that the backlog is ready and that `/piv-loop` executes it: stories
   run on story branches in dispatcher-managed worktrees, contained within
   their epic, through the loop's story helpers (`pvg story claim` ->
   developer -> `pvg story deliver` -> PM-Acceptor review -> `pvg story
   accept`), with the epic completion gate at the end.
2. If the user wants execution to start now, invoke `/piv-loop`.

Do NOT run a pre-loop story cycle from intake: do not spawn developers or
PM-Acceptors here, and do not mutate story status by hand
(`pvg nd update --status ...`) -- claiming, delivery, and acceptance go
through the loop's story helpers.

## Constraints

- No speculative refactoring
- If a fix reveals a deeper problem, create a NEW story via `@paivot-sr-pm`
- After completing all stories, run `/vault-evolve`
