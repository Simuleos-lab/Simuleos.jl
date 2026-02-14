# ScopeTapes write orchestration (all I1x)
# Explicit dependencies are passed as arguments.

"""
    _fill_scope!(ctx, locals, globals, src_file, src_line, label; simignore_rules)

Build a `Scope` from raw locals/globals dictionaries into a `CaptureContext`.
Applies simignore filtering and fills capture metadata.
"""
function _fill_scope!(
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

    ctx.scope = filter_rules(ctx.scope, simignore_rules)

    ctx.timestamp = Dates.now()
    ctx.data[:src_file] = src_file
    ctx.data[:src_line] = src_line
    ctx.data[:threadid] = Threads.threadid()

    return ctx
end

"""
    commit_stage!(tape::TapeIO, storage::BlobStorage, stage::ScopeStage, meta::Dict{String, Any}; commit_label="")

Build a commit payload from the stage and append it to tape.
Blob/lite classification happens during stage serialization.
"""
function commit_stage!(
    tape::TapeIO,
    storage::BlobStorage,
    stage::ScopeStage,
    meta::Dict{String, Any};
    commit_label::String = ""
)
    record = _stage_to_commit_dict(commit_label, stage, meta, storage)
    append!(tape, record)

    tape_size = filesize(tape.path)
    if tape_size > MAX_TAPE_SIZE_BYTES
        @warn "Tape file is large" path=tape.path size_mb=round(tape_size / 1_000_000; digits=1)
    end

    return nothing
end
