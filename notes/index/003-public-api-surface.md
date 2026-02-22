## Public API Surface

- `Simuleos` is the single public export surface.
- Cross-subsystem collaboration should use explicit imports/qualification.
- Do not rely on implicit exports from internal modules.
- New external features should be promoted through `src/Simuleos.jl` only after the interface is stable.
- Default policy: keep new symbols internal unless there is a clear user-layer need.
