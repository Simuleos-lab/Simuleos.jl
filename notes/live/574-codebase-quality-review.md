## ~~### Issue: `SimuleosProject.git_handler` is typed as `Any`~~

**Location:** `src/Kernel/core/types.jl`, `src/Kernel/core/base.jl`

**Why this is an issue:**
An `Any`-typed core field weakens type safety in a central runtime object and obscures the contract for git metadata providers. It increases maintenance risk when plumbing git behavior through session/capture flows.

**Evidence:**
- `git_handler::Any` in `SimuleosProject` (`src/Kernel/core/types.jl:175-181`).
- Constructor also accepts untyped `git_handler` (`src/Kernel/core/base.jl:23-30`).

**Improvement proposals:**
1. Small: change the field to `Union{Nothing, GitHandler}` by reordering declarations.
2. Medium: introduce `abstract type AbstractGitHandler end` and store `Union{Nothing, AbstractGitHandler}`.
3. Larger: parameterize `SimuleosProject` on git handler type for stricter compile-time guarantees.

**Expected impact:**
Stronger invariants, clearer extension boundaries, and better maintainability in core session/capture code paths.

---

~~### Issue: SQLite row materialization depends on internal SQLite.jl fields and is duplicated in tests~~

**Location:** `src/SQLiteIndex/sql_helpers.jl`, `test/sqlite_index_tests.jl`

**Why this is an issue:**
Accessing private row internals (`row.q.names`) is brittle against upstream package changes. Duplicating the same brittle pattern in tests multiplies migration cost and failure modes.

**Evidence:**
- Internal-field access in production helper: `names = getfield(getfield(row, :q), :names)` (`src/SQLiteIndex/sql_helpers.jl:47-50`).
- Same pattern duplicated in tests (`test/sqlite_index_tests.jl:11-15`).

**Improvement proposals:**
1. Small: centralize row-materialization in one helper and reuse it in tests.
2. Medium: switch to a public/stable row access route (e.g., `propertynames(row)` + `getproperty`, or Tables-compatible extraction).
3. Larger: provide a typed query adapter layer returning NamedTuples/structs to avoid ad-hoc row decoding.

**Expected impact:**
Lower breakage risk across SQLite.jl upgrades and reduced duplication in query-heavy tests.

---

### ~~Issue: generated workflow sandbox artifacts appear to be tracked, creating repository noise~~

**Location:** `examples/workflows/_sandbox/**`, `.gitignore`

**Why this is an issue:**
Generated `.simuleos` runtime data in workflow sandboxes creates high-churn diffs unrelated to source changes, increasing review overhead and accidental commits. This also obscures meaningful code changes in day-to-day work.

**Evidence:**
- `_sandbox` contains many generated artifacts (`examples/workflows/_sandbox/**/proj/.simuleos/...`, `metadata-v1.sqlite`, generated report files).
- `.gitignore` ignores `.simuleos/` at repo root (`/.simuleos`) but not nested workflow sandbox outputs (`.gitignore:12`).

**Improvement proposals:**
1. Small: add ignore rules for generated workflow sandbox outputs (`examples/workflows/_sandbox/**/proj/.simuleos/**`, generated report files).
2. Medium: keep only minimal deterministic fixtures and regenerate heavy outputs during tests/examples.
3. Larger: add CI guard to reject accidental commits of generated sandbox state.

**Expected impact:**
Cleaner diffs, smaller review burden, and less accidental repository churn.

---

## Top 5 prioritized improvements

1. Fix `settings_reload!` vs `:cli` inconsistency (runtime correctness + developer trust).
2. Stop using `Any` for `SimuleosProject.git_handler` (core type-safety improvement).
3. Replace brittle SQLite row materialization internals and deduplicate helper usage.
4. Consolidate CLI parser/error boilerplate and remove private-helper coupling.
5. Ignore/generated-manage `_sandbox` runtime artifacts to reduce repo noise.

## Codebase health summary

The codebase is in good shape and recently improved (notably around SQLite index split and macro-dispatch structure), with strong test coverage and clearer subsystem boundaries than before. Current risk is concentrated in cross-cutting maintainability edges: layer reload semantics, weakly typed core fields, brittle DB row extraction, and workflow artifact hygiene. Addressing the prioritized list above should deliver meaningful quality gains with incremental, low-risk changes.
