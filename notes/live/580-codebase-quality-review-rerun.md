# Codebase Quality Review (Rerun)

Scope reviewed: active package surfaces in `src/`, `test/`, and public API docs in `README.md`.

### Issue: Tape I/O logic is concentrated in one large multi-purpose module

**Location:** `src/Kernel/Infra/tapeio/tape.jl`

**Why this is an issue:**
Path/fragment selection, append behavior, iterators, forward scan, reverse scan, and query helpers all live together. This raises maintenance risk and makes targeted edits harder to reason about.

**Evidence:**
- `tape.jl` has 689 lines.
- It contains 35+ functions, spanning path helpers (`_fragment_files`), append flow (`append!`), iteration (`Base.iterate`), reverse scan internals (`_scan_jsonl_file_reverse!`), and query APIs (`findfirst_tape_record`, `table_tape_records`).

**Improvement proposals:**

1. Add a short internal “file map” comment and stricter section boundaries.
2. Split into focused files (`tape_paths.jl`, `tape_iter.jl`, `tape_query.jl`) while keeping API names.
3. Consolidate forward/reverse scanning around a shared internal scanning core.

**Expected impact:**
Lower cognitive load and safer incremental refactors.

### Issue: `@simos` command registry is dense and centralized

**Location:** `src/SimosAPI/macro/dispatch.jl`

**Why this is an issue:**
Command metadata, guard rules, invocation mode routing, and help rendering are tightly coupled in one file. Adding commands or changing command semantics requires edits in a dense high-risk area.

**Evidence:**
- `dispatch.jl` has 492 lines.
- `_SIMOS_COMMAND_SPECS` occupies a large contiguous block (about lines 69-349).
- The same file also handles command lookup/guards and help text rendering.

**Improvement proposals:**

1. Move `_SIMOS_COMMAND_SPECS` to its own include file.
2. Extract help text rendering into a separate helper module/file.
3. Add a load-time spec validator pass (arity, mode compatibility, duplicate path checks).

**Expected impact:**
Improved command-surface maintainability and less dispatch-registry drift risk.

### Issue: Runtime kernel assembly still includes placeholder scaffold files

**Location:** `src/Kernel/Kernel.jl` and placeholder files under `src/Kernel/Classes/*` and `src/Kernel/Workflows/*`

**Why this is an issue:**
Comment-only scaffold includes blur the boundary between implemented behavior and roadmap placeholders.

**Evidence:**
- `Kernel.jl` includes placeholder files directly (lines 36, 39-40, 59-60).
- Included placeholder files are comment-only scaffolds (`Classes/src/placeholder.jl`, `Classes/rec/placeholder.jl`, `Classes/snap/shared_placeholder.jl`, `Workflows/contextref/placeholder.jl`, `Workflows/sharedstate/placeholder.jl`).

**Improvement proposals:**

1. Keep includes but annotate them as non-runtime scaffolds with roadmap references.
2. Stop runtime-including placeholders and track planned lanes only in notes/index.
3. Introduce an explicit feature-lane registration mechanism for non-default lanes.

**Expected impact:**
Cleaner architecture signaling and less contributor ambiguity.

### Issue: Large integration test files reduce granularity and ownership clarity

**Location:** `test/worksession_tests.jl`, `test/simos_macro_tests.jl`, `test/sqlite_index_tests.jl`

**Why this is an issue:**
Large files with many behaviors grouped together make failures harder to isolate and increase merge conflict pressure.

**Evidence:**
- Sizes: 698 lines (`worksession_tests.jl`), 662 lines (`simos_macro_tests.jl`), 644 lines (`sqlite_index_tests.jl`).
- Testset counts are high/broad (`25`, `24`, `3` respectively).

**Improvement proposals:**

1. Add stable sectioning conventions in each file by behavior cluster.
2. Split by concern (session lifecycle, macro dispatch, sqlite rebuild/refresh/drift, etc.).
3. Move fixture/setup patterns into reusable focused helpers in `test/`.

**Expected impact:**
Faster triage and cleaner ownership boundaries in tests.

### Issue: Public README export list is inconsistent with real module exports

**Location:** `README.md`, `src/Simuleos.jl`

**Why this is an issue:**
Public contract drift increases user confusion and causes incorrect assumptions for API usage.

**Evidence:**
- README export section lists `each_commits` and `each_scopes` in exported symbols.
- `src/Simuleos.jl` export block does not export either symbol.

**Improvement proposals:**

1. Update README export list to exactly match `src/Simuleos.jl`.
2. Add a test/check comparing documented exports against source exports.
3. Generate export docs from source to remove manual drift.

**Expected impact:**
More trustworthy documentation and fewer API misuse errors.

## Top 5 prioritized improvements

1. Decompose `tape.jl` by concern.
2. Split `@simos` command spec metadata from dispatch logic.
3. Clarify runtime policy for placeholder includes.
4. Break large integration test files into behavior-focused units.
5. Eliminate README-vs-exports drift and enforce consistency checks.

## Codebase health summary

Overall code health is solid and trending better, but maintainability risk remains concentrated in a few dense modules and broad test files. The largest immediate wins are structural decomposition in tape/dispatch surfaces and tightening public API documentation accuracy. These changes can be incremental and behavior-preserving.
