# ==================================
# _fill_scope! — Build scope from raw variables into CaptureContext
# ==================================

"""
    _fill_scope!(simos, ctx, locals, globals, src_file, src_line, label; simignore_rules)

I1x — reads `simos` (via `project(simos).simuleos_dir`), operates on `ctx` (CaptureContext)

Build a Scope from raw locals/globals dictionaries into a CaptureContext.
Applies simignore filtering. Blob/lite classification is deferred to serialization.

# Arguments
- `simos::SimOs`: Core system state (for project root, settings)
- `ctx::CaptureContext`: The capture context to fill
- `locals::Dict{Symbol,Any}`: Local variables captured from caller
- `globals::Dict{Symbol,Any}`: Global variables captured from Main
- `src_file::String`: Source file path
- `src_line::Int`: Source line number
- `label::String`: Capture label
- `simignore_rules::Vector`: Simignore rules (from SessionRecorder)
"""
function _fill_scope!(
    simos::Kernel.SimOs,
    ctx::Kernel.CaptureContext,
    locals::Dict{Symbol,Any},
    globals::Dict{Symbol,Any},
    src_file::String,
    src_line::Int,
    label::String;
    simignore_rules::Vector
)
    # Combine capture label with any existing context labels (from @session_context)
    labels = vcat([label], ctx.scope.labels)

    # Build scope from dicts (locals override globals on collision)
    ctx.scope = Kernel.Scope(labels, locals, globals)

    # Apply simignore filtering
    Kernel.filter_vars!(ctx.scope) do name, sv
        !_should_ignore_var(name, sv.val, label, simignore_rules)
    end

    # Set capture metadata
    ctx.timestamp = Dates.now()
    ctx.data[:src_file] = src_file
    ctx.data[:src_line] = src_line
    ctx.data[:threadid] = Threads.threadid()

    return ctx
end

# ==================================
# write_commit_to_tape — Persist stage to tape
# ==================================

"""
    write_commit_to_tape(simos, session_label, commit_label, stage, meta)

I1x — reads `simos` (via `project(simos).simuleos_dir`), reads `stage.captures`

Write a commit record from the stage to the session's tape file.
Blob/lite classification happens at this point during serialization.

# Arguments
- `simos::SimOs`: Core system state (for project root)
- `session_label::String`: Session identifier
- `commit_label::String`: Commit label (can be empty)
- `stage::Stage`: The stage containing captures to commit
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
