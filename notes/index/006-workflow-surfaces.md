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

## Queued Commit Retention
- Keep retention layers explicit and separate:
  - staged scopes not yet grouped into a logical commit
  - logical commits queued in memory before persistence
  - physical tape fragmentation on disk (storage-level rollover)
- Immediate commit path:
  - flush older queued logical commits first, then persist the current staged commit
  - preserves record order when immediate and queued modes are mixed
- Queued commit path:
  - convert the current staged scopes into one logical commit and enqueue it
  - auto-flush the queue when the queued-commit threshold is reached
- Explicit finalization point:
  - create one tail logical commit from any remaining staged scopes
  - flush all queued logical commits
  - does not implicitly end or clear the active session object

## Keyed Cache Equivalence Assumption
- Cache-key collisions are treated as semantic equivalence, not a correctness conflict.
- If two computations resolve the same cache key, the system assumes they represent the same result contract.
- Caller-owned responsibility:
  - include all materially relevant inputs in the cache context/key composition
  - use extra key parts when one context hash must be partitioned into distinct cached outputs
- Current non-goal:
  - do not add synchronization/ownership logic just to distinguish which equivalent writer "won" a collision


## Pipeline Workflow
- Purpose: let numbered scripts exchange typed data through tapes instead of ad-hoc files
on disk.
- Typical use case: a multi-stage analysis where each script produces results the next
script consumes (e.g. data prep → model fitting → summary report).
- Pipeline workflows are implementable with existing scope recording and reading
interfaces.
- Convention: each script stage commits its output with a well-known commit label.
- The next stage retrieves the upstream scope by commit_label + src_file.
- No dedicated pipeline abstraction is needed:
    - the commit label is the interface contract between stages.
    - the tape provides lineage (who committed what, when, from which file).
    - src_file filtering on latest_scope addresses the producer.
- Reference: dev/live/504-stage-lineage-pipeline.jl
