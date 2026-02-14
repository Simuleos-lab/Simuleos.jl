# 140 Index Drift Review

- Scope reviewed: `notes/index/index.md` + all `notes/index/*.md`, against `src/`.
- Prior drift reports reviewed: `notes/live/138-index-drift-review.md` (only matching prior report currently available).

1. Invariant: `SimuleOs: sim_init`
File: `src/Simuleos.jl:29`
Rationale: Workflow notes define `sim_init` as the system entrypoint, but the root module only wires session macros and does not expose `sim_init`/`sim_activate` on `Simuleos`. Runtime guidance still instructs `Simuleos.sim_init(...)` (`src/Kernel/core/sys-init-I0x.jl:15`), so documented API and actual root API diverge.
    - #FEEDBACK
        - this is a good point
        - we should export sim_init and sim_activate at the root level

2. Invariant: `Integration Classification Constraints`
File: `src/Registry/home-I0x.jl:3`
Rationale: `home-I0x.jl` delegates to `Kernel.init_home`, implemented in `src/Kernel/core/project-I1x.jl:10`. This creates an `I0x -> I1x` call edge, contradicting the invariant that caller level must be equal to or higher than callee level.
    - #FEEDBACK
        - Nice, we need to discuss about it

3. Invariant: `Julia Include Order`
File: `src/Kernel/Kernel.jl:22`
Rationale: The index specifies an early include chain `home.jl -> types.jl -> project.jl`, but current bootstrapping inserts Scoperias includes before `project-I0x.jl` (`src/Kernel/Kernel.jl:28`). The documented include-order invariant no longer matches the active load order.
    - #FEEDBACK
        - nice, I addressed this already