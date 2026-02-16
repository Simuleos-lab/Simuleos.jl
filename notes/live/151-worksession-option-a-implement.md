# WorkSession Option A — Pending Implementation
**Session**: `308307c3-7de1-430f-9441-fc6e497c742d` (2026-02-16)

**Focus at interruption**: implement the WorkSession interface split (Option A), before macros.

## Agreed Direction
- Use `resolve_*` vs `*_init!` convention:
  - `resolve_session(simos, proj, ...)::WorkSession`: resolve/load-or-create object, no writes, no validation, no side effects on `simos`.
  - `session_init!(simos, proj, ...)`: resolve + set `simos.worksession` + disk prep + validation + metadata capture.
- Do not rely on internal `simos.project` by default; pass project explicitly.
- Add minimal `session.json` as session identity/metadata file.
- Keep interface work first; macro refactor comes later.

## Option Chosen
- User selected **Option A**: no extra non-bang initializer layer beyond `resolve_session` and `session_init!`.
- User command was: `- I prefer option A` + `Implement`.

## What Was About To Be Implemented
- Start coding the Option A interface and remove old/overlapping paths.
- Align current WorkSession init flow with the new resolve/init split.
- Ensure behavior matches project pattern already adopted (`resolve_project` + `proj_init!`).

## Immediate Pre-Implementation Reads
Assistant paused due rate limit right after opening:
- `src/WorkSession/session-I0x.jl`
- `src/WorkSession/base-I0x.jl`
- `src/Kernel/scopetapes/base-I0x.jl`
- `src/Kernel/core/uxlayer-I2x.jl`

These reads were to ground the implementation before editing.

## Next Concrete Step
Implement Option A in WorkSession API surface (resolve/init split with `session.json` support), then reconnect call sites incrementally.
