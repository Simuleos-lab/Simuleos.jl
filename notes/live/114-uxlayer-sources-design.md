# UXLayer Sources Design - Decisions

**Date**: 2026-02-05
**Topic**: Settings sources configuration for `SimOS._ux_root`

---

## Summary

Settings are resolved from multiple sources checked in priority order (first hit wins). No merging - sources remain separate dictionaries.

## Sources (Priority Order)

| Priority | Source | Description |
|----------|--------|-------------|
| 1 (highest) | `args` | `Dict{String, Any}` passed to `activate(path, args)` |
| 2 | `bootstrap` | `Dict{String, Any}` passed to `SimOS()` constructor |
| 3 | local | `.simuleos/settings.json` in project |
| 4 | global | `~/.simuleos/settings.json` user config |
| 5 (lowest) | `DEFAULTS` | `Simuleos.DEFAULTS` constant |

---

## Decisions

**Q**: Where should layer composition code live?
**A**: Single file `src/UXLayer.jl` (not a module)

**Q**: When to initialize the layer stack?
**A**: At `activate(path, args)` - fail fast on config issues

**Q**: How are ARGS passed?
**A**: Pre-parsed `Dict{String, Any}`, caller handles parsing. Required parameter to `activate()`.

**Q**: What is bootstrap?
**A**: Explicit `bootstrap::Dict{String, Any}` field in `SimOS()` constructor

**Q**: SimOS constructor signature?
**A**:
```julia
@kwdef mutable struct SimOS
    home_path::String = joinpath(homedir(), ".simuleos")
    project_root::Union{Nothing, String} = nothing
    bootstrap::Dict{String, Any} = Dict{String, Any}()  # NEW
    _project::Any = nothing
    _home::Any = nothing
    _ux_root::Any = nothing
end
```

**Q**: activate() signature?
**A**: Required parameter: `activate(path::String, args::Dict{String, Any})`

**Q**: JSON file structure?
**A**: First-level keys only. Values are opaque - system doesn't interpret nested structure.

**Q**: How does resolution work?
**A**: No merge. Sources stay separate. Resolver checks each source in priority order, returns first hit.

**Q**: Missing source files?
**A**: Skip silently (empty source). Missing KEY: error on `settings(s, key)`, use default on `settings(s, key, default)`.

**Q**: Malformed JSON file?
**A**: Not decided (left open)

**Q**: Built-in defaults location?
**A**: `Simuleos.DEFAULTS` constant (location TBD - in UXLayer.jl or Simuleos.jl)

**Q**: Settings introspection?
**A**: None - keep it simple

**Q**: UXLayers layers?
**A**: Single layer only. Multiple sources feed into one `UXLayerView`.

---

## Architecture

```
activate(path, args)
       │
       ▼
┌─────────────────────────────────────────────┐
│  _build_ux_root!(os, args)                  │
│                                             │
│  sources = [                                │
│    args,                    # priority 1    │
│    os.bootstrap,            # priority 2    │
│    _load_json(local),       # priority 3    │
│    _load_json(global),      # priority 4    │
│    DEFAULTS                 # priority 5    │
│  ]                                          │
│                                             │
│  os._ux_root = UXLayerView("simuleos")      │
│  # configure view with sources              │
└─────────────────────────────────────────────┘
       │
       ▼
settings(os, key)
       │
       ▼
for source in sources:
    if haskey(source, key):
        return source[key]
error("Setting not found: $key")
```

---

## Implementation Plan

### Step 1: Update `SimOS` struct
- Add `bootstrap::Dict{String, Any} = Dict{String, Any}()` field
- Location: `src/Core/types.jl`

### Step 2: Create `src/UXLayer.jl`
- `const DEFAULTS = Dict{String, Any}(...)`
- `_load_settings_json(path)::Dict{String, Any}` - returns empty dict if missing
- `_build_ux_root!(os::SimOS, args::Dict{String, Any})` - builds source list, creates view

### Step 3: Update `activate()`
- Change signature to `activate(path::String, args::Dict{String, Any})`
- Call `_build_ux_root!(OS, args)` after setting project_root
- Update `activate()` (no-args) to call `activate(detected_path, Dict{String, Any}())`

### Step 4: Update `src/Core/settings.jl`
- Modify `settings(os, key)` to iterate sources instead of single view lookup
- Keep `_init_ux_root!` for backward compat or remove if no longer needed

### Step 5: Update `set_os!()` and `reset_os!()`
- Handle new `bootstrap` field
- Reset sources on `reset_os!()`

### Step 6: Include `src/UXLayer.jl`
- In `src/Simuleos.jl` after Core, before other modules

---

## Open Items

- [ ] Decide: Error or warn on malformed JSON?
- [ ] Define initial `DEFAULTS` keys
- [ ] Update tests for new `activate(path, args)` signature
