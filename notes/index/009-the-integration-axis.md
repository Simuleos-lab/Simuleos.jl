## The Integration Axis (I Axis)

### I Axis: Context and interface styles

- Every SimuleOs function has an integration level on the I Axis.
- Integration primitives:
    - SimOs: context type holding system/subsystem state.
    - SIMOS: global Ref to active SimOs.
    - Accessing simos.<subsystem> is subsystem integration.
- Classify a function by:
    - explicit dependencies in arguments
    - implicit dependencies via globals (SIMOS[], simos.<subsystem>)
- Preferred subsystem API pair:
    - Base API (~I1x): explicit dependencies, subsystem-internal use.
    - User API (~I3x): dependencies resolved internally (SIMOS[]).
- This is guidance, not a hard rule.
- Each function should declare its I level and implicit objects used.


### I Axis: Interface styles:

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

### I Axis: Levels of integration:
- Level `I0x` — zero integration, utilities: `f(...)`
    - no access to any `SimOs` object
    - Pure with respect to the integration system (no `SimOs`, no `SIMOS[]`)
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

### Integration Axis File Naming Convention
- Files are named with their primary integration level suffix to indicate their interaction with the `SimOs` context:
    - `*-I0x.jl`: Pure utilities, no `SimOs` integration.
    - `*-I1x.jl`: Explicit `SimOs` dependencies as arguments.
    - `*-I2x.jl`: Explicit `SimOs` object passed, accesses its internal fields.
    - `*-I3x.jl`: Resolves `SimOs` dependencies internally via global `SIMOS[]`.


### Integration Classification Constraints
- If a function `F` (classified `Ix`) calls another classified function `G` (classified `Iy`), then `Ix` *must be equal to or greater than* `Iy`
    - otherwise, `F` or `G` are **misclassified** and should be revised


### The flotation line
- Moving down the integration axis is easier than moving up.
- Upward moves are harder because higher-level code has fewer dependents.
- Practical strategy: start with integrated APIs, then refactor downward when reuse/
flexibility is needed.
    - Example: start at I2x, then split toward I1x or I0x.