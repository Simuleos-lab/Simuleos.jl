# 563 — `@simos settings...` Settings Stack Implementation Plan

**Date:** 2026-02-24
**Status:** Planned (v1 command contract frozen)
**Scope:** design + implementation plan for a unified runtime settings stack and `@simos settings...` user interface

---

## Goal

Implement a unified settings system that can merge and inspect multiple sources while preserving the intended bootstrap boundary:

- runtime settings sources:
  - home settings JSON
  - project settings JSON
  - external JSON files (ordered, multiple)
  - environment (`SIMULEOS_*`)
  - CLI args (`ARGS` or explicit args vector)
  - script-level overrides
  - session-level overrides
- user-facing interface: `@simos settings...`
- internal interface: typed APIs usable by Kernel/WorkSession/CLI without macro dependency

Non-goal (v1):
- moving bootstrap locator keys (`home.path`, `project.root`) into runtime settings

---

## Architectural Constraints (must preserve)

1. Bootstrap boundary is intentional
- `home.path` / `project.root` may be required before settings files can be loaded.
- Keep engine/bootstrap location resolution in `system.init` / `sim_init!`, not in runtime settings mutation.

2. No backward compatibility retention
- Prefer replacing current ad-hoc settings logic with a single SSOT stack.
- Remove deprecated paths after migration in the same implementation cycle.

3. Explicit imports and internal APIs
- No new exports in internal modules.
- Top-level `Simuleos` exports only if user-facing API needs it (macro path may avoid exports entirely).

4. Keep user-facing ergonomics but avoid hidden magic
- Make layer names explicit (`:script`, `:session`, etc.).
- Provide provenance/explain APIs to inspect winners and overrides.

---

## Current State Summary (baseline to replace)

- Global merged settings are a flat `Dict{String,Any}` snapshot built at `sim_init!`.
- Merge order is `home < project < env < bootstrap`.
- Session settings are a runtime-only cache that falls back to global settings.
- No external JSON source registration.
- No CLI args settings parser.
- No `@simos settings...` macro commands.
- No provenance/introspection beyond raw value lookup.
- No reload of source layers after init.

---

## Proposed v1 Model (SSOT)

### 1. Data Structures

Add a settings stack object owned by `SimOs` (replace raw merged dict as primary state).

Proposed core types (names can change, behavior is the important part):

- `SettingsLayer`
  - `name::Symbol`
  - `kind::Symbol` (`:home`, `:project`, `:env`, `:json_file`, `:cli`, `:script`, `:session`)
  - `mutable::Bool`
  - `persistent::Bool`
  - `origin::Dict{String,Any}` metadata (path, parser style, optional, insertion position, etc.)
  - `data::Dict{String,Any}` normalized flat dotted-key map

- `SettingsStack`
  - `layers::Vector{SettingsLayer}` ordered low->high priority
  - `effective::Dict{String,Any}` cached merged result
  - `provenance::Dict{String,Vector{NamedTuple}}` optional cache (winner/overrides info)
  - `version::Int` increment on mutation/reload

Minimal v1 simplification:
- provenance can be computed on demand instead of cached

### 2. Canonical Key Shape

- Canonical internal keys are flat dotted strings (`"solver.tol"`).
- JSON objects are flattened into dotted keys on load.
- Env keys remain current mapping (`SIMULEOS_X_Y` -> `"x.y"`).
- CLI parser emits dotted keys directly.

Why:
- matches current code usage (e.g., `"worksession.batch_commit.max_pending_commits"`)
- simpler merge semantics than deep recursive merge
- easier provenance and prefix filtering

### 3. Bootstrap vs Runtime Split

Separate two concerns explicitly:

- `BootstrapConfig` (existing `bootstrap` / sandbox / env locator behavior)
  - engine/home/project discovery/init
- `SettingsStack` (runtime configuration after engine init)
  - query/mutate/reload/explain/persist runtime settings layers

Enforce:
- runtime mutations to bootstrap-only keys error with actionable message
- `@simos settings.set("project.root", ...)` -> error suggesting `@simos system.init(...; reinit=true, bootstrap=...)`

---

## Proposed Layer Order (v1)

Ordered low -> high priority:

1. `:home` (persistent, file-backed)
2. `:project` (persistent, file-backed)
3. registered external JSON file layers (`:json_file` in insertion order)
4. `:env` (ephemeral, reloadable)
5. `:cli` (ephemeral, mutable/reparseable)
6. `:script` (ephemeral mutable overlay)
7. `:session` (ephemeral mutable overlay; reset on session init)

Notes:
- `:cli` is a named overlay populated by parser; not tied to CLI executable only.
- `:script` survives session changes.
- `:session` is reset when a work session starts/switches.

---

## `@simos settings...` Surface (v1)

### Contract Freeze (2026-02-24)

This section freezes the v1 user-facing command signatures and return shapes so implementation can proceed without re-litigating syntax.

### Query / Introspection

- `@simos settings.get("key")`
- `@simos settings.get("key"; default=value, layer=:effective)`
- `@simos settings.require("key")`
- `@simos settings.require("key"; layer=:effective)`
- `@simos settings.has("key")`
- `@simos settings.has("key"; layer=:effective)`
- `@simos settings.keys(; layer=:effective, prefix="")`
- `@simos settings.snapshot(; layer=:effective, prefix="", nested=false)`
- `@simos settings.layers()`
- `@simos settings.explain("key")`
- `@simos settings.explain("key"; layer=:effective)` (kept for symmetry; `:effective` is the normal use)

Signature decisions:
- `get` uses keyword `default`, not positional default.
- `layer` is always a keyword for query APIs.
- `require` never accepts `default`.
- `keys`/`snapshot`/`layers` return plain Julia values (no wrapper types).
- `layer=:effective` means query the merged result.
- `layer=<symbol>` (e.g. `:project`) means query only that layer snapshot.

Recommended return shapes:
- `get` -> value or default
- `require` -> value or error
- `has` -> `Bool`
- `keys` -> `Vector{String}` (sorted)
- `snapshot` -> `Dict{String,Any}`
  - `nested=false` (default): flat dotted-key map
  - `nested=true`: nested object tree using `Dict{String,Any}` at each object node
- `layers` -> vector of named tuples (`name`, `kind`, `mutable`, `persistent`, `size`, `origin`)
- `explain` -> named tuple:
  - `key`
  - `found::Bool`
  - `layer::Symbol` (query target, usually `:effective`)
  - `winner_layer::Union{Nothing,Symbol}` (when `layer=:effective`; otherwise same as layer if found)
  - `value` (or `nothing` when missing)
  - `candidates::Vector{NamedTuple}` (layer/value/priority)

### Mutation (runtime overlays + selected file-backed layers)

- `@simos settings.set("key", value; layer=:script)`
- `@simos settings.unset("key"; layer=:script)`
- `@simos settings.merge(dict; layer=:script, clear=false)`
- `@simos settings.clear(; layer=:script, prefix=nothing)`

Behavior:
- default target layer = `:script`
- `:session` allowed
- `:cli` allowed (as overlay edits after parse)
- `:home` / `:project` allowed only if explicitly targeting that layer
- readonly layers (`:env`, registered JSON file layers unless policy says mutable=false) should reject direct set/unset
- `settings.merge(dict; ...)` accepts nested or flat dicts; nested objects are flattened into dotted keys before merge
- `settings.clear(; prefix=...)` removes only keys that start with `prefix`
- bootstrap-only keys (e.g. `project.root`, `home.path`) are rejected for runtime mutation on any layer

### Source Registration / Reload

- `@simos settings.source.list()`
- `@simos settings.source.add_json(path; name=nothing, after=:project, optional=false, replace=false)`
- `@simos settings.source.add_args(args=ARGS; name=:cli, after=:env, replace=true, style=:simos_v1)`
- `@simos settings.source.remove(name::Symbol)`
- `@simos settings.source.reload(name::Symbol)`
- `@simos settings.source.reload_all()`

Behavior:
- `add_json` inserts one layer and records file origin metadata
- `add_json(...; replace=false)` errors on name collision
- `add_args` parses args and populates/replaces target layer
- `add_args(...; replace=true)` replaces an existing same-name `:cli` layer by default
- `reload` re-reads by source kind using stored origin metadata
- `reload_all` reloads dynamic layers (`:home`, `:project`, `:json_file`, `:env`, `:cli`)

### Persistence / Import-Export

- `@simos settings.save(:home)`
- `@simos settings.save(:project)`
- `@simos settings.import_json(path; layer=:script)`
- `@simos settings.export_json(path; layer=:effective, nested=true)`

Behavior:
- `save` writes the target layer’s current flat dict as nested JSON (human-friendly)
- `import_json` is convenience = read + flatten + merge
- `export_json` writes snapshot (effective or specific layer)

### Lifecycle / Reset

- `@simos settings.reload()`
- `@simos settings.reset(; layers=[:script, :session, :cli])`

Behavior:
- `reload()` delegates to `source.reload_all()` and rebuilds effective cache
- `reset()` clears mutable overlays and preserves persistent sources by default

---

## Internal API Plan (non-macro SSOT)

Create a dedicated Kernel settings-stack module/file set (exact file split can vary):

- `src/Kernel/core/settings_types.jl`
  - `SettingsLayer`, `SettingsStack`

- `src/Kernel/core/settings_normalize.jl`
  - flatten nested dict -> dotted keys
  - unflatten dotted keys -> nested dict
  - key validation

- `src/Kernel/core/settings_stack.jl`
  - create stack
  - insert/remove/find layer
  - rebuild effective
  - query APIs (`get`, `has`, `snapshot`, `explain`)
  - mutate APIs (`set!`, `unset!`, `merge!`, `clear!`)

- `src/Kernel/core/settings_sources.jl`
  - load home/project/env/json/args sources
  - source registration metadata
  - reload logic

- `src/Kernel/core/settings_persist.jl`
  - save/export/import helpers

If simpler for v1, start with 2 files (`settings.jl`, `settings_sources.jl`) and split later.

### `SimOs` integration

Change `SimOs` from:
- `settings::Dict{String,Any}`

to something like:
- `settings_stack::SettingsStack`

Compatibility shim during migration (short-lived, same PR allowed):
- `get_setting(simos, ...)` delegates to stack effective lookup
- `settings(simos, ...)` unchanged external behavior

Optional:
- keep `settings::Dict` as derived cache only if needed, but prefer deleting and using stack cache as SSOT

### WorkSession integration

Replace `ws._settings_cache` ad-hoc fallback logic with `:session` layer operations:

- on `session_init!`: clear `:session` layer
- `session_setting(ws, ...)` delegates to stack query
- `session_setting!(ws, key, value)` becomes stack set on `:session`

Migration option (incremental):
- keep `_settings_cache` temporarily but mirror to `:session` layer, then delete `_settings_cache` after tests pass

Preferred final state:
- remove `_settings_cache` field if not needed elsewhere

---

## CLI Args Parsing Plan (shared parser)

Introduce a parser that both CLI and scripts can use via settings source API.

### v1 parser scope

Support only settings-oriented args for source ingestion, independent of command dispatch:

- `--set key=value`
- `--set=key=value`
- `--unset key`
- `--unset=key`
- `--config path.json`
- `--config=path.json`
- `--settings-json path.json`
- `--settings-json=path.json`
- `--` terminator (stop settings-flag scanning; remaining args go to `extras`)

Frozen v1 parser behavior:
- Parser is extraction-oriented, not a full CLI validator.
- Unknown flags and positional args are preserved in `extras` (not errors).
- Recognized settings flags with malformed/missing values are errors.
- Repeated flags are allowed and applied in input order.
- For `--set`, split on the first `=` only (`key=value=tail` -> key=`key`, value=`value=tail`).
- Empty keys are errors.
- Empty values are allowed (`--set k=` -> `""`).
- `--unset` records explicit removal of a key in the args layer.

Parsing output should be a deterministic struct / named tuple:
- `sets::Dict{String,Any}` (values parsed conservatively)
- `unsets::Vector{String}`
- `json_files::Vector{String}`
- `extras::Vector{String}` (non-settings args left for command dispatch if needed)
- `events::Vector{NamedTuple}` (recommended internal-only; ordered normalized operations for replay/debug)

Value parsing policy (v1, explicit and simple):
- primitive coercions (case-sensitive):
  - `true` -> `Bool(true)`
  - `false` -> `Bool(false)`
  - `null` -> `nothing`
  - integer regex (`^[+-]?\\d+$`) -> `Int`
  - float regex (`^[+-]?(\\d+\\.\\d*|\\d*\\.\\d+)([eE][+-]?\\d+)?$` or exponent form) -> `Float64`
- complex JSON literals require explicit prefix:
  - `json:<payload>` -> parse `<payload>` with `JSON3.read`
  - examples:
    - `--set tags=json:[\"a\",\"b\"]`
    - `--set opts=json:{\"k\":1}`
- otherwise keep as raw `String`

Layer-application semantics for `add_args` (frozen v1):
- Parse args into parser output.
- For each `json_files` entry (in order), register/load a JSON source layer (generated names unless user passed `name` and exactly one file).
- Apply `sets` and `unsets` into the target args layer (`name`, default `:cli`).
- `extras` are returned to caller but do not affect settings.

This parser can feed:
- `settings.source.add_args(args)`
- future CLI global settings pre-processing

---

## JSON Source Handling Plan

### Read path
- JSON file -> nested dict -> string keys -> flatten dotted keys

### Write path
- flat dotted dict -> nested dict -> pretty JSON (`JSON3.pretty`)

### Error behavior
- missing file + `optional=false` -> error
- missing file + `optional=true` -> empty layer + warning metadata flag
- malformed JSON -> error with path
- non-object JSON root -> error (v1), keep semantics strict

### Duplicate layer names
- default generated names for `add_json` when no `name`:
  - `:file_1`, `:file_2`, ...
- explicit name collision:
  - either replace if `replace=true`
  - else error (recommended default)

---

## Provenance / Explain Semantics (important)

`settings.explain("x")` should be implementation-grade, not cosmetic.

For a queried key, return:
- all candidate layers that define it, ordered low->high
- winner (highest priority candidate)
- effective value
- source metadata for each candidate (e.g., path for JSON file, `ENV` for env, parser style for args)

This is critical for debugging layered config behavior.

---

## Macro Interface Implementation Plan

Add `settings` command group to `@simos` in `src/SimosAPI/macro.jl`.

### Commands to register (v1)

- `(:settings, :get)`
- `(:settings, :require)`
- `(:settings, :has)`
- `(:settings, :keys)`
- `(:settings, :snapshot)`
- `(:settings, :layers)`
- `(:settings, :explain)`
- `(:settings, :set)`
- `(:settings, :unset)`
- `(:settings, :merge)`
- `(:settings, :clear)`
- `(:settings, :reload)`
- `(:settings, :reset)`
- `(:settings, :save)`
- `(:settings, :import_json)`
- `(:settings, :export_json)`
- `(:settings, :source, :list)`
- `(:settings, :source, :add_json)`
- `(:settings, :source, :add_args)`
- `(:settings, :source, :remove)`
- `(:settings, :source, :reload)`
- `(:settings, :source, :reload_all)`

### Macro dispatch strategy

- Keep macro parser strict and thin:
  - validate positional/keyword shape
  - forward to WorkSession/Kernel runtime functions
- Do not embed settings logic in macro code

### Runtime host location

Choose one:
- `WorkSession` runtime wrappers (consistent with current `@simos` runtime entrypoints)
- or direct `Kernel` calls for settings-only commands

Recommended:
- settings runtime functions live in `Kernel`
- macro handlers call `Kernel` through a small `WorkSession`/SimosAPI wrapper only if current pattern requires it

---

## Phased Implementation Sequence (detailed)

### Phase 0 — Lock spec + tests first (small)

1. Add a live test matrix note (can be same file section) defining exact semantics for:
- layer precedence
- bootstrap-key mutation rejection
- explain output ordering
- reload behavior
- session reset behavior

2. Decide and freeze:
- `get` signature style (`get(key; default=...)`) [DONE in this note]
- `snapshot(nested=true)` output type [DONE in this note]
- CLI args parser v1 accepted forms [DONE in this note]

Deliverable:
- documented command/API contract (this note + code comments)

### Phase 1 — Internal stack foundation (Kernel)

1. Add settings stack types and core merge/rebuild/query functions.
2. Add normalize helpers (flatten/unflatten dotted keys).
3. Port current `load_all_settings` behavior to stack creation.
4. Keep old `get_setting`/`settings` wrappers delegating to new effective stack.
5. Preserve existing behavior for current callers.

Tests:
- unit tests for flatten/unflatten
- precedence tests for `home/project/env/bootstrap-equivalent` stack construction
- `get/require/has` behavior parity

### Phase 2 — Dynamic sources + reload

1. Add source registration metadata and `add_json`, `remove`, `list`.
2. Add env source reload and `reload_all`.
3. Add file source reload, optional file handling.
4. Add `explain` provenance implementation.

Tests:
- add/remove/reload json source
- source ordering (`after=:project`, insertion stability)
- explain winner/candidates

### Phase 3 — Script/session overlays + WorkSession migration

1. Add built-in mutable layers `:script` and `:session`.
2. Route `session_setting` / `session_setting!` through stack.
3. Reset `:session` on session init/switch.
4. Remove `_settings_cache` if no longer necessary.

Tests:
- session override beats script/env/project
- session reset on `session_init!`
- script persists across session changes
- `worksession.batch_commit.max_pending_commits` still works

### Phase 4 — Persistence + import/export

1. Implement `save(:home|:project)` writing nested JSON.
2. Implement `import_json` / `export_json`.
3. Add readonly checks for non-persistent/non-mutable layers.

Tests:
- save/load roundtrip for dotted keys
- nested JSON write/read normalization
- reject save on unsupported layers

### Phase 5 — CLI args parser + args source

1. Add shared parser for settings-focused CLI args.
2. Add `settings.source.add_args`.
3. Add `:cli` built-in layer semantics.
4. (Optional in same phase) integrate CLI executable pre-processing if desired.

Tests:
- parse `--set`, `--unset`, `--config`
- value parsing coercion
- `add_args` populates correct layer and precedence

### Phase 6 — `@simos settings...` macro surface

1. Register settings commands in `_SIMOS_COMMANDS`.
2. Add macro dispatch branches and handlers.
3. Implement runtime functions for each command.
4. Keep errors strict and actionable.

Tests:
- macro invocation shape validation
- representative happy paths for each command family
- error messages for bad layer names / bad args / bootstrap-key mutation

### Phase 7 — Cleanup + docs/index alignment

1. Remove obsolete ad-hoc settings code paths / aliases.
2. Update index notes for finalized settings stack semantics.
3. Add one live example script in `dev/live/` showing multi-source config stack.

Tests:
- full suite
- targeted regression for `@simos session.queue` batching setting

---

## Test Plan (concrete)

Create/extend tests in:
- `test/simos_macro_tests.jl` (macro surface)
- `test/worksession_tests.jl` (session layer behavior and batch commit setting)
- new `test/settings_tests.jl` (recommended)

### `settings_tests.jl` coverage

1. Stack construction
- home/project/env precedence
- empty/missing home/project files
- string-key normalization

2. Flatten/unflatten
- nested dict to dotted keys
- dotted keys back to nested dict
- mixed scalar/object conflict behavior (explicitly define)

3. Query APIs
- get/require/has/keys/snapshot(prefix)
- layer-specific snapshots

4. Provenance
- explain missing key
- explain key with 1 source
- explain key with 4+ sources

5. Source management
- add/remove/list json sources
- reload single source
- reload all dynamic sources

6. Mutation
- set/unset/merge/clear on `:script`, `:session`, `:project`
- readonly rejection on `:env` and json file layers
- bootstrap-key mutation rejection

7. Persistence
- save project/home and reload
- export effective/import script

8. CLI args source
- add_args parser and precedence against env/script

### Macro tests

- `@simos settings.get/require/has`
- `@simos settings.set/unset/merge/clear`
- `@simos settings.layers/explain`
- `@simos settings.source.add_json/add_args/reload/remove/list`
- invalid command arg shapes and invalid keyword names

---

## Error Semantics (explicit)

Use clear, strict errors (consistent with current code style):

- unknown layer name
- readonly layer mutation
- unsupported save target
- missing required key
- malformed JSON file
- duplicate source name
- invalid insertion anchor (`after=:nope`)
- bootstrap-only key mutation attempted via runtime settings
- invalid key format (empty / whitespace-only)

Prefer deterministic messages because macro tests assert on error quality.

---

## Performance / Complexity Notes

- Effective merged cache should rebuild only on mutations/reloads, not every `get`.
- `explain` can scan layers on demand (fine for v1).
- `keys(prefix=...)` should avoid heavy allocations where easy, but correctness first.
- Do not over-optimize before feature completion; settings ops are cold path relative to capture flow.

---

## Migration / Compatibility Strategy (short-lived)

Implementation target is one refactor cycle, not long-lived compatibility.

Allowed temporary shims during implementation:
- old `get_setting` delegates to stack effective cache
- old `session_setting!` delegates to `:session` layer

Final cleanup (same effort window):
- remove redundant merged-dict SSOT and ad-hoc session cache if replaced
- keep only one settings storage path in runtime state

---

## Acceptance Criteria (done definition)

1. `@simos settings...` supports querying, mutation, source registration, reload, explain, and save/import/export for v1 commands.
2. Settings can be layered from multiple JSON files, env, args, script, and session overlays.
3. Session-level settings reset on session init, while script-level settings persist.
4. Bootstrap boundary is enforced by runtime mutation errors for locator keys.
5. Existing settings-dependent behavior (e.g., batch commit threshold) still works.
6. Tests cover precedence, provenance, persistence, and macro surface.

---

## Suggested First Implementation Slice (pragmatic)

If implementing incrementally in the next session, start here:

1. Kernel `SettingsStack` + built-in layers (`home`, `project`, `env`, `script`, `session`)
2. Query APIs + `set/unset/merge/clear` for script/session
3. WorkSession migration to `:session` layer
4. `@simos settings.get/set/explain/layers`

Then add:

5. external JSON sources + reload
6. save/import/export
7. args parser + `add_args`
8. full macro surface
