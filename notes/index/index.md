## What Is The Index
- The index is the project’s compact knowledge map under `notes/index/`.
- It captures stable architecture/workflow decisions, invariants, and conventions that guide implementation.
- It is for orientation and decision support, not for transient task logs or brainstorming drafts.
- Each index file should have a clear scope and remain concise, explicit, and scannable.
- Prefer updating an existing index note when the topic already has a home; add new files only when needed.
- The index is a reference layer for humans and agents to reduce ambiguity and avoid duplicated decisions.
- The index is for reading, not writing; it should be updated only by human maintainers.

## Index TOC

- `AGENTS.md` — States index-folder guardrails for agents, especially strict read-only
behavior and pointer to the index overview.
- `api-surface-ownership.md` — Defines API ownership so only Simuleos exports public
symbols while subsystems stay internal with explicit qualification.
- `functionality-inventory.md` — Lists current and planned system capabilities, including
memoization, replay, diffing, and a proposed resource resolution system.
- `simuleos-arch.md` — Summarizes the Simuleos state model across runtime and disk with
lazy evaluation and core-managed state interfaces.
- `subsystem-arch.md` — Captures subsystem architecture rules, layer dependency
constraints, subsystem classification, and key include-order guidance.
- `the-index-workflow.md` — Defines the index maintenance workflow with read-only agent
discovery/reporting and user-only authorship decisions.
- `the-integration-axis.md` — Defines the I-axis integration levels (I0x-I3x), interface
style guidance, naming conventions, and classification constraints.
- `workflows-inventory.md` — Describes major product workflows (scope recording, database
reading, sim_init, tape rewrite) and their intended step sequences.