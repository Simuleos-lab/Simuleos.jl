# 138 Index Drift Review

- Scope reviewed: `notes/index/index.md` + all `notes/index/*.md`, against `src/`.
- Prior `notes/live/NNN-index-drift-review.md` reports: none found.

1. Invariant: `Current architecture`
File: `src/Kernel/scoperias/types-I0x.jl:9`
Rationale: The index states `types.jl` in Kernel.Core is the type SSOT for all subsystems, but subsystem types are defined outside Kernel.Core (`ScopeVariable`/`Scope` here, plus ScopeTapes records elsewhere). Type ownership is now distributed.
    - #FEEDBACK
        - fix this, move all type definitions to `Kernel/core/types.jl`

2. Invariant: `Current architecture`
File: `src/Kernel/blobstorage/blob-I2x.jl:1`
Rationale: Kernel-SubSystems are described as I0x-I1x, but BlobStorage includes explicit I2x wrappers in the Kernel layer. The layer/integration map in the index no longer matches implementation.
    - #FEEDBACK
        - this is a nice issue
        - the problem is that I do not wan artifitial separations
            - like, create a full folder/module only to hold I2x wrappers
        - how can we fix his semantic problem?
        - what do you think?

3. Invariant: `The Integration Axis (I Axis)`
File: `src/Kernel/core/types.jl:1`
Rationale: The index defines `*-I0x`/`*-I1x`/`*-I2x`/`*-I3x` file naming, yet multiple core files are unsuffixed (`types.jl`, `project.jl`, `SIMOS.jl`, `home.jl`, `sys-init.jl`). Integration naming is only partially applied.
    - #FEEDBACK
        - check if was addressed

4. Invariant: `The Integration Axis (I Axis)`
File: `src/Kernel/blobstorage/blob-I0x.jl:6`
Rationale: The index says each function should declare its integration level and implicit object usage, but many functions have no per-function annotation/docstring. Integration metadata is inconsistent across the codebase.
    - #FEEDBACK
        - ignore for now
        - TODO: I need to make a skill for adding integration anotation...

5. Invariant: `Workflows List`
File: `src/Simuleos.jl:35`
Rationale: The workflow note says workflows should start with `sim_init` (explicitly or implicitly), but module startup calls `Kernel.sim_activate()` directly and session setup expects pre-activation. Runtime entry behavior diverges from the documented `sim_init`-first workflow.
    - #FEEDBACK
        - ignoring for now
