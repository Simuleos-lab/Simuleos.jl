## Simuleos State
- State machine with two scopes: Runtime (`SimOs`) and Disk (`./.simuleos`, `~/.simuleos`)
- Lazy evaluation at runtime (avoid sync issues)
    - best-effort caching when needed
- Core provides objects/interfaces to manage state; prefer simplicity over syncronicity

