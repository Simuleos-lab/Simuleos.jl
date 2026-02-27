# Permanent Refactoring as Scientific Method

Date: 2026-02-18
Context: `scripts/simulations.uh.2/014-trade-space.jl` inner-loop evolution

Scientific simulation code is not only software. It is also an experimental instrument. In this setting, refactoring is not just technical cleanup. It is often a hypothesis change, an operational definition change, or a shift in what the simulation is actually measuring. That means the "exploratory phase" is not a temporary phase before production. It is the dominant mode of work.

The practical consequence is simple: we should treat algorithm changes as experiment variants, not as ordinary code churn.

The current trade-space case is a good example. Changing from a viability threshold floor to a biomass cap altered the semantics of "viable" and expanded the number of pairs entering the expensive blocking loop. Same script, same inputs, very different experiment behavior. If this change is recorded only as code diff, we lose scientific traceability. If it is recorded as an experiment variant with explicit intent and outputs, we gain reusable knowledge.

## Core strategy

Use a dual-track workflow:

1. **Fast code evolution** for trying ideas quickly.
2. **Strict experiment bookkeeping** for preserving scientific meaning.

The trick is to keep coding flexible while making run artifacts immutable and queryable.

## What to standardize

### 1) Variant identity

Every meaningful algorithm choice gets a variant ID and short label. Example for the inner loop:

- `innerloop_v1_baseline_candidates`
- `innerloop_v2_recompute_candidates_each_step`
- `innerloop_v3_stop_on_first_lethal`
- `innerloop_v4_rank_by_delta_then_block`

The variant ID belongs in metadata and output paths, not just commit messages.

### 2) Run manifest

Every run writes a manifest file before heavy computation starts. The manifest should include:

- script path
- git commit hash
- dirty-worktree flag
- variant ID
- all thresholds and caps
- random seed
- input files + hashes
- start timestamp

This makes each output self-describing and auditable.

### 3) Immutable result directories

Never overwrite a prior experiment JSON. Write to per-run folders, for example:

`results/trade-space/runs/2026-02-18T14-35-10Z__innerloop_v2__seed42/`

Inside:

- `manifest.json`
- `results.json`
- `stdout.log`
- `summary.tsv`

If you re-run, create a new folder. Comparison becomes safe and mechanical.

### 4) Stable summary surface

Keep a tiny, stable summary schema across variants so results stay comparable:

- total pairs
- viable pairs
- tested blocks
- failed solves
- runtime totals
- runtime per pair quantiles

When internals change, this summary still supports quick cross-variant checks.

### 5) Experiment index note

Maintain one append-only note that maps run ID -> intent -> result location -> key findings. This prevents "lost experiments" when many variants are tested in short cycles.

## How this applies to the current inner-loop work

If the goal is to test several inner-loop versions while always being able to recover outcomes:

1. Keep one shared model-construction path.
2. Isolate the blocking logic into named strategy functions.
3. Select strategy by parameter at runtime.
4. Emit run manifests and immutable run folders.
5. Add a tiny comparator script that reads all run summaries and prints a table.

Then exploratory refactoring stops being fragile. It becomes a controlled series of experiments with durable memory.

## Decision rule for future refactors

When a change can alter scientific interpretation, treat it as a new experimental variant.  
When a change is performance-only and interpretation-preserving, keep variant ID stable but record the implementation revision.

This rule keeps velocity high without sacrificing reproducibility.

## Closing view

In commercial software, "done" is often feature completion.  
In scientific simulation, "done" is often a trustworthy chain of experiments.

So permanent refactoring is not a failure of planning. It is the normal method. The right response is not to freeze code early, but to engineer traceability so each refactor remains scientifically usable.
