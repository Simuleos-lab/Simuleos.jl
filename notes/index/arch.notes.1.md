## Simuleos State
- State machine with two scopes: Runtime (SimOs) and Disk (./.simuleos, ~/.simuleos)
- Lazy evaluation at runtime (avoid sync issues); best-effort caching when needed
- Core provides objects/interfaces to manage state; prefer simplicity over syncronicity


## Simuleos Core Interface
- All must run on a functional interface
- We have two general workflows
    - functional
        - input -> function -> output
        - we can carry the context on objects
            - eg: `load_tape(S::Session, tapeid::String, ...)`
    - global state
        - context comes from global state
            - eg: `load_tape(tapeid::String, ...)`
                - load tape from global `current_session`
- Issue: how to diffirentiate between the two interfaces
    - function names
    - dispatch
    - modules
        - `OS.load_tape(tapeid::String, ...)`
    - mixure

