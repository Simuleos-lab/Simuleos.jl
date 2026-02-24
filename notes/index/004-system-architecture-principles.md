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

## Macro Hygiene — Module References In Generated Code

- Macros that emit code referencing other modules must use `const` aliases, not bare module names.
- Pattern: `const _ModAlias = ActualModule`, then interpolate `$(_ModAlias).symbol` in `quote` blocks.
- This ensures generated code resolves correctly regardless of the caller's namespace.
- Review trigger: bare `$(ModuleName).func` in a `quote` block without a corresponding `const` alias.

## Settings Bootstrap Phase Boundary

- Some config values are intentionally resolved before the merged settings stack exists.
- Early bootstrap inputs (`bootstrap` / environment) may set locator keys such as `home.path` and `project.root`.
- Rationale: home/project settings files cannot be read until home/project locations are already known.
- Therefore, `~/.simuleos/settings.json` and project `.simuleos/settings.json` do not define where to find themselves.
- Treat this as a bootstrap simplification boundary, not a settings inconsistency.
- When extending the settings stack, keep "engine location/bootstrap" inputs conceptually separate from regular runtime settings.
