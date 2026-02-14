# ScopeTapes/TapeIO Boundary Refactor - Decisions

**Issue**: Re-scope tape responsibilities so `TapeIO` is the low-level JSONL I/O boundary and `ScopeTapes` is domain glue (`Scoperias + TapeIO + BlobStore`) without session-awareness.

**Q**: What should `TapeIO` own?
**A**: A single path-based object named `TapeIO`, representing one `.jsonl` tape file.

**Q**: What read/write data shape should `TapeIO` expose?
**A**: `TapeIO` reads and appends JSONL records as Dicts (no typed record structs at TapeIO level).

**Q**: Should `TapeIO` depend on `SimOs` or session abstractions?
**A**: No. `TapeIO` must stay independent of `SimOs` and session-aware objects.

**Q**: Where should typed wrappers live?
**A**: Keep typed wrappers in `ScopeTapes`; `TapeIO` remains Dict-only.

**Q**: What is the intended responsibility of `ScopeTapes`?
**A**: `ScopeTapes` is not session-aware; it is glue over `Scoperias`, `TapeIO`, and `BlobStore`, and owns the stage-to-commit workflow.

**Q**: How should stage/commit naming evolve?
**A**: Rename `Stage` to `ScopeStage`.

**Q**: Should commit records keep `session_label`?
**A**: No. Remove `session_label`; extra context goes into `metadata`.

**Q**: What should `ScopeTapes` expose on the read side?
**A**: Typed-only tape iteration over `TapeIO` (no separate public raw iterator in ScopeTapes).

**Q**: How should `TapeIO` handle invalid JSON lines?
**A**: Throw an error immediately.

**Q**: Should append auto-create directories?
**A**: Yes, `append!` should `mkpath(dirname(path))`.

**Q**: What input type should `TapeIO.append!` accept?
**A**: Accept `AbstractDict` and normalize keys to `String`.

**Q**: What is the latest direction for session-aware code?
**A**: Eliminate session-aware code now; it will be reimplemented later.

**Decision**: Execute a one-shot refactor where `TapeIO` becomes the sole low-level JSONL boundary (`TapeIO(path)`, `append!`, iterator read of Dict records), `ScopeTapes` keeps domain typed wrappers and scope-commit orchestration without session coupling, and current session-aware navigation/workflows are removed in this pass and rebuilt later on top of the new boundary.
