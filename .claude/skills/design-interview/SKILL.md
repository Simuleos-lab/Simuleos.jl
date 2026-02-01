---
name: design-interview
description: Gather requirements and make design decisions through Q&A conversation. Use when user shares documents with FEEDBACK notes, wants to discuss design decisions, or says "let's plan together" or "ask me questions".
model: opus
---

# Design Interview

Structured approach for gathering requirements and making design decisions through conversational Q&A.

## Workflow

### Phase 1: Initial Analysis

1. Read the referenced document or context
2. Identify all FEEDBACK items, open questions, or unclear requirements
3. Present a brief summary of what you found

### Phase 2: Question Loop

For each item requiring clarification:

1. Print questions directly in the chat (no interactive tools)
2. Number questions clearly (1, 2, 3...)
3. Provide context: quote the relevant item, explain current behavior if applicable
4. Offer concrete options when possible
5. Wait for user reply

User replies with:
- "feedback" followed by answers
- Direct answers referencing question numbers
- Additional context

After each reply:
- Acknowledge decisions made
- Ask follow-up questions if ambiguities remain
- Continue the loop

**Keep rounds short**: 2-4 questions maximum per round.

### Phase 3: Exit

The loop ends when user requests an action:
- "make a summary"
- "implement this"
- "create a plan"
- Any concrete task

On exit:
- Produce a decision document (issue/answer format)
- Store at user-specified location (default: `notes/live/`)
- use a proper consecutive prefix number for the file
   - eg. `notes/live/104-design-interview.md`
   - check existing files to pick the next number
- Summarize next steps if implementation requested


## Style

- Be direct, no fluff
- Questions must be specific and actionable
- Quote code or docs when relevant
- Prefer binary/multiple-choice over open-ended
- Group related questions

## Decision Document Format

```markdown
# [Topic] - Decisions

**Issue**: [Brief description]

**Q**: [Question]
**A**: [Decision]

**Q**: [Question]
**A**: [Decision]

**Decision**: [Summary of final approach]
```
