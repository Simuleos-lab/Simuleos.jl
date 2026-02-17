# Simuleos Type/Constructor Separation Refactor - Decisions
**Session**: 2026-02-14 10:45 CST

**Issue**: Remove `@kwdef` from core type definitions and split type definitions from constructor behavior, while preserving current constructor behavior.

**Q**: Should constructor behavior stay backward compatible with existing keyword/default usage?
**A**: Yes. Keep full backward compatibility.

**Q**: Where should constructors live?
**A**: Distributed by subsystem (`base-Ixx.jl` files), not centralized in one file. Type centralization is only for include-order simplification.

**Q**: Where should `ScopeStage` constructors live?
**A**: `Simuleos/src/Kernel/scopetapes/base-I0x.jl`.

**Q**: Where should `WorkSession` constructors live?
**A**: Create `Simuleos/src/WorkSession/base-I0x.jl` and place `WorkSession(...)` constructors there.

**Q**: What is the policy for defaults currently in `types-I0x.jl`?
**A**: Remove all field defaults from type definitions; move all defaults to base constructors.

**Q**: What rollout strategy should be used?
**A**: One-shot local refactor across all targeted `@kwdef` types (no PR workflow).

**Decision**: Refactor all remaining `@kwdef` core types (`SimOs`, `Project`, `ScopeStage`, `WorkSession`, `SimuleosHome`, `ContextLink`) by removing field defaults from `core/types-I0x.jl` and implementing backward-compatible keyword/default constructors in subsystem-aligned base files. Preserve current call sites and behavior.
