# Explicitness Axis — Decisions

**Issue**: Define the system-wide interface contract for how functions access SimuleOs state. Generalize the implicit/explicit pattern observed in Recorder to all subsystems.

---

## The Explicitness Spectrum

SimuleOs functions sit on an explicitness axis for how they receive context:

**Q**: What are the levels?
**A**: Three levels, from most to least explicit:
- **Level i** — Pass SimOs AND pass specific subsystem objects as separate arguments (e.g., `f(simos, recorder, stage)`)
- **Level ii** — Pass SimOs, access subsystem through it (e.g., `f(simos)` then use `simos.recorder`)
- **Level iii** — Use global SIMOS, access everything through it (e.g., `f()` internally resolves `SIMOS[]`)

---

## Interface Contract

**Q**: How do the two interface types map to this axis?
**A**:
- **Explicit interface** targets level i — all dependencies are arguments
- **Implicit interface** wraps at level iii — resolves globals, then calls the explicit version
- Level ii is acceptable but less preferred than i

**Q**: Must every subsystem provide both interfaces?
**A**: Yes, when possible. The explicit interface is the core functionality. The implicit interface is a convenience wrapper that resolves globals and delegates to the explicit.

---

## SimOs and SIMOS

**Q**: What is SimOs's role in this?
**A**: SimOs is the central context object ("god object") that holds all SimuleOs state — project, settings, subsystem references.

**Q**: Naming?
**A**: `SimOs` = the type. `SIMOS` = the global instance.

**Q**: When should SimOs be passed?
**A**: Only when the function needs project/system state (paths, settings, subsystem refs). Pure utilities like `_is_lite(val)` don't take it.

---

## Documentation Requirement

**Q**: How do functions document their position on the axis?
**A**: Functions must document when they use implicit objects. If a function internally accesses `SIMOS[].recorder`, that dependency must be stated.

---

## Summary

```
Level i  (explicit):   f(simos, recorder, stage, ...)   ← explicit interface target
Level ii (mixed):      f(simos, ...)                     ← acceptable, less preferred
Level iii (implicit):  f(...)                            ← implicit interface, wraps level i

SimOs  = type (central context object)
SIMOS  = global instance (Ref)

Rule: explicit interface at level i, implicit wraps at iii
Rule: functions document implicit dependencies
Rule: pass SimOs only when system state is needed
```
