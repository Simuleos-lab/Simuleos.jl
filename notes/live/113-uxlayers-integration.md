# UXLayers Integration - Decisions

**Issue**: Integrate UXLayers.jl into Simuleos for hierarchical settings management while maintaining performance for hot-path simulation code.

---

## Architecture Decisions

**Q**: What is the hot path vs cold path boundary?
**A**: Only `@sim_session` is cold path. All other macros (`@sim_capture`, `@sim_commit`, `@sim_store`, `@checkpoint`) are hot path and must be fast.

**Q**: When should UXLayers be invoked?
**A**: Only at SimOS initialization (lazy) and indirectly via session cache misses. UXLayers is never called directly in hot paths.

**Q**: What is the primary UXLayers feature to leverage?
**A**: Settings hierarchy (source of truth for all config). Event system deferred for future CLI work.

---

## Caching Strategy

**Q**: Snapshot vs cache approach?
**A**: Cache approach. Session owns a settings cache that is:
- Reset at `@sim_session` start
- Populated lazily on first access per key
- Caches misses with `:__MISSING__` sentinel to avoid repeated UXLayers calls

**Q**: Where does the cache live?
**A**: Field on Session struct: `_settings_cache::Dict{String, Any}`

---

## UXLayers Ownership

**Q**: Where does UXLayers live?
**A**: On SimOS as `_ux_root::Union{Nothing, UXLayerView}`, lazily initialized on first `settings(OS, key)` call.

**Q**: What is the UXLayers view hierarchy?
**A**: Flat - single view. Project vs home distinction handled by source priorities within that single view. Sources to be implemented later.

---

## API Design

**Q**: What is the settings access pattern?
**A**: Explicit object argument:
```julia
settings(OS, key)            # direct UXLayers, error on miss
settings(OS, key, dflt)      # direct UXLayers, return dflt on miss
settings(session, key)       # cache hit or fetch+cache, error on miss
settings(session, key, dflt) # cache hit or fetch+cache, return dflt on miss
```

**Q**: What happens on cache miss outside a session?
**A**: `settings(OS, key)` without default errors if key not found in UXLayers.

**Q**: Should `settings` be exported?
**A**: Yes, export from Simuleos for user access.

---

## Code Placement

**Q**: Where should the `settings()` function live?
**A**: Each version in its object's module:
- `settings(::SimOS, ...)` → `src/Core/`
- `settings(::Session, ...)` → `src/ContextIO/`

**Q**: Where to modify Session struct?
**A**: Add `_settings_cache::Dict{String, Any} = Dict{String, Any}()` to Session in `src/Core/types.jl`

**Q**: When to reset cache?
**A**: At the very start of `@sim_session`, before git checks or any other logic.

**Q**: Where to import UXLayers?
**A**: Wherever necessary (Core for SimOS settings, ContextIO for Session settings).

---

## Decision Summary

```
SimOS (in Core)
└── _ux_root::UXLayerView         # lazy init on first settings() call
        │
        └── settings(OS, key[, dflt]) → resolve from UXLayers

Session (in ContextIO)
└── _settings_cache::Dict          # reset at @sim_session start
        │
        └── settings(session, key[, dflt])
                → cache hit: return value
                → cache miss: fetch from OS._ux_root, store in cache
                → UXLayers miss: store :__MISSING__ sentinel
```

**Data flow:**
1. `@sim_session` starts → reset `session._settings_cache`
2. Hot path calls `settings(session, "key")` → cache hit (fast)
3. First access per key → UXLayers call (cold), then cached
4. Missing keys cached as `:__MISSING__` → no repeated UXLayers calls

**Files to modify:**
- `Project.toml` - add UXLayers dependency
- `src/Core/types.jl` - add `_ux_root` to SimOS, `_settings_cache` to Session
- `src/Core/` - add `settings(::SimOS, ...)` functions
- `src/ContextIO/` - add `settings(::Session, ...)` functions
- `src/ContextIO/macros.jl` - add cache reset at `@sim_session` start
- `src/Simuleos.jl` - export `settings`
