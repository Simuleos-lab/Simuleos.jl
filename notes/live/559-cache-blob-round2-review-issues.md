# Cache/Blob Round 2 Review Issues

Focused review of the current cache/blob/worksession changes after closing `558`.

## 1. `blob_write` has a TOCTOU race and can silently overwrite concurrent writes

- Status: accepted non-goal (for now)
- Severity: high
- Location:
  - `src/Kernel/blobstorage/blob.jl:70`
  - `src/Kernel/blobstorage/blob.jl:74`
  - `src/Kernel/cache.jl:123`
  - `src/Kernel/cache.jl:127`
- Problem:
  - `blob_write` checks `isfile(path)` and then opens the file with `"w"`.
  - Between the check and the open, another writer can create the file.
  - In that case, the second writer may still open/truncate/write successfully instead of throwing `BlobAlreadyExistsError`.
  - This undermines the cache race handling in `cache_store!` / `cache_remember!` (which assumes duplicate-key races are detected by `BlobAlreadyExistsError`).
- Why this matters:
  - Cache race semantics (`:stored`, `:already_exists`, `:race_lost`) become unreliable under true concurrency.
  - Final persisted value for a cache key can depend on write timing rather than deterministic race handling.
- Decision (current scope):
  - Cache-key collisions are treated as semantic equivalence.
  - We do not manage writer races just to identify which equivalent computation "won".
  - Caller responsibility is to compose keys so collisions only happen for equivalent results.
  - Reference: `notes/index/006-workflow-surfaces.md` (`## Keyed Cache Equivalence Assumption`)
- Improvement options:
  1. Use atomic create semantics (`O_CREAT | O_EXCL`) for new blob writes.
  2. Write to a temp file and atomically rename only when target does not exist.
  3. Document single-writer-only guarantees if concurrency is intentionally unsupported.

## 2. `@remember` and `remember!` have divergent extra-key APIs and key-shape semantics

- Status: solved
- Severity: medium
- Location:
  - `src/WorkSession/macros.jl:64`
  - `src/WorkSession/macros.jl:83`
  - `src/WorkSession/cache.jl:9`
  - `src/WorkSession/cache.jl:52`
- Problem:
  - `@remember` extra-key tuples now accept only `key=value` pairs.
  - `remember!` still accepts `ctx_extra` as `NamedTuple`, `Tuple`, `AbstractVector`, or a single raw value.
  - These surfaces are conceptually the same feature (composed cache context), but they accept different shapes and normalize them differently.
- Why this matters:
  - API users can get inconsistent cache-key behavior depending on whether they use macro or function surface.
  - The contract is harder to explain and harder to test as the feature evolves.
- Improvement options:
  1. Define one canonical extra-key data model (recommended: labeled pairs / named data only) and apply it to both surfaces.
  2. If intentional, document the asymmetry explicitly with examples of accepted forms on each surface.
  3. Add parity tests that prove equivalent macro/function usage yields the same composed hash.
- Solved how:
  - `remember!` now narrows `ctx_extra` to named data only: `NamedTuple` (or `nothing`).
  - Raw tuple/vector/scalar `ctx_extra` inputs now throw a clear error.
  - `@remember` already required explicit `key=value` extra parts, so both surfaces now align on named-key semantics.
  - Existing `NamedTuple`-based `remember!` uses remain valid.

## 3. Cache metadata tag updates are effectively write-once and silently lossy

- Severity: medium
- Location:
  - `src/Kernel/cache.jl:67`
  - `src/Kernel/cache.jl:68`
  - `src/Kernel/cache.jl:128`
- Problem:
  - `_cache_meta_touch!` only writes `tags` when metadata has no tags (missing or empty).
  - Later calls with new tags do not merge or replace existing tags.
  - `cache_store!` race-loser path and `cache_tryload` both rely on `_cache_meta_touch!`.
- Why this matters:
  - Tag metadata can be incomplete depending on which caller populated the cache first.
  - Later callers cannot enrich cache metadata for discovery/debugging without rewriting the metadata file manually.
- Improvement options:
  1. Merge tags on touch (set union, stable order).
  2. Make tags immutable by design and document that first-writer wins.
  3. Split immutable creation tags from mutable access tags.

## 4. Macro cache path duplicates cache race/store logic instead of reusing one SSOT helper

- Severity: medium
- Location:
  - `src/WorkSession/cache.jl:83`
  - `src/WorkSession/cache.jl:88`
  - `src/WorkSession/macros.jl:362`
  - `src/Kernel/cache.jl:144`
- Problem:
  - `remember!` calls `Kernel.cache_remember!`, but `@remember` uses `_remember_tryload` + `_remember_store_result!` (a separate two-step implementation).
  - The macro path therefore mirrors backend race/status behavior in WorkSession code instead of reusing a single backend primitive end-to-end.
- Why this matters:
  - Future changes to cache statuses, metadata behavior, instrumentation, or tag handling can drift between the macro and function surfaces.
  - The duplication is already visible in separate tryload/store-result helper plumbing.
- Improvement options:
  1. Introduce a shared backend helper for “store and canonicalize result” and use it from both surfaces.
  2. Keep duplication but add explicit parity tests for status/value behavior across `remember!` and `@remember`.
  3. Document the intended divergence (if any), especially around metadata/tags.

## 5. BlobStorage file has small cleanup leftovers from the refactor

- Severity: low
- Location:
  - `src/Kernel/blobstorage/blob.jl:8`
  - `src/Kernel/blobstorage/blob.jl:108`
- Problem:
  - `BLOB_HASH_CHUNK_SIZE` appears unused.
  - `blob_read(simos::SimOs, key)` has a redundant `if key isa BlobRef` branch where both branches call the same function.
- Why this matters:
  - Minor maintenance noise increases code reading cost and obscures the real behavior.
- Improvement options:
  1. Remove the unused constant if no streaming hash implementation is planned.
  2. Collapse `blob_read(simos::SimOs, key)` to a single return statement.
  3. Add a comment if the branch/constant is intentionally reserved for a near-term change.

## Priority Order

1. Define and implement a tag update policy in cache metadata (issue 3).
2. Reduce macro/function cache-path logic duplication or add parity tests (issue 4).
3. Clean BlobStorage leftovers (issue 5).
