## Current architecture

### Key architecture patterns

- Subsystems are workflow slices, not module/directory boxes.
    - A subsystem can span layers and share components.
    - Responsibility is defined by workflow, not ownership.
- Layers are derived from the dependency DAG.
    - Across layers: dependencies only point downward.
    - Within a layer: flat graph (all-to-all allowed).
    - If lower code needs upper behavior, move components downward.
- Layer set (by integration):
    - `Kernel.Core`: shared types/state/settings/paths/utils.
    - `Kernel-SubSystems`: core workflows (I0x-I1x).
    - `App-SubSystems`: user-facing workflows (I2x-I3x).
- Subsystems may have Kernel and App parts; Core-only subsystems have no App part.
- types.jl in Kernel.Core is the type SSOT for all subsystems.
- Kernel.Core is shared foundation, not a subsystem.

 ### Type SSOT 
- `Kernel.Core/types-I0x.jl` is the SSOT for all Simuleos type definitions.
- Subsystems should not define new domain/runtime structs in subsystem files; define types in `Kernel.Core/types-I0x.jl` and consume them from there.


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
  │  WorkSession (WorkSession/)   Registry                         │
  │  - session lifecycle + staging + commit                        │
  │  - @session_* user workflow macros                             │
  └───────────────────────────────┬────────────────────────────────┘
                                  │
                                  ▼ only downward
  ┌─────────────────────────────────────────────────────────────────┐
  │                    KERNEL-SUBSYSTEMS                           │
  │                    (I0x-I1x, flat)                             │
  │                                                                 │
  │  Scoperias     ScopeTapes     BlobStore      TapeIO    GitMeta   │
  │  - types       - handlers    - blob write   - json    - git md  │
  │  - ops         - read/write                               read   │
  │  - @scope_capture (I0x wrt SimOs)                                │
  │  - filter_rules(scope, rules)                                   │
  └───────────────┬──────────────┬──────────────┬──────────┬────────┘
                  │              │              │          │
                  ▼ only downward
  ┌─────────────────────────────────────────────────────────────────┐
  │                        KERNEL.CORE                              │
  │  types.jl · SIMOS.jl · SIMOS-settings.jl · uxlayer.jl          │
  │  project.jl · sys-init.jl · utils.jl · home.jl                 │
  └──────────────────────────┬──────────────────────────────────────┘
                             ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │ EXTERNAL: JSON3 · LibGit2 · SHA · Serialization · UXLayers      │
  │           UUIDs · Dates                                          │
  └─────────────────────────────────────────────────────────────────┘
```

### Subsystem classification

Kernel-SubSystems (complete within Core, `I0x-I1x`):
- BlobStore — content-addressed value storage (blob.jl)
- TapeIO — JSONL tape serialization (json.jl)
- GitMeta — git repository metadata extraction (git.jl)
- ScopeTapes — unified low-level scope tape read/write over .simuleos tapes
- Scoperias — Scope runtime types and operations

App-SubSystems (Kernel part + App part, span `I0x-I3x`):
- WorkSession — unified session workflow (init/context/store/capture/commit)
- Registry — cross-project resolution (deferred)

### Kernel.Core

- Not a subsystem. The shared foundation all subsystems depend on.
- Contains all type definitions (types.jl), global state (SIMOS), settings resolution,
  project paths, and pure utilities.

### Kernel-subsystem I2x Policy
- Kernel-subsystem integration levels are a recommendation: prefer `I0x-I1x`.
- Thin `I2x` wrappers are allowed in Kernel when integration is light and they only adapt existing Kernel primitives.
- Do not create artificial folders/modules only to host `I2x` trivial wrappers.
- If an `I2x` wrapper grows non-trivial workflow/state behavior, reclassify and move it to the proper app-facing subsystem.

### Julia Include Order
- All `Core.*` calls resolve at runtime, so include order only matters for type/const definitions
- `types.jl` must be early, it is the SSOT for all types.