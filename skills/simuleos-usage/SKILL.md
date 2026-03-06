---
name: simuleos-usage
description: How to use Simuleos properly — philosophy, mental model, patterns, and best practices for recording and reading simulation state. Use when writing scripts that use Simuleos, or when an agent needs to learn how to work with Simuleos.
user-invocable: true
---

# Using Simuleos

Simuleos is a Julia package for recording simulation and workflow state as traceable, typed records. It is composed of subsystems that are combined into user-facing workflows.

---

## Philosophy

### Your computation is an experiment

Code changes can change the meaning of your experiment, not only its implementation. Your computation deserves the same traceability that a lab notebook gives a wet-lab experiment.

### Record first, filter later

Capture data at the moment it exists rather than deciding in advance what matters. Post-processing and selection can be refined later; lost data cannot.

### Maximize exploration speed without losing traceability

Keep the default workflow lightweight so you can iterate quickly while still producing a traceable record. Higher-cost rigor (full reproducibility pinning, strict commit policies) is opt-in.

### Maximize resolution at constant cost

Whenever you can increase the ability to distinguish records without spending more resources, do it. Labels, metadata keys, and scope names are cheap — use them to their full discriminating potential. Free resolution gains should never be left on the table.

---

## Mental Model

### Subsystems

Simuleos is composed of subsystems, each responsible for a specific concern. User-facing **workflows** are compositions of these subsystems.

| Subsystem | Responsibility |
|-----------|---------------|
| **Tape** | Append-only record persistence. Reads and writes serialized records to tape files. |
| **Blob storage** | Content-addressed binary storage for large values. |
| **Capture** | Extracts data from runtime sources, routes variables through storage policies, composes typed snapshots. |
| **Settings** | Layered key-value configuration from multiple sources (defaults, project, env, CLI, runtime). |
| **Session** | Groups captures into a named timeline with commits. Manages staging, commit grouping, and persistence. |
| **Git** | Repository metadata extraction (commit, branch, dirty state) for code provenance. |
| **SQLite index** | Optional query acceleration over tape metadata. |
| **Shared state** | In-memory named scope registry for cross-script data handoff within a process. |
| **Cache** | Keyed computation cache backed by blob storage and tape. |

### Data classes

Simuleos organizes recorded data around **semantic data classes** (`SimuleosDataClass`). A class defines how data is captured, serialized, and rehydrated — the contract between runtime and disk.

Three class families:

- **`src.*` — source observations.** Atomic data extracted from a specific runtime source at capture time. The Julia scope is one such source, but not the only one:
  - `src.namespace_bindings` — variable bindings from local/global scope
  - `src.execution_site` — source file, line, thread, timestamp
  - `src.codebase` — git commit, branch, dirty state
  - `src.runtime_host` — Julia version, hostname, OS, threads
  - `src.settings_access` — which settings were read during the session
  - `src.session_state` — session identity and labels
  - More sources can be added without changing existing ones.

- **`snap.*` — snapshots.** Compositions of sources into observation units:
  - `snap.scope` — `src.namespace_bindings` + `src.execution_site`. Produced by `@simos scope.capture(label)`.
  - `snap.context` — settings + codebase + host + execution + session state. Full provenance at a point in time.
  - `snap.shared` — `src.namespace_bindings` + `src.execution_site` for in-memory handoff.

- **`rec.*` — records.** Persistence envelopes written to tape:
  - `rec.capture_commit` — groups one or more `snap.scope` with a commit label.
  - `rec.ref` — content-addressed reference to another record.

### Workflows

User-facing operations compose multiple subsystems:

- **Scope recording** (capture + session + tape + blob storage) — extract source observations, stage and group into commits, persist. The most common workflow.

- **Scope reading** (tape + class system + blob storage) — load records from tape, decode into typed objects, rehydrate blob values on demand.

- **Queried reading** (SQLite index + scope reading) — fast metadata filtering, then value materialization.

- **Pipeline handoff** (recording + reading) — each script commits under a well-known label; the next script reads by that label. The commit label is the contract.

- **Shared in-memory handoff** (shared state) — named scopes held in memory for cross-script exchange, bypassing tape.

### Capture routing

When `@simos scope.capture(label)` runs, every visible variable is routed through a priority chain. The design goal is to balance **recording everything that matters** with **efficiency** — lite scalars are inlined automatically, complex types are voided by default. The user opts in to storing complex data via `stage.*` commands.

**Pre-filter:** Modules and Functions are completely ignored — they never enter the scope record.

**Routing priority** (first match wins):

1. **`@simos stage.blob(var)`** → **Blob** — binary-serialized to content-addressed file; scope stores a `BlobRef`
2. **`@simos stage.inline(var)`** → **Inline** — JSON-serialized directly in the tape record
3. **`@simos stage.hash(var)`** → **Hash** — only a SHA-1 fingerprint stored
4. **Lite scalar types** (`Bool`, `Int`, `Float64`, `String`, `Nothing`, `Missing`, `Symbol`) → **Inline** — auto-inlined, no staging needed
5. **Everything else** → **Void** — type name recorded, value dropped

**Implications:**

- **Scalars are free.** Auto-inlined at rule 4 with no staging needed.
- **Complex types are voided by default.** `DataFrame`, `Dict{String,Vector}`, custom structs, etc. are silently dropped unless explicitly staged. This keeps captures fast and lean.
- **Staging is sticky per session.** Once you call `@simos stage.blob(df)`, that name stays in the blob set for all subsequent captures.
- **Choosing `stage.blob` vs `stage.inline` is consequential.** These decisions affect tape size, read performance, and queryability. Document or communicate the choice — ideally consult the user/researcher. Use `stage.inline` for moderate data that benefits from being JSON-queryable; `stage.blob` for large binary data.

---

## The `@simos` Interface

The `@simos` macro is the **only** user-facing interface. Think of it as a runtime CLI — you issue commands in `namespace.verb(args...)` form and the macro dispatches to the appropriate subsystem. Direct function calls into internal modules are not supported and may break without notice.

### Namespaces

| Namespace | Subsystem | Purpose |
|-----------|-----------|---------|
| `system.*` | Lifecycle | Runtime init and reset |
| `session.*` | Session | Init, commit, batch commit, finalize |
| `stage.*` | Capture | Stage variables and metadata before capture |
| `scope.*` | Capture | Capture scopes, bind variables from recorded scopes |
| `settings.*` | Settings | Layered settings management |
| `cache.*` | Cache | Keyed computation cache |
| `shared.*` | Shared state | In-memory scope registry for cross-script handoff |
| `project.*` | Project | Active project handle |
| `context.*` | Capture | Context capture and provenance tagging |
| `sqlite.*` | SQLite index | Metadata queries over tapes |

### Scope recording workflow

```
system.init → session.init → [stage.* → scope.capture → session.commit]... → session.close → system.reset
```

1. `@simos system.init(...)` — start the engine.
2. `@simos session.init(label)` — open a session timeline.
3. `@simos stage.inline(vars...)` / `stage.blob(...)` / `stage.hash(...)` — configure capture routing.
4. `@simos stage.meta(key = value, ...)` — annotate with metadata.
5. `@simos scope.capture(label)` — extract sources, produce a `snap.scope`.
6. `@simos session.commit(label)` / `session.batch_commit(...)` — group staged scopes into `rec.capture_commit`, persist to tape.
7. `@simos session.close(label)` — flush remaining staged/queued commits.
8. `@simos system.reset()` — clean up.

### Scope reading workflow

1. `proj = @simos project.current()` — get project handle.
2. `latest_scope(proj; session=..., commit_label=...)` — query.
3. `value(scope.variables[:x], proj)` — materialize values (blob storage rehydrates on demand).
4. `each_scopes(proj; session=...)`, `each_commits(proj; ...)` — iterate.
5. `scope_table(proj; ...)` — flat row export.

---

## CLI Settings

The settings subsystem automatically parses `Base.ARGS` at module load time (`using Simuleos`). CLI flags are available as settings immediately — no manual call needed.

### Syntax

```bash
julia myscript.jl --set sim.n_samples=5000 --set sim.commit_every=100
julia myscript.jl --config my_run.json
julia myscript.jl --config defaults.json --set sim.n_samples=500
```

Value coercion is automatic: `"true"`/`"false"` → `Bool`, integer strings → `Int`, float strings → `Float64`, otherwise `String`.

### Reading settings in scripts

```julia
N_SAMPLES = @simos settings.get(sim.n_samples, default=1000)
OUTPUT_DIR = @simos settings.require(sim.output_dir)

if @simos settings.has(sim.debug)
    # ...
end
```

Call `@simos settings.source.add_args(ARGS)` explicitly only if you need to re-parse or inject a custom argument vector after `system.init`.

---

## Patterns

<!-- APPEND-FRIENDLY: each entry is one `- **Title.**` bullet. Add new entries at the end. -->

- **Recovery and resume.** Pick up where a previous run left off: `seed = latest_scope(proj; session=..., commit_label=...)` then `@simos scope.bind(seed, proj, x, y, z)` to hydrate variables. Continue recording into a new session. See `examples/workflows/003-recover-and-resume.jl`.

- **Keyed cache.** Skip expensive recomputation: `hash = @simos cache.key(input_data, config)` then `@simos cache.remember(hash, result) do ... end`. Cache-key collisions are treated as semantic equivalence — include all materially relevant inputs. See `examples/workflows/004-keyed-cache-remember.jl`.

- **Pipeline across scripts.** Each stage commits under a well-known label, the next stage reads it: `latest_scope(proj; commit_label = "preprocessed")`. The commit label is the contract. See `examples/workflows/005-pipeline-stage-lineage.jl`.

- **Shared in-memory handoff.** Exchange typed data in the same process: `@simos shared.capture("key", vars...)` / `@simos shared.bind("key", vars...)`. See `examples/workflows/006-shared-scope-handoff.jl`.

- **Settings-driven workflow.** Use `settings.get(key, default=...)` for optional inputs, `settings.require(key)` for required inputs, `settings.snapshot()` for reproducibility snapshots. See `examples/workflows/007-settings-and-context-tags.jl`.

- **SQLite metadata queries.** `@simos sqlite.open(; sync = :refresh)` for fast metadata queries. Use views (`v_sessions`, `v_commits`, `v_scope_inventory`, etc.). SQLite stores metadata only — hydrate values with `latest_scope` + `value()`. See `examples/workflows/008-sqlite-metadata-queries.jl`.

---

## Best Practices

<!-- APPEND-FRIENDLY: each entry is one `- **Title.**` bullet. Add new entries at the end. -->

- **Name sessions and commits meaningfully.** These labels are how you (and future-you) will find runs later. Short, descriptive, unique enough.

- **Prefer unique commit labels per commit site.** Each `session.commit(label)` call in a script represents a different point in execution. Even when commits are semantically related, the labels should differ enough to identify their origin. Share semantic roots but add a distinguishing suffix — e.g., `"run.main.summary"` and `"run.main.sample"` instead of `"run.main"` for both. This is a direct application of the "maximize resolution at constant cost" principle: the label field is already there, so use it.

- **Use metadata liberally.** `stage.meta(step = i, phase = "main")` — annotate anything you'll want to filter by later. Metadata is cheap.

- **Trust the default capture behavior.** Lite scalar types are auto-inlined without staging. For complex types, choose `stage.inline` or `stage.blob` deliberately — these are consequential decisions that affect tape size and queryability.

- **Always sandbox during development.** `@simos system.init(; reinit = true, sandbox = (root = ..., clean_on_init = true, cleanup_on_reset = false))` keeps real project data untouched.

- **Respect the dirty-repo guard.** Simuleos errors on dirty git state at session init by design — it ties data to a known code state. Use `git_dirty_policy = "commit_all"` only when you understand the tradeoff.

- **Use `project_basename_hint` in editor workflows.** Pass it to `system.init` to fail fast on project mismatches when running from an unexpected working directory.

- **Learn from the curated examples.** `examples/workflows/` is the source of truth for current call syntax — prefer it over reading source code.

---

## Anti-Patterns

<!-- APPEND-FRIENDLY: each entry is one `- **Don't ...** bullet. Add new entries at the end. -->

- **Don't skip `system.init`.** It bootstraps the runtime. Nothing works without it.

- **Don't call internal functions directly.** Use `@simos namespace.verb(...)` for everything. Internal modules (`Kernel`, `SimosAPI`, `WorkSession`) are not public API.

- **Don't parse error messages for control flow.** Use typed results and structured outcomes.

- **Don't duplicate Kernel logic.** If Simuleos defines a path convention or parsing rule, use it — don't reimplement.

- **Don't hold sessions open indefinitely.** Finalize or commit when your logical unit of work is done.

---

## Reference

- Curated examples: `examples/workflows/` (start with `001-record-read-roundtrip.jl`)
- Workflow catalog: `examples/workflows/README.md`
- Design principles: `notes/index/002-core-design-principles.md`
- Workflow surfaces: `notes/index/006-workflow-surfaces.md`
- Anti-patterns: `notes/index/008-anti-patterns-to-avoid.md`
- Public API policy: `notes/index/003-public-api-surface.md`

### Exported symbols (`import Simuleos`)

- **Lifecycle:** `sim_init!`, `sim_reset!`
- **Reader/query:** `project`, `each_commits`, `each_scopes`, `latest_scope`, `value`, `scope_table`
- **Cache:** `cache_remember!`
- **Capture filters:** `simignore!`, `capture_filter_register!`, `capture_filter_bind!`, `capture_filters_snapshot!`, `capture_filters_reset!`
- **Macro:** `@simos`
