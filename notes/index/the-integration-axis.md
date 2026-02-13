## The Integration Axis (I Axis)

- SimuleOs is a system with many subsystems (e.g., worksession, settings, scopetapes)
- Every function at SimuleOs sits on an integration spectrum:
- The integration model uses `SimOs` objects and `SIMOS` global for integration
- `SimOs` = the type (central context object holding all system state)
- `SIMOS` = the global instance (Ref)
- also important, `SimOs` containing internal integration globals
    - e.g., `SimOs.worksession` is the active session-workflow subsystem
        - so functions that use it are integrated with that subsystem
- So, we can evaluate each function's integration level by looking at:
    - its arguments (does it take `SimOs` or other subsystem refs?)
    - its use of globals (does it access `SIMOS` or `SimOs.worksession` internally?)


## I Axis: Interface styles:

- Ideally, for each SimuleOs subsystem we want to follow a similar design
    - have a lower integration base interface (around `I1x`) 
        - that takes explicit arguments for all dependencies
    - and a higher integration user interface (around `I3x`)
        - that resolves dependencies internally (e.g., via `SIMOS[]`)
- both public
    - one is intended for internal use by other subsystems
    - the other for external use by agents and users
- but this is a guideline, not a strict rule 
    - some functions may be more naturally designed at different points on the spectrum
- Pass `SimOs` only when the function needs system state integration (paths, settings, subsystem refs)
- Functions must document its integration level
    - and the use of implicit objects (e.g., "uses `SIMOS[].worksession`")

## I Axis: Levels of integration:
- Level `I0x` — zero integration, utilities: `f(...)`
    - no access to any `SimOs` object
    - Pure utilities (e.g., `_is_lite(val)`) don't take it, `I0x` = pure
- Level `I1x` — all dependencies as arguments: `f(simos, worksession, stage, ...)`
    - explicit access to `SimOs` object
    - no use of `SimOs` inner globals
        - eg: explicit `worksession` argument
- Level `I2x` — pass `SimOs`, reach inside it: `f(simos, ...)`
    - explicit access to `SimOs` object
    - use of `SimOs` inner globals
        - eg: `simos.worksession`
- Level `I3x` — resolve globals internally: `f(...)` 
    - no explicit `SimOs` argument
    - use of `SIMOS` internal global
    - eg: uses `SIMOS[]`, `SIMOS[].worksession`
- each level can have sub-levels (e.g., `I11`, `I12`) for finer granularity if needed

## Integration Axis File Naming Convention
- Files are named with their primary integration level suffix to indicate their interaction with the `SimOs` context:
    - `*-I0x.jl`: Pure utilities, no `SimOs` integration.
    - `*-I1x.jl`: Explicit `SimOs` dependencies as arguments.
    - `*-I2x.jl`: Explicit `SimOs` object passed, accesses its internal fields.
    - `*-I3x.jl`: Resolves `SimOs` dependencies internally via global `SIMOS[]`.


## Integration Classification Constraints
- If a function `F` (classified `Ix`) calls another classified function `G` (classified `Iy`), then `Ix` *must be equal to or greater than* `Iy`
    - otherwise, `F` or `G` are **misclassified** and should be revised
