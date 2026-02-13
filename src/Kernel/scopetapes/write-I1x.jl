# ScopeTapes write orchestration (all I1x)
# Explicit dependencies are passed as arguments.

"""
    _fill_scope!(simos, ctx, locals, globals, src_file, src_line, label; simignore_rules)

Build a `Scope` from raw locals/globals dictionaries into a `CaptureContext`.
Applies simignore filtering and fills capture metadata.
"""
function _fill_scope!(
    simos::SimOs,
    ctx::CaptureContext,
    locals::Dict{Symbol, Any},
    globals::Dict{Symbol, Any},
    src_file::String,
    src_line::Int,
    label::String;
    simignore_rules::Vector
)
    labels = vcat([label], ctx.scope.labels)
    ctx.scope = Scope(labels, locals, globals)

    filter_vars!((name, sv) -> !_should_ignore_var(name, sv.val, label, simignore_rules), ctx.scope)

    ctx.timestamp = Dates.now()
    ctx.data[:src_file] = src_file
    ctx.data[:src_line] = src_line
    ctx.data[:threadid] = Threads.threadid()

    return ctx
end

"""
    write_commit_to_tape(simos, session_label, commit_label, stage, meta)

Write a commit record from the stage to the session's tape file.
Blob/lite classification happens at serialization time.
"""
function write_commit_to_tape(
    simos::SimOs,
    session_label::String,
    commit_label::String,
    stage::Stage,
    meta::Dict
)
    root_dir = project(simos).simuleos_dir

    root = RootHandler(root_dir)
    session = SessionHandler(root, session_label)
    tape_handler = TapeHandler(session)
    tape_path = _tape_path(tape_handler)
    mkpath(dirname(tape_path))

    open(tape_path, "a") do io
        _write_commit_record(io, session_label, commit_label, stage, meta, root_dir)
        println(io)
    end

    tape_size = filesize(tape_path)
    if tape_size > MAX_TAPE_SIZE_BYTES
        @warn "Tape file is large" path=tape_path size_mb=round(tape_size / 1_000_000; digits=1)
    end

    return nothing
end
