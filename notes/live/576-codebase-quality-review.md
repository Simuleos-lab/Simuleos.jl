### Issue: session start uses stale persisted git-dirty metadata

**Location:** `src/WorkSession/session.jl`

**Why this is an issue:**
`session_init!` only captures git metadata when `ws.metadata` is empty, but always enforces the dirty guard from stored metadata. Reopening an existing session can keep old dirty state and block session start even after the repo is clean.

**Evidence:**
- Metadata capture is conditional (`if isempty(ws.metadata) ...`) (`src/WorkSession/session.jl:155-159`).
- Dirty guard always checks stored metadata right after (`src/WorkSession/session.jl:160-161`).

**Improvement proposals:**
1. Small: recompute git dirty status at init-time before enforcing the guard.
2. Medium: refresh only git-related metadata fields on every `session_init!`.
3. Larger: separate immutable session metadata from runtime validation checks so guards always use live state.

**Expected impact:**
More reliable session lifecycle behavior and fewer false-negative startup failures.

---

### Issue: `latest_scope` always performs a full forward scan

**Location:** `src/ScopeReader/ScopeReader.jl`

**Why this is an issue:**
`latest_scope` iterates all filtered scopes to keep only the last one. For long tapes, this is O(n) per call and can become a hot-path bottleneck in interactive analysis scripts.

**Evidence:**
- Loop-over-all pattern: `for scope in each_scopes(...) ; latest = scope ; end` (`src/ScopeReader/ScopeReader.jl:117-120`).

**Improvement proposals:**
1. Small: add a fast-path using indexed metadata when available (e.g., SQLite index).
2. Medium: add reverse iteration support in tape reader and stop at first matching scope.
3. Larger: cache per-filter “last seen” scope references with invalidation on new commit writes.

**Expected impact:**
Lower query latency and better scalability on large session histories.

---

### Issue: session-label resolution can be nondeterministic on timestamp ties

**Location:** `src/Kernel/core/project.jl`

**Why this is an issue:**
Session scanning reads directory entries without sorting and tie-breaks only by timestamp using `>`. If two matching sessions have equal timestamps, winner selection depends on filesystem order.

**Evidence:**
- Unsorted scan: `for entry in readdir(sdir)` (`src/Kernel/core/project.jl:170`).
- Winner update only when `ts > best_ts` (`src/Kernel/core/project.jl:201`), no deterministic tie-breaker.

**Improvement proposals:**
1. Small: sort entries before scanning.
2. Medium: add deterministic tie-break (e.g., timestamp then UUID/session_id lexicographic).
3. Larger: persist monotonic sequence/order metadata and resolve by explicit order key.

**Expected impact:**
Deterministic session resolution and more predictable behavior across platforms.

---

~~### Issue: sqlite runtime open/refresh/rebuild paths duplicate cache lifecycle logic~~

**Location:** `src/SimosAPI/macro/runtime.jl`

**Why this is an issue:**
Open/refresh/rebuild each manually repeat project assertions, cached DB close/reopen decisions, and db-path updates. This duplication raises drift risk when one path changes and others are not updated.

**Evidence:**
- Similar cache-close/reopen flows in:
  - `_simos_sqlite_open_runtime!` (`src/SimosAPI/macro/runtime.jl:59-87`)
  - `_simos_sqlite_refresh_runtime!` (`src/SimosAPI/macro/runtime.jl:89-100`)
  - `_simos_sqlite_rebuild_runtime!` (`src/SimosAPI/macro/runtime.jl:102-113`)

**Improvement proposals:**
1. Small: extract one helper for “refresh/rebuild with optional reopen”.
2. Medium: unify operations behind a single `sync(mode)` runtime path.
3. Larger: model sqlite runtime as a small state machine (closed/open/stale/reopening) to centralize transitions.

**Expected impact:**
Lower maintenance overhead and safer future changes to SQLite runtime behavior.

---

### Issue: missing-session pruning uses per-row deletes (N+1 query pattern)

**Location:** `src/SQLiteIndex/session_index.jl`

**Why this is an issue:**
Pruning fetches all indexed sessions, then loops and executes delete operations row-by-row. This increases DB round-trips and maintenance complexity as session counts grow.

**Evidence:**
- Loads all session IDs, then loops with per-row delete statements (`src/SQLiteIndex/session_index.jl:193-200`).

**Improvement proposals:**
1. Small: issue one SQL delete using a `NOT IN (...)`/temporary table strategy.
2. Medium: perform catalog + sessions cleanup using a single batched pruning transaction.
3. Larger: maintain a sync table of “seen this refresh” markers and prune set-differentially in SQL.

**Expected impact:**
Faster refresh operations and simpler pruning logic for larger projects.

---

## Top 5 prioritized improvements

1. Fix stale git-dirty enforcement in `session_init!`.
2. Make session label resolution deterministic on timestamp ties.
3. Add a fast-path for `latest_scope` to avoid full scans.
4. Refactor duplicated sqlite runtime cache lifecycle logic.
5. Batch missing-session pruning to avoid row-by-row deletes.

## Codebase health summary

The codebase is generally healthy, with clear module boundaries and strong test coverage, but several runtime paths still rely on implicit behavior and repeated control flow. Main risk areas are deterministic resolution semantics, query/runtime efficiency on growing data, and duplicated lifecycle logic in sqlite + session paths. Incremental refactors around these hotspots should improve maintainability without broad architectural change.
