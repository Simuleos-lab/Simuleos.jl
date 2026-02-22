## Workflow Surfaces

- Main user workflow families:
  - system lifecycle: initialize and reset active runtime context.
  - scope recording lifecycle: start session, capture scopes, commit staged captures.
  - scope reading lifecycle: resolve project/session, iterate recorded scopes, load values.
  - maintenance lifecycle: rewrite/consolidate stored tape data when formats evolve.
- Workflow goals:
  - simple default path for common interactive use.
  - explicit handles for advanced and multi-session use.
  - traceable records tied to session and commit context.
- Rewrite and migration workflows must preserve functional equivalence of recorded data.

## Scope Trace
- Purpose:
  - collect and preserve the simulation data the user chooses to keep as a run trace.
  - keep simulation runs explainable and analyzable by recording runtime state at key moments.
- General mechanics:
  - runtime snapshots are captured as scopes containing variable state plus contextual metadata.
  - captured scopes are accumulated in a session timeline and persisted as commit-grouped records.
  - stored records can be replayed/iterated later to reconstruct state evolution across a run.
