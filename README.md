# Simuleos.jl

Simuleos is a Julia package for recording simulation/workflow state as traceable scopes, organizing them by session/commit lineage, and reading them back for analysis, recovery, and cross-script handoff.

This repository contains:

- the main Julia package (`src/`)
- curated runnable workflow examples (`examples/workflows/`)
- a small project CLI (`cli/`)
- design/index notes that describe intended surfaces (`notes/index/`)

## Who This README Is For

This README is written so another agent (or a new human contributor) can quickly learn the current main features and use the repo without reverse-engineering internals.

Recommended learning path:

1. Read this README for the feature map.
2. Run `examples/workflows/001-record-read-roundtrip.jl`.
3. Use `examples/workflows/README.md` as the canonical workflow catalog.
4. Check `notes/index/003-public-api-surface.md` and `notes/index/006-workflow-surfaces.md` for design constraints.

## Quick Start (Repo Local)

Requires Julia `1.10` (see `Project.toml`).

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
```

Run the curated examples:

```bash
julia --project=. examples/workflows/001-record-read-roundtrip.jl
julia --project=. examples/workflows/002-compare-sessions-and-export.jl
julia --project=. examples/workflows/003-recover-and-resume.jl
julia --project=. examples/workflows/004-keyed-cache-remember.jl
julia --project=. examples/workflows/005-pipeline-stage-lineage.jl
julia --project=. examples/workflows/006-shared-scope-handoff.jl
```

## Main Features (Agent-Oriented Map)

- Record runtime state into scopes with `@simos`.
- Organize scopes into sessions and commit-labeled history.
- Read traces back via `each_commits`, `each_scopes`, `latest_scope`, `value`, `scope_table`.
- Recover/resume runs by binding variables from recorded scopes.
- Reuse expensive computations with keyed cache (`remember!`, `@simos cache.*`).
- Exchange in-memory typed handoff scopes via `@simos shared.*`.
- Control capture content with reusable capture filters.
- Inspect project state from the CLI (`cli/bin/simos`).

## Minimal Record + Read Workflow

This is the smallest useful pattern to learn first.

```julia
import Simuleos: each_scopes, latest_scope, value, @simos

const SANDBOX_DIR = joinpath(@__DIR__, "_sandbox", basename(@__FILE__))

@simos system.init(; reinit = true, sandbox = (;
    root = SANDBOX_DIR,
    clean_on_init = true,
    cleanup_on_reset = false,
))
@simos session.init("demo", "run-1")

let
    step = 1
    params = Dict("alpha" => 0.2, "beta" => 0.8)
    total = 42.0

    @simos stage.inline(params, total)
    @simos stage.meta(step = step, phase = "warmup")
    @simos scope.capture("snapshot")
    @simos session.close("final")
end

proj = @simos project.current()
scope = latest_scope(proj; session = "demo", commit_label = "final")
println(value(scope.variables[:params], proj))

for s in each_scopes(proj; session = "demo")
    println("labels=", s.labels, " metadata=", s.metadata)
end

@simos system.reset()
```

Notes:

- Use `@simos system.init(...)` before any session work.
- Use `@simos session.init(...)` to begin a session timeline.
- `stage.*` collects variables/metadata to be captured.
- `scope.capture(...)` turns staged content into a recorded scope.
- `session.commit(...)`, `session.queue(...)`, and `session.close(...)` control commit grouping/finalization.

## Core `@simos` Workflow Surfaces

Main namespaces used in curated examples:

- `system.*`: runtime lifecycle (`system.init`, `system.reset`)
- `session.*`: session lifecycle (`session.init`, `session.commit`, `session.queue`, `session.close`)
- `stage.*`: stage values and metadata (`stage.inline`, `stage.blob`, `stage.hash`, `stage.meta`)
- `scope.*`: capture/bind scope data (`scope.capture`, `scope.bind`)
- `cache.*`: compute cache keys and cache-backed assignment (`cache.key`, `cache.remember`)
- `shared.*`: in-memory shared-scope registry (`capture`, `bind`, `merge`, `keys`, `has`, `drop`, `clear`)
- `project.*`: active project helpers (`project.current`)

Use the curated examples as the source of truth for current call-style syntax.

## Reading and Querying Recorded Data

The main exported reader functions are:

- `each_commits(proj; ...)`: iterate commit groups
- `each_scopes(proj; ...)`: iterate scopes across commits
- `latest_scope(proj; ...)`: resolve a specific/latest scope
- `value(varref, proj)`: materialize stored variable values (inline/blob/hash-backed)
- `scope_table(proj; ...)`: flatten scopes into row dictionaries for analysis/export

Typical query flow:

1. Get a project handle via `@simos project.current()`.
2. Filter by session and/or commit label.
3. Resolve variables with `value(...)` when needed.

See:

- `examples/workflows/001-record-read-roundtrip.jl`
- `examples/workflows/002-compare-sessions-and-export.jl`
- `examples/workflows/003-recover-and-resume.jl`

## Recovery / Resume Pattern

Simuleos supports resuming a workflow by reading a previously recorded scope and binding variables into the current local scope:

- Use `latest_scope(...)` (or another query) to find the seed scope.
- Use `@simos scope.bind(seed_scope, proj, ...)` to hydrate typed/untyped variables.
- Continue recording into a new session/attempt.

Reference:

- `examples/workflows/003-recover-and-resume.jl`

## Keyed Cache and `remember!`

Main cache features:

- `remember!(name; ctx=..., tags=...) do ... end` for named cached values.
- `@simos cache.key(...)` for stable context hashes derived from inputs.
- `@simos cache.remember(hash, var; extra_key_parts...) do ... end` for assignment-style memoization.

Design note (current behavior): cache-key collisions are treated as semantic equivalence, so callers are responsible for including all materially relevant inputs in the cache key/context.

Reference:

- `examples/workflows/004-keyed-cache-remember.jl`
- `notes/index/006-workflow-surfaces.md` (Keyed Cache Equivalence Assumption)

## Pipeline Stage Lineage (Cross-Script Contracts)

A simple pipeline workflow can be built without a dedicated pipeline abstraction:

- each stage writes scopes under well-known commit labels
- downstream stages query upstream results by `commit_label` + `src_file`
- tape history preserves lineage (who wrote what, where)

Reference:

- `examples/workflows/005-pipeline-stage-lineage.jl`
- `notes/index/006-workflow-surfaces.md` (Pipeline Workflow)

## Shared In-Memory Handoff (`shared.*`)

`shared.*` provides an in-process registry for exchanging scopes without writing external ad-hoc files.

Useful operations:

- `@simos shared.capture(key, ...)`
- `@simos shared.bind(key, ...)`
- `@simos shared.merge(dst, src)`
- `@simos shared.keys()`, `@simos shared.has(key)`, `@simos shared.drop(key)`, `@simos shared.clear()`

Capture filters can be reused here:

- `capture_filter_register!(...)`
- `capture_filter_bind!(...)`
- `capture_filters_snapshot!()`
- `capture_filters_reset!()`

Reference:

- `examples/workflows/006-shared-scope-handoff.jl`

## Julia Exports (Top-Level `Simuleos`)

Current top-level exported symbols (see `src/Simuleos.jl`):

- Lifecycle: `sim_init!`, `sim_reset!`
- Reader/query: `project`, `each_commits`, `each_scopes`, `latest_scope`, `value`, `scope_table`
- Cache helper: `remember!`
- Capture filter management: `simignore!`, `capture_filter_register!`, `capture_filter_bind!`, `capture_filters_snapshot!`, `capture_filters_reset!`
- Macro/API: `@simos`, `SIMOS_GLOBAL_LOCK`, `SIMOS_GLOBAL_LOCK_ENABLED`

## CLI (Project Tooling Surface)

The repo includes a standalone CLI wrapper at `cli/bin/simos` (the help text currently brands itself as `Simules CLI`).

Examples:

```bash
./cli/bin/simos help
./cli/bin/simos stats
./cli/bin/simos stats /path/to/project
./cli/bin/simos stats --project /path/to/project
```

CLI validation:

```bash
julia --project=cli cli/test/runtests.jl
```

## Repo Pointers (Use These First)

- `examples/workflows/README.md`: curated workflow catalog and syntax conventions
- `examples/workflows/*.jl`: runnable examples for each major feature
- `src/Simuleos.jl`: public export surface
- `notes/index/003-public-api-surface.md`: public API policy
- `notes/index/006-workflow-surfaces.md`: workflow families and behavioral assumptions

## Contributor Notes for Agents

- Prefer the curated examples over older ad-hoc scripts when learning syntax.
- Treat `src/Simuleos.jl` as the public export boundary.
- Use explicit imports and qualified internal references when editing internals.
- For live experimentation, sandbox your Simuleos home/project paths (see `dev/live/501-record-and-read.jl` and repo `AGENTS.md` guidance).
