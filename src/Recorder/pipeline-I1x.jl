# ==================================
# Variable Processing (helper)
# ==================================

# I1x — operates on `scope` (Scope object), writes scope.variables
function _process_var!(
        scope::Kernel.Scope,
        sym::Symbol, val::Any, src::Symbol,
        root_dir::String
    )
    name = string(sym)
    src_type = Kernel._get_type_string(val)

    if sym in scope.blob_set
        hash = Kernel._write_blob(root_dir, val)
        scope.variables[name] = Kernel.ScopeVariable(
            name=name, src_type=src_type,
            value=nothing, blob_ref=hash, src=src
        )
    elseif Kernel._is_lite(val)
        scope.variables[name] = Kernel.ScopeVariable(
            name=name, src_type=src_type,
            value=Kernel._liteify(val), blob_ref=nothing, src=src
        )
    else
        scope.variables[name] = Kernel.ScopeVariable(
            name=name, src_type=src_type,
            value=nothing, blob_ref=nothing, src=src
        )
    end
end

# ==================================
# _fill_scope! — Populate scope from raw variables
# ==================================

"""
    _fill_scope!(simos, scope, stage, locals, globals, src_file, src_line, label; simignore_rules)

I1x — reads `simos` (via `project(simos).simuleos_dir`), operates on `scope`, `stage`

Fill a Scope object from raw locals/globals dictionaries.
Applies simignore filtering, writes blobs, liteifies values.

# Arguments
- `simos::SimOs`: Core system state (for project root, settings)
- `scope::Scope`: The scope object to fill
- `stage::Stage`: The current stage (for blob_set tracking)
- `locals::Dict{Symbol,Any}`: Local variables captured from caller
- `globals::Dict{Symbol,Any}`: Global variables captured from Main
- `src_file::String`: Source file path
- `src_line::Int`: Source line number
- `label::String`: Scope label
- `simignore_rules::Vector`: Simignore rules (from SessionRecorder)
"""
function _fill_scope!(
    simos::Kernel.SimOs,
    scope::Kernel.Scope,
    stage::Kernel.Stage,
    locals::Dict{Symbol,Any},
    globals::Dict{Symbol,Any},
    src_file::String,
    src_line::Int,
    label::String;
    simignore_rules::Vector
)
    root_dir = Kernel.project(simos).simuleos_dir

    # Process globals first (can be overridden by locals)
    for (sym, val) in globals
        _should_ignore_var(sym, val, label, simignore_rules) && continue
        _process_var!(scope, sym, val, :global, root_dir)
    end

    # Process locals (override globals if same name)
    for (sym, val) in locals
        _should_ignore_var(sym, val, label, simignore_rules) && continue
        _process_var!(scope, sym, val, :local, root_dir)
    end

    # Set scope metadata
    scope.label = label
    scope.timestamp = Dates.now()
    scope.isopen = false
    scope.data[:src_file] = src_file
    scope.data[:src_line] = src_line
    scope.data[:threadid] = Threads.threadid()

    return scope
end

# ==================================
# write_commit_to_tape — Persist stage to tape
# ==================================

"""
    write_commit_to_tape(simos, session_label, commit_label, stage, meta)

I1x — reads `simos` (via `project(simos).simuleos_dir`), reads `stage.scopes`

Write a commit record from the stage to the session's tape file.

# Arguments
- `simos::SimOs`: Core system state (for project root)
- `session_label::String`: Session identifier
- `commit_label::String`: Commit label (can be empty)
- `stage::Stage`: The stage containing scopes to commit
- `meta::Dict`: Session metadata
"""
function write_commit_to_tape(
    simos::Kernel.SimOs,
    session_label::String,
    commit_label::String,
    stage::Kernel.Stage,
    meta::Dict
)
    root_dir = Kernel.project(simos).simuleos_dir

    # Build tape path via Core handlers (SSOT for .simuleos/ layout)
    root = Kernel.RootHandler(root_dir)
    session = Kernel.SessionHandler(root, session_label)
    tape = Kernel.TapeHandler(session)
    tape_path = Kernel._tape_path(tape)
    mkpath(dirname(tape_path))

    open(tape_path, "a") do io
        _write_commit_record(io, session_label, commit_label, stage, meta, root_dir)
        println(io)
    end

    # Warn if tape file is getting large
    tape_size = filesize(tape_path)
    if tape_size > MAX_TAPE_SIZE_BYTES
        @warn "Tape file is large" path=tape_path size_mb=round(tape_size / 1_000_000; digits=1)
    end
end
