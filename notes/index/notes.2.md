### Julia Include Order
- All `Core.*` calls resolve at runtime, so include order only matters for type/const definitions
- `home.jl` → `types.jl` → `project.jl` must be early (types depend on home paths)

## The flotation line
- There exist an asymetry 
- Moving down at the integration index is easier than moving up
    - one cause is that, bieng up means less subsystems dependent on you
- So, we can start with more integrated functions and then refactor down if we need to support more use cases
    - e.g., start with `I2x` user-facing functions that take `SimOs` and then refactor to `I1x`, or even `I0x`, if we need more flexible internal use