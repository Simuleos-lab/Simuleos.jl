# 560 — Codebase Quality Review: Dead Code & Backward Compat

**Date:** 2026-02-23
**Focus:** eliminate backward-compat code, no deprecated patterns

---

## ~~Issue 1: Legacy verb dispatch in `@simos` macro~~ SOLVED

Deleted `_SIMOS_LEGACY_VERBS`, `_simos_legacy_verb_list_str()`,
`_simos_dispatch_legacy()` (~40 lines). Removed Symbol fallthrough branch
from macro body. Replaced docstring "Equivalent old macro" column with
descriptions. Migrated all legacy syntax in `test/simos_macro_tests.jl` and
`test/worksession_tests.jl` to dotted-command call syntax.

---

## ~~Issue 2: Backward-compatible 6-arg `_make_scope_variable` overload~~ SOLVED

**Location:** `src/Kernel/scoperias/base.jl:79-86`

Explicitly labeled backward-compat overload, never called anywhere.

```julia
# Backward-compatible 6-arg form (no hash_vars)
function _make_scope_variable(
        level::Symbol, value,
        inline_vars::Set{Symbol}, blob_vars::Set{Symbol},
        name::Symbol, storage::Union{BlobStorage, Nothing}
    )
```

Deleted backward-compatible 6-arg overload in `src/Kernel/scoperias/base.jl`.

---

## ~~Issue 3: Dead `reset!` and `nuke!` on SimOs~~ SOLVED

**Location:** `src/Kernel/core/simos.jl:245-256`

`reset!(simos::SimOs)` is never called — the public API uses `sim_reset!()`.
`nuke!(simos::SimOs)` is never called or tested and dangerously does
`rm(...; recursive=true, force=true)`.

Deleted `reset!(simos::SimOs)` and `nuke!(simos::SimOs)` from `src/Kernel/core/simos.jl`.

---

## ~~Issue 4: Dead utility functions in `utils.jl`~~ SOLVED

Deleted `getvariable`, `variables`, `setvariable!`, `_liteify`, `_symbol_keys`
(15 lines). Kept `hasvar` (used in tests).

---

## ~~Issue 5: Dead scope operations in `scoperias/ops.jl`~~ SOLVED

Deleted `filter_vars`, `filter_vars!`, `filter_labels`, `filter_labels!`,
`merge_scopes` (38 lines). Only `filter_rules` + `_resolve_action` remain.

---

## ~~Issue 6: Dead functions scattered across Kernel~~ SOLVED

| Function | File:Line | Reason |
|---|---|---|
| `home_simuleos_default_path()` | `home.jl:9` | Unused alias |
| `init_home!(::SimuleosHome)` | `home.jl:29-31` | Unused wrapper |
| `git_remote()` / `git_remote(::GitHandler)` | `gitmeta/git.jl:76-83, 89` | Never called or tested |
| `commit_stage!()` | `scopetapes/write.jl:110-117` | Pre-WorkSession relic |
| `append_simignore_rule!()` | `simignore.jl:132-136` | Never called |
| `proj_path()` / `proj_json_path()` | `project.jl:92-93` | Unused accessors |
| `BLOB_HASH_CHUNK_SIZE` | `blob.jl:8` | Unused constant |

Deleted all listed dead symbols: `home_simuleos_default_path`, `init_home!(::SimuleosHome)`,
`git_remote` (both methods), `commit_stage!`, `append_simignore_rule!`,
`proj_path`, `proj_json_path`, and `BLOB_HASH_CHUNK_SIZE`.

---

## ~~Issue 7: Stale "replaces UXLayers" comments~~ SOLVED

Removed "(replaces UXLayers)" from `types.jl:239` and `settings.jl:2`.

---

## Priority

| # | Issue | ~Lines | Effort |
|---|---|---|---|
| 1 | Delete legacy verb dispatch (Issue 1) | 50 | Medium — update tests |
| 2 | Delete dead scope ops (Issue 5) | 38 | Trivial |
| 3 | Delete dead Kernel functions (Issue 6) | 35 | Trivial |
| 4 | Delete dead utils (Issue 4) | 15 | Trivial |
| 5 | Delete reset!/nuke!/6-arg overload (Issues 2,3) | 20 | Trivial |

Issues 7 and 8 are quick comment fixes, do alongside any of the above.

## Health Summary

Core architecture is clean — small focused files, clear module boundaries,
minimal external deps (only JSON3 beyond stdlib). Main debt is ~16 unused
functions, 1 unused constant, and a full legacy dispatch path. Roughly **~160
lines** deletable with zero behavioral change. Legacy verb dispatch is the
biggest item — it doubles the `@simos` macro surface area.
