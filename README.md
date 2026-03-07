
[![CI](https://github.com/Simuleos-lab/Simuleos.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/Simuleos-lab/Simuleos.jl/actions/workflows/CI.yml)
[![Coverage](https://codecov.io/gh/Simuleos-lab/Simuleos.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Simuleos-lab/Simuleos.jl)

# Simuleos.jl



Simuleos is a Julia package for recording simulation and workflow state as traceable scopes, organizing them by session and commit lineage, and reading them back for analysis, recovery, and cross-script handoff.

## Quick Start

Requires Julia `1.10+` (see `Project.toml`).

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
julia --project=. examples/workflows/007-settings-and-context-tags.jl
julia --project=. examples/workflows/008-sqlite-metadata-queries.jl
```

## Minimal Example

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

    @simos rec.inline(params, total)
    @simos rec.meta(step = step, phase = "warmup")
    @simos rec.capture("snapshot")
    @simos session.close("final")
end

proj = @simos project.current()
scope = latest_scope(proj; session = "demo", commit_label = "final")
println(value(scope.variables[:params], proj))

@simos system.reset()
```

## Project Layout

```
src/            — main Julia package
  Kernel/       — internal engine: state, classes, infra, workflows
  SimosAPI/     — @simos macro dispatch
  WorkSession/  — user-facing session control
  SQLiteIndex/  — optional SQLite query backend
examples/       — curated runnable workflows
cli/            — project CLI tool
notes/index/    — design principles and constraints
test/           — test suite
```

## Learning Path

1. Read this README for orientation.
2. Run `examples/workflows/001-record-read-roundtrip.jl`.
3. Browse `examples/workflows/README.md` for the full workflow catalog.
4. Check `notes/index/` for design principles and constraints.

## Repo Pointers

- `examples/workflows/README.md` — workflow catalog and syntax conventions
- `examples/workflows/*.jl` — runnable examples for each major feature
- `src/Simuleos.jl` — public export surface
- `notes/index/002-core-design-principles.md` — core design philosophy
- `notes/index/003-public-api-surface.md` — API stability policy
- `notes/index/006-workflow-surfaces.md` — workflow families and behavioral contracts
- `AGENTS.md` — contributor guidelines for agents developing Simuleos

## CLI

```bash
./cli/bin/simos help
./cli/bin/simos stats
./cli/bin/simos stats /path/to/project
```

## License

See `LICENSE`.
