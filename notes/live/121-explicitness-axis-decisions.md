# Integration Axis (I Axis) — Decisions

**Issue**: Define the system-wide interface contract for how functions access SimuleOs state. Generalize the implicit/explicit pattern observed in Recorder to all subsystems.

---

## The Integration Spectrum

SimuleOs functions sit on an integration axis for how they receive context:

**Q**: What are the levels?
**A**: Four levels, from zero to full integration:
- **I00** — Zero integration, pure utilities (e.g., `_is_lite(val)`)
- **I10** — All dependencies as explicit arguments (e.g., `f(simos, recorder, stage)`)
- **I20** — Pass SimOs, reach inside it (e.g., `f(simos)` then use `simos.recorder`)
- **I30** — Resolve globals internally (e.g., `f()` resolves `SIMOS[]`)

---

## Interface Contract

**Q**: How do the two interface types map to this axis?
**A**:
- **Base interface** targets I10 — all dependencies are arguments
- **User interface** wraps at I30 — resolves globals, then calls the base version
- I20 is acceptable but less preferred than I10

**Q**: Must every subsystem provide both interfaces?
**A**: Yes, when possible. The base interface is the core functionality. The user interface is a convenience wrapper that resolves globals and delegates to the base.

---

## SimOs and SIMOS

**Q**: What is SimOs's role in this?
**A**: SimOs is the central context object ("god object") that holds all SimuleOs state — project, settings, subsystem references.

**Q**: Naming?
**A**: `SimOs` = the type. `SIMOS` = the global instance.

**Q**: When should SimOs be passed?
**A**: Only when the function needs project/system state (paths, settings, subsystem refs). Pure utilities like `_is_lite(val)` don't take it — they are I00.

---

## Documentation Requirement

**Q**: How do functions document their position on the axis?
**A**: Functions must document their integration level and list any implicit objects used. If a function internally accesses `SIMOS[].recorder`, that dependency must be stated.

---

## Summary

```
I00 (zero):      f(...)                            ← pure utilities, no SimOs
I10 (explicit):  f(simos, recorder, stage, ...)    ← base interface target
I20 (mixed):     f(simos, ...)                     ← acceptable, less preferred
I30 (implicit):  f(...)                            ← user interface, wraps I10

SimOs  = type (central context object)
SIMOS  = global instance (Ref)

Rule: base interface at I10, user interface wraps at I30
Rule: functions document integration level and implicit dependencies
Rule: pass SimOs only when system state is needed
```
