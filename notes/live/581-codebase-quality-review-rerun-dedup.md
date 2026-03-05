# Codebase Quality Review (Rerun, deduplicated findings)

Scope reviewed: `src/`, `test/`, and prior quality-review live notes.  
Assumption used for deduplication: avoid repeating previously reported rerun themes (`tape.jl` concentration, `@simos` dispatch concentration, placeholder includes, large test files, README export drift).

### Issue: `session_init!` can enforce stale persisted git-dirty metadata

**Location:** `src/WorkSession/session.jl`

**Why this is an issue:**
Git dirty policy is only applied when session metadata is empty, but dirty enforcement always checks persisted metadata afterward. Reopening an existing session can therefore enforce outdated `git_dirty` state instead of current repository state.

**Evidence:**
- Metadata/policy refresh only under `if isempty(ws.metadata)` (`session.jl:206-211`).
- Dirty guard always runs after that (`session.jl:212-213`).
- Result: stale persisted metadata can block starts even when live repo state has changed.

**Improvement proposals:**

1. Small: recompute `SESSION_META_GIT_DIRTY_KEY` on every `session_init!` before the guard.
2. Medium: refresh git-only metadata fields unconditionally while keeping other metadata immutable.
3. Larger: split persisted session metadata from runtime validation state and always validate against live git status.

**Expected impact:**
More reliable session lifecycle behavior and fewer false blocking errors.

### Issue: session label lookup hard-codes “primary label only” semantics

**Location:** `src/Kernel/Infra/project/project.jl`

**Why this is an issue:**
Label resolution only matches against `labels[1]`, so secondary labels are silently ignored by lookup. This creates hidden semantics that are easy to misuse and hard to discover.

**Evidence:**
- Resolver explicitly matches only first label entry: `labels[1] == stripped` (`project.jl:193-199`).
- No explicit API/type signal that only the first label is resolvable by `find_session_id`.

**Improvement proposals:**

1. Small: document first-label-only behavior near the resolver/API docs.
2. Medium: support full-label matching (`any(==(stripped), labels)`) with a compatibility flag.
3. Larger: split “session key” and “labels/tags” into separate persisted fields.

**Expected impact:**
Clearer label semantics and reduced lookup surprises for contributors/users.

### Issue: label resolution is nondeterministic on timestamp ties and scales linearly

**Location:** `src/Kernel/Infra/project/project.jl`

**Why this is an issue:**
Session scanning uses unsorted directory order and tie-breaks only on strict `>` timestamp checks. On equal timestamps, winner selection depends on filesystem iteration order; repeated lookups also require full scans.

**Evidence:**
- Unsorted scan over entries: `for entry in readdir(sdir)` (`project.jl:166-171`).
- Winner update only when `ts > best_ts` (`project.jl:197-200`), no stable tie-break key.
- Full scan performed per lookup via `scan_project_sessions` (`project.jl:192-201`).

**Improvement proposals:**

1. Small: sort scanned entries and add deterministic tie-break (`session_id` lexical).
2. Medium: maintain an index map `{label => latest_session_id}` refreshed on session write.
3. Larger: use SQLite metadata index as authoritative label-to-session resolver.

**Expected impact:**
Deterministic behavior across platforms and better performance for frequent label lookups.

### Issue: missing-session pruning in SQLite index uses row-by-row deletes

**Location:** `src/SQLiteIndex/session_index.jl`

**Why this is an issue:**
Pruning loads all indexed sessions and executes per-session delete operations, creating an N+1 query pattern that will degrade as session counts grow.

**Evidence:**
- Fetch all sessions, then iterate and delete per row (`session_index.jl:192-200`).
- Each missing session triggers `_delete_scope_tape_catalog!` plus a `DELETE FROM sessions`.

**Improvement proposals:**

1. Small: batch missing IDs and delete with one SQL set operation.
2. Medium: write seen IDs into a temp table and prune with `DELETE ... WHERE session_id NOT IN (...)` inside one transaction.
3. Larger: persist refresh-generation markers and prune by generation in SQL.

**Expected impact:**
Lower refresh latency and simpler operational scaling for larger projects.

### Issue: quality-review live notes have duplication-prone tracking semantics

**Location:** `notes/live/`

**Why this is an issue:**
Quality-review notes currently allow repeated findings and prefix collisions without a canonical supersession/status model, making it hard to identify the latest authoritative review and increasing duplicate reporting effort.

**Evidence:**
- Duplicate numeric prefix exists: `580-codebase-quality-review-pass2.md` and `580-codebase-quality-review-rerun.md`.
- Prior notes rely on manual strikethrough status (`579-codebase-quality-review.md`, `573/574` review notes), which is not machine-queryable.

**Improvement proposals:**

1. Small: enforce unique prefix + one-line “supersedes” metadata block in each rerun note.
2. Medium: add a lightweight review-manifest entry (latest note, superseded notes, active findings).
3. Larger: generate deduplicated review deltas automatically from structured issue IDs.

**Expected impact:**
Less duplicated review effort, clearer historical traceability, and easier maintenance planning.

## Top 5 prioritized improvements

1. Fix stale git-dirty enforcement path in `session_init!`.
2. Make label resolution deterministic (stable tie-break + sorted scan).
3. Clarify or redesign primary-label-only lookup semantics.
4. Batch SQLite missing-session pruning to remove N+1 behavior.
5. Add canonical supersession metadata for codebase-quality-review live notes.

## Codebase health summary

Core internals are improving, but reliability and maintainability risks remain in session-resolution semantics, lifecycle state freshness, and incremental-index scalability. The rerun’s highest-value opportunities are mostly behavioral/deterministic refinements rather than large architectural rewrites. Addressing these items should reduce both runtime surprises and review-process duplication with incremental, low-risk changes.
