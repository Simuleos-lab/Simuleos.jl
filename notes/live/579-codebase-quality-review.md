# Codebase Quality Review (Simuleos)

Scope reviewed: `src/`, `test/`, and repository layout surfaces that directly affect maintainability.

### ~~Issue: Settings subsystem is concentrated in one very large file~~

**Location:** `src/Kernel/Infra/settings/settings.jl`

**Why this is an issue:**
One file currently mixes settings data model definitions, stack caching, registry logic, source loading/reloading, layer mutation APIs, and explain/reporting logic. This makes the module harder to navigate, raises review friction, and increases regression risk when changing one concern.

**Evidence:**
- `settings.jl` is 983 lines (`wc -l`).
- Same file contains:
  - constructors and low-level helpers (`SettingsLayer`, `SettingsStack`, lines 12-124),
  - built-in layer assembly (`_settings_builtin_layers`, lines 435-507),
  - source insertion/reload (`settings_source_add_json!`, `settings_reload!`, lines 749-825),
  - explain/report surface (`settings_explain`, lines 871-983).

**Improvement proposals:**

1. Keep behavior unchanged, but reorganize by section and add a strict "public API first" index comment at file top.
2. Split into focused files (`stack.jl`, `registry.jl`, `sources.jl`, `explain.jl`) and keep the current API entrypoints.
3. Introduce a `SettingsService` facade with explicit internal interfaces for read, mutate, source, and explain flows.

**Expected impact:**
Lower cognitive load, smaller diffs, faster onboarding, and safer incremental changes in settings behavior.

### Issue: `@simos` handlers remain broad and repetitive

**Location:** `src/SimosAPI/macro/handlers.jl`

**Why this is an issue:**
The handlers file centralizes many command families and repeats wrapper patterns heavily, making it easy for command semantics to drift and harder to audit for consistency.

**Evidence:**
- `handlers.jl` is 853 lines (`wc -l`).
- Repeated wrapper pattern (`_ = mod`, `_ = src`, then forwarding) appears across many commands (e.g., lines 159-339, 391-467, 817-853).
- Similar staging wrappers (`_simos_store`, `_simos_hash`, `_simos_inline`) duplicate nearly identical loops (lines 479-519).

**Improvement proposals:**

1. Extract tiny helper builders for common wrapper forms (no-posargs, one-arg string conversion, keyword-only forwarding).
2. Split handlers by command namespace (`handlers_settings.jl`, `handlers_sqlite.jl`, `handlers_scope.jl`, etc.).
3. Generate boilerplate forwarding handlers from command spec metadata and keep only custom handlers handwritten.

**Expected impact:**
More uniform command behavior, reduced duplication bugs, and easier extension of `@simos` surfaces.

### Issue: Multiple silent catch/fallback paths hide actionable failures

**Location:** `src/Kernel/Foundation/simos.jl`, `src/SQLiteIndex/sql_helpers.jl`, `src/Kernel/Infra/project/project.jl`, `src/Kernel/Infra/cache/cache.jl`

**Why this is an issue:**
Silent catches and fallback defaults can mask real corruption/state problems and make production/debug behavior non-obvious.

**Evidence:**
- `simos.jl` swallows any close error for cached SQLite handle (`catch` with no handling, lines 67-74).
- SQLite transaction helper swallows rollback failure (`sql_helpers.jl`, lines 18-23).
- Session timestamp parse failure is silently converted to `DateTime(0)` (`project.jl`, lines 147-151).
- Cache hit parsing failure silently returns `0` hits (`cache.jl`, lines 39-43).

**Improvement proposals:**

1. Keep current control flow but emit warning logs for swallowed errors and fallback paths.
2. Replace broad catches with targeted exception handling and structured error payloads.
3. Add a strict mode (or test mode default) that converts these fallbacks into hard errors.

**Expected impact:**
Faster root-cause analysis, reduced hidden data-quality issues, and safer operational behavior.

### Issue: Placeholder lanes are included in runtime module loading

**Location:** `src/Kernel/Kernel.jl`, `src/Kernel/Classes/*/placeholder.jl`, `src/Kernel/Workflows/*/placeholder.jl`

**Why this is an issue:**
Loading placeholders as normal includes blurs the boundary between implemented and planned features, and can confuse contributors about production-supported surfaces.

**Evidence:**
- `Kernel.jl` includes placeholders directly (lines 36-38, 57-58).
- Placeholder files currently only contain comments (e.g., `Classes/src/placeholder.jl`, `Classes/snap/placeholder.jl`, `Workflows/contextref/placeholder.jl`).

**Improvement proposals:**

1. Keep files but mark placeholder includes with explicit "non-runtime scaffold" comments plus issue/roadmap IDs.
2. Stop including placeholders at runtime; leave stubs discoverable via docs/notes instead.
3. Move planned lanes to an explicit feature registry that can be toggled and tested independently.

**Expected impact:**
Clearer implementation boundaries, less ambiguity during maintenance, and cleaner module load graph.

### Issue: Legacy/reference trees add high noise to day-to-day engineering workflows

**Location:** repository root (`_DEPRECATED/`, `refs/`)

**Why this is an issue:**
Large legacy/reference trees in the same repo increase search noise and make it harder to quickly locate active-source signals, especially for automated scans and new contributors.

**Evidence:**
- Root contains both `_DEPRECATED/` and `refs/`.
- TODO scan for Julia files is dominated by `refs/` hits rather than `src/`/`test/`.

**Improvement proposals:**

1. Add explicit contributor guidance and default search ignores for `_DEPRECATED/` and `refs/`.
2. Move archived/reference code to a dedicated archive path/repo and keep only pointers in this repo.
3. Keep only reproducible snapshots (minimal examples + notes) and remove full legacy trees.

**Expected impact:**
Higher signal-to-noise during code search/review, faster onboarding, and fewer mistaken edits in non-active code.

### Issue: README export documentation is out of sync with top-level exports

**Location:** `README.md`, `src/Simuleos.jl`

**Why this is an issue:**
API docs drift causes onboarding friction and incorrect usage assumptions, especially for agents/new contributors relying on README as source of truth.

**Evidence:**
- README "Current top-level exported symbols" includes `each_commits` and `each_scopes` (lines 206-209).
- `src/Simuleos.jl` export block (lines 15-20) does not export `each_commits` or `each_scopes`.

**Improvement proposals:**

1. Update README export list immediately to match `src/Simuleos.jl`.
2. Add a small doc-check test that compares documented exports to actual exports.
3. Auto-generate the export section from module metadata during docs updates.

**Expected impact:**
More trustworthy docs, fewer integration mistakes, and reduced maintenance drift.

## Top 5 Prioritized Improvements

1. Split `settings.jl` by concern while preserving current API.
2. Decompose/standardize `@simos` handlers to reduce repetitive wrapper logic.
3. Remove or instrument silent catch/fallback paths in state/index/project/cache flows.
4. Decide and enforce a strict policy for runtime placeholders vs roadmap scaffolds.
5. Isolate `_DEPRECATED/` and `refs/` from default contributor/search workflows.

## Codebase Health Summary

Core architecture is functional and reasonably test-covered, but maintainability risk is concentrated in a few very large, multi-responsibility files and in repository signal noise from legacy/reference trees. Main risk areas are settings complexity, macro handler sprawl, and silent error fallback behavior that can hide operational issues. Addressing the top 5 items above should yield immediate improvements without requiring a rewrite.
