# @session_init Finish Plan
**Session**: 2026-02-16

## Scope
Finalize `@session_init` behavior end-to-end for WorkSession, with project-attached session resolution and strict initialization semantics.

## Plan
1. Lock API contract
- Keep macro labels string-only.
- Use first label as lookup key.
- Match by exact `labels[1]`.
- On multiple matches, pick most recent.
- On no match, create a new in-memory session driver.
- Re-init must fail when active session is dirty.

2. Separate resolver/init responsibilities
- Keep SSOT read/scan APIs in I1x:
  - `proj_scan_session_files(f, proj)`
  - `parse_session(proj, raw)`
  - `resolve_session(proj, label)`
- Keep init orchestration in init APIs only (macro wrapper + explicit init path).

3. Implement real dirty-check
- Replace temporary `isdirty(...) = true`.
- Dirty when any pending staged state exists:
  - `stage.current_scope` labels/data
  - `stage.blob_refs`
  - `stage.captures`
- Keep clear user-facing error on blocked re-init.

4. Confirm persistence semantics
- Strict resume: existing `session_id` does not overwrite `session.json`.
- Reuse notice printed only when an existing session is reused.
- Make metadata refresh behavior explicit and consistent.

5. Harden error behavior
- Clear errors for:
  - non-string macro labels
  - empty first label
  - invalid/corrupt `session.json`
- Keep scan behavior strict (error on invalid files).

6. Complete test coverage
- Add/adjust tests for:
  - macro string-only enforcement
  - label-based reuse
  - no-match new session
  - multi-match most-recent selection
  - active dirty session blocks re-init
  - explicit `session_id` path behavior

7. Align docs/index
- Update workflow notes in `notes/index` to reflect finalized `@session_init` semantics.
- Remove stale UUID-first user-facing wording.

8. Validate
- Run targeted tests:
  - `julia --project -e 'using Pkg; Pkg.test(; test_args=["worksession_tests"])'`
- Run full suite after targeted tests pass.
