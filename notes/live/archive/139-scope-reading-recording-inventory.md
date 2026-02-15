# Scope Reading and Recording Inventory

Date: 2026-02-14
Repo scan scope: `src/` (plus validation against tests/index notes)

## Objects

- `Simuleos.Kernel.ScopeVariable`: captured variable value + source (`src/Kernel/core/types-I0x.jl:27`)
    - #FEEDBACK
        - this are the modes a ScopeVariable will be
            - in-memory wrapper
                - hold actual value
            - blob storaged
                - do not hold the value, but a link to blobstorage
            - a placeholder
                - no value, only metadata
                - usage: we keep the fact that it existed in the original scope
            - we need to discusse how we implement this
- `Simuleos.Kernel.Scope`: runtime scope container (`src/Kernel/core/types-I0x.jl:37`)
- `Simuleos.Kernel.CaptureContext`: one pending capture + metadata/blob requests (`src/Kernel/core/types-I0x.jl:154`)
    - #FEEDBACK
        - We need to revise this
        - in conjuction with `ScopeStage` and Scope itself
        - I think we must just mirror what will be at the tape
            - avoid unnecessary nesting
- `Simuleos.Kernel.ScopeStage`: staged captures pending commit (`src/Kernel/core/types-I0x.jl:166`)
    - #FEEDBACK
        - We need to revise this
        - in conjuction with `ScopeStage`
- `Simuleos.Kernel.VariableRecord`: typed variable row for tape reads (`src/Kernel/core/types-I0x.jl:76`)
- `Simuleos.Kernel.ScopeRecord`: typed scope row for tape reads (`src/Kernel/core/types-I0x.jl:63`)
    - #FEEDBACK
        - We need to revise this
        - we need to converge recording and reading produced objects
        - in the intermediate, we have only raw Dict
- `Simuleos.Kernel.CommitRecord`: typed commit row for tape reads (`src/Kernel/core/types-I0x.jl:51`)
    - #FEEDBACK
        - We need to revise this
        - we need to converge recording and reading produced objects
- `Simuleos.Kernel.TapeIO`: JSONL tape handle (`src/Kernel/core/types-I0x.jl:93`)
    - #FEEDBACK
        - nice and clear
- `Simuleos.Kernel.BlobStorage`: blob driver (`src/Kernel/core/types-I0x.jl:14`)
    - #FEEDBACK
        - nice and clear driver
- `Simuleos.Kernel.BlobRef`: blob reference (`src/Kernel/core/types-I0x.jl:238`)
    - #FEEDBACK
        - nice and clear
- `Simuleos.Kernel.WorkSession`: active recording session state (`src/Kernel/core/types-I0x.jl:177`)
    - #FEEDBACK
        - this is the next level
        - I want to also refactor Sission handling
        - We have session aware subsystems and "global" subsystems
- `Simuleos.Kernel.SIMOS` (`const Ref`): global active app state (`src/Kernel/core/SIMOS-I3x.jl:4`)
    - #FEEDBACK
        - this is the next level

## Recording APIs and Functions

- #FEEDBACK
    - we will discuse about the types first and deal with the functions later...

- `Simuleos.@session_init`, `Simuleos.WorkSession.session_init` (`src/WorkSession/macros-I3x.jl:5`, `src/WorkSession/session-I3x.jl:24`)
- `Simuleos.@session_store`, helper `_extract_symbols` (`src/WorkSession/macros-I3x.jl:16`, `src/WorkSession/macros-I0x.jl:4`)
- `Simuleos.@session_context` (`src/WorkSession/macros-I3x.jl:40`)
- `Simuleos.@session_capture`, function form `session_capture` (`src/WorkSession/macros-I3x.jl:67`, `src/WorkSession/macros-I3x.jl:137`)
- `Simuleos.@session_commit`, function form `session_commit` (`src/WorkSession/macros-I3x.jl:106`, `src/WorkSession/macros-I3x.jl:158`)
- Worksession commit bridge `_commit_worksession!` (`src/WorkSession/macros-I2x.jl:3`)
- Session access/metadata helpers `_get_worksession`, `_capture_worksession_metadata` (`src/WorkSession/session-I3x.jl:10`, `src/WorkSession/session-I0x.jl:14`)
- Simignore controls `simignore!`, `set_simignore_rules!`, `append_simignore_rule!`, `_should_ignore`, `check_rules` (`src/WorkSession/simignore-I3x.jl:8`, `src/WorkSession/simignore-I1x.jl:16`, `src/WorkSession/simignore-I1x.jl:32`, `src/WorkSession/simignore-I1x.jl:48`, `src/WorkSession/simignore-I0x.jl:15`)
- Scope fill + commit orchestrators `_fill_scope!`, `commit_stage!` (`src/Kernel/scopetapes/write-I1x.jl:10`, `src/Kernel/scopetapes/write-I1x.jl:38`)
- Commit payload builders `_stage_to_commit_dict`, `_capture_to_scope_dict`, `_scope_var_to_dict`, `_compute_blob_refs`, `_get_type_string` (`src/Kernel/scopetapes/write-I0x.jl:67`, `src/Kernel/scopetapes/write-I0x.jl:40`, `src/Kernel/scopetapes/write-I0x.jl:21`, `src/Kernel/scopetapes/write-I0x.jl:10`, `src/Kernel/scopetapes/write-I0x.jl:6`)
- Scope constructors/capture/filter core: `Scope(...)` overloads, `@scope_capture`, `_should_ignore_var`, `filter_rules` (`src/Kernel/scoperias/base-I0x.jl:5`, `src/Kernel/scoperias/base-I0x.jl:8`, `src/Kernel/scoperias/base-I0x.jl:11`, `src/Kernel/scoperias/base-I0x.jl:14`, `src/Kernel/scoperias/macros-I0x.jl:10`, `src/Kernel/scoperias/ops-I0x.jl:87`, `src/Kernel/scoperias/ops-I0x.jl:116`)
- Tape write path: `append!`, `_normalize_tape_value`, `_write_json` overloads (`src/Kernel/tapeio/tape-I0x.jl:20`, `src/Kernel/tapeio/tape-I0x.jl:4`, `src/Kernel/tapeio/json-I0x.jl:5`, `src/Kernel/tapeio/json-I0x.jl:8`, `src/Kernel/tapeio/json-I0x.jl:11`, `src/Kernel/tapeio/json-I0x.jl:14`, `src/Kernel/tapeio/json-I0x.jl:28`, `src/Kernel/tapeio/json-I0x.jl:38`)
- Blob write path: `blob_write` overloads, `blob_ref`, `_hash_key`, `_serialize_bytes`, `exists` overloads (`src/Kernel/blobstorage/blob-I0x.jl:39`, `src/Kernel/blobstorage/blob-I2x.jl:4`, `src/Kernel/blobstorage/blob-I0x.jl:27`, `src/Kernel/blobstorage/blob-I0x.jl:6`, `src/Kernel/blobstorage/blob-I0x.jl:21`, `src/Kernel/blobstorage/blob-I0x.jl:31`, `src/Kernel/blobstorage/blob-I0x.jl:35`)

## Reading APIs and Functions

- Typed tape reader `iterate_tape`, `Base.collect(Vector{CommitRecord}, ...)` (`src/Kernel/scopetapes/read-I1x.jl:9`, `src/Kernel/scopetapes/read-I1x.jl:14`)
- Raw-to-typed conversion `_raw_to_commit_record`, `_raw_to_scope_record`, `_raw_to_variable_record`, `_as_string_any_dict` (`src/Kernel/scopetapes/read-I0x.jl:50`, `src/Kernel/scopetapes/read-I0x.jl:26`, `src/Kernel/scopetapes/read-I0x.jl:16`, `src/Kernel/scopetapes/read-I0x.jl:4`)
- Raw tape iteration `Base.iterate(tape::TapeIO)` overloads (`src/Kernel/tapeio/tape-I0x.jl:30`, `src/Kernel/tapeio/tape-I0x.jl:37`)
- Blob reads `blob_read` overloads (`src/Kernel/blobstorage/blob-I0x.jl:67`, `src/Kernel/blobstorage/blob-I0x.jl:75`, `src/Kernel/blobstorage/blob-I2x.jl:9`, `src/Kernel/blobstorage/blob-I2x.jl:14`)

## Additional Scope Ops (in-memory)

- `getvariable`, `setvariable!`, `variables`, `hasvar`, `filter_vars`, `filter_vars!`, `filter_labels`, `filter_labels!`, `merge_scopes`, plus `Base.length`, `Base.isempty`, `Base.iterate`, `Base.eltype` for `Scope` (`src/Kernel/scoperias/ops-I0x.jl:8`, `src/Kernel/scoperias/ops-I0x.jl:9`, `src/Kernel/scoperias/ops-I0x.jl:10`, `src/Kernel/scoperias/ops-I0x.jl:16`, `src/Kernel/scoperias/ops-I0x.jl:30`, `src/Kernel/scoperias/ops-I0x.jl:39`, `src/Kernel/scoperias/ops-I0x.jl:49`, `src/Kernel/scoperias/ops-I0x.jl:54`, `src/Kernel/scoperias/ops-I0x.jl:63`, `src/Kernel/scoperias/ops-I0x.jl:17`, `src/Kernel/scoperias/ops-I0x.jl:18`, `src/Kernel/scoperias/ops-I0x.jl:21`, `src/Kernel/scoperias/ops-I0x.jl:22`, `src/Kernel/scoperias/ops-I0x.jl:23`)
