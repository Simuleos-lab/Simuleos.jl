# Codebase Quality Review (Pass 2)

Scope reviewed: `src/`, `test/`, and API/docs consistency in `README.md`.

### Issue: Tape I/O implementation has too many responsibilities in one file

**Location:** `src/Kernel/Infra/tapeio/tape.jl`

**Why this is an issue:**
The same module currently owns path/fragment management, append semantics, iterator protocol, forward scan, reverse scan, filtering APIs, and table helpers. This increases cognitive load and makes changes riskier because unrelated concerns sit in one edit surface.

**Evidence:**
- File size: 689 lines.
- 35+ functions in one file, spanning path helpers (`_fragment_files`), write path (`append!`), iteration (`Base.iterate`), reverse scanning (`_scan_jsonl_file_reverse!`), and query helpers (`findfirst_tape_record`, `table_tape_records`).
- Function clusters are spread across distant regions (e.g., lines 10-160, 230-403, 411-689).

**Improvement proposals:**

1. Small: add clear internal section boundaries and a short “module map” comment at the top.
2. Medium: split into `tape_paths.jl`, `tape_append_iter.jl`, and `tape_query.jl` while preserving current API names.
3. Larger: define a tiny internal scanner interface reused by both forward and reverse scans to remove duplicated flow logic.

**Expected impact:**
Easier maintenance, safer refactors, and faster onboarding for contributors touching tape logic.

### Issue: `@simos` command spec registry is centralized and bulky

**Location:** `src/SimosAPI/macro/dispatch.jl`

**Why this is an issue:**
A large static command table plus dispatch/guard/help logic in one file makes command evolution error-prone (especially when adding/removing commands). Changes require editing a dense section where mistakes are easy to miss.

**Evidence:**
- File size: 492 lines.
- `_SIMOS_COMMAND_SPECS` occupies a long contiguous block (roughly lines 69-349).
- Same file also contains guard logic, invocation routing, and help text generation (lines 1-67 and 351-492).

**Improvement proposals:**

1. Small: extract `_SIMOS_COMMAND_SPECS` into a dedicated file and keep dispatch functions in `dispatch.jl`.
2. Medium: split help-generation into `help_catalog.jl` to isolate presentation from dispatch behavior.
3. Larger: generate command specs from a compact declarative table validated at load-time (duplicate path, mode compatibility, required args).

**Expected impact:**
Cleaner macro surface maintenance and lower risk of command-registry drift.

### Issue: Runtime module still includes scaffold placeholders

**Location:** `src/Kernel/Kernel.jl`, `src/Kernel/Classes/*/placeholder*.jl`, `src/Kernel/Workflows/*/placeholder.jl`

**Why this is an issue:**
Including placeholder files in production module assembly blurs the line between implemented and planned surfaces, which can confuse contributors and increase accidental coupling to unfinished lanes.

**Evidence:**
- `Kernel.jl` includes placeholder files directly (lines 36, 39-40, 59-60).
- Placeholder files are comment-only scaffolds:
  - `Classes/src/placeholder.jl`
  - `Classes/rec/placeholder.jl`
  - `Classes/snap/shared_placeholder.jl`
  - `Workflows/contextref/placeholder.jl`
  - `Workflows/sharedstate/placeholder.jl`

**Improvement proposals:**

1. Small: annotate these includes as non-runtime scaffolds with explicit roadmap links.
2. Medium: stop including placeholder files in `Kernel.jl`; keep roadmap intent in docs/notes.
3. Larger: introduce a feature-lane registry where planned lanes are declared but not loaded unless explicitly enabled.

**Expected impact:**
Clearer architecture boundaries and less ambiguity about what is truly operational.

### Issue: Integration tests are concentrated in very large files

**Location:** `test/worksession_tests.jl`, `test/simos_macro_tests.jl`, `test/sqlite_index_tests.jl`

**Why this is an issue:**
Very large test files make targeted ownership and debugging harder, and increase merge conflict risk when multiple contributors edit the same surface.

**Evidence:**
- File sizes:
  - `worksession_tests.jl`: 698 lines
  - `simos_macro_tests.jl`: 662 lines
  - `sqlite_index_tests.jl`: 644 lines
- `@testset` density:
  - `worksession_tests.jl`: 25 testsets
  - `simos_macro_tests.jl`: 24 testsets
  - `sqlite_index_tests.jl`: 3 very broad testsets

**Improvement proposals:**

1. Small: add high-level section headers and stable naming conventions for testset groupings.
2. Medium: split each large file by behavior family (e.g., lifecycle, error paths, macro syntax, sqlite refresh/drift).
3. Larger: move to “one concern per file” with shared helpers in `test/test-init.jl` and explicit fixture builders.

**Expected impact:**
Faster failure triage, reduced conflict rate, and clearer test ownership.

### Issue: README export list is still out of sync with real top-level exports

**Location:** `README.md`, `src/Simuleos.jl`

**Why this is an issue:**
Documentation drift at the public API boundary causes user confusion and integration mistakes, especially when contributors trust README as the contract.

**Evidence:**
- README export section lists `each_commits` and `each_scopes` (lines 206-210).
- `src/Simuleos.jl` exports do not include those symbols (lines 15-20).

**Improvement proposals:**

1. Small: update README export list to exactly match current exports.
2. Medium: add a doc consistency test that compares documented export names to `src/Simuleos.jl`.
3. Larger: auto-generate the exported-symbol list into README from source metadata.

**Expected impact:**
More reliable docs and fewer API expectation mismatches.

### Issue: Test driver contains a non-informative sentinel assertion

**Location:** `test/runtests.jl`

**Why this is an issue:**
A placeholder assertion (`@test 1 == 1`) adds noise without validating behavior, which can mislead readers about intentional smoke coverage.

**Evidence:**
- `test/runtests.jl` has a dedicated top-level testset with only `@test 1 == 1` (lines 11-13).

**Improvement proposals:**

1. Small: remove the sentinel assertion and keep only included real test files.
2. Medium: replace with a meaningful package-load smoke check.
3. Larger: add a tiny end-to-end smoke test that validates one real `@simos` record/read roundtrip.

**Expected impact:**
Cleaner test signal and better confidence from top-level test harness behavior.

## Top 5 Prioritized Improvements

1. Split `tape.jl` by concern (paths/append-iterate/query).
2. Break `@simos` command registry metadata out of `dispatch.jl`.
3. Decide and enforce placeholder loading policy in `Kernel.jl`.
4. Split large integration test files into behavior-focused units.
5. Fix README export drift and add a docs-vs-exports consistency check.

## Codebase Health Summary

The codebase is actively improving (notably around error-path strictness and macro handler decomposition), but maintainability risk is still concentrated in a few dense files and broad test files. Main risk areas are tape/query internals, command-dispatch metadata concentration, and architecture signaling around placeholders. A focused incremental cleanup on those areas should yield high quality gains without changing public behavior.
