 ## API Surface Ownership

- Simuleos is the only module that should export user-facing symbols.
- Subsystem modules (Kernel, WorkSession, Registry) are internal and should not export
symbols.
- Cross-subsystem calls should use explicit qualification/imports, not implicit exports.
- New public APIs should be exposed only by wiring them through src/Simuleos.jl (using/
import then export at root).
- Default for new symbols: keep internal unless intentionally promoted to stable
external API.