Summary: Simuleos Core vs. Convenience Separation

- Goal: clear conceptual boundary between Core (engine) and user-facing surfaces (macros/CLI).
- Core owns the global state model, disk layout, and all state transitions.
- Global state is shared between runtime and disk.
- Disk state splits into project-local `.simuleos/` and global `~/.simuleos/`.
- Any operation on runtime/disk state must go through Core functions.
- User-facing surfaces (embedded code, future CLI) are conveniences that call Core.

Core (engine, control-surface agnostic)
- Types and global state: `src/Core/types.jl`
- Activation/lifecycle: `src/Core/OS.jl`
- Settings resolution: `src/Core/OS-settings.jl` + `src/Core/UXLayer.jl`
- Persistence: `src/ContextIO/blob.jl`, `src/ContextIO/tape.jl`, `src/ContextIO/json.jl`
- Scope processing: `src/ContextIO/scope.jl`
- Registry/home: `src/Registry/home.jl`
- Git metadata: `src/Core/git.jl`

Conveniences (user-facing surfaces)
- Macros: `src/ContextIO/macros.jl`
- Top-level entrypoint: `src/Simuleos.jl`
- Future CLI should call Core API only.

Boundary rule
- Core must not depend on top-level `Simuleos` or UI surfaces.
- Convenience layers can depend on Core.
- All mutations of global or disk state must be performed by Core functions.
