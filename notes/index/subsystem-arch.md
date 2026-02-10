## Current architecture

### Introduction — Key architecture patterns

- **Subsystems are workflows, not boxes.**
  A subsystem is everything required to carry a workflow.
  It is not confined to a single module or directory — it's a vertical slice across integration layers.
  Subsystems can share components, they are defined by workflow responsibility, not code ownership.

- **Layers emerge from the dependency graph.**
  Layers are not designed top-down — they are contour lines on the dependency DAG.
  The only hard rule: **edges point downward, never upward.**
  Within a layer, the graph is flat — any component can depend on any other in the same layer.
  If a subsystem needs something from a higher layer, it must push that component down.

- **Three layers** (ordered by integration level):
  - **Kernel.Core** — shared foundation: types, global state, settings, paths, utilities.
  - **Kernel-SubSystems** — core workflow subsystems, complete within Core (I0x-I1x).
  - **App-SubSystems** — extended workflow subsystems with user-facing integration (I2x-I3x).
  Layer names are cosmetic. The real constraint is the downward-only dependency rule.

- **Every subsystem can span layers.**
  A subsystem may have a Kernel part (flat, long names, I0x-I1x, no user-facing concerns)
  and an App part (own directory, I2x-I3x, user-facing lifecycle and macros).
  Core-only subsystems simply have no App part.

- **All types are centralized in Kernel.Core.**
  `types.jl` holds type definitions for all subsystems.
  Subsystem modules are for code organization, not type ownership.

- **Kernel.Core is not a subsystem.**
  It is the shared base: types, global state, settings, project paths, utilities.
  Every subsystem depends on it.

### Layer rules

```
  App-SubSystems              flat (all-to-all OK within layer)
        │
        ▼ only downward
  Kernel-SubSystems           flat (all-to-all OK within layer)
        │
        ▼ only downward
  Kernel.Core                 flat (all-to-all OK within layer)
        │
        ▼ only downward
  External
```

Between layers: strictly downward (no upward edges).
Within a layer: flat, any component can depend on any other.
If a subsystem needs upper-layer functionality, it must add components to the lower layer.

### Architecture graph

```
 ┌─────────────────────────────────────────────────────────────────┐
 │                      APP-SUBSYSTEMS                             │
 │                      (I2x-I3x, user-facing)                     │
 │                                                                 │
 │  ┌─────────────────┐  ┌───────────────┐  ┌──────────────────┐  │
 │  │ ScopeRecorder   │  │ ScopeReader   │  │ Registry         │  │
 │  │                 │  │               │  │                  │  │
 │  │ APP PART:       │  │ APP PART:     │  │ APP PART:        │  │
 │  │  Recorder/      │  │  Reader/      │  │  Registry/       │  │
 │  │  · macros       │  │  · high-level │  │  · cross-project │  │
 │  │  · session mgmt │  │    query API  │  │    resolution    │  │
 │  │  · staging      │  │               │  │                  │  │
 │  │  · simignore    │  │               │  │                  │  │
 │  │  · pipeline     │  │               │  │                  │  │
 │  │                 │  │               │  │                  │  │
 │  │ KERNEL PART:    │  │ KERNEL PART:  │  │ KERNEL PART:     │  │
 │  │  · SimOs.rec.   │  │  · SimOs.rdr  │  │  · home.jl       │  │
 │  │  · types in     │  │  · types in   │  │  · types in      │  │
 │  │    types.jl     │  │    types.jl   │  │    types.jl      │  │
 │  └────┬──┬──┬──────┘  └───┬──┬───────┘  └────┬─────────────┘  │
 │       │  │  │              │  │               │                 │
 └───────┼──┼──┼──────────────┼──┼───────────────┼─────────────────┘
         │  │  │              │  │               │
         ▼  ▼  ▼              ▼  ▼               ▼  only downward
 ┌─────────────────────────────────────────────────────────────────┐
 │                    KERNEL-SUBSYSTEMS                             │
 │                    (I0x-I1x, complete within Core)               │
 │                    flat: all-to-all dependencies OK              │
 │                                                                 │
 │        ┌────────────────┐                                       │
 │        │   QueryNav     │                                       │
 │        │ · handlers.jl  │                                       │
 │        │ · loaders.jl   │                                       │
 │        └────┬─────┬─────┘                                       │
 │             │     │                                              │
 │             ▼     ▼                                              │
 │  ┌──────────┐  ┌─────────┐  ┌─────────┐                        │
 │  │BlobStore │  │ TapeIO  │  │ GitMeta │                        │
 │  │          │  │         │  │         │                        │
 │  │· blob.jl │  │· json.jl│  │· git.jl │                        │
 │  │· SHA-1   │  │· JSONL  │  │· hash   │                        │
 │  │· content │  │· stream │  │· branch │                        │
 │  │  addr.   │  │· serial.│  │· dirty  │                        │
 │  └────┬─────┘  └────┬────┘  └────┬────┘                        │
 │       │              │           │                              │
 └───────┼──────────────┼───────────┼──────────────────────────────┘
         │              │           │
         ▼              ▼           ▼  only downward
 ┌─────────────────────────────────────────────────────────────────┐
 │                       KERNEL.CORE                               │
 │                       (shared foundation)                       │
 │                                                                 │
 │  types.jl ────── ALL types (all subsystems)                     │
 │  SIMOS.jl ────── Global Ref{SimOs}, set/reset                   │
 │  SIMOS-settings   Settings access via UXLayers                  │
 │  uxlayer.jl ──── Multi-source resolution                        │
 │  project.jl ──── Project struct & path helpers                  │
 │  sys-init.jl ─── sim_init / sim_activate                        │
 │  utils.jl ────── Lite detection, conversions                    │
 └──────────────────────────┬──────────────────────────────────────┘
                            │
                            ▼  only downward
 ┌─────────────────────────────────────────────────────────────────┐
 │  EXTERNAL: JSON3 · LibGit2 · SHA · Serialization               │
 │            UXLayers · UUIDs · Dates                             │
 └─────────────────────────────────────────────────────────────────┘
```

### Dependency summary

```
  App-SubSystems layer:
    ScopeRecorder ──→ BlobStore · TapeIO · GitMeta
    ScopeReader   ──→ QueryNav
    Registry      ──→ Kernel.Core

  Kernel-SubSystems layer (flat, all-to-all OK):
    QueryNav      ──→ BlobStore · TapeIO
    BlobStore     ──→ Kernel.Core
    TapeIO        ──→ Kernel.Core
    GitMeta       ──→ Kernel.Core
```

### Subsystem classification

Kernel-SubSystems (complete within Core, I0x-I1x):
- BlobStore — content-addressed value storage (blob.jl)
- TapeIO — JSONL tape serialization (json.jl)
- GitMeta — git repository metadata extraction (git.jl)
- QueryNav — handler-based navigation of .simuleos structure (query/)

App-SubSystems (Kernel part + App part, span I0x-I3x):
- ScopeRecorder — captures simulation state into tapes and blobs
- ScopeReader — structured access to recorded sessions
- Registry — cross-project resolution (deferred)

### Kernel.Core

- Not a subsystem. The shared foundation all subsystems depend on.
- Contains all type definitions (types.jl), global state (SIMOS), settings resolution,
  project paths, and pure utilities.
