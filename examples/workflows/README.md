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

## Settings + Context Best Practices

- Prefer the public `@simos settings.*` commands in scripts/examples instead of calling `Kernel.settings_*` internals directly.
- Put script defaults in a mutable layer (`:script` or `:session`) and make the chosen precedence explicit.
- For CLI-driven workflows, load overrides with `@simos settings.source.add_args(ARGS)`; use `after = :script` if CLI should override script defaults.
- Use `@simos settings.require(...)` for required inputs and `@simos settings.get(...; default=...)` for optional inputs.
- Use `@simos settings.snapshot(...)` to emit a reproducible settings snapshot alongside exported artifacts.
- Create artifact filenames with a context tag from `@simos context.capture()` (returns a `RecordRef` with string-friendly short form).
- Resolve provenance with `@simos context.resolve(ref)` while the session is active.
- Keep artifact generation inside an active session if you need `@simos context.capture()` / `@simos context.resolve(...)`.

## SQLite Query Best Practices

- Use `@simos sqlite.open(; sync = :refresh)` to open the index — it incrementally updates from tapes.
- Access row columns by name (`row[:column_name]`) instead of positional `SQLite.values(row)`.
- Use `v_sessions`, `v_commits`, `v_scope_inventory`, `v_scope_vars_inventory`, `v_scope_meta_inventory` views for fully joined queries.
- Use `session_labels` (not `session_label`) to find sessions by secondary labels (e.g. `"alpha-run"` when the primary label is `"experiment"`).
- Use `session_labels_csv` from `v_sessions` for display — it shows all labels semicolon-separated.
- For value hydration (reading actual blob/inline values), use `latest_scope` + `value()` or `scope.bind` — the SQLite index stores metadata only, not values.
- Close the handle with `@simos sqlite.close()` when done.

## Run

```bash
julia --project=. examples/workflows/001-record-read-roundtrip.jl
julia --project=. examples/workflows/002-compare-sessions-and-export.jl
julia --project=. examples/workflows/003-recover-and-resume.jl
julia --project=. examples/workflows/004-keyed-cache-remember.jl
julia --project=. examples/workflows/005-pipeline-stage-lineage.jl
julia --project=. examples/workflows/006-shared-scope-handoff.jl
julia --project=. examples/workflows/007-settings-and-context-tags.jl

julia --project=. examples/workflows/008-sqlite-metadata-queries.jl

# With CLI settings overrides:
julia --project=. examples/workflows/007-settings-and-context-tags.jl \
  --set workflow.context_demo.scale=2.0 \
  --set workflow.context_demo.tag=experiment-A
```

## Scripts

- `001-record-read-roundtrip.jl`: basic recording + reading round-trip, including `stage.inline`, `stage.blob`, and `stage.hash` capture modes. Reads back via `@simos sqlite.*` queries against commits, scopes, variables, and metadata.
- `002-compare-sessions-and-export.jl`: record two sessions, cross-compare by step metadata via SQLite joins, and export a CSV.
- `003-recover-and-resume.jl`: recover state from `latest_scope`, hydrate variables with `@simos scope.bind(...)`, resume in a new session, then verify recovery lineage and step progression via SQLite.
- `004-keyed-cache-remember.jl`: compute context hashes and reuse cached results with `remember!` and `@simos cache.key(...)` / `@simos cache.remember(...)`.
- `005-pipeline-stage-lineage.jl`: multi-stage pipeline using commit labels + `scope.bind` for inter-stage data flow. Pipeline lineage, stage metadata, and per-stage variables queried via SQLite.
- `006-shared-scope-handoff.jl`: in-memory `@simos shared.*` workflow using filtered capture, typed bind, merge, and registry helpers (`keys/has/drop/clear`).
- `007-settings-and-context-tags.jl`: settings-driven artifact export using `@simos settings.*`, `@simos context.capture()`, and context-tagged filenames.
- `008-sqlite-metadata-queries.jl`: dedicated SQLite query cookbook — session overview, commit/scope/variable queries, metadata filters, blob lookup, aggregations, tape health checks, and parameterized SQL.
