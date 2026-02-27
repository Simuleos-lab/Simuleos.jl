# Cache/Session Quality Review Issues (Collapsed)

Closure note for the cache/session workflow quality review (`@remember`, ctx-hash composition, queued commit flushing).

## Status

- Closed
- All review issues and the follow-up test item were addressed

## Resolved Items

1. Queued commit flush retry duplication risk
- Fixed `_flush_pending_commits!` to trim only the successfully flushed prefix on failure and rethrow.
- Added a failure-injection test proving retry does not duplicate already-written commits.

2. `@remember` extra-key tuple parsing ambiguity
- Resolved by restricting extra-key tuples to explicit `key=value` pairs only.
- Added parser tests for accepted/rejected forms.

3. Cache race semantics returning non-canonical value
- Resolved in current implementation: `cache_store!` returns structured status and `cache_remember!` re-reads canonical value on race loss (`:race_lost`).
- Covered by race-simulation tests.

4. ctx-hash composition SSOT/layering coupling
- Moved runtime `_ctx_hash_*` helpers from `src/WorkSession/macros.jl` to `src/WorkSession/cache.jl`.
- `@ctx_hash` and cache interfaces continue sharing one runtime hash composition path.

5. `@remember` block-form assignment error wording mismatch
- Updated error text to match actual `@isdefined` semantics ("did not leave `<var>` defined").

## Validation

- `julia --project test/runtests.jl` passed after the fixes.
