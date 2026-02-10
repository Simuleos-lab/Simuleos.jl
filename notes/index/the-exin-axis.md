## The Explicitness Axis

- Every function that touches SimuleOs state sits on an explicitness spectrum:
    - Level `ex0` — no integration, utilities: `f(...)`
    - Level `ex1` — all dependencies as arguments: `f(simos, recorder, stage, ...)`
    - Level `ex2` — pass SimOs, reach inside it: `f(simos, ...)` → uses simos.recorder
    - Level `ex3` — resolve globals internally: `f(...)` → uses `SIMOS[]`, `SIMOS[].recorder`
- `SimOs` = the type (central context object holding all system state)
- `SIMOS` = the global instance (Ref)
- Two interface styles per subsystem (when possible):
    - Explicit interface → targets level `ex1` (all dependencies are arguments)
    - Implicit interface → wraps at level `ex3` (resolves globals, delegates to explicit)
        - avoid using kwargs
- Pass `SimOs` only when the function needs system state integration (paths, settings, subsystem refs)
    - Pure utilities (e.g., `_is_lite(val)`) don't take it, `ex0` = pure
- Functions must document when they use implicit objects (e.g., "uses `SIMOS[].recorder[]`")