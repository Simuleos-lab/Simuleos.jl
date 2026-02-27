## ~~Issue: SQLite index logic is too concentrated and duplicates full/incremental paths~~

Location: src/SQLiteIndex/SQLiteIndex.jl

Why this is an issue: Schema management, view creation, session upsert, tape scanning, drift
detection, and helper utilities are all in one 1227-line file, making changes risky and
reviews expensive. The same core logic appears in both rebuild and incremental paths, which
increases drift risk when one branch changes and the other is missed.

Evidence:

- Schema + views in same unit: _create_schema! and _recreate_public_views!
(src/SQLiteIndex/SQLiteIndex.jl:238-404)
- Repeated tape-scan/index loops: _index_session_tape! vs _index_session_tape_incremental!
(509-574 and 662-753)
- Repeated session write logic: insert/update branches in _index_session! and
_refresh_session! (480-494, 606-638)

Improvement proposals:

1. Extract shared helpers for session upsert and common tape-scan bookkeeping (small, safe).
2. Merge full/incremental scanning through a single scanner callback with strategy flags for
“verify prefix vs insert”.
3. Split file into schema.jl, session_index.jl, tape_index.jl, and sql_helpers.jl while
preserving API.

Expected impact: Lower regression risk in indexing, faster onboarding for contributors, and
easier targeted testing.

---------------------------------------------------------------------------------------------

## ~~Issue: @simos command dispatch is a long manual if/elseif chain~~

Location: src/SimosAPI/macro/dispatch.jl

Why this is an issue: A large imperative chain is hard to extend safely; command additions
require editing a fragile central block with repeated precondition checks. This pattern tends
to create subtle inconsistencies (e.g., missing do/kwargs guards for one command).

Evidence:

- Single large path matcher with repeated checks and routing
(src/SimosAPI/macro/dispatch.jl:1-228)

Improvement proposals:

1. Introduce tiny local helpers for common guard patterns (no_kwargs_no_do, no_posargs,
etc.).
2. Move to a declarative command table: path => (validator, handler).
3. Generate dispatch from a command spec shared with help/docs so routing rules and docs stay
aligned.

Expected impact: Safer command growth, less copy/paste validation code, and easier reasoning
about macro behavior.

---------------------------------------------------------------------------------------------

## ~~Issue: Settings macro handlers are highly repetitive boilerplate~~

Location: src/SimosAPI/macro/handlers.jl

Why this is an issue: Many handlers repeat the same structure (arg count checks, kwargs
validation, quote wrapper construction), which is error-prone and expensive to maintain. Small
semantic changes require touching many near-identical functions.

Evidence:

- Repeated pattern across settings handlers (93-239, 242-270)
- Duplicated kwargs validation logic in settings.registry.register (312-321) instead of fully
reusing _simos_validate_kwargs

Improvement proposals:

1. Add a shared helper for “validate + wrap runtime call” and migrate settings handlers
first.
2. Define settings command metadata (arity, allowed kwargs, runtime function) and generate
handlers from it.
3. Consolidate handler + dispatcher metadata so one source defines both validation and
routing.

Expected impact: Less boilerplate, fewer inconsistencies across settings commands, faster
feature additions.

---------------------------------------------------------------------------------------------

## ~~Issue: Git metadata capture swallows failures and produces noisy stderr in non-git contexts~~

Location: src/Kernel/gitmeta/git.jl (observed during Pkg.test())

Why this is an issue: Catch-all fallbacks hide failure modes ("", false, "unknown") while
shelling out to git describe emits fatal stderr lines in non-repo contexts. This reduces
observability and clutters test/CI output.

Evidence:

- Broad catches in git_hash, git_dirty, git_branch, git_describe (34-73)
- Shell command without stderr handling: read(\git -C ... describe ...`, String) (69-70`)
- Baseline test run passed but repeatedly printed fatal: not a git repository

Improvement proposals:

1. Narrow exception handling to expected git/repo errors and suppress/route stderr
intentionally.
2. Prefer LibGit2-based describe/metadata retrieval to avoid shell stderr leakage.
3. Return structured git metadata status (ok, missing_repo, detached, etc.) instead of silent
defaults.

Expected impact: Cleaner logs, clearer diagnostics, and safer downstream decisions based on
git metadata.
