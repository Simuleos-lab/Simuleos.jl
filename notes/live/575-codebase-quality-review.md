### Issue: `settings_reload!` can fail after adding CLI args settings

**Location:** `src/Kernel/core/settings.jl`, `src/Kernel/core/cli_args.jl`

**Why this is an issue:**
The code allows creating a `:cli` settings layer, but a full reload path still treats `:cli` as reloadable while its reload branch explicitly errors. This makes reload behavior depend on prior runtime calls and can break scripts unexpectedly.

**Evidence:**
- CLI layer creation: `kind = :cli` (`src/Kernel/core/cli_args.jl:104-107`).
- Full reload includes `:cli` (`src/Kernel/core/settings.jl:819-820`).
- Reload handler for `:cli` throws: `error("CLI settings source reload is not implemented yet.")` (`src/Kernel/core/settings.jl:801-803`).
- Repro:
  - `sim_init!(sandbox=true); @simos settings.source.add_args(["--set","x=1"]); @simos settings.source.reload()`
  - raises `ErrorException: CLI settings source reload is not implemented yet.`

**Improvement proposals:**
1. Small: remove `:cli` from `settings_reload!` until reload semantics are implemented.
2. Medium: add a per-layer `reloadable` capability and only reload layers that declare it.
3. Larger: persist enough `:cli` origin metadata to deterministically rebuild CLI data on reload.

**Expected impact:**
More predictable runtime behavior and fewer reload-time surprises.

---

### Issue: CLI settings parser silently ignores unknown arguments

**Location:** `src/Kernel/core/cli_args.jl`

**Why this is an issue:**
Unknown flags are skipped without warning, so typos or stale options quietly disappear. Silent drops increase debugging time and can produce hard-to-explain configuration drift.

**Evidence:**
- Parser fallback branch: `# Skip unrecognized arguments` (`src/Kernel/core/cli_args.jl:79-81`).
- Only `--set` / `--config` are processed; everything else is ignored.

**Improvement proposals:**
1. Small: collect unknown args and emit one warning with the ignored list.
2. Medium: add a strict mode (`strict=true`) that errors on unknown args.
3. Larger: return `(settings, diagnostics)` so callers can decide warning/error policy explicitly.

**Expected impact:**
Safer configuration handling and faster diagnosis of option mistakes.

---

### Issue: invalid session timestamps silently collapse to epoch and bias session resolution

**Location:** `src/Kernel/core/project.jl`

**Why this is an issue:**
Timestamp parse failures are silently mapped to `DateTime(0)`, then used in recency selection for labeled sessions. Corrupt or malformed metadata can be treated as old sessions without surfacing data quality problems.

**Evidence:**
- Parse fallback returns epoch on any parse error (`src/Kernel/core/project.jl:147-150`).
- Session lookup picks the max timestamp for a label (`src/Kernel/core/project.jl:194-204`).

**Improvement proposals:**
1. Small: log/warn on timestamp parse failures with session ID/path context.
2. Medium: return `Union{Nothing, DateTime}` from `_session_timestamp` and handle invalid timestamps explicitly.
3. Larger: validate timestamp format at write time and reject invalid metadata early.

**Expected impact:**
More trustworthy session resolution and better observability of metadata issues.

---

### Issue: SQLite transaction rollback failure is swallowed

**Location:** `src/SQLiteIndex/sql_helpers.jl`

**Why this is an issue:**
If transaction rollback itself fails, the code suppresses that error and rethrows only the original error. This can hide real DB state problems and make recovery/debugging harder.

**Evidence:**
- Nested silent catch around rollback (`src/SQLiteIndex/sql_helpers.jl:18-22`).
- No logging or contextual signal when rollback fails.

**Improvement proposals:**
1. Small: emit a warning when rollback fails before rethrowing.
2. Medium: wrap and throw a composite error that preserves both original and rollback failures.
3. Larger: centralize transaction error policy with structured error types and diagnostics.

**Expected impact:**
Better incident diagnosis and safer handling of DB failure scenarios.

---

### Issue: cache hit counter parsing can silently reset malformed values

**Location:** `src/Kernel/cache.jl`

**Why this is an issue:**
Malformed persisted `hits` values are coerced to `0` without signaling corruption, then incremented and written back. This silently masks metadata integrity issues and can skew cache observability.

**Evidence:**
- `_cache_hits` catches parse failure and returns `0` (`src/Kernel/cache.jl:35-43`).
- Result is immediately persisted as `meta["hits"] = _cache_hits(...) + 1` (`src/Kernel/cache.jl:73`).

**Improvement proposals:**
1. Small: warn when coercion fallback is used (include offending value).
2. Medium: use stricter validation and keep invalid original value under an error key for forensics.
3. Larger: migrate cache metadata to a typed schema with versioned validation.

**Expected impact:**
More reliable cache metrics and earlier detection of metadata corruption.

---

## Top 5 prioritized improvements

1. Fix `settings_reload!` / `:cli` inconsistency to prevent runtime reload failures.
2. Stop silently ignoring unknown CLI args (add warnings or strict mode).
3. Surface invalid session timestamp data instead of silently coercing to epoch.
4. Improve SQLite transaction rollback diagnostics (do not silently swallow rollback failures).
5. Harden cache hit metadata parsing to avoid silent counter resets.

## Codebase health summary

The codebase remains structurally strong, with clear modules and substantial tests, and recent refactors improved major hotspots. Current maintainability risks are mostly in error/diagnostic semantics where silent fallbacks can hide real state problems. Prioritizing explicit failure signaling and deterministic reload/config behavior should yield high quality gains with small incremental changes.
