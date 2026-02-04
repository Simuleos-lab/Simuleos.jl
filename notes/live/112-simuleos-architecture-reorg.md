# Simuleos Architecture Reorganization - Decisions

**Date**: 2026-02-03
**Topic**: Internal organization for organic growth

---

## Context

Simuleos is an "Operative System for simulations" that needs to grow organically to support:
- Project/file management
- Cross-project data sharing with git versioning
- Simulation tooling (memoization, progress recovery, parameter sweeps)
- Full context traceability (hash → context links)

Currently the system is focused on context I/O (sessions, scopes, tape, blobs). Need architecture to add peer subsystems cleanly.

---

## Decisions

**Q**: Package structure - monolithic or multi-package?
**A**: Monolithic. Single package with internal submodule organization.

**Q**: What is a "Project"?
**A**: A directory with `.simuleos/` folder, likely also a git repo root. Projects discover each other via a simuleos home registry (~/.simuleos), similar to Julia's depot system.

**Q**: Subsystem coupling model?
**A**: Core module defines all types. App modules have access to all types. Julia handles method circular dependencies fine.

**Q**: State management pattern?
**A**: God Object pattern. Single global instance (`SimOS`), swappable for testing. Lazy initialization throughout - subsystems construct from bootstrap data only, load on demand.

**Q**: What is the root object?
**A**: `Project` becomes the entry point. Session is contained within Project.

**Q**: God Object naming?
**A**: `SimOS`

**Q**: God Object access pattern?
**A**: `Simuleos.OS` - constant (but mutable struct)

**Q**: Project activation?
**A**: Auto-detect from working directory by default, explicit override via `Simuleos.activate(path)`.

**Q**: Submodule export strategy?
**A**: No re-export. Users do `using Simuleos.ContextIO` explicitly for each subsystem they need.

**Q**: Test swapping mechanism?
**A**: `Simuleos.set_os!(new_os)` - explicit setter function.

---

## Architecture

### Subsystems (Initial)

| Module | Purpose | Status |
|--------|---------|--------|
| Core | Types, git interface, shared utilities | Migrate existing |
| ContextIO | Sessions, scopes, tape, blobs, query | Migrate existing |
| FileSystem | File operations, simignore, file finder | Migrate simignore |
| Registry | ~/.simuleos home, project discovery, cross-project refs | Mock |
| Tools | Memoization, progress recovery, parameter sweeps | Mock |
| Traceability | Hash → context links, "WTF made this" queries | Mock |

### Directory Structure

```
src/
├── Simuleos.jl              # Main module, defines SimOS, global instance
├── Core/
│   ├── Core.jl              # module Core
│   ├── types.jl             # SimOS, Project, all shared types
│   ├── git.jl               # LibGit2 wrapper
│   └── utils.jl             # shared utilities
├── ContextIO/
│   ├── ContextIO.jl         # module ContextIO
│   ├── session.jl
│   ├── scope.jl
│   ├── tape.jl
│   ├── blob.jl
│   └── query/               # handlers, wrappers, loaders
├── FileSystem/
│   ├── FileSystem.jl        # module FileSystem
│   ├── simignore.jl
│   └── finder.jl
├── Registry/
│   ├── Registry.jl          # module Registry
│   ├── home.jl
│   └── resolver.jl
├── Tools/
│   ├── Tools.jl             # module Tools (stub)
│   └── memo.jl
└── Traceability/
    ├── Traceability.jl      # module Traceability (stub)
    └── context_links.jl
```

### SimOS Structure

```julia
@kwdef mutable struct SimOS
    # Bootstrap data (provided at creation)
    home_path::String = joinpath(homedir(), ".simuleos")
    project_root::Union{Nothing, String} = nothing

    # Lazy subsystems (initialized on first access)
    _project::Union{Nothing, Project} = nothing
    _home::Union{Nothing, SimuleosHome} = nothing
    # ... other subsystems as needed
end

# Global instance
const OS = SimOS()

# Test swapping
function set_os!(new_os::SimOS)
    # Implementation TBD
end

# Project activation
function activate(path::String)
    # Set OS.project_root, invalidate lazy state
end
```

### Module Dependencies

```
Core ← (no deps, foundation)
  ↑
  ├── ContextIO
  ├── FileSystem
  ├── Registry
  ├── Tools
  └── Traceability
```

All subsystems depend only on Core. No cross-dependencies between app modules (communicate through Core types or SimOS).

---

## Next Steps

1. Create directory structure
2. Extract Core module (types, git)
3. Migrate ContextIO (current session system)
4. Migrate FileSystem (simignore)
5. Create stubs for Registry, Tools, Traceability
6. Wire up SimOS with lazy accessors
7. Update tests

---

## Open Questions (Deferred)

- Git versioning scope (commits vs tags vs both)
- Exact SimOS fields beyond project and home
- Cross-project data access API details
- Traceability storage format
