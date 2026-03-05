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

## SimuleosDataClass Type Model

- A `SimuleosDataClass` subtype is the single runtime representation of a record, used for both reading and writing. `disk representation <-> runtime representation` — that is what a Simuleos class is.
- Read and write must be symmetric: if decode returns `T`, then encode accepts `T`, and the tape write path accepts `T`. No sneaking a different type through the write path.
- Type transitions mark semantic transitions. When data changes role (e.g., from in-progress accumulation to committed record), that is where you change types. Conversion logic belongs at the semantic boundary, not inside the serializer.
- General containers (like `CaptureTree`) are structural building blocks, not records. They can live inside a `SimuleosDataClass` but are not themselves classes. The record is the envelope that gives captured data identity in the class system.
- Mutable internal structs inside a committed record are treated as immutable by convention. Document it; do not over-engineer enforcement. Same pattern as a `Dict` field — the contract says do not mutate after construction.

## Macro Hygiene — Module References In Generated Code

- Macros that emit code referencing other modules must use `const` aliases, not bare module names.
- Pattern: `const _ModAlias = ActualModule`, then interpolate `$(_ModAlias).symbol` in `quote` blocks.
- This ensures generated code resolves correctly regardless of the caller's namespace.
- Review trigger: bare `$(ModuleName).func` in a `quote` block without a corresponding `const` alias.

## Settings Stack

- Ordered layers, low → high priority: `defaults` → `home` → `project` → `env` → `runtime` → `script` → `session`.
- Higher-priority layer wins for the same key.
- `home.path` and `project.root` are resolved before the stack exists (bootstrap boundary — settings files can't define where to find themselves).

### Key Alias System

- Each registered setting has a **canonical key** (e.g., `"session.init.git_dirty_policy"`).
- Two automatic aliases are derived from every canonical key:
  - **Julia-id**: `"." → "_"` → `"session_init_git_dirty_policy"` (for kwargs — Julia symbols can't have dots).
  - **Fully-dotted**: `"_" → "."` → `"session.init.git.dirty.policy"` (what `_runtime_settings_from_pairs` produces via blanket underscore-to-dot replacement).
- Explicit aliases can be added at registration (e.g., `SIMULEOS_HOME_PATH` for env vars).
- Resolution scans layers highest-to-lowest, checking canonical + all aliases per layer before moving down. First match wins.
- This means `@simos system.init(session_init_git_dirty_policy = "commit_all")` just works: the kwarg becomes a dotted key in the runtime layer, and the alias system resolves it when the canonical key is queried.

### Implementation

- `src/Kernel/Infra/settings/` — stack, registry, sources, explain, cli_args, env.
- `src/Kernel/Foundation/utils.jl` — canonical key constants and defaults.
- `src/WorkSession/settings.jl` — session-level settings (`:session` layer).
- `src/SimosAPI/macro/handlers/settings.jl` — `@simos settings.*` dispatch.
