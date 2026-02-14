# 143 Index Drift Review

- Scope reviewed: `notes/index/index.md` + all `notes/index/*.md`, against `src/`.
- Prior drift reports reviewed: `notes/live/138-index-drift-review.md`, `notes/live/140-index-drift-review.md` (only matching prior reports available).

1. Invariant: `SimuleOs: sim_init`
File: `src/Simuleos.jl:35`
Rationale: Module load always runs `Kernel.sim_activate()` in `__init__`, but project auto-detection accepts any `.simuleos/` directory (`src/Kernel/core/project-I0x.jl:23`). This can hard-fail on import outside a real project, which conflicts with the documented lightweight entry workflow.

2. Invariant: `SimuleOs: sim_init`
File: `src/Kernel/core/sys-init-I0x.jl:15`
Rationale: User guidance points to `Simuleos.sim_init(...)`, yet root wiring still exposes only session macros (`src/Simuleos.jl:29`) and does not surface `sim_init`/`sim_activate` on `Simuleos`. Documented API entry and actual root API remain out of sync.

3. Invariant: `Integration Classification Constraints`
File: `src/Registry/home-I0x.jl:3`
Rationale: `home-I0x.jl` delegates to `Kernel.init_home`, whose implementation is `I1x` (`src/Kernel/core/project-I1x.jl:10`). That creates an `I0x -> I1x` dependency edge, violating the documented `Ix >= Iy` call constraint.

4. Invariant: `I Axis: Levels of integration`
File: `src/Kernel/scopetapes/read-I1x.jl:9`
Rationale: The index defines `I1x` around explicit `SimOs` integration, but `iterate_tape(tape::TapeIO)` (and similar `I1x` APIs) has no `SimOs` dependency at all. Current `I1x` usage in code diverges from the level semantics in the index.

5. Invariant: `I Axis: Context and interface styles`
File: `src/Kernel/scopetapes/write-I1x.jl:11`
Rationale: The index asks each function to declare integration level and implicit-object usage, but `_fill_scope!` and `commit_stage!` omit that metadata while other files include it. Integration-axis annotations are currently inconsistent and not reliably auditable.
