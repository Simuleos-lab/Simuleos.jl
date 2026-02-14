---
name: git-commit-trigger
description: Run a full git commit flow when explicitly invoked. Stage all changes with git add -A, auto-generate a concrete and complete Conventional Commit message from the staged diff, commit immediately, never run tests, and never push.
user-invocable: true
allowed-tools: Bash(git status *, git rev-parse *, git add -A, git diff --staged *, git commit *, mktemp, cat *, rm *)
---

# Git Commit Trigger

Commit all current repository changes in one deterministic flow.

## Trigger Policy

Use this skill only when explicitly invoked by name (for example: `$git-commit-trigger`).
Do not run this workflow automatically at the end of unrelated tasks.

## Workflow

### 1) Preflight

1. Ensure current directory is inside a Git repository:
   - `git rev-parse --is-inside-work-tree`
2. Check for pending changes:
   - `git status --porcelain`
3. If there are no changes, stop and report: `No changes to commit.`

### 2) Stage

Stage everything:

- `git add -A`

### 3) Gather Commit Context

Read staged changes to synthesize the message:

- `git diff --staged --name-status`
- `git diff --staged --stat`
- `git diff --staged`

### 4) Compose Commit Message (Conventional Commit)

Generate a concrete and complete message inferred from staged changes.

Rules:

1. Subject format:
   - `<type>(<optional-scope>): <specific summary>`
   - Example types: `feat`, `fix`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`
2. Subject quality:
   - specific, descriptive, and behavior-oriented
   - avoid vague summaries like `update files` or `misc changes`
3. Body requirements:
   - include 2 to 6 bullet points
   - each bullet must describe a concrete change (what changed and where)
4. Keep the message faithful to the diff; do not invent intent not visible in changes.

### 5) Commit Immediately

Commit without running tests and without requesting additional confirmation.

Use:

- `git commit -m "<subject>" -m "<bullet1>\n<bullet2>\n..."`

If multiline shell quoting is awkward, use a temporary message file and `git commit -F <file>`.

## Safety Rules

- Never run tests in this skill.
- Never push in this skill.
- Never use `--amend` unless explicitly requested by the user in the same prompt.
- Never use `--no-verify` unless explicitly requested by the user in the same prompt.

## Output Contract

After committing, report:

1. Commit hash and subject (`git log -1 --oneline` equivalent)
2. Files changed summary (`git show --name-status --oneline --no-patch` plus staged file list used for message generation)
3. Confirmation that no push was performed
