# TapeIO Raw Search Beneficiaries (Pre-Implementation)

## Context

- Goal under discussion: support string-first search on tape `.jsonl` records, then parse only candidate lines.
- Motivation: avoid full JSON parse cost when looking for a specific record by known `key:value` content (especially hashes), while still doing a parsed double-check to avoid false positives.

## Current Behavior

- `TapeIO` parses every non-empty line during iteration (`src/Kernel/tapeio/tape.jl:155`, `src/Kernel/tapeio/tape.jl:175`, `src/Kernel/tapeio/tape.jl:181`).
- `ScopeTapes` typed iteration filters commit rows only after raw JSON parse (`src/Kernel/scopetapes/read.jl:22`).
- There is no built-in raw-line prefilter API yet.

## Systems That Can Profit (Priority Order)

### 1) ScopeReader selective reads (`latest_scope`, `each_scopes`, `scope_table`)

- `each_scopes` filters by `commit_label` and `src_file` after parsing commits (`src/ScopeReader/ScopeReader.jl:45`, `src/ScopeReader/ScopeReader.jl:53`).
- `latest_scope` scans through matches to return the last scope (`src/ScopeReader/ScopeReader.jl:75`, `src/ScopeReader/ScopeReader.jl:82`).
- These filters are common in user-facing workflows:
- `examples/workflows/005-pipeline-stage-lineage.jl:32`
- `examples/workflows/005-pipeline-stage-lineage.jl:56`
- `examples/workflows/003-recover-and-resume.jl:45`
- The project notes explicitly define pipeline retrieval by `commit_label + src_file` (`notes/index/006-workflow-surfaces.md:56`, `notes/index/006-workflow-surfaces.md:57`).

Why it benefits:

- `commit_label` and `src_file` appear as plain JSON strings inside commit lines.
- A raw-line prefilter can skip most commit parses in long session tapes.
- `latest_scope` especially benefits because it is a selective lookup, not a full scan for all records.

### 2) BlobStorage shard tape scans / backfill index checks

- Blob metadata tapes are sharded by hash prefix (`src/Kernel/core/fs.jl:39`).
- Backfill reads shard rows and parses all rows to collect existing `blob_hash` values (`src/Kernel/blobstorage/blob.jl:86`, `src/Kernel/blobstorage/blob.jl:91`).
- `blob_record` lines include `blob_hash` directly (`src/Kernel/blobstorage/blob.jl:55`, `src/Kernel/blobstorage/blob.jl:57`).

Why it benefits:

- Hash lookup is a strong string-prefilter use case.
- Sharding already narrows by first two hash chars; raw-line matching can narrow further by full hash.
- This path may scan many shard rows during `blob_tapes_backfill!`.

### 3) Hash-based scope record lookup (future / natural next user)

- Hashed scope variables are serialized with `"value_hash"` (`src/Kernel/scopetapes/write.jl:41`, `src/Kernel/scopetapes/write.jl:46`).
- They parse back into `HashedScopeVariable` (`src/Kernel/scopetapes/base.jl:18`).
- There is no dedicated query API for `value_hash` yet.

Why it benefits:

- This is the exact workflow motivating the feature: prefilter by hash substring, then parse candidate commit records and verify nested fields.
- False positives are expected and acceptable if the parsed predicate is the final authority.

### 4) Tape maintenance / migration tooling

- Project notes call out maintenance workflows that rewrite/consolidate tape data (`notes/index/006-workflow-surfaces.md:7`, `notes/index/006-workflow-surfaces.md:12`).

Why it benefits:

- Maintenance tools commonly filter by `"type"` / `"schema"` and can avoid parsing irrelevant rows.

## Systems With Limited Benefit

- `WorkSession` commit write paths are append-only and do not perform tape searching (`src/WorkSession/macros.jl:145`, `src/WorkSession/macros.jl:209`).
- Full unfiltered iteration (`each_commits` when caller truly wants all commits) still needs full parsing.

## Interface Requirements (Derived From Real Callers)

- Make it generic, not hash-specific.
- Support both `TapeIO("file.jsonl")` and fragmented tape directories (`fragN.jsonl`).
- Separate two stages explicitly:
- raw string prefilter (cheap, no parse)
- parsed predicate / verifier (exact match, handles false positives)
- Support retrieval modes needed by callers:
- first match
- last match
- stream/all matches
- Preserve tape order semantics by default (important for lineage and `latest_scope`).
- Return enough context for debugging and higher-level wrappers:
- parsed record
- optionally raw line
- source file path
- line number
- Keep initial API in `Kernel` (internal), then add focused wrappers in `ScopeReader` / `BlobStorage`.

## Suggested Layering (Implementation Order)

### Layer 1: Kernel / TapeIO primitive

- Minimal primitive for raw-line scanning over a `TapeIO`.
- Should centralize:
- single-file vs fragmented traversal
- newline handling / empty-line skip
- source file + line counting
- optional candidate parsing

### Layer 2: ScopeReader optimization

- Optimize `latest_scope(...; commit_label=..., src_file=...)` using raw-line prefilter on known strings.
- Keep current semantics and error messages.
- Fallback to normal parse path when no selective filters are provided.

### Layer 3: BlobStorage helper

- Add a targeted helper for shard lookup / presence checks using `blob_hash` prefilter.
- Reuse the same Kernel primitive instead of ad-hoc file scanning.

## Candidate API Shapes (Minimal to Richer)

### Minimal primitive

- `Kernel.each_tape_lines(tape::TapeIO)` -> iterate raw lines with source metadata

### Search helper

- `Kernel.find_tape_record(tape::TapeIO; contains::Vector{String}=String[], parse_if::Function=..., match::Function=...)`

### Stream helper

- `Kernel.filter_tape_records(tape::TapeIO; contains=..., parsed_predicate=...)`

Notes:

- Start with substring `contains` (AND semantics) before adding regex.
- Regex can be added later if real users need it.

## Design Constraints To Keep In Mind

- False positives are expected when prefiltering on substrings.
- Do not rely on JSON key order for correctness; string prefilter is only a candidate gate.
- Metadata rows (`"type":"tape_metadata"`) should be cheap to skip.
- Malformed JSON handling should remain consistent with current `TapeIO` behavior when a candidate line is parsed.

## Recommended First Consumer To Implement

- `ScopeReader.latest_scope(...; commit_label=..., src_file=...)`

Reason:

- It is user-facing and already central to documented pipeline and recovery workflows.
- It uses exactly the selective-read pattern this feature is meant to accelerate.
- It helps validate API ergonomics before adding BlobStorage-specific helpers.
