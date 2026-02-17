# Scope Recording Object Model - Decisions
**Session**: 2026-02-14 10:14 CST

**Issue**: Redesign recording/reading scope objects to reduce type surface, remove redundant recording wrappers, and keep recording workflow explicit without backward compatibility constraints.

**Q**: How should `ScopeVariable` modes be modeled?
**A**: Use concrete variants under a shared model. Variant names: `InMemoryScopeVariable`, `BlobScopeVariable`, `VoidScopeVariable`. Parsing should return specific concrete variant types.

**Q**: Should recording keep `CaptureContext`?
**A**: No. Remove `CaptureContext`.

**Q**: What is `ScopeStage` after refactor?
**A**: Recording-only handler with:
- `captures::Vector{Scope}`
- `current_scope::Scope`
- `blob_refs::Dict{Symbol, BlobRef}`

**Q**: Where does per-scope context live?
**A**: On `Scope` itself (`labels` and `data`).

**Q**: Where should timestamp be stored?
**A**: One timestamp per commit in commit metadata (`metadata["timestamp"]`), not per scope.

**Q**: How should recording/reading models converge?
**A**: Shared common model uses `ScopeVariable` variants + `Scope` + `ScopeCommit`. Remove `VariableRecord`, `ScopeRecord`, and `CommitRecord`.

**Q**: What is `@session_store` behavior?
**A**: Blob write happens at store time. Store-time snapshot wins. If a variable is already in current-stage `blob_refs`, another store call for that variable errors. No capture-time value-change checks.

**Q**: What is capture finalization behavior?
**A**: `@session_capture` finalizes/pushes `current_scope`, resets `current_scope`, and clears `blob_refs` with `empty!`.

**Q**: What is `ScopeCommit` shape?
**A**: Read-only object with fields:
- `commit_label`
- `metadata`
- `scopes`
No `blob_refs` field.

**Q**: How should non-lite non-blob variables be represented?
**A**: `VoidScopeVariable` with short type string.

**Q**: What fields are required across all `ScopeVariable` variants?
**A**: All variants include `src::Symbol` and `type_short::String`.

**Q**: Backward compatibility policy?
**A**: None. Breaking refactor is acceptable; remove old paths/types/tests.

**Decision**: Refactor to a minimal shared object model where `ScopeStage` is purely recording-time state, `ScopeCommit` is read/commit representation, and `ScopeVariable` uses explicit variants. Blob materialization is decoupled and performed at store time, while capture materializes final per-scope variable entries from current state plus staged blob refs.
