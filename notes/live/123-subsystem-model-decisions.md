# Subsystem Model - Decisions

**Issue**: SimuleOs lacks a clear subsystem model; subsystem boundaries and integration levels are ambiguous.

**Q**: What counts as a subsystem?
**A**: A subsystem is a logical capability, even if spread across modules/folders/files, defined by workflow responsibility.

**Q**: Which subsystems are authoritative now?
**A**: ScopeRecorder, ScopeReader, FileSystem (workflow owners); system should allow more subsystems in the future as new workflows are added.

**Q**: How should subsystem integration levels be expressed?
**A**: Each subsystem should provide a lower-integrated (~I10) base interface and, if needed, a higher-integrated (>I30) user-facing interface. 
- this is a guideline
- The exact I-Axis level apply per-function.

**Q**: How to make integration levels explicit in code organization?
**A**: Group files by I-level with a consistent `*-I##.jl` naming scheme (e.g., `recorder-I10.jl`, `settings-I30.jl`).

**Decision**: Define subsystems by workflow responsibility. The authoritative subsystems now are ScopeRecorder, ScopeReader, and FileSystem. Subsystems should expose base (lower-integrated) and user-facing (higher-integrated) interfaces where appropriate, and integration level should be explicit in file naming using a consistent `*-I##.jl` scheme.
