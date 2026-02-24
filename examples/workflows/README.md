# Examples: Workflows

Curated runnable workflow examples for documentation.

- `dev/live/` is the design/exploration surface.
- `examples/workflows/` is the stable, curated documentation surface.
- Each script runs in its own sandboxed Simuleos ecosystem under `examples/workflows/_sandbox/<script-name>/`.
- Scripts use the current exported `@simos` macro surface plus exported query functions.

## Syntax Conventions

- Use the standard call-style `@simos` interface in examples (for example `@simos session.init(...)`, `@simos stage.meta(...)`, `@simos cache.key(...)`).
- Do not use mixed legacy-style forms like `@simos init reinit = true ...` in curated examples.
- System operations use the `system.*` namespace.
- Engine init/reinit (including sandboxing) belongs on `@simos system.init(...)`.
- `@simos system.init(...)` is engine-only and does not accept session labels.
- `@simos system.reset(...)` wraps `sim_reset!()` (supports `sandbox_cleanup=`).
- `@simos session.init(...)` is session-only and should not carry engine lifecycle kwargs.
- Sandboxed startup is shown with `@simos system.init(...)` call-style keywords:

```julia
const SANDBOX_SPEC_CLEAN = (root = SANDBOX_DIR, clean_on_init = true, cleanup_on_reset = false)
@simos system.init(; reinit = true, sandbox = SANDBOX_SPEC_CLEAN)
@simos session.init("demo", "run-1")
```

## Run

```bash
julia --project=. examples/workflows/001-record-read-roundtrip.jl
julia --project=. examples/workflows/002-compare-sessions-and-export.jl
julia --project=. examples/workflows/003-recover-and-resume.jl
julia --project=. examples/workflows/004-keyed-cache-remember.jl
julia --project=. examples/workflows/005-pipeline-stage-lineage.jl
julia --project=. examples/workflows/006-shared-scope-handoff.jl
```

## Scripts

- `001-record-read-roundtrip.jl`: basic recording + reading round-trip, including `stage.inline`, `stage.blob`, and `stage.hash` capture modes.
- `002-compare-sessions-and-export.jl`: record two sessions, flatten with `scope_table`, compare rows, and export a CSV.
- `003-recover-and-resume.jl`: recover state from `latest_scope`, hydrate variables with `@simos scope.bind(...)`, and resume in a new session.
- `004-keyed-cache-remember.jl`: compute context hashes and reuse cached results with `remember!` and `@simos cache.key(...)` / `@simos cache.remember(...)`.
- `005-pipeline-stage-lineage.jl`: multi-stage pipeline pattern using commit labels and `src_file` filtering as stage contracts.
- `006-shared-scope-handoff.jl`: in-memory `@simos shared.*` workflow using filtered capture, typed bind, merge, and registry helpers (`keys/has/drop/clear`).
