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
vlt vault="Claude" read file="Session Operating Mode" follow
vlt vault="Claude" read file="<project-name>" follow
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

### Concurrency Limits (HARD RULE)

Heavy stacks (Rust, iOS/Swift, C#, CF Workers): max 2 dev, 1 PM, 3 total
Light stacks (Python, non-CF TS/JS): max 4 dev, 2 PM, 6 total

### Execution Loop

Work through the approved backlog top-to-bottom. For each story:

1. Spawn `@paivot-developer` to implement
2. Spawn `@paivot-pm` to review
3. Capture learnings to vault
4. Move to next story

## Constraints

- No speculative refactoring
- If a fix reveals a deeper problem, create a NEW story via `@paivot-sr-pm`
- After completing all stories, run `/vault-evolve`
