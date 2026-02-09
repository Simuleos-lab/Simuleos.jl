### Julia Include Order
- All `Core.*` calls resolve at runtime, so include order only matters for type/const definitions
- `home.jl` → `types.jl` → `project.jl` must be early (types depend on home paths)
