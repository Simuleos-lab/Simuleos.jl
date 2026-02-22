## System Architecture Principles

- Architecture is workflow-oriented: subsystems model workflows, not folder ownership.
- Core layer model:
  - `Kernel.Core`: shared types, runtime state, settings, paths, utilities.
  - Kernel subsystems: low-level storage, tape, scope, and metadata primitives.
  - App/user subsystems: user-facing orchestration and macro workflows.
- Across layers, dependencies should point downward.
- Within a layer, collaboration should stay explicit and simple.
- `Kernel.Core` is shared foundation, not a business subsystem.
- Type and runtime state definitions stay centralized in core as SSOT.
- State spans runtime and disk:
  - runtime active state: `SimOs`.
  - disk state: project `.simuleos/` plus home `~/.simuleos/`.
- Recording architecture is performance-sensitive:
  - distinguish hot path calls from cold path calls.
  - keep recording overhead low on simulation hot paths.
  - move heavy, non-critical recording work to cold paths when possible.
- Current index scope tracks this as a principle only; detailed hot/cold call inventory is still pending.
