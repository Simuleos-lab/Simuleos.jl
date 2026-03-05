# Usage Patterns: Simulation Workflows

Date: 2026-03-02
Source: Integration review of `Auxotrophs_CoCultures_20251109/scripts/simulations.uh.1/`

## Context

First real integration of Simuleos into a parameter-sweep FBA simulation workflow.
The workflow has a recording script (MAIN) and a reading/plotting script (PLOTS).

---

## Idiomatic patterns confirmed

### Implicit capture via Julia scope

`scope.capture` picks up local variables (YA1, YA2, df) from the Julia lexical scope. This is the intended input surface. No explicit staging of captured variables is needed unless changing storage kind (e.g., `stage.blob(df)` for large objects).

Staging metadata (`stage.meta`) is for workflow-level provenance (script name, config), not for duplicating captured variables. If a variable is captured, it should not also be staged as metadata.

### Session lifecycle

```
@simos system.init(...)
@simos session.init("label")
# loop:
    @simos scope.capture("scope.label")
    @simos session.commit("commit.label")
@simos session.close("commit.label")
```

### Blob staging for large objects

`@simos stage.blob(df)` before the loop — persists across captures (only `meta_buffer` is cleared per capture). Correct for DataFrames and other non-scalar objects.

---

## Reading path: sqlite is the user-facing query interface

### Principle

- `@simos sqlite.*` is the intended read/query path.
- `each_scopes()` / raw tape iteration is internal only.
- `@simos scope.bind()` is not the target pattern — sqlite queries are.

### Current read pattern (sqlite-based)

```julia
@simos system.init(...)
@simos sqlite.open(; sync = :refresh)

for row in @simos sqlite.execute("""
    SELECT sv.blob_ref, ...
    FROM v_scope_vars_inventory sv
    JOIN scope_labels sl ON sv.scope_uid = sl.scope_uid
    WHERE sv.session_label = ?
      AND sl.label = 'main.sample'
      AND sv.var_name = 'df'
      AND sv.storage_kind = 'blob'
""", (session_label,))
    df = _read_blob(row[:df_blob_ref])
end
```

### Blob materialization

No `@simos blob.read(hash)` exists. Current workaround:

```julia
proj = @simos project.current()
ref = Simuleos.Kernel.BlobRef(hash = String(blob_hash))
payload = Simuleos.Kernel.blob_read(proj.blobstorage, ref)
```

This reaches into Kernel internals. A macro-level `@simos blob.read(hash)` would complete the sqlite read path.

---

## Feature gaps identified

### 1. Inline variable values not in sqlite index

The `scope_vars` table indexes variable metadata (name, type, storage kind, blob ref) but **not** the actual value of inline variables. For small scalars (Float64, Int64, String, Bool), this means sqlite alone cannot retrieve parameter values like YA1, YA2.

**Impact**: The sqlite query path is incomplete for the common pattern of "find scopes and read their scalar parameters." Users must either fall back to tape reads or redundantly stage values as metadata.

**Possible resolution**: Add a `value_text` column to `scope_vars` for small scalar types. The index builder already knows the storage kind and type — it could stringify scalars at index time.

### 2. No macro-level blob read

`@simos blob.meta(hash)` exists but returns metadata only. There is no `@simos blob.read(hash)` to materialize a blob payload. This forces users into `Simuleos.Kernel.blob_read(...)` which bypasses the macro API contract.

### 3. Commit batching ergonomics

`session.commit` per scope (e.g., per sample in a 10k sweep) creates one tape record per commit — too granular. A single massive commit is also wrong. `session.queue` with `cmt_every` exists but users must manually tune the batch size.

**Missing**: A mechanism to help users balance commit granularity. Adaptive batching, size-based thresholds, or at minimum clear guidance on choosing `cmt_every` for common patterns.

### 4. Progress feedback during long sessions

No built-in progress reporting during long recording loops. Not critical but would improve usability for sweeps with thousands of samples.

---

## Anti-patterns rejected

- **Duplicating captured variables as metadata** — redundant; Simuleos captures from the Julia scope.
- **Imposing parameter semantics** — what is a "parameter" vs a "variable" is context-dependent and inferable from source. Simuleos should not impose structure.
- **Validation hooks in Simuleos** — Simuleos does not duplicate Julia control logic. Validation belongs in user code.
- **Comparison session abstractions** — use sqlite queries directly; stress what can be done with SQL before adding specialized abstractions.

---

## Scripts reference

- Recording: `scripts/simulations.uh.1/201.fix.point.fba.v1.MAIN.jl`
- Reading/plotting: `scripts/simulations.uh.1/202.fix.point.fba.v1.PLOTS.jl`
- Init: `scripts/simulations.uh.1/000.simos.init.jl`
